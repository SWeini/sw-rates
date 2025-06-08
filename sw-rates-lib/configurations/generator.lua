do
    ---@class (exact) Rates.Configuration.Generator : Rates.Configuration.Base
    ---@field type "generator"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field temperature number
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")
local generated_temperatures = require("scripts.generated-temperatures")

local logic = { type = "generator" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("generator")

---@param prototype LuaEntityPrototype
---@return { input: LuaFluidPrototype? }
local function get_fluids(prototype)
    local fluidbox = prototype.fluidbox_prototypes
    local input_fluid = fluidbox[1].filter
    return { input = input_fluid }
end

---@param conf Rates.Configuration.Generator
logic.get_id = function(conf)
    return tostring(conf.temperature)
end

---@param conf Rates.Configuration.Generator
logic.gui_recipe = function(conf)
    return { sprite = "tooltip-category-electricity" }
end

---@param conf Rates.Configuration.Generator
logic.get_production = function(conf, result, options)
    local fluid = get_fluids(conf.entity).input

    if (fluid == nil or conf.entity.scale_fluid_usage or conf.entity.burns_fluid) then
        return
    end

    local amount = conf.entity.get_fluid_usage_per_tick(conf.quality) * 60

    result[#result + 1] = {
        tag = "energy-source-input",
        node = node.create.fluid(fluid, conf.temperature),
        amount = -amount
    }

    local temperature = conf.temperature
    if (conf.entity.maximum_temperature and temperature > conf.entity.maximum_temperature) then
        temperature = conf.entity.maximum_temperature
    end

    local energy = amount * (temperature - fluid.default_temperature) * fluid.heat_capacity

    result[#result + 1] = {
        tag = "product",
        node = node.create.electric_power(),
        amount = energy * conf.entity.effectivity / configuration.energy_factor
    }
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local fluids = get_fluids(entity)
        local id = "generator/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.fluid(fluids.input.name, {}, "*") -- TODO: temp must be above default
            },
            post = {
                progression.create.electric_power("*")
            },
            multi = options.locations
        }
    end
end

---@param result Rates.Configuration.Generator[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        local fluids = get_fluids(entity)
        local temperatures = generated_temperatures.get_generated_fluid_temperatures(fluids.input)
        for _, temperature in ipairs(temperatures) do
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                id = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = entity,
                quality = prototypes.quality.normal,
                temperature = temperature
            }
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "generator") then
        return
    end

    local fluids = get_fluids(options.entity)
    local temperature = options.entity.maximum_temperature or fluids.input.default_temperature
    if (entity.type ~= "entity-ghost") then
        local fluid = entity.fluidbox[1]
        if (fluid) then
            temperature = fluid.temperature --[[@as number]]
        end
    end

    -- TODO: return all possible temperatures

    ---@type Rates.Configuration.Generator
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        temperature = temperature
    }
end

return logic
