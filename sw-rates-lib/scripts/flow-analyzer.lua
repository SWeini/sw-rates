local configuration = require("scripts.configuration")
local configuration_util = require("configuration-util")
local base = require("base-util")
local flow_item = require("flow-item")
local flow_fluid = require("flow-fluid")

---@class (strict) Rates.Analyzer.Context
---Entities that need their inputs determined
---@field required_entities table<uint64, LuaEntity>
---Entities that can place items that are difficult to search for
---@field item_placer_entities table<uint64, LuaEntity>
---Entities that can drop items at specific locations
---@field item_drop_locations table<Rates.Analyzer.ItemLocation, table<uint64, LuaEntity>>
---Index into item_segments for all analyzed item locations
---@field item_locations table<Rates.Analyzer.ItemLocation, integer>
---All item segments with content and graph structure
---@field item_segments Rates.Analyzer.ItemSegment[]
---Index into fluid_segments for all analyzed fluid boxes
---@field fluid_boxes table<Rates.Analyzer.FluidLocation, integer>
---All fluid segments with content and graph structure
---@field fluid_segments Rates.Analyzer.FluidSegment[]
---Analyzed entities
---@field entities table<uint64, { entity: LuaEntity, outputs: Rates.Analyzer.EntityOutputs }>

---@class (strict) Rates.Analyzer.ItemWithQuality
---@field item LuaItemPrototype
---@field quality LuaQualityPrototype

---container, crafting-machine: e/unit_number/inventory_index
---
---transport-tbelt-connectable: b/unit_number/transport_line_index
---
---map: m/surface/x/y (item-on-ground)
---
---linked-container: l/name/id
---@alias Rates.Analyzer.ItemLocation string
---@alias Rates.Analyzer.ItemSet table<string, Rates.Analyzer.ItemWithQuality>
---@alias Rates.Analyzer.ItemFilter fun(item: Rates.Analyzer.ItemWithQuality): boolean
---@alias Rates.Analyzer.FilteredItemForwardSpecification { filter: Rates.Analyzer.ItemFilter, pass: Rates.Analyzer.ItemLocation[], fail: Rates.Analyzer.ItemLocation[] } | { pass: Rates.Analyzer.ItemLocation[] }
---@alias Rates.Analyzer.FilteredItemForward { entity: LuaEntity, filter?: Rates.Analyzer.ItemFilter, pass: table<Rates.Analyzer.ItemLocation, Rates.Analyzer.ItemSegment>, fail: table<Rates.Analyzer.ItemLocation, Rates.Analyzer.ItemSegment> }

---@class (strict) Rates.Analyzer.ItemSegment
---@field content Rates.Analyzer.ItemSet
---@field item_drop_entities table<uint64, { type: string, entity: LuaEntity }>
---@field dependent_entities table<uint64, { type: string, entity: LuaEntity }>
---@field filtered_forward_segments table<uint64, Rates.Analyzer.FilteredItemForward>

---@class (strict) Rates.Analyzer.FluidWithTemperature
---@field fluid LuaFluidPrototype
---@field temperature number

---unit_number/fluid_box_index/pipe_connection_index
---@alias Rates.Analyzer.FluidLocation string
---@alias Rates.Analyzer.FluidSet table<string, Rates.Analyzer.FluidWithTemperature>
---@alias Rates.Analyzer.FluidFilter fun(fluid: Rates.Analyzer.FluidWithTemperature): boolean
---@alias Rates.Analyzer.FilteredFluidForward { entity: LuaEntity, filter?: Rates.Analyzer.FluidFilter, pass: table<Rates.Analyzer.FluidLocation, Rates.Analyzer.FluidSegment> }

---@class (strict) Rates.Analyzer.FluidSegment
---@field content Rates.Analyzer.FluidSet
---@field dependent_entities table<uint64, LuaEntity>
---@field filtered_forward_segments table<uint64, Rates.Analyzer.FilteredFluidForward>

