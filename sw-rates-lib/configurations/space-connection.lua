local progression = require("scripts.progression")

local logic = { type = "space-connection" } ---@type Rates.Configuration.Type

---@param spawns? SpaceConnectionAsteroidSpawnDefinition[]
---@param location string
---@return string[]
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

    local result = {} ---@type string[]

    for asteroid, _ in pairs(asteroids) do
        result[#result + 1] = progression.create.space_asteroid(asteroid, location)
    end

    for entity, _ in pairs(entities) do
        result[#result + 1] = progression.create.map_entity(entity, location)
    end

    return result
end

logic.fill_progression = function(result, options)
    local space_platforms = {} ---@type string[]
    for _, loc in ipairs(options.locations) do
        if (progression.is_space_platform(loc)) then
            space_platforms[#space_platforms + 1] = loc
        end
    end

    for _, connection in pairs(prototypes.space_connection) do
        do
            local id = "space-connection/move-forward/" .. connection.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.space_travel(connection.from.name, "*"),
                    progression.create.unlock_location(connection.to.name),
                    progression.create.thrust("*")
                },
                post = {
                    progression.create.space_travel(connection.to.name, "*")
                },
                multi = space_platforms
            }
        end

        do
            local id = "space-connection/move-backward/" .. connection.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.space_travel(connection.to.name, "*"),
                    progression.create.unlock_location(connection.from.name),
                    progression.create.thrust("*")
                },
                post = {
                    progression.create.space_travel(connection.from.name, "*")
                },
                multi = space_platforms
            }
        end

        do
            local id = "space-connection/asteroid-spawn/" .. connection.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.space_travel(connection.from.name, "*"),
                    progression.create.space_travel(connection.to.name, "*")
                },
                post = get_spawns(connection.asteroid_spawn_definitions, "*"),
                multi = space_platforms
            }
        end
    end
end

return logic
