do
    ---@class (exact) Rates.Configuration.FusionGenerator : Rates.Configuration.Base
    ---@field type "fusion-generator"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field temperature number
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")
local generated_temperatures = require("scripts.generated-temperatures")

local logic = { type = "fusion-generator" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("fusion-generator")

local support_effectivity = helpers.compare_versions(helpers.game_version, "2.0.67") >= 0

---@param prototype LuaEntityPrototype
---@return { input: LuaFluidPrototype, output: LuaFluidPrototype }
local function get_fluids(prototype)
    local fluidbox = prototype.fluidbox_prototypes
    local input_fluid = fluidbox[#fluidbox - 1].filter --[[@as LuaFluidPrototype]]
    local output_fluid = fluidbox[#fluidbox].filter --[[@as LuaFluidPrototype]]
    return { input = input_fluid, output = output_fluid }
end

---@param conf Rates.Configuration.FusionGenerator
logic.get_id = function(conf)
    return tostring(conf.temperature)
end

---@param conf Rates.Configuration.FusionGenerator
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-electricity" },
        name = { "sw-rates-node.electric-power" }
    }
end

---@param conf Rates.Configuration.FusionGenerator
logic.get_production = function(conf, result, options)
    local fluids = get_fluids(conf.entity)

    if (fluids.input == nil or fluids.output == nil) then
        return
    end

    local burns_fluid ---@type boolean
    local effectivity ---@type number
    if (support_effectivity) then
        burns_fluid = conf.entity.burns_fluid
        effectivity = conf.entity.effectivity
    else
        burns_fluid = false
        effectivity = 1.0
    end

    local input_temperature = conf.temperature
    local energy_per_fluid ---@type number
    if (burns_fluid) then
        energy_per_fluid = fluids.input.fuel_value * effectivity
    else
        energy_per_fluid = fluids.input.heat_capacity * input_temperature * effectivity
    end

    if (energy_per_fluid <= 0) then
        return
    end

    local flow = conf.entity.get_fluid_usage_per_tick(conf.quality)
    local max_energy = conf.entity.electric_energy_source_prototype.get_output_flow_limit(conf.quality)
    if (max_energy < energy_per_fluid * flow) then
        flow = max_energy / energy_per_fluid
    end

    result[#result + 1] = {
        tag = "energy-source-input",
        node = node.create.fluid(fluids.input, input_temperature),
        amount = -flow * 60
    }
    result[#result + 1] = {
        tag = "energy-source-output",
        node = node.create.fluid(fluids.output, fluids.output.default_temperature),
        amount = flow * 60
    }
    result[#result + 1] = {
        tag = "product",
        node = node.create.electric_power(),
        amount = flow * energy_per_fluid * 60
    }
end

logic.fill_generated_temperatures = function(result)
    for _, entity in pairs(entities) do
        local fluids = get_fluids(entity)
        configuration.add_fluid_temperature(result.fluids, fluids.output)
    end
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local fluids = get_fluids(entity)
        local id = "fusion-generator/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.fluid(fluids.input.name, {}, "*")
            },
            post = {
                progression.create.electric_power("*"),
                progression.create.fluid(fluids.output.name, fluids.output.default_temperature, "*")
            },
            multi = options.locations
        }
    end
end

---@param result Rates.Configuration.FusionGenerator[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        local fluids = get_fluids(entity)
        local temperatures = generated_temperatures.get_generated_fluid_temperatures(fluids.input)
        for _, temperature in ipairs(temperatures) do
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = entity,
                quality = prototypes.quality.normal,
                temperature = temperature
            }
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "fusion-generator") then
        return
    end

    local fluid = get_fluids(options.entity)
    local temperature = fluid.input.default_temperature
    local fluidbox = entity.fluidbox[1]
    if (fluidbox) then
        temperature = fluidbox.temperature --[[@as number]]
    end

    ---@type Rates.Configuration.FusionGenerator
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        temperature = temperature
    }
end

---@param conf Rates.Configuration.FusionGenerator
---@return LuaFluidPrototype
local function get_input_fluid(conf)
    return get_fluids(conf.entity).input
end

---@param conf Rates.Configuration.FusionGenerator
---@return LuaFluidPrototype
local function get_output_fluid(conf)
    return get_fluids(conf.entity).output
end

return {
    types = { logic },
    get_input_fluid = get_input_fluid,
    get_output_fluid = get_output_fluid,
}
