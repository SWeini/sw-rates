do
    ---@class (exact) Rates.Configuration.MiningDrill : Rates.Configuration.Base
    ---@field type "mining-drill"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field module_effects Rates.Configuration.ModuleEffects
    ---@field resource? LuaEntityPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")
local location = require("scripts.location")

local logic = { type = "mining-drill" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("mining-drill")
local resources = prototypes.get_entity_filtered { { filter = "type", type = "resource" }, { filter = "minable" } }

local support_mining_area = helpers.compare_versions(helpers.game_version, "2.0.69") >= 0

---@param entity LuaEntityPrototype
---@param resource LuaEntityPrototype
---@return boolean
local function can_mine(entity, resource)
    if (not entity.resource_categories[resource.resource_category]) then
        return false
    end

    if (resource.mineable_properties.required_fluid) then
        if (entity.type == "character") then
            return false
        end

        if (#entity.fluidbox_prototypes == 0) then
            return false
        end
    end

    return true
end

---@param conf Rates.Configuration.MiningDrill
logic.get_id = function(conf)
    return conf.resource and conf.resource.name or "<no-resource>"
end

---@param conf Rates.Configuration.MiningDrill
logic.gui_recipe = function(conf)
    if (conf.resource) then
        ---@type Rates.Gui.NodeDescription
        return {
            element = { type = "entity", name = conf.resource.name }
        }
    end

    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "utility/resources_depleted_icon" }
    }
end

---@param conf Rates.Configuration.MiningDrill
logic.get_production = function(conf, result, options)
    local effective_values = {} ---@type ModuleEffects
    local speed, drain
    if (conf.entity.type == "character") then
        speed = conf.entity.mining_speed

        effective_values.consumption = 0
        effective_values.speed = 1
        effective_values.productivity = 0
        effective_values.pollution = 0
        effective_values.quality = 0
        drain = 1
    else
        speed = conf.entity.mining_speed

        ---@param m LuaItemPrototype
        ---@return boolean
        local function is_module_allowed(m)
            return true
        end

        local surface_effect = options.surface and location.get_global_effect(options.surface)
        local additional_effects = {} ---@type Rates.Internal.FloatModuleEffects[]
        if (options.force) then
            if (conf.entity.uses_force_mining_productivity_bonus) then
                additional_effects[#additional_effects + 1] = {
                    productivity = options.force.mining_drill_productivity_bonus
                }
            end
        end

        effective_values = configuration.calculate_effects(
            conf.entity.effect_receiver,
            conf.module_effects,
            surface_effect,
            additional_effects,
            nil,
            options.force,
            is_module_allowed)

        drain = conf.entity.resource_drain_rate_percent / 100 * conf.quality.mining_drill_resource_drain_multiplier
        local energy_usage = conf.entity.energy_usage * effective_values.consumption
        configuration.calculate_energy_source(result, conf.entity, energy_usage, options, effective_values.pollution)
    end

    if (not conf.resource) then
        return
    end

    local mineable = conf.resource.mineable_properties
    local duration = mineable.mining_time
    local frequency = speed * effective_values.speed / duration

    result[#result + 1] = {
        tag = "resource",
        node = node.create.map_entity(conf.resource, prototypes.quality.normal),
        amount = -frequency * drain
    }

    if (mineable.required_fluid) then
        result[#result + 1] = {
            tag = "mining-fluid",
            node = node.create.fluid(prototypes.fluid[mineable.required_fluid], {}),
            amount = -mineable.fluid_amount / 10 * frequency
        }
    end

    if (mineable.products) then
        local quality_distribution = nil
        if (options.apply_quality) then
            quality_distribution = configuration.calculate_quality_distribution(prototypes.quality.normal,
                effective_values.quality, options.force)
        end

        configuration.calculate_products(result, prototypes.quality.normal, mineable.products,
            frequency, effective_values.productivity, quality_distribution)
    end
end

logic.fill_generated_temperatures = function(result)
    for _, entity in pairs(resources) do
        local mineable = entity.mineable_properties
        for _, product in ipairs(mineable.products or {}) do
            if (product.type == "fluid") then
                configuration.add_fluid_temperature(result.fluids, prototypes.fluid[product.name], product.temperature)
            end
        end
    end
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        for _, resource in pairs(resources) do
            if (can_mine(entity, resource)) then
                ---@type Rates.Progression.Pre
                local pre_burner = {
                    progression.create.map_entity(resource.name, "*")
                }

                ---@type Rates.Progression.Pre
                local pre = {
                    progression.create.map_entity(entity.name, "*"),
                    progression.create.map_entity(resource.name, "*"),
                    progression.create.energy_source(entity, "*")
                }

                local fluid = resource.mineable_properties.required_fluid
                if (fluid) then
                    pre[#pre + 1] = progression.create.fluid(fluid, {}, "*")
                    pre_burner[#pre_burner + 1] = progression.create.fluid(fluid, {}, "*")
                    -- TODO: unlock mining fluid
                end

                local id = "mining-drill/" .. entity.name .. "/" .. resource.name .. "/*"
                result[id] = {
                    pre = pre,
                    post =
                    {
                        progression.create.products(resource.mineable_properties.products, "*")
                    },
                    multi = options.locations
                }

                progression.add_burner(result, entity, pre_burner, "*", resource.name).multi = options.locations
            end
        end
    end
end

---@param result Rates.Configuration.MiningDrill[]
logic.fill_basic_configurations = function(result, options)
    -- TODO: remove entity from basic configuration
    for _, entity in pairs(prototypes.get_entity_filtered { { filter = "type", type = { "mining-drill", "character" } } }) do
        for _, resource in pairs(resources) do
            if (can_mine(entity, resource)) then
                result[#result + 1] = {
                    type = nil, ---@diagnostic disable-line: assign-type-mismatch
                    entity = entity,
                    quality = prototypes.quality.normal,
                    module_effects = {},
                    resource = resource
                }
            end
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "mining-drill") then
        return
    end

    local resource

    if (entity.type ~= "entity-ghost") then
        local target = entity.mining_target
        if (target) then
            resource = target.prototype
        end
    end

    if (not resource) then
        local mining_area ---@type BoundingBox.0
        if (support_mining_area) then
            mining_area = entity.mining_area
        else
            local radius = options.entity.get_mining_drill_radius(options.quality)
            local center = entity.position
            mining_area = {
                left_top = {
                    x = center.x - radius,
                    y = center.y - radius
                },
                right_bottom = {
                    x = center.x + radius,
                    y = center.y + radius
                }
            }
        end
        local resources_in_range = entity.surface.find_entities_filtered { type = "resource", area = mining_area }
        for _, target in ipairs(resources_in_range) do
            -- find_entities_filtered returns all colliding resources, but for mining drills the resource center needs to be inside the mining area
            if (configuration.bbox_position_inside(target.position, mining_area)) then
                local category = target.prototype.resource_category
                if (options.entity.resource_categories[category]) then
                    resource = target.prototype
                end
            end
        end
    end

    local module_effects = configuration.get_useful_module_effects(entity, options.use_ghosts)
    configuration.filter_module_effects_receiver(module_effects, options.entity.effect_receiver)
    configuration.filter_module_effects_allowed(module_effects, options.entity.allowed_effects)
    configuration.filter_module_effects_category(module_effects, options.entity.allowed_module_categories)

    ---@type Rates.Configuration.MiningDrill
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        module_effects = module_effects,
        resource = resource,
    }
end

return logic
