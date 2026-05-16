local base = require("base-util")
local conf = require("configuration-util")

---@type table<string, true>
local types_with_vector_to_place_result = {
    ["assembling-machine"] = true,
    ["furnace"] = true,
    ["mining-drill"] = true,
}

---@type string[]
local types_with_item_interaction = {
    "agricultural-tower",
    "asteroid-collector",
    "boiler",
    "burner-generator",
    "container",
    "logistic-container",
    "infinity-container",
    "assembling-machine",
    "rocket-silo",
    "furnace",
    "fusion-generator",
    "fusion-reactor",
    "generator",
    "lab",
    "linked-container",
    "mining-drill",
    "offshore-pump",
    "proxy-container",
    "pump",
    "reactor",
    "lane-splitter",
    "linked-belt",
    "loader-1x1",
    "loader",
    "splitter",
    "transport-belt",
    "underground-belt",
}

---@type table<string, true>
local type_is_belt = {
    ["transport-belt"] = true,
    ["underground-belt"] = true,
    ["splitter"] = true,
    ["loader"] = true,
    ["loader-1x1"] = true,
    ["lane-splitter"] = true,
    ["linked-belt"] = true,
}

---@param direction defines.direction
---@param vector MapPosition.0
---@return MapPosition.0
local function rotate_vector(direction, vector)
    if (direction == defines.direction.north) then
        return { x = vector.x, y = vector.y }
    elseif (direction == defines.direction.east) then
        return { x = -vector.y, y = vector.x }
    elseif (direction == defines.direction.south) then
        return { x = -vector.x, y = -vector.y }
    elseif (direction == defines.direction.west) then
        return { x = vector.y, y = -vector.x }
    else
        error("invalid direction")
    end
end

---@param direction defines.direction
---@return  defines.direction
local function direction_reverse(direction)
    return (16 - direction) % 16
end

---@param entity LuaEntity
---@param vector MapPosition.0
---@return MapPosition.0
local function get_relative_position(entity, vector)
    local rot = rotate_vector(entity.direction, vector)
    local pos = entity.position --[[@as MapPosition.0]]
    return { x = pos.x + rot.x, y = pos.y + rot.y }
end

---@param entity LuaEntity
---@param position MapPosition.0
---@return MapPosition.0
local function get_relative_vector(entity, position)
    local pos = entity.position --[[@as MapPosition.0]]
    local vec = { x = position.x - pos.x, y = position.y - pos.y }
    local rot = rotate_vector(direction_reverse(entity.direction), vec)
    return rot
end

---@param entity LuaEntity | { unit_number: uint64 }
---@param index string
---@return Rates.Analyzer.ItemLocation
local function item_location_entity(entity, index)
    return "e/" .. entity.unit_number .. "/" .. index
end

---@param entity LuaEntity
---@param index string
---@return Rates.Analyzer.ItemLocation
local function item_location_belt(entity, index)
    return "b/" .. entity.unit_number .. "/" .. index
end

---@param surface LuaSurface
---@param position MapPosition.0
---@return Rates.Analyzer.ItemLocation
local function item_location_map(surface, position)
    return "m/" .. surface.index .. "/" .. math.floor(position.x) .. "/" .. math.floor(position.y)
end

---@param entity LuaEntity
---@return Rates.Analyzer.ItemLocation
local function item_location_linked(entity)
    return "l/" .. base.get_entity_name(entity) .. "/" .. entity.link_id
end

---@param entity LuaEntity
---@return MapPosition.0
local function loader_get_container_position(entity)
    local type = base.get_entity_type(entity)
    local len = type == "loader" and 1.5 or 1
    if (entity.loader_type == "input") then
        len = -len
    end
    return get_relative_position(entity, { x = 0, y = len })
end

