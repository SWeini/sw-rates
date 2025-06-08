local progression = require("scripts.progression")

local logic = { type = "unit-spawner" } ---@type Rates.Configuration.Type

local entities = prototypes.get_entity_filtered { { filter = "type", type = "unit-spawner" } }

---@param spawns? UnitSpawnDefinition[]
---@param location string
---@return Rates.Progression.Post
local function get_spawns(spawns, location)
    ---@type Rates.Progression.Post
    local result = {}
    for _, unit in pairs(spawns or {}) do
        result[#result + 1] = progression.create.map_entity(unit.unit, location)
    end

    return result
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local id = "unit-spawner/spawn/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*")
            },
            post = get_spawns(entity.result_units, "*")
        }
    end
end

return logic
