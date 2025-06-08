do
    ---@class (exact) Rates.Configuration.Lab : Rates.Configuration.Base
    ---@field type "lab"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field module_effects Rates.Configuration.ModuleEffects
    ---@field technology LuaTechnologyPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")
local location = require("scripts.location")

local logic = { type = "lab" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("lab")
local technologies = prototypes.technology

---@param entity LuaEntityPrototype
---@param technology LuaTechnologyPrototype
---@return boolean
local function can_research(entity, technology)
    local lab_inputs = {}
    for _, input in ipairs(entity.lab_inputs or {}) do
        lab_inputs[input] = true
    end
    for _, ingredient in ipairs(technology.research_unit_ingredients) do
        if (not lab_inputs[ingredient.name]) then
            return false
        end
    end

    return true
end

---@param conf Rates.Configuration.Lab
logic.get_id = function(conf)
    return conf.technology.name
end

---@param conf Rates.Configuration.Lab
logic.gui_recipe = function(conf)
    return { sprite = "technology/" .. conf.technology.name }
end

---@param conf Rates.Configuration.Lab
logic.get_production = function(conf, result, options)
    local effective_values = {} ---@type ModuleEffects
    local speed = conf.entity.get_researching_speed(conf.quality)

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
        all_effects[#all_effects + 1] = {
            speed = options.force.laboratory_speed_modifier,
            productivity = options.force.laboratory_productivity_bonus
        }
    end

    local sum_effects = configuration.module_add(all_effects)
    effective_values = configuration.get_effective_values(sum_effects)
    local energy_usage = conf.entity.energy_usage * effective_values.consumption
    configuration.calculate_energy_source(result, conf.entity, energy_usage)

    local duration = conf.technology.research_unit_energy / 60
    local frequency = speed * effective_values.speed / duration
    local science_drain = conf.entity.science_pack_drain_rate_percent / 100
    -- TODO science drain from quality

    for i, ingredient in ipairs(conf.technology.research_unit_ingredients) do
        result[#result + 1] = {
            tag = "ingredient",
            tag_extra = i,
            node = node.create.item(prototypes.item[ingredient.name], prototypes.quality.normal),
            amount = -ingredient.amount * frequency * science_drain
        }
    end

    result[#result + 1] = {
        tag = "product",
        node = node.create.unlock_technology(conf.technology),
        amount = frequency * (1 + effective_values.productivity)
    }
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        for _, technology in pairs(technologies) do
            if (can_research(entity, technology)) then
                ---@type Rates.Progression.Pre
                local pre = {
                    progression.create.map_entity(entity.name, "*"),
                    progression.create.energy_source(entity, "*")
                }

                for _, ingredient in ipairs(technology.research_unit_ingredients) do
                    pre[#pre + 1] = progression.create.item(ingredient.name, "*")
                end

                for _, prerequisite in pairs(technology.prerequisites) do
                    pre[#pre + 1] = progression.create.unlock_technology(prerequisite.name)
                end

                local id = "lab/" .. entity.name .. "/" .. technology.name .. "/*"
                result[id] = {
                    pre = pre,
                    post = {
                        progression.create.unlock_technology(technology.name)
                    },
                    multi = options.locations
                }
            end
        end
    end
end

---@param result Rates.Configuration.Lab[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(prototypes.get_entity_filtered { { filter = "type", type = "lab" } }) do
        for _, technology in pairs(prototypes.technology) do
            if (can_research(entity, technology)) then
                result[#result + 1] = {
                    type = nil, ---@diagnostic disable-line: assign-type-mismatch
                    id = nil, ---@diagnostic disable-line: assign-type-mismatch
                    entity = entity,
                    quality = prototypes.quality.normal,
                    module_effects = {},
                    technology = technology
                }
            end
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "lab") then
        return
    end

    local technology = entity.force.current_research
    if (not technology) then
        return
    end

    local module_effects = configuration.get_useful_module_effects(entity, options.use_ghosts)
    configuration.filter_module_effects_receiver(module_effects, options.entity.effect_receiver)
    configuration.filter_module_effects_allowed(module_effects, options.entity.allowed_effects)
    configuration.filter_module_effects_category(module_effects, options.entity.allowed_module_categories)

    ---@type Rates.Configuration.Lab
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        module_effects = module_effects,
        technology = technology.prototype
    }
end

return logic