---@param entity LuaEntity
---@param type string
---@param position MapPosition.0
---@return Rates.Analyzer.ItemLocation
local function get_item_location_drop_on_belt(entity, type, position)
    local vec = get_relative_vector(entity, position)
    if (type == "transport-belt") then
        local shape = entity.belt_shape
        if (shape == "straight") then
            return item_location_belt(entity, vec.x < 0 and "L" or "R")
        elseif (shape == "left") then
            local x = vec.x + 0.5
            local y = vec.y + 0.5
            local dsqr = x * x + y * y
            return item_location_belt(entity, dsqr < 0.5 and "L" or "R")
        else -- shape == "right"
            local x = vec.x - 0.5
            local y = vec.y + 0.5
            local dsqr = x * x + y * y
            return item_location_belt(entity, dsqr < 0.5 and "R" or "L")
        end
    elseif (type == "underground-belt" or type == "linked-belt" or type == "loader" or type == "loader-1x1") then
        return item_location_belt(entity, vec.x < 0 and "L" or "R")
    elseif (type == "splitter") then
        local x = vec.x
        if (x < -0.5) then
            return item_location_belt(entity, "LIL")
        elseif (x < 0) then
            return item_location_belt(entity, "RIL")
        elseif (x < 0.5) then
            return item_location_belt(entity, "LIR")
        else
            return item_location_belt(entity, "RIR")
        end
    elseif (type == "lane-splitter") then
        return item_location_belt(entity, vec.x < 0 and "LI" or "RI")
    else
        error("entity not a belt")
    end
end

---@param entity LuaEntity
---@param type string
---@return Rates.Analyzer.ItemLocation
local function get_item_location_drop_on_entity(entity, type)
    if (type == "linked-container") then
        return item_location_linked(entity)
    else
        return item_location_entity(entity, "I")
    end
end

---@param entity LuaEntity?
---@param surface LuaSurface
---@param position MapPosition.0
---@return Rates.Analyzer.ItemLocation
local function get_item_location_drop(entity, surface, position)
    if (not entity) then
        return item_location_map(surface, position)
    end
    local type = base.get_entity_type(entity)
    if (type_is_belt[type]) then
        return get_item_location_drop_on_belt(entity, type, position)
    end
    return get_item_location_drop_on_entity(entity, type)
end

---@param surface LuaSurface
---@param position MapPosition.0
---@return LuaEntity?
local function find_drop_or_pickup_target(surface, position)
    local low = { math.floor(position.x), math.floor(position.y) }
    local high = { x = low[1] + 1, y = low[2] + 1 }
    local area = { low, high }
    local entities = surface.find_entities_filtered {
        area = area,
        type = types_with_item_interaction,
        to_be_deconstructed = false
    }
    if (entities[1]) then
        return entities[1]
    end
    entities = surface.find_entities_filtered {
        area = area,
        ghost_type = types_with_item_interaction
    }
    return entities[1]
end

---@param entity LuaEntity
---@return Rates.Analyzer.ItemLocation
local function get_item_placer_drop_location_position(entity)
    local target = entity.drop_target
    local position = entity.drop_position
    local surface = entity.surface
    if (not target) then
        target = find_drop_or_pickup_target(surface, position)
    end
    return get_item_location_drop(target, surface, position)
end

---@param entity LuaEntity
---@return LuaEntity?
local function loader_get_container(entity)
    local target = entity.type ~= "entity-ghost" and entity.loader_container or nil
    if (not target) then
        target = find_drop_or_pickup_target(entity.surface, loader_get_container_position(entity))
    end
    if (target) then
        if (type_is_belt[base.get_entity_type(target)]) then
            return nil
        end
    end
    return target
end

---@param entity LuaEntity
---@return Rates.Analyzer.ItemLocation?
local function get_item_placer_drop_location(entity)
    local type = base.get_entity_type(entity)
    if (type == "inserter") then
        return get_item_placer_drop_location_position(entity)
    elseif (type == "loader" or type == "loader-1x1") then
        if (entity.loader_type == "input") then
            local target = loader_get_container(entity)
            if (target) then
                local target_type = base.get_entity_type(target)
                return get_item_location_drop_on_entity(target, target_type)
            end
        end
    elseif (types_with_vector_to_place_result[type]) then
        local prototype = base.get_entity_prototype(entity)
        local vector_to_place_result = prototype.vector_to_place_result
        if (vector_to_place_result) then
            return get_item_placer_drop_location_position(entity)
        end
    end
