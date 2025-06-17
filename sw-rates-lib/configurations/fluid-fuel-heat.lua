do
    ---@class (exact) Rates.Configuration.FluidFuelHeat : Rates.Configuration.Base
    ---@field type "fluid-fuel-heat"
    ---@field fluid LuaFluidPrototype
    ---@field temperature number
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local generated_temperatures = require("scripts.generated-temperatures")

local logic = { type = "fluid-fuel-heat" } ---@type Rates.Configuration.Type

---@param conf Rates.Configuration.FluidFuelHeat
logic.get_id = function(conf)
    return conf.fluid.name .. "(" .. conf.temperature .. ")"
end

---@param conf Rates.Configuration.FluidFuelHeat
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-fuel" },
        name = { "sw-rates-node.fluid-fuel" }
    }
end

---@param conf Rates.Configuration.FluidFuelHeat
logic.gui_entity = function(conf)
    local qualifier ---@type LocalisedString
    local temps = generated_temperatures.get_generated_fluid_temperatures(conf.fluid)
    if (#temps == 1 and temps[1] == conf.temperature) then
        qualifier = nil
    else
        qualifier = { "", conf.temperature, { "si-unit-degree-celsius" } }
    end

    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "fluid", name = conf.fluid.name },
        qualifier = qualifier
    }
end

---@param conf Rates.Configuration.FluidFuelHeat
logic.get_production = function(conf, result, options)
    result[#result + 1] = {
        tag = "energy-source-input",
        node = node.create.fluid(conf.fluid, conf.temperature),
        amount = -1
    }

    result[#result + 1] = {
        tag = "product",
        node = node.create.fluid_fuel(),
        amount = conf.fluid.heat_capacity * (conf.temperature - conf.fluid.default_temperature)
    }
end

return logic
