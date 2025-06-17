do
    ---@class (exact) Rates.Configuration.Recipe : Rates.Configuration.Base
    ---@field type "recipe"
    ---@field recipe LuaRecipePrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "recipe" } ---@type Rates.Configuration.Type

---@param conf Rates.Configuration.Recipe
logic.get_id = function(conf)
    return conf.recipe.name
end

---@param conf Rates.Configuration.Recipe
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "recipe", name = conf.recipe.name }
    }
end

---@param conf Rates.Configuration.Recipe
logic.gui_entity = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "recipe", name = conf.recipe.name }
    }
end

---@param conf Rates.Configuration.Recipe
logic.get_production = function(conf, result, options)
    local speed = 1
    local duration = conf.recipe.energy
    local frequency = speed / duration

    configuration.calculate_ingredients(result, prototypes.quality.normal, conf.recipe.ingredients, frequency)
    configuration.calculate_products(result, prototypes.quality.normal, conf.recipe.products, frequency, 0)
end

logic.fill_generated_temperatures = function(result)
    for _, recipe in pairs(prototypes.recipe) do
        for _, product in ipairs(recipe.products) do
            if (product.type == "fluid") then
                configuration.add_fluid_temperature(result.fluids, prototypes.fluid[product.name], product.temperature)
            end
        end
    end
end

logic.fill_progression = function(result, options)
    for _, recipe in pairs(prototypes.recipe) do
        if (not recipe.parameter and recipe.name ~= "recipe-unknown") then
            local locations = {} ---@type string[]
            for _, loc in ipairs(options.locations) do
                if (progression.has_surface_conditions(loc, recipe.surface_conditions)) then
                    locations[#locations + 1] = loc
                end
            end

            ---@type (string | string[])[]
            local pre = {
                progression.create.unlock_recipe(recipe.name)
            }
            for _, ingredient in ipairs(recipe.ingredients) do
                if (ingredient.type == "item") then
                    ---@cast ingredient Ingredient.base
                    pre[#pre + 1] = progression.create.item(ingredient.name, "*")
                elseif (ingredient.type == "fluid") then
                    ---@cast ingredient Ingredient.fluid
                    pre[#pre + 1] = progression.create.fluid(ingredient.name,
                        { min = ingredient.minimum_temperature, max = ingredient.maximum_temperature }, "*")
                end
            end

            local id = "recipe/ingredients/" .. recipe.name .. "/*"
            result[id] = {
                pre = pre,
                post = {
                    progression.create.recipe_ingredients(recipe.name, "*")
                },
                multi = locations
            }

            local id = "recipe/craft/" .. recipe.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.recipe_crafter(recipe.name, "*"),
                    progression.create.recipe_ingredients(recipe.name, "*")
                },
                post = {
                    progression.create.products(recipe.products, "*")
                },
                multi = locations
            }
        end
    end
end

---@param result Rates.Configuration.Recipe[]
logic.fill_basic_configurations = function(result, options)
    for _, recipe in pairs(prototypes.recipe) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            recipe = recipe
        }
    end
end

return logic