end

---@param entity LuaEntity
---@param position MapPosition.0
---@param pickup_from_left_lane boolean
---@param pickup_from_right_lane boolean
---@return string[]
local function get_item_placer_pickup_locations(entity, position, pickup_from_left_lane, pickup_from_right_lane)
    local type = base.get_entity_type(entity)
    if (type == "transport-belt" or type == "underground-belt" or type == "linked-belt") then
        local result = {} ---@type string[]
        if (pickup_from_left_lane) then
            result[#result + 1] = item_location_belt(entity, "L")
        end
        if (pickup_from_right_lane) then
            result[#result + 1] = item_location_belt(entity, "R")
        end
        return result
    elseif (type == "lane-splitter") then
        local result = {} ---@type string[]
        if (pickup_from_left_lane) then
            result[#result + 1] = item_location_belt(entity, "LI")
            result[#result + 1] = item_location_belt(entity, "LO")
        end
        if (pickup_from_right_lane) then
            result[#result + 1] = item_location_belt(entity, "RI")
            result[#result + 1] = item_location_belt(entity, "RO")
        end
        return result
    elseif (type == "splitter") then
        local pos = get_relative_vector(entity, position)
        local side = pos.x < 0 and "L" or "R"
        local result = {} ---@type string[]
        if (pickup_from_left_lane) then
            result[#result + 1] = item_location_belt(entity, "LI" .. side)
            result[#result + 1] = item_location_belt(entity, "LO" .. side)
        end
        if (pickup_from_right_lane) then
            result[#result + 1] = item_location_belt(entity, "RI" .. side)
            result[#result + 1] = item_location_belt(entity, "RO" .. side)
        end
        return result
    elseif (type == "linked-container") then
        return { item_location_linked(entity) }
    else
        return { item_location_entity(entity, "O") }
    end
end

---@param entity LuaEntity
---@return Rates.Analyzer.ItemSet?
local function inserter_get_static_output(entity)
    if (not entity.use_filters) then
        return nil
    end
    local mode = entity.inserter_filter_mode
    if (mode ~= "whitelist") then
        return nil
    end
    local result = {} ---@type Rates.Analyzer.ItemSet
    for slot = 1, entity.filter_slot_count do
        local filter = entity.get_filter(slot)
        if (filter) then
            ---@cast filter ItemFilter.0
            if (not filter.name) then
                return nil
            end

            if (filter.comparator ~= "=") then
                return nil
            end

            conf.add_item_to_set(result, prototypes.item[filter.name], prototypes.quality[filter.quality])
        end
    end

    return result
end

---@type Rates.Analyzer.ItemFilter
local filter_pass = function(item)
    return true
end

---@type Rates.Analyzer.ItemFilter
local filter_fail = function(item)
    return false
end

---@param comparator ComparatorString
---@param level uint32
---@return Rates.Analyzer.ItemFilter
local function create_quality_filter(comparator, level)
    if (comparator == "=") then
        return function(item) return item.quality.level == level end
    elseif (comparator == ">") then
        return function(item) return item.quality.level > level end
    elseif (comparator == "<") then
        return function(item) return item.quality.level < level end
    elseif (comparator == "≠") then
        return function(item) return item.quality.level ~= level end
    elseif (comparator == "≥") then
        return function(item) return item.quality.level >= level end
    elseif (comparator == "≤") then
        return function(item) return item.quality.level <= level end
    end

    error("invalid quality comparator")
end

---@param filter ItemFilter.0
---@return Rates.Analyzer.ItemFilter
local function create_single_filter(filter)
    local name = filter.name
    local quality = filter.quality
    if (quality) then
        local level = prototypes.quality[quality].level
        local comparator = create_quality_filter(filter.comparator, level)
        if (name) then
            return function(item)
                return item.item.name == name and comparator(item)
            end
        else
            return comparator
        end
    else
        if (name) then
            return function(item)
                return item.item.name == name
            end
        else
            return filter_pass
        end
    end
end

---@param filters Rates.Analyzer.ItemFilter[]
---@return Rates.Analyzer.ItemFilter
local function combine_filters(filters)
    local size = table_size(filters)
    if (size == 0) then
        return filter_fail
    elseif (size == 1) then
        return filters[1]
    end

    return function(item)
        for _, filter in ipairs(filters) do
            if (filter(item)) then
                return true
            end
        end

        return false
    end
end

---@param filter Rates.Analyzer.ItemFilter
---@return Rates.Analyzer.ItemFilter
local function invert_filter(filter)
    if (filter == filter_pass) then
        return filter_fail
    elseif (filter == filter_fail) then
        return filter_pass
    end

    return function(item)
        return not filter(item)
    end
end

---@param entity LuaEntity
---@return Rates.Analyzer.ItemFilter?
local function inserter_get_filter(entity)
    if (not entity.use_filters) then
        return nil
    end

    local filters = {} ---@type Rates.Analyzer.ItemFilter[]
    for slot = 1, entity.filter_slot_count do
        local filter = entity.get_filter(slot)
        if (filter) then
            ---@cast filter ItemFilter.0
            filters[#filters + 1] = create_single_filter(filter)
        end
    end

    local combined = combine_filters(filters)
    if (entity.inserter_filter_mode == "blacklist") then
        combined = invert_filter(combined)
    end

    if (combined == filter_pass) then
        return nil
    end

    return combined
end

---@param entity LuaEntity
---@return Rates.Analyzer.ItemFilter?
local function splitter_get_filter_to_left(entity)
    local filter = entity.splitter_filter
    if (not filter) then
        return nil
    end

    local priority = entity.splitter_output_priority
    if (priority == "none") then
        return nil
    end

    ---@cast filter ItemFilter.0
    local single = create_single_filter(filter)
    if (priority == "right") then
        single = invert_filter(single)
    end

    return single
end

---@param entity LuaEntity
---@return Rates.Analyzer.ItemFilter?
local function loader_get_filter(entity)
    local filter_mode = entity.loader_filter_mode
    if (not filter_mode or filter_mode == "none") then
        return nil
    end

    local filters = {} ---@type Rates.Analyzer.ItemFilter[]
    for slot = 1, entity.filter_slot_count do
        local filter = entity.get_filter(slot)
        if (filter) then
            ---@cast filter ItemFilter.0
            filters[#filters + 1] = create_single_filter(filter)
        end
    end

    local combined = combine_filters(filters)
    if (filter_mode == "blacklist") then
        combined = invert_filter(combined)
    end

    if (combined == filter_pass) then
        return nil
    end

    return combined
end

---@param entity LuaEntity
---@return Rates.Analyzer.ItemFilter?, Rates.Analyzer.ItemFilter?
local function loader_get_lane_filters(entity)
    local filter_mode = entity.loader_filter_mode
    if (not filter_mode or filter_mode == "none") then
        return nil, nil
    end

    local filter1 = entity.get_filter(1) --[[@as ItemFilter.0]]
    local single1 = filter1 and create_single_filter(filter1) or filter_fail

    local filter2 = entity.get_filter(2) --[[@as ItemFilter.0?]]
    local single2 = filter2 and create_single_filter(filter2) or filter_fail

    if (filter_mode == "blacklist") then
        single1 = invert_filter(single1)
        single2 = invert_filter(single2)
    end

    return single1 ~= filter_pass and single1 or nil, single2 ~= filter_pass and single2 or nil
end

---@param entity LuaEntity
---@param direction defines.direction
---@param position MapPosition.0
---@return { L: Rates.Analyzer.ItemLocation?, R: Rates.Analyzer.ItemLocation? }
local function belt_get_input_connection(entity, direction, position)
    local type = base.get_entity_type(entity)
    local pos = entity.position
    if (type == "transport-belt") then
        if (position.x ~= pos.x or position.y ~= pos.y) then
            -- game.print("non-matching position: " .. serpent.line({ position = position, expected = pos }))
            return {}
        end
        local dir = entity.direction
        if (dir == direction or entity.belt_shape ~= "straight") then
            return { L = item_location_belt(entity, "L"), R = item_location_belt(entity, "R") }
        elseif ((dir - direction) % 16 == 4) then
            return { L = item_location_belt(entity, "R"), R = item_location_belt(entity, "R") }
        else
            return { L = item_location_belt(entity, "L"), R = item_location_belt(entity, "L") }
        end
    elseif (type == "underground-belt") then
        if (position.x ~= pos.x or position.y ~= pos.y) then
            return {}
        end
        local dir = entity.direction
        if (dir == direction) then
            return { L = item_location_belt(entity, "L"), R = item_location_belt(entity, "R") }
        else
            if (entity.belt_to_ground_type == "output") then
                if ((dir - direction) % 16 == 4) then
                    return { R = item_location_belt(entity, "R") }
                else
                    return { L = item_location_belt(entity, "L") }
                end
            else
                if ((dir - direction) % 16 == 4) then
                    return { L = item_location_belt(entity, "R") }
                else
                    return { R = item_location_belt(entity, "L") }
                end
            end
        end
    elseif (type == "lane-splitter") then
        if (entity.direction ~= direction) then
            return {}
        end
        if (position.x ~= pos.x or position.y ~= pos.y) then
            return {}
        end
        return { L = item_location_belt(entity, "LI"), R = item_location_belt(entity, "RI") }
    elseif (type == "splitter") then
        if (entity.direction ~= direction) then
            return {}
        end
        local vec = get_relative_vector(entity, position)
        if (vec.x == -0.5 and vec.y == 0) then
            return { L = item_location_belt(entity, "LIL"), R = item_location_belt(entity, "RIL") }
        elseif (vec.x == 0.5 and vec.y == 0) then
            return { L = item_location_belt(entity, "LIR"), R = item_location_belt(entity, "RIR") }
        end
    elseif (type == "loader" or type == "loader-1x1") then
        local vec = get_relative_vector(entity, position)
        if (vec.x ~= 0) then
            return {}
        end
        if (entity.direction ~= direction) then
            return {}
        end
        return { L = item_location_belt(entity, "L"), R = item_location_belt(entity, "R") }
    end

    return {}
end

---@param entity LuaEntity
---@param type string
---@return table<Rates.Analyzer.ItemLocation, Rates.Analyzer.ItemLocation>
local function belt_output_connections(entity, type)
    local result = {} ---@type table<Rates.Analyzer.ItemLocation, Rates.Analyzer.ItemLocation>
    if (type == "transport-belt") then
        local output = entity.belt_neighbours.outputs[1]
        if (not output) then
            return result
        end

        local pos = get_relative_position(entity, { x = 0, y = -1 })
        local input = belt_get_input_connection(output, entity.direction, pos)
        result[item_location_belt(entity, "L")] = input.L
        result[item_location_belt(entity, "R")] = input.R
    elseif (type == "underground-belt") then
        if (entity.belt_to_ground_type == "input") then
            local output = entity.neighbours
            if (not output) then
                return result
            end

            result[item_location_belt(entity, "L")] = item_location_belt(output, "L")
            result[item_location_belt(entity, "R")] = item_location_belt(output, "R")
        else
            local output = entity.belt_neighbours.outputs[1]
            if (not output) then
                return result
            end

            local pos = get_relative_position(entity, { x = 0, y = -1 })
            local input = belt_get_input_connection(output, entity.direction, pos)
            result[item_location_belt(entity, "L")] = input.L
            result[item_location_belt(entity, "R")] = input.R
        end
    elseif (type == "lane-splitter") then
        local output = entity.belt_neighbours.outputs[1]
        if (not output) then
            return result
        end

        local pos = get_relative_position(entity, { x = 0, y = -1 })
        local input = belt_get_input_connection(output, entity.direction, pos)
        result[item_location_belt(entity, "LO")] = input.L
        result[item_location_belt(entity, "RO")] = input.R
    elseif (type == "splitter") then
        local outputs = entity.belt_neighbours.outputs

        local pos = get_relative_position(entity, { x = -0.5, y = -1 })
        for _, output in ipairs(outputs) do
            local input = belt_get_input_connection(output, entity.direction, pos)
            if (input.L) then
                result[item_location_belt(entity, "LOL")] = input.L
            end
            if (input.R) then
                result[item_location_belt(entity, "ROL")] = input.R
            end
        end

        pos = get_relative_position(entity, { x = 0.5, y = -1 })
        for _, output in ipairs(outputs) do
            local input = belt_get_input_connection(output, entity.direction, pos)
            if (input.L) then
                result[item_location_belt(entity, "LOR")] = input.L
            end
            if (input.R) then
                result[item_location_belt(entity, "ROR")] = input.R
            end
        end
    elseif (type == "loader" or type == "loader-1x1") then
        if (entity.loader_type == "output") then
            local output = entity.belt_neighbours.outputs[1]
            if (not output) then
                return result
            end

            local pos = get_relative_position(entity, { x = 0, y = type == "loader" and -1.5 or -1 })
            local input = belt_get_input_connection(output, entity.direction, pos)
            result[item_location_belt(entity, "L")] = input.L
            result[item_location_belt(entity, "R")] = input.R
        end
    end

    return result
end

---@param entity LuaEntity
---@param type string
---@return table<Rates.Analyzer.ItemLocation, Rates.Analyzer.FilteredItemForwardSpecification>
local function belt_inner_connections(entity, type)
    if (type == "lane-splitter") then
        local filter = splitter_get_filter_to_left(entity)
        ---@type Rates.Analyzer.FilteredItemForwardSpecification
        local forward
        if (filter) then
            forward = {
                filter = filter,
                pass = { item_location_belt(entity, "LO") },
                fail = { item_location_belt(entity, "RO") }
            }
        else
            forward = {
                pass = { item_location_belt(entity, "LO"), item_location_belt(entity, "RO") }
            }
        end
        return { [item_location_belt(entity, "LI")] = forward, [item_location_belt(entity, "RI")] = forward }
    elseif (type == "splitter") then
        local result = {} ---@type table<string, Rates.Analyzer.FilteredItemForwardSpecification>
        local filter = splitter_get_filter_to_left(entity)
        for _, lane in ipairs({ "L", "R" }) do
            local forward ---@type Rates.Analyzer.FilteredItemForwardSpecification
            if (filter) then
                forward = {
                    filter = filter,
                    pass = { item_location_belt(entity, lane .. "OL") },
                    fail = { item_location_belt(entity, lane .. "OR") }
                }
            else
                forward = {
                    pass = { item_location_belt(entity, lane .. "OL"), item_location_belt(entity, lane .. "OR") }
                }
            end
            result[item_location_belt(entity, lane .. "IL")] = forward
            result[item_location_belt(entity, lane .. "IR")] = forward
        end
        return result
    end

    return {}
end

return {
    item_location_entity = item_location_entity,
    item_location_map = item_location_map,
    item_location_belt = item_location_belt,
    find_drop_or_pickup_target = find_drop_or_pickup_target,
    get_item_placer_drop_location = get_item_placer_drop_location,
    get_item_placer_pickup_locations = get_item_placer_pickup_locations,
    inserter_get_static_output = inserter_get_static_output,
    inserter_get_filter = inserter_get_filter,
    inserter_get_item_placer_drop_location = get_item_placer_drop_location_position,
    loader_get_container = loader_get_container,
    loader_get_filter = loader_get_filter,
    loader_get_lane_filters = loader_get_lane_filters,
    belt_output_connections = belt_output_connections,
    belt_inner_connections = belt_inner_connections,
    type_is_belt = type_is_belt,
}
