do
    ---@class (exact) Rates.Configuration.AsteroidChunk : Rates.Configuration.Base
    ---@field type "asteroid-chunk"
    ---@field asteroid LuaAsteroidChunkPrototype
end

local progression = require("scripts.progression")

local logic = { type = "asteroid-chunk" } ---@type Rates.Configuration.Type

local asteroid_chunks = {} ---@type table<string, LuaAsteroidChunkPrototype>
for name, asteroid in pairs(prototypes.asteroid_chunk) do
    if (not asteroid.parameter) then
        asteroid_chunks[name] = asteroid
    end
end

---@param conf Rates.Configuration.AsteroidChunk
logic.get_id = function(conf)
    return conf.asteroid.name
end

logic.fill_progression = function(result, options)
    local space_platforms = {} ---@type string[]
    for _, loc in ipairs(options.locations) do
        if (progression.is_space_platform(loc)) then
            space_platforms[#space_platforms + 1] = loc
        end
    end

    for _, asteroid in pairs(asteroid_chunks) do
        local id = "asteroid-chunk/collect/" .. asteroid.name .. "/*"
        result[id] = {
            pre = {
                progression.create.can_collect_asteroid("*"),
                progression.create.space_asteroid(asteroid.name, "*")
            },
            post = {
                progression.create.products(asteroid.mineable_properties.products, "*")
            },
            multi = space_platforms
        }
    end
end

---@param result Rates.Configuration.AsteroidChunk[]
logic.fill_basic_configurations = function(result, options)
    for _, asteroid in pairs(asteroid_chunks) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            asteroid = asteroid
        }
    end
end

return logic
