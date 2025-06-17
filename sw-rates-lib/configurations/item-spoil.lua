do
    ---@class (exact) Rates.Configuration.ItemSpoil : Rates.Configuration.Base
    ---@field type "item-spoil"
    ---@field item LuaItemPrototype
    ---@field quality LuaQualityPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "item-spoil" } ---@type Rates.Configuration.Type

local items = prototypes.get_item_filtered { { filter = "spoil-result" } }

---@param conf Rates.Configuration.ItemSpoil
logic.get_id = function(conf)
    return conf.item.name .. "(" .. conf.quality.name .. ")"
end

---@param conf Rates.Configuration.ItemSpoil
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "item-with-quality", name = conf.item.spoil_result.name, quality = conf.quality.name }
    }
    -- or use "tooltip-category-spoilable"?
end

---@param conf Rates.Configuration.ItemSpoil
logic.gui_entity = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "item-with-quality", name = conf.item.name, quality = conf.quality.name }
    }
end

---@param conf Rates.Configuration.ItemSpoil
logic.get_production = function(conf, result, options)
    result[#result + 1] = {
        tag = "ingredient",
        node = node.create.item(conf.item, conf.quality),
        amount = -1
    }
    result[#result + 1] = {
        tag = "product",
        node = node.create.item(conf.item.spoil_result, conf.quality),
        amount = 1
    }
end

logic.fill_progression = function(result, options)
    for _, item in pairs(items) do
        local id = "item/spoil/" .. item.name .. "/*"
        result[id] = {
            pre = {
                progression.create.item(item.name, "*")
            },
            post = {
                progression.create.item(item.spoil_result.name, "*")
            },
            multi = options.locations
        }
    end
end

---@param result Rates.Configuration.ItemSpoil[]
logic.fill_basic_configurations = function(result, options)
    for _, item in pairs(items) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            item = item,
            quality = prototypes.quality.normal
        }
    end
end

return logic
