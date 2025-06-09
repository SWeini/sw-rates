do
    --- An item of specific quality.
    ---@class (exact) Rates.Node.Item : Rates.Node.Base
    ---@field type "item"
    ---@field item LuaItemPrototype
    ---@field quality LuaQualityPrototype
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "item", creator = creator } ---@type Rates.Node.Type

---@param item LuaItemPrototype
---@param quality LuaQualityPrototype
---@return Rates.Node.Item
creator.item = function(item, quality)
    return {
        item = item,
        quality = quality
    }
end

---@param node Rates.Node.Item
result.get_id = function(node)
    return node.item.name .. "(" .. node.quality.name .. ")"
end

---@param node Rates.Node.Item
result.gui_default = function(node)
    return { sprite = "item/" .. node.item.name, quality = node.quality }
end

---@param node Rates.Node.Item
result.gui_text = function(node, options)
    return "[item=" .. node.item.name .. ",quality=" .. node.quality.name .. "]"
end

return result