---@class (strict) Rates.Analyzer.EntityInputs
---@field fluid_boxes? table<integer, Rates.Analyzer.FluidSet>
---@field items? Rates.Analyzer.ItemSet

---@class (strict) Rates.Analyzer.EntityOutputs
---@field required_fluid_box_inputs? table<integer, "once"|"on-change">
---@field fluid_box_outputs? table<integer, Rates.Analyzer.FluidSet>
---@field required_items? "once"|"on-change"
---@field items? Rates.Analyzer.ItemSet
---@field drop_items? Rates.Analyzer.ItemSet

---@class (strict) Rates.Analyzer.FluidBoxConnection
---@field fluidbox LuaFluidBox
---@field index uint32
---@field pipe integer

local get_entity_type = base.get_entity_type

---@return Rates.Analyzer.Context
local function create_context()
    ---@type Rates.Analyzer.Context
    return {
        required_entities = {},
        item_placer_entities = {},
        item_drop_locations = {},
        item_locations = {},
        item_segments = {},
        fluid_boxes = {},
        fluid_segments = {},
        entities = {},
        item_placers = {},
    }
end

---@param context Rates.Analyzer.Context
---@param entity LuaEntity
---@return boolean
local function initialize_entity(context, entity)
    local unit_number = entity.unit_number ---@cast unit_number -nil
    local entities = context.entities
    if (entities[unit_number]) then
        return false
    else
        entities[unit_number] = { entity = entity, outputs = configuration.analyze_flow(entity, {}) }
        return true
    end
end

---@param dirty_entities table<uint64, LuaEntity>
---@param context Rates.Analyzer.Context
---@param id string
---@return Rates.Analyzer.ItemSegment
local function get_item_segment(dirty_entities, context, id)
    local segment_id = context.item_locations[id]
    if (not segment_id) then
        segment_id = #context.item_segments + 1
        context.item_locations[id] = segment_id
        context.item_segments[segment_id] = {
            content = {},
            item_drop_entities = {},
            dependent_entities = {},
            filtered_forward_segments = {},
        }

        local drop_entities = context.item_drop_locations[id]
        if (drop_entities) then
            for unit_number, entity in pairs(drop_entities) do
                dirty_entities[unit_number] = entity
            end
        end
    end

    return context.item_segments[segment_id]
end

---@param context Rates.Analyzer.Context
---@param entity LuaEntity
local function add_required_entity(context, entity)
    if (entity.to_be_deconstructed()) then
        return
    end
    context.required_entities[entity.unit_number] = entity
end

---@param context Rates.Analyzer.Context
---@param entity LuaEntity
local function add_item_placer(context, entity)
    if (entity.to_be_deconstructed()) then
        return
    end
    context.item_placer_entities[entity.unit_number] = entity
end

---@param context Rates.Analyzer.Context
---@param entity LuaEntity
---@param id string
local function add_item_drop_entity(context, id, entity)
    local dropping_entities = context.item_drop_locations[id]
    if (not dropping_entities) then
        dropping_entities = {}
        context.item_drop_locations[id] = dropping_entities
    end
    dropping_entities[entity.unit_number] = entity
end

---@param context Rates.Analyzer.Context
---@param entity LuaEntity
local function initialize_item_placer(context, entity)
    local id = flow_item.get_item_placer_drop_location(entity)
    if (id) then
        add_item_drop_entity(context, id, entity)
    end
end

---@param outputs Rates.Analyzer.EntityOutputs
---@return boolean
local function is_dynamic(outputs)
    if (outputs.required_items == "on-change") then
        return true
    end

    local fluids = outputs.required_fluid_box_inputs
    if (fluids) then
        for _, mode in pairs(fluids) do
            if (mode == "on-change") then
                return true
            end
        end
    end

    return false
end

