local progression = require("scripts.progression")

local logic = { type = "entity" } ---@type Rates.Configuration.Type

local entities_buildable = prototypes.get_entity_filtered { { filter = "buildable" } }
local entities_minable = prototypes.get_entity_filtered { { filter = "minable" }, { mode = "and", invert = true, filter = "type", type = "resource" } }

---@param entity LuaEntityPrototype
---@param location string
---@return Rates.Progression.MultiItemPre
local function items_to_place(entity, location)
    local result = {} ---@type Rates.Progression.MultiItemPre

    for _, item in ipairs(entity.items_to_place_this or {}) do
        result[#result + 1] = progression.create.item(item.name, location)
    end

    return result
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities_buildable) do
        local locations = {} ---@type string[]
        for _, loc in ipairs(options.locations) do
            if (progression.has_surface_conditions(loc, entity.surface_conditions)) then
                locations[#locations + 1] = loc
            end
        end

        local items = items_to_place(entity, "*")

        if (#locations > 0 and #items > 0) then
            local id = "entity/build/" .. entity.name .. "/*"
            result[id] = {
                pre = {
                    items,
                    progression.create.can_build("*")
                },
                post = {
                    progression.create.map_entity(entity.name, "*")
                },
                multi = locations
            }
        end
    end

    for _, entity in pairs(entities_minable) do
        local id = "entity/mine/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.can_build("*")
            },
            post =
            {
                progression.create.products(entity.mineable_properties.products, "*")
            },
            multi = options.locations
        }
    end
end

return logic
