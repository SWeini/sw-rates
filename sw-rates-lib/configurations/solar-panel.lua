do
    ---@class (exact) Rates.Configuration.SolarPanel : Rates.Configuration.Base
    ---@field type "solar-panel"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")
local location = require("scripts.location")

local logic = { type = "solar-panel" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("solar-panel")

---@param conf Rates.Configuration.SolarPanel
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-electricity" },
        name = { "sw-rates-node.electric-power" }
    }
end

---@param conf Rates.Configuration.SolarPanel
logic.get_production = function(conf, result, options)
    local max_energy_production = conf.entity.get_max_energy_production(conf.quality)
    local day = conf.entity.solar_panel_performance_at_day * max_energy_production * 60
    local night = conf.entity.solar_panel_performance_at_night * max_energy_production * 60

    configuration.calculate_solar_power(result,
        day, night,
        options.solar_panel_mode,
        conf.entity.solar_panel_solar_coefficient_property,
        options.surface)
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local id = "solar-panel/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*")
            },
            post = {
                progression.create.electric_power("*")
            },
            multi = options.locations
        }
    end
end

---@param result Rates.Configuration.SolarPanel[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = entity,
            quality = prototypes.quality.normal
        }
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "solar-panel") then
        return
    end

    ---@type Rates.Configuration.SolarPanel
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality
    }
end

return logic