---@param context Rates.Analyzer.Context
---@param entity LuaEntity
---@return Rates.Analyzer.EntityInputs
local function get_entity_inputs(context, entity)
    ---@type Rates.Analyzer.EntityInputs
    local result = {
        fluid_boxes = {}
    }

    local fluidbox = entity.fluidbox
    for i = 1, #fluidbox do
        local content = {} ---@type Rates.Analyzer.FluidSet
        local connections = fluidbox.get_pipe_connections(i)
        for p = 1, #connections do
            local id = flow_fluid.fluidbox_connection_id({ fluidbox = fluidbox, index = i, pipe = p })
            local segment_id = context.fluid_boxes[id]
            if (segment_id) then
                local segment = context.fluid_segments[segment_id]
                for fluid_id, fluid in pairs(segment.content) do
                    content[fluid_id] = fluid
                end
            end
        end

        result.fluid_boxes[i] = content
    end

    local item_location_id = flow_item.item_location_entity(entity, "I")
    local item_segment_id = context.item_locations[item_location_id]
    if (item_segment_id) then
        local item_segment = context.item_segments[item_segment_id]
        result.items = item_segment.content
    end

    return result;
end

local all_lanes = { "L", "R" }

---@param dirty_entities table<uint64, LuaEntity>
---@param dirty_belts table<uint64, LuaEntity>
---@param context Rates.Analyzer.Context
---@param entity LuaEntity
---@param force_input_detection boolean
local function belt_trace_backwards(dirty_entities, dirty_belts, context, entity, force_input_detection)
    local type = base.get_entity_type(entity)
    local unit_number = entity.unit_number ---@cast unit_number -nil

    local changed = false
    local outputs = flow_item.belt_output_connections(entity, type)
    for from, to in pairs(outputs) do
        local to_segment_id = context.item_locations[to]
        if (to_segment_id) then
            if (not context.item_locations[from]) then
                changed = true
            end
            local from_segment = get_item_segment(dirty_entities, context, from)
            from_segment.filtered_forward_segments[unit_number] = {
                entity = entity,
                filter = nil,
                pass = { [to] = context.item_segments[to_segment_id] },
                fail = {}
            }
        end
    end
    local inner = flow_item.belt_inner_connections(entity, type)
    if (table_size(inner) > 0) then
        changed = false
    end
    for from, filter in pairs(inner) do
        local pass = {} ---@type table<string, Rates.Analyzer.ItemSegment>
        local fail = {} ---@type table<string, Rates.Analyzer.ItemSegment>
        local has_target = false
        for _, id in ipairs(filter.pass) do
            local segment_id = context.item_locations[id]
            if (segment_id) then
                pass[id] = context.item_segments[segment_id]
                has_target = true
            end
        end
        for _, id in ipairs(filter.fail or {}) do
            local segment_id = context.item_locations[id]
            if (segment_id) then
                fail[id] = context.item_segments[segment_id]
                has_target = true
            end
        end
        if (has_target) then
            if (not context.item_locations[from]) then
                changed = true
            end
            local from_segment = get_item_segment(dirty_entities, context, from)
            from_segment.filtered_forward_segments[unit_number] = {
                entity = entity,
                filter = filter.filter,
                pass = pass,
                fail = fail
            }
        end
    end
    if (changed or force_input_detection) then
        for _, input in ipairs(entity.belt_neighbours.inputs) do
            dirty_belts[input.unit_number] = input
        end
        if (type == "underground-belt" and entity.belt_to_ground_type == "output") then
            local input = entity.neighbours
            if (input) then
                dirty_belts[input.unit_number] = input
            end
        end
    end
    if (type == "loader" or type == "loader-1x1") then
        if (entity.loader_type == "input") then
            local to_entity = flow_item.loader_get_container(entity)
            if (to_entity) then
                local drop_id = flow_item.get_item_placer_drop_location(entity)
                local drop_segment_id = context.item_locations[drop_id]
                local drop_segment = context.item_segments[drop_segment_id]
                for _, lane in ipairs(all_lanes) do
                    get_item_segment(dirty_entities, context, flow_item.item_location_belt(entity, lane)).filtered_forward_segments[unit_number] = {
                        entity = entity,
                        filter = nil,
                        pass = { [drop_id] = drop_segment },
                        fail = {}
                    }
                end
            end
        else
            local pickup_entity = flow_item.loader_get_container(entity)
            if (pickup_entity) then
                local pickup_id = flow_item.item_location_entity(pickup_entity, "O")
                local pickup_segment = get_item_segment(dirty_entities, context, pickup_id)
                local filter1, filter2 ---@type Rates.Analyzer.ItemFilter?
                if (base.get_entity_prototype(entity).per_lane_filters) then
                    filter1, filter2 = flow_item.loader_get_lane_filters(entity)
                else
                    filter1 = flow_item.loader_get_filter(entity)
                    filter2 = filter1
                end

                for _, lane in ipairs(all_lanes) do
                    local to_id = flow_item.item_location_belt(entity, lane)
                    local to_segment_id = context.item_locations[to_id]
                    if (to_segment_id) then
                        local to_segment = context.item_segments[to_segment_id]
                        pickup_segment.filtered_forward_segments[unit_number .. lane] = {
                            entity = entity,
                            filter = lane == "L" and filter1 or filter2,
                            pass = { [to_id] = to_segment },
                            fail = {}
                        }
                    end
                end
                dirty_entities[pickup_entity.unit_number] = pickup_entity
            end
        end
    end
