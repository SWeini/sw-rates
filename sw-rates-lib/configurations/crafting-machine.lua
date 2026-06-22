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
local energy_source = require("scripts.energy-source")

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
    local has_category = false
    for _, category in ipairs(recipe.categories) do
        if (categories[category]) then
            has_category = true
        end
    end

    if (not has_category) then
        return false
    end

    return can_craft_core(entity, recipe)
end

---@param entity LuaEntity
---@param fluid string
---@param production_type data.ProductionType
---@return integer?
local function get_fluidbox(entity, fluid, production_type)
    for i = 1, entity.fluids_count do
        local proto = entity.get_fluid_box_prototype(i)
        if (proto.object_name ~= "LuaFluidBoxPrototype") then
            proto = proto[1]
        end
        local production = proto.production_type
        if (production == production_type) then
            local filter = entity.get_fluid_filter(i)
            if (filter and filter.name == fluid) then
                return i
            end

            local box = entity.get_fluid(i)
            if (box and box.name == fluid) then
                return i
            end
        end
    end
end

---@param entity LuaEntity
---@param fluid Ingredient.fluid
---@return number?
local function get_fluid_selected_input_temperature(entity, fluid)
    local i = get_fluidbox(entity, fluid.name, "input")
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
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "recipe-with-quality", name = conf.recipe.name, quality = conf.recipe_quality.name }
    }
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

        ---@param m LuaItemPrototype
        ---@return boolean
        local function is_module_allowed(m)
            return true
        end

        local surface_effect = options.surface and location.get_global_effect(options.surface)
        ---@type Rates.Internal.FloatModuleEffects
        local max_effect = {
            productivity = conf.recipe.maximum_productivity
        }
        local additional_effects = {} ---@type Rates.Internal.FloatModuleEffects[]
        if (options.force) then
            local recipe = options.force.recipes[conf.recipe.name]
            if (recipe) then
                additional_effects[#additional_effects + 1] = {
                    productivity = recipe.productivity_bonus
                }
            end
        end

        effective_values = configuration.calculate_effects(
            conf.entity.effect_receiver,
            conf.module_effects,
            surface_effect,
            additional_effects,
            max_effect,
            options.force,
            is_module_allowed)

        local energy_usage = conf.entity.get_max_energy_usage(conf.quality) * effective_values.consumption
        configuration.calculate_energy_source(result, conf.entity, energy_usage, options,
            effective_values.pollution * conf.recipe.emissions_multiplier)
    end

    local duration = conf.recipe.energy
    local frequency = speed * effective_values.speed / duration

    configuration.calculate_recipe_ingredients(result, conf.recipe, conf.recipe_quality, frequency)

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
        configuration.calculate_recipe_products(result, conf.recipe, conf.recipe_quality, frequency,
            effective_values.productivity, effective_values.quality, options.force)
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

            local recipe = entity.fixed_recipe
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

