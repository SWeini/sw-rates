do
    ---@class Rates.Configuration.PySolar : Rates.Configuration.Base
    ---@field type "py-solar"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
end

local api = require("__sw-rates-lib__.api-configuration")
local configuration = api.configuration
local node = api.node
local progression = api.progression

local logic = { type = "py-solar" } ---@type Rates.Configuration.Type

local solar_panels = {
    ["solar-panel-mk02"] = { day = 21 * 1e6 },
    ["solar-panel-mk03"] = { day = 70 * 1e6 },
}

local hidden_solar_panels = {
    ["tidal-mk01"] = "tidal-mk01-solar",
    ["tidal-mk02"] = "tidal-mk02-solar",
    ["tidal-mk03"] = "tidal-mk03-solar",
    ["tidal-mk04"] = "tidal-mk04-solar",
}

---@param conf Rates.Configuration.PySolar
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-electricity" },
        name = { "sw-rates-node.electric-power" }
    }
end

---@param conf Rates.Configuration.PySolar
logic.get_production = function(conf, result, options)
    local solar_panel = solar_panels[conf.entity.name]
    if (solar_panel) then
        local property = prototypes.surface_property["solar-power"]
        configuration.calculate_solar_power(result,
            solar_panel.day or 0, solar_panel.night or 0,
            options.solar_panel_mode,
            property, options.surface)
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type == "simple-entity-with-owner") then
        local hidden_solar_panel = hidden_solar_panels[options.entity.name]
        if (hidden_solar_panel) then
            ---@type Rates.Configuration.SolarPanel
            return {
                type = "solar-panel",
                entity = prototypes.entity[hidden_solar_panel],
                quality = options.quality
            }
        end
    end

    if (options.type ~= "electric-energy-interface") then
        return
    end

    if (solar_panels[options.entity.name]) then
        ---@type Rates.Configuration.PySolar
        return {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = options.entity,
            quality = options.quality
        }
    end
end

return logic