end

---@param dirty_entities table<uint64, LuaEntity>
---@param context Rates.Analyzer.Context
---@param entity LuaEntity
---@param force_input_detection boolean
local function trace_backwards(dirty_entities, context, entity, force_input_detection)
    local unit_number = entity.unit_number ---@cast unit_number -nil
    local type = get_entity_type(entity)
    -- game.print("trace " .. type .. " (" .. unit_number .. ") " .. serpent.line(entity))
    if (type == "inserter") then
        local drop_id = flow_item.inserter_get_item_placer_drop_location(entity)
        local drop_segment_id = context.item_locations[drop_id]
        if (drop_segment_id) then
            local drop_segment = context.item_segments[drop_segment_id]
            local output = flow_item.inserter_get_static_output(entity)
            if (output) then
                for id, item in pairs(output) do
                    drop_segment.content[id] = item
                end
            else
                local target = entity.pickup_target
                local position = entity.pickup_position
                local surface = entity.surface
                if (not target) then
                    target = flow_item.find_drop_or_pickup_target(surface, position)
                end
                local filter = flow_item.inserter_get_filter(entity)
                if (target) then
                    local pickup_ids = flow_item.get_item_placer_pickup_locations(target, position,
                        entity.pickup_from_left_lane, entity.pickup_from_right_lane)
                    for _, id in ipairs(pickup_ids) do
                        local pickup_segment = get_item_segment(dirty_entities, context, id)
                        pickup_segment.filtered_forward_segments[unit_number] = {
                            entity = entity,
                            filter = filter,
                            pass = { [drop_id] = drop_segment },
                            fail = {}
                        }
                    end
                    dirty_entities[target.unit_number] = target
                else
                    local id = flow_item.item_location_map(surface, position)
                    local item_segment = get_item_segment(dirty_entities, context, id)
                    item_segment.filtered_forward_segments[unit_number] = {
                        entity = entity,
                        filter = filter,
                        pass = { [drop_id] = drop_segment },
                        fail = {}
                    }
                end
            end
        end
    elseif (flow_item.type_is_belt[type]) then
        local dirty_belts = {} ---@type table<uint64, LuaEntity>
        belt_trace_backwards(dirty_entities, dirty_belts, context, entity, true)

        while (true) do
            local belt_id, belt = next(dirty_belts)
            if (belt_id == nil) then
                break
            end

            dirty_belts[belt_id] = nil
            ---@cast belt -nil
            belt_trace_backwards(dirty_entities, dirty_belts, context, belt, false)
        end
    elseif (type == "container" or type == "logistic-container" or type == "infinity-container") then
        local input_id = flow_item.item_location_entity(entity, "I")
        local input = get_item_segment(dirty_entities, context, input_id)
        local output_id = flow_item.item_location_entity(entity, "O")
        local output = get_item_segment(dirty_entities, context, output_id)
        input.filtered_forward_segments[unit_number] = {
            entity = entity,
            filter = nil,
            pass = { [output_id] = output },
            fail = {}
        }

        if (type == "infinity-container") then
            for _, filter in ipairs(entity.infinity_container_filters) do
                if (filter.mode == "at-least" or filter.mode == "exactly") then
                    if (filter.count > 0) then
                        configuration_util.add_item_to_set(output.content, prototypes.item[filter.name],
                            prototypes.quality[filter.quality])
                    end
                end
            end
        end
    elseif (type == "linked-container") then
    else
        initialize_entity(context, entity)
        local outputs = context.entities[unit_number].outputs
        if (outputs.required_fluid_box_inputs) then
            local fluidbox = entity.fluidbox
            for index, mode in pairs(outputs.required_fluid_box_inputs) do
                if (mode == "on-change" or (mode and force_input_detection)) then
                    for pipe, connection in ipairs(fluidbox.get_pipe_connections(index)) do
                        local conn = { fluidbox = fluidbox, index = index, pipe = pipe }
                        local id = flow_fluid.fluidbox_connection_id(conn)
                        local segment_id = context.fluid_boxes[id]
                        if (segment_id == nil) then
                            local content = flow_fluid.fluidbox_trace_segment(conn)
                            segment_id = flow_fluid.create_fluid_segment(dirty_entities, context, content)
                        end
                        if (mode == "on-change") then
                            if (connection.flow_direction ~= "output") then
                                local segment = context.fluid_segments[segment_id]
                                segment.dependent_entities[unit_number] = entity
                            end
                        end
                    end
                end
            end
        end
        if (outputs.required_items == "on-change" or (outputs.required_items and force_input_detection)) then
            local id = flow_item.item_location_entity(entity, "I")
            get_item_segment(dirty_entities, context, id) -- adds item placers
            local input_segment = get_item_segment(dirty_entities, context, id)
            input_segment.dependent_entities[unit_number] = entity
        end

        local drop_id = flow_item.get_item_placer_drop_location(entity)
        if (drop_id) then
            local drop_segment_id = context.item_locations[drop_id]
            if (drop_segment_id) then
                local output_id = flow_item.item_location_entity(entity, "O")
                local output_segment = get_item_segment(dirty_entities, context, output_id)
                output_segment.filtered_forward_segments[unit_number] = {
                    entity = entity,
                    filter = nil,
                    pass = { [drop_id] = context.item_segments[drop_segment_id] },
                    fail = {}
                }
            end
        end
    end
