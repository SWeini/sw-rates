local configuration = require("api-usage").configuration

do
    ---@class queue<T>: { [integer]: T, first: integer, last: integer }
end

---@return queue
local function queue_new()
    return { first = 0, last = -1 }
end

---@generic T
---@param queue queue<T>
---@param value T
local function queue_push(queue, value)
    local last = queue.last + 1
    queue.last = last
    queue[last] = value
end

---@generic T
---@param queue queue<T>
---@return T
local function queue_pop(queue)
    local first = queue.first
    if (first > queue.last) then
        error("empty queue")
    end
    local value = queue[first]
    queue[first] = nil
    queue.first = first + 1
    return value
end

---@generic T
---@param queue queue<T>
---@return  boolean
local function queue_is_empty(queue)
    return queue.first > queue.last
end

---@class (strict) Rates.Analyzer.Context
---@field fluid_boxes table<string, integer> key is unit_number/fluid_box_index/pipe_index, value is index into fluid_segments
---@field fluid_segments table<integer, Rates.Analyzer.FluidSegment>
---@field entities table<uint64, Rates.Analyzer.EntityOutputs>
---@field entity_queue queue<LuaEntity>

---@class (strict) Rates.Analyzer.FluidWithTemperature
---@field fluid LuaFluidPrototype
---@field temperature number

---@alias Rates.Analyzer.FluidSet table<string, Rates.Analyzer.FluidWithTemperature>

---@class (strict) Rates.Analyzer.FluidSegment
---@field content Rates.Analyzer.FluidSet
---@field dependent_entities table<uint64, LuaEntity>

---@class (strict) Rates.Analyzer.EntityInputs
---@field fluid_boxes? table<integer, Rates.Analyzer.FluidSet>

---@class (strict) Rates.Analyzer.EntityOutputs
---@field required_fluid_box_inputs? table<integer, "once"|"on-change">
---@field fluid_box_outputs? table<integer, Rates.Analyzer.FluidSet>

---@class (strict) FluidBoxConnection
---@field fluidbox LuaFluidBox
---@field index uint32
---@field pipe integer

---@type table<string, true>
local pipelike_types = { ["pipe"] = true, ["pipe-to-ground"] = true, ["storage-tank"] = true }

---@return Rates.Analyzer.Context
local function create_context()
    ---@type Rates.Analyzer.Context
    return {
        fluid_boxes = {},
        fluid_segments = {},
        entities = {},
        entity_queue = queue_new()
    }
end

