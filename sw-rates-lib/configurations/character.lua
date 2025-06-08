local configuration = require("scripts.configuration-util")
local progression = require("scripts.progression")

local logic = { type = "character" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("character")
local resources = prototypes.get_entity_filtered { { filter = "minable" }, { mode = "and", filter = "type", type = "resource" } }

---@param entity LuaEntityPrototype
---@param resource LuaEntityPrototype
---@return boolean
local function can_mine(entity, resource)
    if (not entity.resource_categories[resource.resource_category]) then
        return false
    end

    if (resource.mineable_properties.required_fluid) then
        return false
    end

    return true
end

logic.fill_progression = function(result, options)
    local active_locations = {} ---@type string[]
    for _, loc in ipairs(options.locations) do
        if (not progression.is_space_platform(loc)) then
            active_locations[#active_locations + 1] = loc
        end
    end

    for _, entity in pairs(entities) do
        local id = "character/build/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*")
            },
            post = {
                progression.create.can_build("*")
            },
            multi = active_locations
        }
    end

    for _, entity in pairs(entities) do
        local id = "character/fight/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*")
            },
            post = {
                progression.create.damage("*")
            },
            multi = active_locations
        }
    end

    for _, entity in pairs(entities) do
        for _, resource in pairs(resources) do
            if (can_mine(entity, resource)) then
                local id = "character/mine/" .. entity.name .. "/" .. resource.name .. "/*"
                result[id] = {
                    pre = {
                        progression.create.map_entity(entity.name, "*"),
                        progression.create.map_entity(resource.name, "*")
                    },
                    post = {
                        progression.create.products(resource.mineable_properties.products, "*")
                    },
                    multi = active_locations
                }
            end
        end
    end
end

return logic
