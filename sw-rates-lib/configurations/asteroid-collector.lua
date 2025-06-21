do
    ---@class (exact) Rates.Configuration.AsteroidCollector : Rates.Configuration.Base
    ---@field type "asteroid-collector"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field asteroid LuaAsteroidChunkPrototype
end

local configuration = require("scripts.configuration-util")
local configuration_api = require("scripts.configuration")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "asteroid-collector" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("asteroid-collector")

local asteroid_chunks = {} ---@type table<string, LuaAsteroidChunkPrototype>
for name, asteroid in pairs(prototypes.asteroid_chunk) do
    if (not asteroid.parameter and asteroid.name ~= "asteroid-chunk-unknown") then
        asteroid_chunks[name] = asteroid
    end
end

---@param space LuaSpaceLocationPrototype
---@return table<string, number>
local function get_space_asteroid_ratio(space)
    local result = {} ---@type { [string]: number }
    for _, spawn in ipairs(space.asteroid_spawn_definitions or {}) do
        if (spawn.type == "asteroid-chunk") then
            result[spawn.asteroid] = spawn.probability
        end
    end

    return result
end

---@param spawn SpaceConnectionAsteroidSpawnPoint[]
local function get_connection_probability(spawn)
    table.sort(spawn, function(a, b)
        return a.distance < b.distance
    end)
    table.insert(spawn, 1, { distance = 0, probability = 0 })
    table.insert(spawn, { distance = 1, probability = 0 })

    local sum = 0
    for i = 2, #spawn - 1 do
        local before = spawn[i - 1]
        local this = spawn[i]
        local after = spawn[i + 1]

        sum = sum + this.probability * (after.distance - before.distance)
    end

    return sum
end

---@param connection LuaSpaceConnectionPrototype
---@return table<string, number>
local function get_connection_asteroid_ratio(connection)
    local result = {} ---@type { [string]: number }
    for _, spawn in ipairs(connection.asteroid_spawn_definitions or {}) do
        if (spawn.type == "asteroid-chunk") then
            result[spawn.asteroid] = get_connection_probability(spawn.spawn_points)
        end
    end

    return result
end

---@param surface LuaSurface
---@return table<string, number>?
local function get_surface_asteroid_ratio(surface)
    local platform = surface.platform
    if (not platform) then
        return
    end

    if (platform.space_location) then
        return get_space_asteroid_ratio(platform.space_location)
    end

    if (platform.space_connection) then
        return get_connection_asteroid_ratio(platform.space_connection)
    end
end

---@param entity LuaEntityPrototype
---@param quality LuaQualityPrototype
---@return { ticks: number, amount: number }
local function get_speed(entity, quality)
    local num_arms = entity.arm_count_base + quality.level * entity.arm_count_quality_scaling
    local arm_inventory_size = entity.get_inventory_size(defines.inventory.asteroid_collector_arm, quality)
    local arm_speed = entity.arm_speed_base + quality.level * entity.arm_speed_quality_scaling -- in tiles/tick
    local collection_radius = entity.radius_visualisation_specification.distance + quality.level
    -- let's assume that the arm doesn't travel to the max distance every time, but then it sometimes goes into the corners
    local average_distance_ratio = 0.7
    local average_distance = collection_radius * average_distance_ratio
        -- the collection area is not centered on the asteroid collector
        + entity.collection_box_offset
        -- the arm does not start/end at the center of the asteroid collector
        - entity.deposit_radius
    local ticks_for_full_movement = 2 * average_distance / arm_speed
    local extra_distance = entity.minimal_arm_swing_segment_retraction * entity.tether_size
        -- always moving just the minimum is not realistic, 2x minimum on average is more likely
        * 2
    local ticks_for_one_extra_movement = 2 * extra_distance / arm_speed
    local ticks_for_all_extra_movements = ticks_for_one_extra_movement * (arm_inventory_size - 1)
    local ticks_for_collecting_max_chunks = ticks_for_full_movement + ticks_for_all_extra_movements
    return {
        ticks = ticks_for_collecting_max_chunks,
        amount = num_arms * arm_inventory_size
    }
end

---@param conf Rates.Configuration.AsteroidCollector
logic.get_id = function(conf)
    return conf.asteroid.name
end

---@param conf Rates.Configuration.AsteroidCollector
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "asteroid-chunk", name = conf.asteroid.name }
    }
end

---@param conf Rates.Configuration.AsteroidCollector
logic.get_production = function(conf, result, options)
    local speed = get_speed(conf.entity, conf.quality)
    local frequency = speed.amount / speed.ticks * 60
    configuration.calculate_energy_source(result, conf.entity, conf.entity.get_max_energy_usage(conf.quality), options)
    configuration.calculate_products(result, prototypes.quality.normal, conf.asteroid.mineable_properties.products,
        frequency, 0)
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local id = "asteroid-collector/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.energy_source(entity, "*")
            },
            post = {
                progression.create.can_collect_asteroid("*")
            },
            multi = options.locations
        }
    end
end

---@param result Rates.Configuration.AsteroidCollector[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        for _, asteroid in pairs(asteroid_chunks) do
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = entity,
                quality = prototypes.quality.normal,
                asteroid = asteroid
            }
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "asteroid-collector") then
        return
    end

    local is_controlled_by_circuits = false
    local behavior = entity.get_control_behavior() --[[@as LuaAsteroidCollectorControlBehavior?]]
    if (behavior) then
        if (behavior.set_filter) then
            for wire, connector in pairs(entity.get_wire_connectors(false)) do
                if (wire == defines.wire_connector_id.circuit_red or wire == defines.wire_connector_id.circuit_green) then
                    if (connector.connection_count > 0) then
                        is_controlled_by_circuits = true
                    end
                end
            end
        end
    end

    local filters_map = {} ---@type table<string, true>
    local unfiltered = true
    if (not is_controlled_by_circuits) then
        for i = 1, entity.filter_slot_count do
            local filter = entity.get_filter(i) --[[@as AsteroidChunkID?]]
            if (filter) then
                local name = filter.name
                if (not filters_map[name]) then
                    filters_map[name] = true
                    unfiltered = false
                end
            end
        end
    end

    local asteroid_ratio = get_surface_asteroid_ratio(entity.surface)
    local sum_of_ratios = 0
    local children = {} ---@type Rates.Configuration[]
    local children_ratio = {} ---@type number[]
    for name, ratio in pairs(asteroid_ratio or {}) do
        if (ratio > 0 and (unfiltered or filters_map[name])) then
            ---@type Rates.Configuration.AsteroidCollector
            local child = {
                type = "asteroid-collector",
                entity = options.entity,
                quality = options.quality,
                asteroid = prototypes.asteroid_chunk[name]
            }
            children[#children + 1] = child
            children_ratio[#children_ratio + 1] = ratio
            sum_of_ratios = sum_of_ratios + ratio
        end
    end

    if (#children == 0 or sum_of_ratios == 0) then
        return
    end

    if (#children == 1) then
        return children[1]
    end

    for i = 1, #children_ratio do
        children_ratio[i] = children_ratio[i] / sum_of_ratios
    end

    ---@type Rates.Configuration.Meta
    return {
        type = "meta",
        children = children,
        children_suggested_factors = children_ratio
    }
end

return logic
