local progression = require("scripts.progression")

local logic = { type = "space-location" } ---@type Rates.Configuration.Type

---@param spawns? SpaceLocationAsteroidSpawnDefinition[]
---@param location string
---@return Rates.Progression.Post
local function get_spawns(spawns, location)
    local asteroids = {} ---@type { [string]: true }
    local entities = {} ---@type { [string]: true }
    for _, spawn in pairs(spawns or {}) do
        if (spawn.type == "asteroid-chunk") then
            asteroids[spawn.asteroid] = true
        elseif (spawn.type == "entity") then
            entities[spawn.asteroid] = true
        end
    end

    local result = {} ---@type Rates.Progression.Post

    for asteroid, _ in pairs(asteroids) do
        result[#result + 1] = progression.create.space_asteroid(asteroid, location)
    end

    for entity, _ in pairs(entities) do
        result[#result + 1] = progression.create.map_entity(entity, location)
    end

    return result
end

logic.fill_progression_locations = function(result, options)
    for _, space in pairs(prototypes.space_location) do
        if (space.type == "planet") then
            result[#result + 1] = "planet-" .. space.name
        end
    end
end

logic.fill_progression = function(result, options)
    local space_platforms = {} ---@type string[]
    for _, loc in ipairs(options.locations) do
        if (progression.is_space_platform(loc)) then
            space_platforms[#space_platforms + 1] = loc
        end
    end

    for _, space in pairs(prototypes.space_location) do
        local id = "space-location/asteroid-spawn/" .. space.name .. "/*"
        result[id] = {
            pre = {
                progression.create.space_travel(space.name, "*")
            },
            post = get_spawns(space.asteroid_spawn_definitions, "*"),
            multi = space_platforms
        }
    end
end

return logic