---@param prototype LuaEntityPrototype
---@param inputs Rates.Analyzer.EntityInputs
---@return { recipe: LuaRecipePrototype, quality: LuaQualityPrototype }[]
local function get_furnace_recipes(prototype, inputs)
    ---@type { recipe: LuaRecipePrototype, quality: LuaQualityPrototype }[]
    local result = {}

    local fluid_set = {} ---@type Rates.Analyzer.FluidSet
    local fluid_boxes = inputs.fluid_boxes
    if (fluid_boxes) then
        local offset = prototype.fluid_energy_source_prototype and 1 or 0
        for i = 1, #prototype.fluidbox_prototypes - offset do
            local fb = prototype.fluidbox_prototypes[i]
            if (fb.production_type == "input") then
                fluid_set = fluid_boxes[1 + offset]
            end
        end
    end

    local fluid_names = {}
    for _, fluid in pairs(fluid_set) do
        fluid_names[#fluid_names + 1] = fluid.fluid.name
    end

    local fluid_only_recipes = prototypes.get_recipe_filtered { { filter = "has-ingredient-fluid", elem_filters = { { filter = "name", name = fluid_names } } } }
    for name, possible_recipe in pairs(fluid_only_recipes) do
        ---@cast possible_recipe LuaRecipePrototype
        if (can_craft(prototype, possible_recipe)) then
            if (#possible_recipe.ingredients == 1) then
                result[#result + 1] = { recipe = possible_recipe, quality = prototypes.quality.normal }
            end
        end
    end

    local items = inputs.items
    if (items) then
        for id, item in pairs(items) do
            local item_recipes = prototypes.get_recipe_filtered { { filter = "has-ingredient-item", elem_filters = { { filter = "name", name = item.item.name } } } }
            for _, possible_recipe in pairs(item_recipes) do
                if (can_craft(prototype, possible_recipe)) then
                    if (#possible_recipe.ingredients == 1) then
                        result[#result + 1] = { recipe = possible_recipe, quality = item.quality }
                    elseif (#possible_recipe.ingredients == 2) then
                        local i = possible_recipe.ingredients[1].type == "item" and 2 or 1
                        local other_ingredient = possible_recipe.ingredients[i]
                        if (other_ingredient.type == "fluid") then
                            local has_fluid = false
                            for _, fluid in pairs(fluid_set) do
                                if (fluid.fluid.name == other_ingredient.name and fluid.temperature >= (other_ingredient.minimum_temperature or -math.huge) and fluid.temperature <= (other_ingredient.maximum_temperature or math.huge)) then
                                    has_fluid = true
                                    break
                                end
                            end
                            if (has_fluid) then
                                result[#result + 1] = { recipe = possible_recipe, quality = item.quality }
                            end
                        end
                    end
                end
            end
        end
    end

    return result
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "assembling-machine" and options.type ~= "furnace" and options.type ~= "rocket-silo") then
        return
    end

    local recipe, recipe_quality = get_recipe(entity)

    if (options.type == "furnace" and recipe == nil and options.analyzer_inputs) then
        local possible_recipes = get_furnace_recipes(options.entity, options.analyzer_inputs)
        local size = table_size(possible_recipes)
        if (size == 1) then
            local first_recipe = possible_recipes[1]
            recipe = first_recipe.recipe
            recipe_quality = first_recipe.quality
        elseif (size > 1) then
            local pseudo_result = { type = "crafting-machine", entity = options.entity }
            local fuel = energy_source.get_from_entity(entity, pseudo_result, options)

            local children = {} ---@type Rates.Configuration[]
            for _, r in ipairs(possible_recipes) do
                local recipe = r.recipe

                local module_effects = configuration.get_useful_module_effects(entity, options.use_ghosts)
                configuration.filter_module_effects_receiver(module_effects, options.entity.effect_receiver)
                configuration.filter_module_effects_allowed(module_effects, options.entity.allowed_effects)
                configuration.filter_module_effects_category(module_effects, options.entity.allowed_module_categories)
                configuration.filter_module_effects_allowed(module_effects, recipe.allowed_effects)
                configuration.filter_module_effects_category(module_effects, recipe.allowed_module_categories)

                ---@type Rates.Configuration.CraftingMachine
                local conf = {
                    type = "crafting-machine",
                    entity = options.entity,
                    quality = options.quality,
                    module_effects = module_effects,
                    recipe = recipe,
                    recipe_quality = r.quality
                }

                if (fuel) then
                    ---@type Rates.Configuration.Meta
                    local m = {
                        type = "meta",
                        children = { conf },
                        fuel = fuel
                    }
                    conf = m
                end

                children[#children + 1] = conf
            end

            ---@type Rates.Configuration.Meta
            local meta = {
                type = "meta",
                children = children,
                entity = options.entity,
                quality = options.quality,
            }
            return meta
        end
    end

    if (recipe and recipe_quality) then
        local temperatures = nil ---@type table<string, string>?
        if (options.analyzer_inputs) then
            local fb = options.analyzer_inputs.fluid_boxes
            if (fb) then
                local index = options.entity.fluid_energy_source_prototype and 1 or 0
                for i, ingredient in ipairs(recipe.ingredients) do
                    if (ingredient.type == "fluid") then ---@cast ingredient Ingredient.fluid
                        index = index + 1
                        local temperature = nil
                        local ambiguous = false
                        for _, temp in pairs(fb[index] or {}) do
                            if (temp.fluid.name == ingredient.name) then
                                if (temperature) then
                                    ambiguous = true
                                end
                                temperature = temp.temperature
                            end
                        end
                        if (temperature and not ambiguous) then
                            temperatures = temperatures or {}
                            temperatures["ingredient-" .. i] = "fluid/" .. ingredient.name .. "/" .. temperature
                        end
                    end
                end
            end
        end
        if (entity.type ~= "entity-ghost") then
            for i, ingredient in ipairs(recipe.ingredients) do
                if (ingredient.type == "fluid") then ---@cast ingredient Ingredient.fluid
                    local temp = get_fluid_selected_input_temperature(entity, ingredient)
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

logic.analyze_flow = function(entity, prototype, inputs)
    if (prototype.type ~= "assembling-machine" and prototype.type ~= "furnace" and prototype.type ~= "rocket-silo") then
        return
    end

    local recipe, recipe_quality = get_recipe(entity)

    if (prototype.type == "furnace" and recipe == nil) then
        ---@type Rates.Analyzer.EntityOutputs
        local result = {
            fluid_box_outputs = {},
            required_fluid_box_inputs = {},
            items = {},
            required_items = "on-change"
        }

        local offset = prototype.fluid_energy_source_prototype and 1 or 0

        local num_input_fluidboxes = 0
        for i = 1, #prototype.fluidbox_prototypes - offset do
            local fb_prototype = prototype.fluidbox_prototypes[i]
            if (fb_prototype.production_type == "input") then
                result.required_fluid_box_inputs[i + offset] = "on-change"
                num_input_fluidboxes = num_input_fluidboxes + 1
            end
        end

        local possible_recipe = get_furnace_recipes(prototype, inputs)
        for _, r in ipairs(possible_recipe) do
            local recipe = r.recipe

            local module_effects = configuration.get_useful_module_effects(entity, true)
            configuration.filter_module_effects_receiver(module_effects, prototype.effect_receiver)
            configuration.filter_module_effects_allowed(module_effects, prototype.allowed_effects)
            configuration.filter_module_effects_category(module_effects, prototype.allowed_module_categories)
            configuration.filter_module_effects_allowed(module_effects, recipe.allowed_effects)
            configuration.filter_module_effects_category(module_effects, recipe.allowed_module_categories)

            ---@type Rates.Configuration.CraftingMachine
            local conf = {
                type = "crafting-machine",
                entity = prototype,
                quality = entity.quality,
                recipe = recipe,
                recipe_quality = r.quality,
                module_effects = module_effects
            }
            local amounts = {} ---@type Rates.Configuration.Amount[]
            logic.get_production(conf, amounts,
                { apply_quality = true, force = entity.force --[[@as LuaForce]], surface = entity.surface })

            local fluidbox_index = num_input_fluidboxes
            for _, amount in ipairs(amounts) do
                if (amount.amount > 0) then
                    local node = amount.node
                    if (node.type == "item") then
                        ---@cast node Rates.Node.Item
                        configuration.add_item_to_set(result.items, node.item, node.quality)
                    elseif (node.type == "fluid") then
                        ---@cast node Rates.Node.Fluid
                        fluidbox_index = fluidbox_index + 1
                        result.fluid_box_outputs[fluidbox_index] = {}
                        configuration.add_fluid_to_set(result.fluid_box_outputs[fluidbox_index], node.fluid,
                            node.temperature)
                    end
                end
            end
        end

        return result
    end

    if (recipe and recipe_quality) then
        ---@type Rates.Analyzer.EntityOutputs
        local result = {
            fluid_box_outputs = {},
            required_fluid_box_inputs = {},
            items = {}
        }
        local index = 0
        if (prototype.fluid_energy_source_prototype) then
            index = index + 1
        end

        for _, ingredient in ipairs(recipe.ingredients) do
            if (ingredient.type == "fluid") then
                index = index + 1
                local fluid = prototypes.fluid[ingredient.name]
                local temperature = { min = ingredient.minimum_temperature, max = ingredient.maximum_temperature }
                local temps = generated_temperatures.get_generated_fluid_temperatures(fluid, temperature)
                if (#temps > 1) then
                    result.required_fluid_box_inputs[index] = "once"
                end
            end
        end

        local quality_distribution ---@type { quality: LuaQualityPrototype, multiplier: number }[]
        if (recipe_quality.next) then
            local module_effects = configuration.get_useful_module_effects(entity, true)
            configuration.filter_module_effects_receiver(module_effects, prototype.effect_receiver)
            configuration.filter_module_effects_allowed(module_effects, prototype.allowed_effects)
            configuration.filter_module_effects_category(module_effects, prototype.allowed_module_categories)
            configuration.filter_module_effects_allowed(module_effects, recipe.allowed_effects)
            configuration.filter_module_effects_category(module_effects, recipe.allowed_module_categories)

            ---@param m LuaItemPrototype
            ---@return boolean
            local function is_module_allowed(m)
                return true
            end

            local surface_effect = entity.surface.global_effect
            ---@type Rates.Internal.FloatModuleEffects
            local max_effect = {
                productivity = recipe.maximum_productivity
            }
            local additional_effects = {} ---@type Rates.Internal.FloatModuleEffects[]
            do
                local recipe = entity.force.recipes[recipe.name]
                if (recipe) then
                    additional_effects[#additional_effects + 1] = {
                        productivity = recipe.productivity_bonus
                    }
                end
            end

            local effective_values = configuration.calculate_effects(
                prototype.effect_receiver,
                module_effects,
                surface_effect,
                additional_effects,
                max_effect,
                entity.force --[[@as LuaForce]],
                is_module_allowed)

            quality_distribution = configuration.calculate_quality_distribution(recipe_quality,
                    effective_values.quality, nil, nil, entity.force --[[@as LuaForce]]) or
                { { quality = recipe_quality, multiplier = 1 } }
        else
            quality_distribution = { { quality = recipe_quality, multiplier = 1 } }
        end

        for _, product in ipairs(recipe.products) do
            if (product.type == "fluid") then
                index = index + 1
                local fluid = prototypes.fluid[product.name]
                result.fluid_box_outputs[index] =
                    configuration.build_fluid_set(fluid, product.temperature or fluid.default_temperature)
            elseif (product.type == "item") then
                for _, quality in pairs(quality_distribution) do
                    configuration.add_item_to_set(result.items, prototypes.item[product.name], quality.quality)
                end
            end
        end

        if (prototype.vector_to_place_result) then
            result.drop_items = {}
            for id, item in pairs(result.items) do
                result.drop_items[id] = item
            end
        end

        return result
    end
end

return logic