---@param entity LuaEntity
---@param outputs Rates.Analyzer.EntityOutputs
local function debug_fluidbox(entity, outputs)
    local fb = entity.fluidbox
    local dbg = { entity = entity, fluidboxes = #fb, outputs = outputs }
    for i = 1, #fb do
        dbg[i] = { content = fb[i], filter = fb.get_filter(i), lock = fb.get_locked_fluid(i) }
    end
    game.print(serpent.line(dbg))
end

---@param connection FluidBoxConnection
---@return string
local function fluidbox_connection_id(connection)
    return connection.fluidbox.owner.unit_number .. "/" .. connection.index .. "/" .. connection.pipe
end

---@param outputs Rates.Analyzer.EntityOutputs
---@return boolean
local function is_dynamic(outputs)
    local fluid_box_inputs = outputs.required_fluid_box_inputs
    if (fluid_box_inputs) then
        if (next(fluid_box_inputs) ~= nil) then
            return true
        end
    end

    return false
end

---@param context Rates.Analyzer.Context
---@param entity LuaEntity
local function add_required_entity(context, entity)
    local outputs = configuration.analyze_flow(entity, {})
    -- debug_fluidbox(entity, outputs)
    local unit_number = entity.unit_number ---@cast unit_number -nil
    context.entities[unit_number] = outputs
    queue_push(context.entity_queue, entity)
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
            local id = fluidbox_connection_id({ fluidbox = fluidbox, index = i, pipe = p })
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

    return result;
end

---@param connection FluidBoxConnection
---@return table<string, FluidBoxConnection>
local function fluidbox_trace_segment(connection)
    local result = {} ---@type table<string, FluidBoxConnection>
    local queue = queue_new() ---@type queue<FluidBoxConnection>

    ---@param connection FluidBoxConnection
    local function pass_through(connection)
        local pipe_connections = connection.fluidbox.get_pipe_connections(connection.index)
        local pipe_connection = pipe_connections[connection.pipe]
        if (pipe_connection.flow_direction == "input-output") then
            for i, pipe_connection in ipairs(pipe_connections) do
                if (i ~= connection.pipe and pipe_connection.flow_direction == "input-output") then
                    local conn = { fluidbox = connection.fluidbox, index = connection.index, pipe = i } ---@type FluidBoxConnection
                    local id = fluidbox_connection_id(conn)
                    if (not result[id]) then
                        result[id] = conn
                        if (pipe_connection.target) then
                            ---@type FluidBoxConnection
                            local target_connection = {
                                fluidbox = pipe_connection.target,
                                index = pipe_connection.target_fluidbox_index,
                                pipe = pipe_connection.target_pipe_connection_index
                            }
                            local id = fluidbox_connection_id(target_connection)
                            if (not result[id]) then
                                result[id] = target_connection
                                queue_push(queue, target_connection)
                            end
                        end
                    end
                end
            end
        end
    end

    local id = fluidbox_connection_id(connection)
    result[id] = connection
    pass_through(connection)
    local other = connection.fluidbox.get_pipe_connections(connection.index)[connection.pipe]
    if (other.target) then
        ---@type FluidBoxConnection
        local target_connection = {
            fluidbox = other.target,
            index = other.target_fluidbox_index,
            pipe = other.target_pipe_connection_index
        }
        local id = fluidbox_connection_id(target_connection)
        if (not result[id]) then
            result[id] = target_connection
            pass_through(target_connection)
        end
    end

    while true do
        if (queue_is_empty(queue)) then
            return result
        end

        local next = queue_pop(queue)
        pass_through(next)
    end
end

---@param context Rates.Analyzer.Context
---@param connections table<string, FluidBoxConnection>
---@return integer
local function create_fluid_segment(context, connections)
    local segment_id = #context.fluid_segments + 1
    ---@type Rates.Analyzer.FluidSegment
    local segment = {
        content = {},
        dependent_entities = {}
    }
    context.fluid_segments[segment_id] = segment

    local entities = {} ---@type table<uint64, LuaEntity>
    for id, connection in pairs(connections) do
        context.fluid_boxes[id] = segment_id
        local entity = connection.fluidbox.owner
        local unit_number = entity.unit_number ---@cast unit_number -nil
        entities[unit_number] = entity
    end

    for unit_number, entity in pairs(entities) do
        local type = entity.type
        if (type == "entity-ghost") then
            type = entity.ghost_type
        end
        if (not pipelike_types[type]) then
            local outputs = context.entities[unit_number]
            if (not outputs) then
                outputs = configuration.analyze_flow(entity, {})
                context.entities[unit_number] = outputs
            end

            local fluidbox = entity.fluidbox
            for index = 1, #fluidbox do
                local pipe_connections = fluidbox.get_pipe_connections(index)
                for pipe, pipe_connection in ipairs(pipe_connections) do
                    local connection = { fluidbox = fluidbox, index = index, pipe = pipe } ---@type FluidBoxConnection
                    local id = fluidbox_connection_id(connection)
                    if (connections[id]) then
                        if (pipe_connection.flow_direction ~= "input") then
                            -- is output
                            if (outputs.fluid_box_outputs) then
                                local out = outputs.fluid_box_outputs[connection.index]
                                if (out) then
                                    for id, fluid in pairs(out) do
                                        segment.content[id] = fluid
                                    end

                                    if (is_dynamic(outputs)) then
                                        queue_push(context.entity_queue, entity)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return segment_id
end

---@param context Rates.Analyzer.Context
local function analyze_full(context)
    local queue = context.entity_queue
    while true do
        if (queue_is_empty(queue)) then
            break
        end

        local entity = queue_pop(queue)
        local unit_number = entity.unit_number ---@cast unit_number -nil

        -- game.print("analyze " .. serpent.line(entity))

        local outputs = context.entities[unit_number]
        if (outputs.required_fluid_box_inputs) then
            local fluidbox = entity.fluidbox
            for index, mode in pairs(outputs.required_fluid_box_inputs) do
                for i_conn, connection in ipairs(fluidbox.get_pipe_connections(index)) do
                    local conn = { fluidbox = fluidbox, index = index, pipe = i_conn }
                    local id = fluidbox_connection_id(conn)
                    local segment_id = context.fluid_boxes[id]
                    if (segment_id == nil) then
                        local content = fluidbox_trace_segment(conn)
                        segment_id = create_fluid_segment(context, content)
                        -- game.print(serpent.line { segment_id = segment_id, size = table_size(content), content = context.fluid_segments[segment_id].content, dependent_entities = context.fluid_segments[segment_id].dependent_entities })
                    end
                    if (mode == "on-change" and connection.flow_direction ~= "output") then
                        local segment = context.fluid_segments[segment_id]
                        segment.dependent_entities[unit_number] = entity
                    end
                end
            end
        end
    end

    -- for segment_id, segment in ipairs(context.fluid_segments) do
    --     game.print(serpent.line { segment_id = segment_id, content = segment.content, dependent_entities = segment.dependent_entities })
    -- end

    local dirty = {} ---@type table<uint64, LuaEntity>
    for segment_id, segment in ipairs(context.fluid_segments) do
        for unit_number, entity in pairs(segment.dependent_entities) do
            dirty[unit_number] = entity
        end
    end

    while true do
        local unit_number, entity = next(dirty)
        if (not unit_number) then
            break
        end

        ---@cast entity -nil
        dirty[unit_number] = nil
        local inputs = get_entity_inputs(context, entity)
        local outputs = configuration.analyze_flow(entity, inputs)
        local fluidbox = entity.fluidbox
        local changed_segments = {} ---@type table<integer, Rates.Analyzer.FluidSegment>
        for index, out in pairs(outputs.fluid_box_outputs) do
            local pipe_connections = fluidbox.get_pipe_connections(index)
            for pipe, pipe_connection in ipairs(pipe_connections) do
                local id = fluidbox_connection_id({ fluidbox = fluidbox, index = index, pipe = pipe })
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
end

return {
    create_context = create_context,
    add_required_entity = add_required_entity,
    analyze_full = analyze_full,
    get_entity_inputs = get_entity_inputs,
}
