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
    ["solar-panel-mk02"] = { day = 7 * 1e6 },
    ["solar-panel-mk03"] = { day = 14 * 1e6 },
    ["anti-solar"] = { night = 100 * 1e6 },
}

---@param conf Rates.Configuration.PySolar
logic.gui_recipe = function(conf)
    return { sprite = "tooltip-category-electricity" }
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
    if (options.type ~= "electric-energy-interface") then
        return
    end

    if (solar_panels[options.entity.name]) then
        ---@type Rates.Configuration.PySolar
        return {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = options.entity,
            quality = options.quality
        }
    end
end

return logic
