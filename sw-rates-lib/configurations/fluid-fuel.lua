do
    ---@class (exact) Rates.Configuration.FluidFuel : Rates.Configuration.Base
    ---@field type "fluid-fuel"
    ---@field fluid LuaFluidPrototype
    ---@field temperature number
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")
local generated_temperatures = require("scripts.generated-temperatures")

local logic = { type = "fluid-fuel" } ---@type Rates.Configuration.Type

local fluids = prototypes.get_fluid_filtered { { filter = "fuel-value", comparison = ">", value = 0 } }

---@param conf Rates.Configuration.FluidFuel
logic.get_id = function(conf)
    return conf.fluid.name .. "(" .. conf.temperature .. ")"
end

---@param conf Rates.Configuration.FluidFuel
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-fuel" },
        name = { "sw-rates-node.fluid-fuel" }
    }
end

---@param conf Rates.Configuration.FluidFuel
logic.gui_entity = function(conf)
    local qualifier ---@type LocalisedString
    local temps = generated_temperatures.get_generated_fluid_temperatures(node.fluid)
    if (#temps == 1 and temps[1] == node.temperature) then
        qualifier = nil
    else
        qualifier = { "", node.temperature, { "si-unit-degree-celsius" } }
    end

    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "fluid", name = conf.fluid.name },
        qualifier = qualifier
    }
end

---@param conf Rates.Configuration.FluidFuel
logic.get_production = function(conf, result, options)
    result[#result + 1] = {
        tag = "energy-source-input",
        node = node.create.fluid(conf.fluid, conf.temperature),
        amount = -1
    }

    result[#result + 1] = {
        tag = "product",
        node = node.create.fluid_fuel(),
        amount = conf.fluid.fuel_value / configuration.energy_factor
    }
end

logic.fill_progression = function(result, options)
    for _, fluid in pairs(fluids) do
        local id = "fluid-fuel/" .. fluid.name .. "/*"
        result[id] = {
            pre = {
                progression.create.fluid(fluid.name, {}, "*")
            },
            post = {
                progression.create.fluid_fuel("*")
            }
        }
    end
end

---@param result Rates.Configuration.FluidFuel[]
logic.fill_basic_configurations = function(result, options)
    for _, fluid in pairs(fluids) do
        for _, temp in ipairs(generated_temperatures.get_generated_fluid_temperatures(fluid)) do
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                fluid = fluid,
                temperature = temp
            }
        end
    end
end

return logic
