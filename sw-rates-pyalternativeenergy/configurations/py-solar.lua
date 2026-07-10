do
    ---@class Rates.Configuration.PySolar : Rates.Configuration.Base
    ---@field type "py-solar"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
end

local api = require("__sw-rates-lib__.api-configuration")
local node = api.node

local logic = { type = "py-solar" } ---@type Rates.Configuration.Type

---@type table<string, { type: "wind" | "tidal" }>
local dynamic_solar_panels = {
    ["multiblade-turbine-mk01"] = { type = "wind" },
    ["multiblade-turbine-mk03"] = { type = "wind" },
    ["hawt-turbine-mk01"] = { type = "wind" },
    ["hawt-turbine-mk02"] = { type = "wind" },
    ["hawt-turbine-mk03"] = { type = "wind" },
    ["hawt-turbine-mk04"] = { type = "wind" },
    ["vawt-turbine-mk01"] = { type = "wind" },
    ["vawt-turbine-mk02"] = { type = "wind" },
    ["vawt-turbine-mk03"] = { type = "wind" },
    ["vawt-turbine-mk04"] = { type = "wind" },
    ["tidal-mk01-solar"] = { type = "tidal" },
    ["tidal-mk02-solar"] = { type = "tidal" },
    ["tidal-mk03-solar"] = { type = "tidal" },
    ["tidal-mk04-solar"] = { type = "tidal" },
}

---@type table<string, string>
local hidden_solar_panels = {
    ["tidal-mk01"] = "tidal-mk01-solar",
    ["tidal-mk02"] = "tidal-mk02-solar",
    ["tidal-mk03"] = "tidal-mk03-solar",
    ["tidal-mk04"] = "tidal-mk04-solar",
}

---@type table<string, true>
local ignored_solar_panels = {}
for _, value in pairs(hidden_solar_panels) do
    ignored_solar_panels[value] = true
end

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
    local solar_panel = dynamic_solar_panels[conf.entity.name]
    if (solar_panel) then
        local max_energy_production = conf.entity.get_max_energy_production(conf.quality)
        local average_multiplier = 1
        if (options.surface) then
            if (solar_panel.type == "wind") then
                local min = options.surface.get_property("py-wind-speed-min")
                local max = options.surface.get_property("py-wind-speed-max")
                average_multiplier = (min + max) / 2
            elseif (solar_panel.type == "tidal") then
                local min = options.surface.get_property("py-tide-height-min")
                local max = options.surface.get_property("py-tide-height-max")
                -- actually it's a bit higher, but that might just be a bug that will be fixed
                average_multiplier = (min + max) / 2
            end
        end

        result[#result + 1] = {
            tag = "product",
            node = node.create.electric_power(),
            amount = max_energy_production * 60 * average_multiplier
        }
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type == "simple-entity-with-owner") then
        local hidden_solar_panel = hidden_solar_panels[options.entity.name]
        if (hidden_solar_panel) then
            ---@type Rates.Configuration.SolarPanel
            return {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = prototypes.entity[hidden_solar_panel],
                quality = options.quality
            }
        end
    end

    if (options.type ~= "solar-panel") then
        return
    end

    local prototype = options.entity

    if (prototype.name:sub(#prototype.name - 5) == "-blank") then
        prototype = prototypes.entity[prototype.name:sub(1, #prototype.name - 6)]
        if (not prototype) then
            return
        end
    end

    if (ignored_solar_panels[prototype.name]) then
        return {
            type = "ignore"
        }
    end

    if (dynamic_solar_panels[prototype.name]) then
        ---@type Rates.Configuration.PySolar
        return {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = prototype,
            quality = options.quality
        }
    end
end

return logic
