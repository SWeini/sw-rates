do
    ---@class Rates.Configuration.PySmartFarm : Rates.Configuration.CraftingMachine
    ---@field type "py-smartfarm"
end

local api = require("__sw-rates-lib__.api-configuration")
local node = api.node
local progression = api.progression
local configuration = require("__sw-rates-lib__.scripts.configuration")
local crafting = require("__sw-rates-lib__.configurations.crafting-machine")

local logic = { type = "py-smartfarm", stats = { priority = 100 } } ---@type Rates.Configuration.Type

---@type { [string]: { seed: string, crop: string } }
local farm_types = {
    ["mova"] = { seed = "replicator-mova", crop = "mova" },
    ["cadaveric-arum"] = { seed = "replicator-cadaveric-arum", crop = "arum" },
    ["native-flora"] = { seed = "replicator-bioreserve", crop = "ore-bioreserve" },
    ["grod"] = { seed = "replicator-grod", crop = "grod-flower" },
    ["kicalk"] = { seed = "replicator-kicalk", crop = "kicalk-tree" },
    ["ralesia"] = { seed = "replicator-ralesia", crop = "ralesia-flowers" },
    ["rennea"] = { seed = "replicator-rennea", crop = "rennea-flowers" },
    ["tuuphra"] = { seed = "replicator-tuuphra", crop = "tuuphra-tuber" },
    ["yotoi-fruit"] = { seed = "replicator-yotoi-fruit", crop = "yotoi-tree-fruit" },
    ["yotoi"] = { seed = "replicator-yotoi", crop = "yotoi-tree" }
}

---@param recipe LuaRecipePrototype
---@return boolean
local function is_farm_recipe(recipe)
    if (not prototypes.entity["mega-farm"].crafting_categories[recipe.category]) then
        return false
    end

    if (#recipe.products ~= 1) then
        return false
    end

    local product = recipe.products[1]
    if (product.type ~= "item" or not farm_types[product.name]) then
        return false
    end

    return true
end

logic.get_id = crafting.get_id
logic.gui_recipe = crafting.gui_recipe

---@param conf Rates.Configuration.PySmartFarm
logic.get_production = function(conf, result, options)
    crafting.get_production(conf, result, options)

    local idx_orbit = 1
    while (result[idx_orbit].node.type ~= "send-to-orbit") do
        idx_orbit = idx_orbit + 1
    end

    local frequency = result[idx_orbit].amount
    local product = conf.recipe.products[1] --[[@as ItemProduct]]
    local config = farm_types[product.name]

    if (config) then
        result[idx_orbit] = {
            tag = "ingredient",
            tag_extra = "replicator",
            node = node.create.item(prototypes.item[config.seed], conf.recipe_quality),
            amount = -frequency
        }
        result[#result + 1] = {
            tag = "product",
            tag_extra = 1,
            node = node.create.map_entity(prototypes.entity[config.crop], prototypes.quality.normal),
            amount = frequency * product.amount
        }
    end
end

logic.fill_progression = function(result, options)
    local entity = prototypes.entity["mega-farm"]

    for _, recipe in pairs(prototypes.recipe) do
        if (is_farm_recipe(recipe)) then
            local locations = {} ---@type string[]
            for _, loc in ipairs(options.locations) do
                if (progression.has_surface_conditions(loc, recipe.surface_conditions)) then
                    locations[#locations + 1] = loc
                end
            end

            ---@type Rates.Progression.Pre
            local pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.recipe_ingredients(recipe.name, "*"),
                progression.create.energy_source(entity, "*")
            }

            local config
            for _, product in ipairs(recipe.products) do
                if (product.type == "item") then
                    config = farm_types[product.name]
                end
            end

            pre[#pre + 1] = progression.create.item(config.seed, "*")

            local id = "recipe/craft/" .. recipe.name .. "/*"
            result[id] = {
                pre = pre,
                post = {
                    progression.create.map_entity(config.crop, "*")
                },
                multi = locations
            }
        end
    end

    do
        local id = "crafting-machine/" .. entity.name .. "/*"
        result[id] = {
            pre = {},
            post = {},
            multi = options.locations
        }
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "rocket-silo" or options.entity.name ~= "mega-farm") then
        return
    end

    local result = crafting.get_from_entity(entity, options)
    if (result.type == "meta") then
        local child = result.children[1]
        child.type = "py-smartfarm"
        child.id = nil
        result.id = nil
    else
        result.type = "py-smartfarm"
        result.id = nil
    end

    return result
end

return logic
