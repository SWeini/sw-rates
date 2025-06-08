do
    ---@class (exact) Rates.Configuration.AsteroidCollector : Rates.Configuration.Base
    ---@field type "asteroid-collector"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field asteroid LuaAsteroidChunkPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "asteroid-collector" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("asteroid-collector")
local asteroids = prototypes.asteroid_chunk

---@param space LuaSpaceLocationPrototype
---@return { [string]: number }
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
---@return { [string]: number }
local function get_connection_asteroid_ratio(connection)
    local result = {} ---@type { [string]: number }
    for _, spawn in ipairs(connection.asteroid_spawn_definitions or {}) do
        if (spawn.type == "asteroid-chunk") then
            result[spawn.asteroid] = get_connection_probability(spawn.spawn_points)
        end
    end

    return result
end

---@param conf Rates.Configuration.AsteroidCollector
logic.get_id = function(conf)
    return conf.asteroid.name
end

---@param conf Rates.Configuration.AsteroidCollector
logic.gui_recipe = function(conf)
    return { sprite = "asteroid-chunk/" .. conf.asteroid.name }
end

---@param conf Rates.Configuration.AsteroidCollector
logic.get_production = function(conf, result, options)
    configuration.calculate_energy_source(result, conf.entity, conf.entity.get_max_energy_usage(conf.quality))
    configuration.calculate_products(result, prototypes.quality.normal, conf.asteroid.mineable_properties.products, 1, 0)
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
        for _, asteroid in pairs(asteroids) do
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                id = nil, ---@diagnostic disable-line: assign-type-mismatch
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

    local filter = entity.get_filter(1)
    if (not filter) then
        return
    end

    ---@type Rates.Configuration.AsteroidCollector
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        asteroid = prototypes.asteroid_chunk[filter.name]
    }
end

return logic