end

---@param dirty_entities table<uint64, LuaEntity>
---@param segment Rates.Analyzer.ItemSegment
---@param id string
---@param item Rates.Analyzer.ItemWithQuality
local function propagate_item_forward(dirty_entities, segment, id, item)
    local dirty = { [""] = segment } ---@type table<string, Rates.Analyzer.ItemSegment>
    while (true) do
        local segment_id, next_segment = next(dirty)
        if (segment_id == nil) then
            return
        end

        dirty[segment_id] = nil
        ---@cast next_segment -nil
        for unit_number, entity in pairs(next_segment.dependent_entities) do
            dirty_entities[unit_number] = entity
        end
        for _, forward in pairs(next_segment.filtered_forward_segments) do
            local target ---@type table<Rates.Analyzer.ItemLocation, Rates.Analyzer.ItemSegment>
            if (forward.filter) then
                if (forward.filter(item)) then
                    target = forward.pass
                else
                    target = forward.fail
                end
            else
                target = forward.pass
            end

            for forward_id, segment in pairs(target) do
                local content = segment.content
                if (not content[id]) then
                    content[id] = item
                    dirty[forward_id] = segment
                end
            end
        end
    end
end

---@param dirty_entities table<uint64, LuaEntity>
---@param segment Rates.Analyzer.FluidSegment
---@param id string
---@param fluid Rates.Analyzer.FluidWithTemperature
local function propagate_fluid_forward(dirty_entities, segment, id, fluid)
    local dirty = { [""] = segment } ---@type table<string, Rates.Analyzer.FluidSegment>
    while (true) do
        local segment_id, next_segment = next(dirty)
        if (segment_id == nil) then
            return
        end

        dirty[segment_id] = nil
        ---@cast next_segment -nil
        for unit_number, entity in pairs(next_segment.dependent_entities) do
            dirty_entities[unit_number] = entity
        end
        for _, forward in pairs(next_segment.filtered_forward_segments) do
            if (not forward.filter or forward.filter(fluid)) then
                for forward_id, segment in pairs(forward.pass) do
                    local content = segment.content
                    if (not content[id]) then
                        content[id] = fluid
                        dirty[forward_id] = segment
                    end
                end
            end
        end
    end
