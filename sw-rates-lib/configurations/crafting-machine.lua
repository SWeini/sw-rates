do
    ---@class (exact) Rates.Configuration.CraftingMachine : Rates.Configuration.Base
    ---@field type "crafting-machine"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field module_effects Rates.Configuration.ModuleEffects
    ---@field recipe LuaRecipePrototype
    ---@field recipe_quality LuaQualityPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")
local location = require("scripts.location")
local generated_temperatures = require("scripts.generated-temperatures")
local meta = require("meta")

local logic = { type = "crafting-machine" } ---@type Rates.Configuration.Type

local entities = prototypes.get_entity_filtered { { filter = "type", type = { "assembling-machine", "furnace", "rocket-silo" } } }

---@param entity LuaEntity
---@return LuaRecipePrototype?, LuaQualityPrototype?
local function get_recipe(entity)
    local recipe, quality = entity.get_recipe()
    if (recipe and quality) then
        return recipe.prototype, quality
    end

    if (entity.type == "furnace") then
        local prev_recipe = entity.previous_recipe
        if (prev_recipe) then
            return prev_recipe.name --[[@as LuaRecipePrototype]], prev_recipe.quality --[[@as LuaQualityPrototype]]
        end
    end
end

---@param entity LuaEntityPrototype
---@param recipe LuaRecipePrototype
---@return boolean
local function can_craft_core(entity, recipe)
    local num_fluid = 0
    local num_item_in = 0
    for _, ingredient in ipairs(recipe.ingredients) do
        if (ingredient.type == "item") then
            num_item_in = num_item_in + 1
        elseif (ingredient.type == "fluid") then
            num_fluid = num_fluid + 1
        end
    end

    for _, product in ipairs(recipe.products) do
        if (product.type == "fluid") then
            num_fluid = num_fluid + 1
        end
    end

    if (entity.type == "character") then
        if (num_fluid > 0) then
            return false
        end
    else
        if (num_fluid > #entity.fluidbox_prototypes) then
            return false
        end
    end

    local max = entity.ingredient_count
    if (max and num_item_in > max) then
        return false
    end

    return true
end

---@param entity LuaEntityPrototype
---@param recipe LuaRecipePrototype
---@return boolean
local function can_craft(entity, recipe)
    local categories = entity.crafting_categories or {}
    local has_category = categories[recipe.category]
    for _, category in ipairs(recipe.additional_categories) do
        if (categories[category]) then
            has_category = true
        end
    end

    if (not has_category) then
        return false
    end

    return can_craft_core(entity, recipe)
end

---@param fluidbox LuaFluidBox
---@param fluid string
---@param production_type data.ProductionType
---@return integer?
local function get_fluidbox(fluidbox, fluid, production_type)
    for i = 1, #fluidbox do
        local proto = fluidbox.get_prototype(i)
        if (proto.object_name ~= "LuaFluidBoxPrototype") then
            proto = proto[1]
        end
        local production = proto.production_type
        if (production == production_type) then
            local filter = fluidbox.get_filter(i)
            if (filter and filter.name == fluid) then
                return i
            end

            local box = fluidbox[i]
            if (box and box.name == fluid) then
                return i
            end
        end
    end
end

---@param fluidbox LuaFluidBox
---@param fluid Ingredient.fluid
---@return number?
local function get_fluid_selected_input_temperature(fluidbox, fluid)
    local i = get_fluidbox(fluidbox, fluid.name, "input")
    if (not i) then
        -- no fluidbox found
        return
    end

    local box = fluidbox[i]
    if (not box) then
        -- no fluid present
        return
    end

    local generated_filter = { min = fluid.minimum_temperature, max = fluid.maximum_temperature }
    local filtered_temperatures = generated_temperatures.get_generated_fluid_temperatures(fluid.name, generated_filter)
    if (#filtered_temperatures <= 1) then
        -- only one temperature is possible, no selection necessary
        return
    end

    local temperature = box.temperature
    for _, temp in ipairs(filtered_temperatures) do
        if (temperature == temp) then
            return temperature
        end
    end

    -- temperature does not match a generated temperature, likely being very dynamic
    return
end

---@param conf Rates.Configuration.CraftingMachine
logic.get_id = function(conf)
    return conf.recipe.name .. "(" .. conf.recipe_quality.name .. ")"
end

---@param conf Rates.Configuration.CraftingMachine
logic.gui_recipe = function(conf)
    return { sprite = "recipe/" .. conf.recipe.name, quality = conf.recipe_quality }
end

---@param conf Rates.Configuration.CraftingMachine
logic.get_production = function(conf, result, options)
    local effective_values = {} ---@type ModuleEffects
    local speed
    if (conf.entity.type == "character") then
        speed = 1

        effective_values.consumption = 0
        effective_values.speed = 1
        effective_values.productivity = 0
        effective_values.pollution = 0
        effective_values.quality = 0
    else
        speed = conf.entity.get_crafting_speed(conf.quality)

        local all_effects = {} ---@type ModuleEffects[]

        local effect_receiver = conf.entity.effect_receiver
        if (effect_receiver) then
            all_effects[#all_effects + 1] = effect_receiver.base_effect
        end

        ---@param m LuaItemPrototype
        ---@return boolean
        local function is_module_allowed(m)
            return true
        end

        if (effect_receiver == nil or effect_receiver.uses_module_effects) then
            local module_effects = configuration.get_module_effects(conf.module_effects.modules, is_module_allowed)
            all_effects[#all_effects + 1] = module_effects
        end

        if (effect_receiver == nil or effect_receiver.uses_beacon_effects) then
            local beacon_effects = configuration.get_beacon_effects(conf.module_effects.beacons, is_module_allowed)
            all_effects[#all_effects + 1] = beacon_effects
        end

        if (options.surface) then
            if (effect_receiver == nil or effect_receiver.uses_surface_effects) then
                all_effects[#all_effects + 1] = location.get_global_effect(options.surface)
            end
        end

        if (options.force) then
            local recipe = options.force.recipes[conf.recipe.name]
            if (recipe) then
                all_effects[#all_effects + 1] = { productivity = recipe.productivity_bonus }
            end
        end

        local sum_effects = configuration.module_add(all_effects)
        effective_values = configuration.get_effective_values(sum_effects)
        effective_values.productivity = math.min(effective_values.productivity, conf.recipe.maximum_productivity)
        local energy_usage = conf.entity.energy_usage * effective_values.consumption
        configuration.calculate_energy_source(result, conf.entity, energy_usage)
    end

    local duration = conf.recipe.energy
    local frequency = speed * effective_values.speed / duration

    configuration.calculate_ingredients(result, conf.recipe_quality, conf.recipe.ingredients, frequency)

    if (conf.entity.type == "rocket-silo") then
        local amount = frequency * (1 + effective_values.productivity) / conf.entity.rocket_parts_required
        if (conf.entity.launch_to_space_platforms) then
            result[#result + 1] = {
                tag = "product",
                node = node.create.send_to_platform(),
                amount = amount
            }
        else
            local rocket_capacity = conf.entity.get_inventory_size(defines.inventory.rocket_silo_rocket)
            result[#result + 1] = {
                tag = "product",
                node = node.create.send_to_orbit(),
                amount = amount * rocket_capacity
            }
        end
    else
        local quality_distribution = nil
        if (options.force and options.apply_quality) then
            quality_distribution = configuration.calculate_quality_distribution(conf.recipe_quality,
                effective_values.quality, options.force)
        end

        configuration.calculate_products(result, conf.recipe_quality, conf.recipe.products, frequency,
            effective_values.productivity, quality_distribution)
    end
end

logic.fill_progression = function(result, options)
    ---@type { [string]: LuaRecipePrototype[] }
    local crafting_categories = {}

    ---@param recipe LuaRecipePrototype
    ---@param category string
    local function add_recipe_catogory(recipe, category)
        local recipes = crafting_categories[category]
        if (not recipes) then
            recipes = {}
            crafting_categories[category] = recipes
        end

        recipes[#recipes + 1] = recipe
    end

    local character_craft_locations = {} ---@type string[]
    for _, loc in ipairs(options.locations) do
        if (not progression.is_space_platform(loc)) then
            character_craft_locations[#character_craft_locations + 1] = loc
        end
    end

    for _, recipe in pairs(prototypes.recipe) do
        if (not recipe.parameter and recipe.name ~= "recipe-unknown") then
            add_recipe_catogory(recipe, recipe.category)
            for _, category in ipairs(recipe.additional_categories) do
                add_recipe_catogory(recipe, category)
            end
        end
    end

    for _, entity in pairs(prototypes.get_entity_filtered { { filter = "type", type = "character" } }) do
        ---@type string[]
        local post = {}
        for category, _ in pairs(entity.crafting_categories) do
            for _, recipe in ipairs(crafting_categories[category] or {}) do
                if (can_craft_core(entity, recipe)) then
                    post[#post + 1] = progression.create.recipe_crafter(recipe.name, "*")
                end
            end
        end

        local id = "character/craft/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*")
            },
            post = post,
            multi = character_craft_locations
        }
    end

    for _, entity in pairs(entities) do
        if (entity.fixed_recipe) then
            -- fixed recipe is a bit special, the recipe might still be locked (and this is fine)

            local recipe = prototypes.recipe[entity.fixed_recipe]
            local locations = {} ---@type string[]
            for _, loc in ipairs(options.locations) do
                if (progression.has_surface_conditions(loc, recipe.surface_conditions)) then
                    locations[#locations + 1] = loc
                end
            end

            if (#locations > 0 and can_craft(entity, recipe)) then
                local pre = progression.create.ingredients(recipe.ingredients, "*")
                pre[#pre + 1] = progression.create.map_entity(entity.name, "*")
                pre[#pre + 1] = progression.create.energy_source(entity, "*")

                local post = {} ---@type string[]
                if (entity.type == "rocket-silo") then
                    if (entity.launch_to_space_platforms) then
                        post[#post + 1] = progression.create.send_to_platform("*")
                    else
                        post[#post + 1] = progression.create.send_to_orbit("*")
                    end
                else
                    post = progression.create.products(recipe.products, "*")
                end

                local id = "crafting-machine/" .. entity.name .. "/*"
                result[id] = {
                    pre = pre,
                    post = post,
                    multi = locations
                }

                progression.add_burner(result, entity, progression.create.ingredients(recipe.ingredients, "*"), "*").multi =
                    options.locations
            end
        elseif (entity.type == "rocket-silo") then
            -- don't use recipe crafter, because the products are not produced

            ---@type (string | string[])[]
            local pre = {}
            ---@type string[]
            local pre_burner = {}
            for category, _ in pairs(entity.crafting_categories) do
                for _, recipe in ipairs(crafting_categories[category] or {}) do
                    if (can_craft_core(entity, recipe)) then
                        pre[#pre + 1] = progression.create.recipe_ingredients(recipe.name, "*")
                        pre_burner[#pre_burner + 1] = progression.create.recipe_ingredients(recipe.name, "*")
                    end
                end
            end

            pre[#pre + 1] = progression.create.map_entity(entity.name, "*")
            pre[#pre + 1] = progression.create.energy_source(entity, "*")

            local post = {} ---@type string[]
            if (entity.launch_to_space_platforms) then
                post[#post + 1] = progression.create.send_to_platform("*")
            else
                post[#post + 1] = progression.create.send_to_orbit("*")
            end

            local id = "crafting-machine/" .. entity.name .. "/*"
            result[id] = {
                pre = pre,
                post = post,
                multi = options.locations
            }

            progression.add_burner(result, entity, {
                pre_burner
            }, "*").multi = options.locations
        else
            -- the normal case, use recipe_crafter

            ---@type string[]
            local post = {}
            ---@type string[]
            local pre_burner = {}
            for category, _ in pairs(entity.crafting_categories) do
                for _, recipe in ipairs(crafting_categories[category] or {}) do
                    if (can_craft_core(entity, recipe)) then
                        post[#post + 1] = progression.create.recipe_crafter(recipe.name, "*")
                        pre_burner[#pre_burner + 1] = progression.create.recipe_ingredients(recipe.name, "*")
                    end
                end
            end

            local id = "crafting-machine/" .. entity.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.map_entity(entity.name, "*"),
                    progression.create.energy_source(entity, "*")
                },
                post = post,
                multi = options.locations
            }

            progression.add_burner(result, entity, {
                pre_burner
            }, "*").multi = options.locations
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "assembling-machine" and options.type ~= "furnace" and options.type ~= "rocket-silo") then
        return
    end

    local recipe, recipe_quality = get_recipe(entity)

    if (recipe and recipe_quality) then
        local temperatures = nil ---@type table<string, string>?
        if (entity.type ~= "entity-ghost") then
            for i, ingredient in ipairs(recipe.ingredients) do
                if (ingredient.type == "fluid") then ---@cast ingredient Ingredient.fluid
                    local temp = get_fluid_selected_input_temperature(entity.fluidbox, ingredient)
                    if (temp) then
                        temperatures = temperatures or {}
                        temperatures["ingredient-" .. i] = "fluid/" .. ingredient.name .. "/" .. temp
                    end
                end
            end
        end

        local module_effects = configuration.get_useful_module_effects(entity, options.use_ghosts)
        configuration.filter_module_effects_receiver(module_effects, options.entity.effect_receiver)
        configuration.filter_module_effects_allowed(module_effects, options.entity.allowed_effects)
        configuration.filter_module_effects_category(module_effects, options.entity.allowed_module_categories)
        configuration.filter_module_effects_allowed(module_effects, recipe.allowed_effects)
        configuration.filter_module_effects_category(module_effects, recipe.allowed_module_categories)

        ---@type Rates.Configuration.CraftingMachine
        local result = {
            type = "crafting-machine",
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = options.entity,
            quality = options.quality,
            module_effects = module_effects,
            recipe = recipe,
            recipe_quality = recipe_quality
        }

        if (temperatures) then
            return meta.with_selection(result, temperatures)
        end

        return result
    end
end

return logic
