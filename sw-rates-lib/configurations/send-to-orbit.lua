do
    ---@class (exact) Rates.Configuration.SendToOrbit : Rates.Configuration.Base
    ---@field type "send-to-orbit"
    ---@field item LuaItemPrototype
    ---@field quality LuaQualityPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "send-to-orbit" } ---@type Rates.Configuration.Type

local items = prototypes.get_item_filtered { { filter = "has-rocket-launch-products" } }

---@param conf Rates.Configuration.SendToOrbit
logic.get_id = function(conf)
    return conf.item.name .. "(" .. conf.quality.name .. ")"
end

---@param conf Rates.Configuration.SendToOrbit
logic.gui_recipe = function(conf)
    return { sprite = "item/" .. conf.item.name, quality = conf.quality }
end

---@param conf Rates.Configuration.SendToOrbit
logic.gui_entity = function(conf)
    return { sprite = "utility/space_age_icon" }
end

---@param conf Rates.Configuration.SendToOrbit
logic.get_production = function(conf, result, options)
    result[#result + 1] = {
        tag = "energy-source-input",
        node = node.create.send_to_orbit(),
        amount = -1
    }
    result[#result + 1] = {
        tag = "ingredient",
        node = node.create.item(conf.item, conf.quality),
        amount = -conf.item.stack_size
    }
    configuration.calculate_products(result, conf.quality, conf.item.rocket_launch_products, conf.item.stack_size, 0)
end

logic.fill_progression = function(result, options)
    for _, item in pairs(items) do
        local id = "item/send-to-orbit/" .. item.name .. "/*"
        result[id] = {
            pre = {
                progression.create.send_to_orbit("*"),
                progression.create.item(item.name, "*")
            },
            post = {
                progression.create.products(item.rocket_launch_products, "*")
            },
            multi = options.locations
        }
    end
end

---@param result Rates.Configuration.SendToOrbit[]
logic.fill_basic_configurations = function(result, options)
    for _, item in pairs(items) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            item = item,
            quality = prototypes.quality.normal
        }
    end
end

return logic
