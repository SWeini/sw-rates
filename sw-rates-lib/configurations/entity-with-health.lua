local progression = require("scripts.progression")

local logic = { type = "entity-with-health" } ---@type Rates.Configuration.Type

local enemies = prototypes.get_entity_filtered { { filter = "type", type = { "unit-spawner", "unit" } }, { mode = "and", filter = "flag", flag = "placeable-enemy" } }

---@param loots? Loot[]
---@param location any
---@return Rates.Progression.Post
local function get_loot(loots, location)
    local result = {} ---@type Rates.Progression.Post

    for _, loot in ipairs(loots or {}) do
        result[#result + 1] = progression.create.item(loot.item, location)
    end

    return result
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(enemies) do
        local loot = get_loot(entity.loot, "*")
        if (loot) then
            local id = "entity-with-health/loot/" .. entity.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.map_entity(entity.name, "*"),
                    progression.create.damage("*")
                },
                post = loot,
                multi = options.locations
            }
        end
    end
end

return logic