end

---@param context Rates.Analyzer.Context
local function dump_context(context)
    game.print("entities: " .. table_size(context.entities))
    game.print("item locations: " .. table_size(context.item_locations))
    for id, segment_id in pairs(context.item_locations) do
        local segment = context.item_segments[segment_id]
        local content = {}
        for id, _ in pairs(segment.content) do
            content[#content + 1] = id
        end
        local dependent = {}
        for unit_number, entity in pairs(segment.dependent_entities) do
            dependent[#dependent + 1] = unit_number
        end
        local forwards = {}
        local filter_forwards = {}
        for _, forward in pairs(segment.filtered_forward_segments) do
            if (forward.filter) then
                for id, _ in pairs(forward.pass) do
                    filter_forwards[#filter_forwards + 1] = id
                end
                for id, _ in pairs(forward.fail) do
                    filter_forwards[#filter_forwards + 1] = id
                end
            else
                for id, _ in pairs(forward.pass) do
                    forwards[#forwards + 1] = id
                end
            end
        end
        game.print("i" ..
            id ..
            ": " ..
            serpent.line({ content = content, dependent = dependent, forward = forwards, filter_forward = filter_forwards }))
    end
    game.print("fluid locations: " .. table_size(context.fluid_boxes))
    for id, segment in pairs(context.fluid_segments) do
        local content = {}
        for id, _ in pairs(segment.content) do
            content[#content + 1] = id
        end
        local dependent = {}
        for unit_number, entity in pairs(segment.dependent_entities) do
            dependent[#dependent + 1] = unit_number
        end
        game.print("f" .. id .. ": " .. serpent.line({ content = content, dependent = dependent }))
    end
end

---@param context Rates.Analyzer.Context
local function analyze_full(context)
    -- STEP 1: Register inserter/loader/mining-drill at their drop location

    local prof = game.create_profiler()
    for _, entity in pairs(context.item_placer_entities) do
        initialize_item_placer(context, entity)
    end

    -- game.print({ "", "item placers: ", prof })
    -- game.print("before trace: " .. serpent.block { item_drop_locations = context.item_drop_locations })

    -- STEP 2: Build graph of items/fluid flow for everything that is required

    local dirty = {} ---@type table<uint64, LuaEntity>

    for _, entity in pairs(context.required_entities) do
        trace_backwards(dirty, context, entity, true)
    end

    while (true) do
        local unit_number, entity = next(dirty)
        if (not unit_number) then
            break
        end

        ---@cast entity -nil
        dirty[unit_number] = nil

        trace_backwards(dirty, context, entity, false)
    end
    -- game.print({ "", "backwards trace: ", prof })
    -- game.print(serpent.line { item_locations = table_size(context.item_locations), fluid_boxes = table_size(context.fluid_boxes), entities = table_size(context.entities) })

    -- game.print("after backwards trace:")
    -- dump_context(context)

    -- STEP 3: Initialize contents with static outputs of entities
    for unit_number, entity_outputs in pairs(context.entities) do
        local entity = entity_outputs.entity
        local outputs = entity_outputs.outputs
        if (outputs.items) then
            local output_id = flow_item.item_location_entity({ unit_number = unit_number }, "O")
            local segment_id = context.item_locations[output_id]
            if (segment_id) then
                local segment = context.item_segments[segment_id]
                for id, item in pairs(outputs.items) do
                    segment.content[id] = item
                end
            end
        end

        if (outputs.fluid_box_outputs) then
            for index, fluids in pairs(outputs.fluid_box_outputs) do
                local pipe_connections = entity.fluidbox.get_pipe_connections(index)
                for pipe, _ in ipairs(pipe_connections) do
                    ---@type Rates.Analyzer.FluidBoxConnection
                    local connection = { fluidbox = entity.fluidbox, index = index, pipe = pipe }
                    local output_id = flow_fluid.fluidbox_connection_id(connection)
                    local segment_id = context.fluid_boxes[output_id]
                    if (segment_id) then
                        local segment = context.fluid_segments[segment_id]
                        for id, fluid in pairs(fluids) do
                            segment.content[id] = fluid
                        end
                    end
                end
            end
        end
    end
    -- game.print({ "", "initial segment contents: ", prof })

    -- game.print(serpent.block(context.entities))

    -- game.print("after segment initialization:")
    -- dump_context(context)

    -- STEP 4: Propagate items/fluids forward

    for _, segment in ipairs(context.item_segments) do
        for id, item in pairs(segment.content) do
            propagate_item_forward(dirty, segment, id, item)
        end
    end

    for _, segment in ipairs(context.fluid_segments) do
        for id, fluid in pairs(segment.content) do
            propagate_fluid_forward(dirty, segment, id, fluid)
        end
    end

    for unit_number, outputs in pairs(context.entities) do
        local entity = outputs.entity
        if (is_dynamic(outputs.outputs)) then
            dirty[unit_number] = entity
        end
    end
    -- game.print({ "", "initial propagation: ", prof })

    -- game.print("after first forward propagation:")
    -- dump_context(context)

    while (true) do
        local unit_number, entity = next(dirty)
        if (not unit_number) then
            break
        end

        ---@cast entity -nil
        dirty[unit_number] = nil
        local inputs = get_entity_inputs(context, entity)
        local outputs = configuration.analyze_flow(entity, inputs)
        -- game.print("forward " .. unit_number .. ": " .. serpent.line({ inputs = inputs, outputs = outputs }))
        if (outputs.fluid_box_outputs) then
            local fluidbox = entity.fluidbox
            local changed_segments = {} ---@type table<integer, Rates.Analyzer.FluidSegment>
            for index, out in pairs(outputs.fluid_box_outputs) do
                local pipe_connections = fluidbox.get_pipe_connections(index)
                for pipe, pipe_connection in ipairs(pipe_connections) do
                    local id = flow_fluid.fluidbox_connection_id({ fluidbox = fluidbox, index = index, pipe = pipe })
                    local segment_id = context.fluid_boxes[id]
                    if (segment_id) then
                        local segment = context.fluid_segments[segment_id]
                        local content = segment.content
                        for id, fluid in pairs(out) do
                            if (not content[id]) then
                                content[id] = fluid
                                changed_segments[segment_id] = segment
                            end
                        end
                    end
                end
            end

            for segment_id, segment in pairs(changed_segments) do
                for unit_number, entity in pairs(segment.dependent_entities) do
                    dirty[unit_number] = entity
                end
            end
        end

        if (outputs.items) then
            local segment_id = context.item_locations[flow_item.item_location_entity(entity, "O")]
            if (segment_id) then
                local segment = context.item_segments[segment_id]
                local content = segment.content
                for id, item in pairs(outputs.items) do
                    if (not content[id]) then
                        content[id] = item
                        propagate_item_forward(dirty, segment, id, item)
                    end
                end
            end
        end
    end
    -- game.print({ "", "full propagation: ", prof })

    -- game.print("after full forward propagation:")
    -- dump_context(context)
end

return {
    create_context = create_context,
    add_required_entity = add_required_entity,
    add_item_placer = add_item_placer,
    analyze_full = analyze_full,
    get_entity_inputs = get_entity_inputs,
}
