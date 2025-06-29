do
    --- Alternatives on the input side. Most importantly used for fluid/heat temperatures.
    ---@class (exact) Rates.Node.Any : Rates.Node.Base
    ---@field type "any"
    ---@field children Rates.Node[]
    ---@field details? Rates.Node.Any.Details
end

local util = require("scripts.node")

local creator = {} ---@class Rates.Node.Creator
local result = { type = "any", creator = creator } ---@type Rates.Node.Type

---@param children Rates.Node[]
---@return Rates.Node
creator.any = function(children)
    if (#children == 1) then
        return children[1]
    end

    return {
        children = children
    }
end

---@param node Rates.Node.Any
result.get_id = function(node)
    if (#node.children == 0) then
        return "-"
    end

    local ids = {} ---@type string[]
    for i, child in ipairs(node.children) do
        ids[i] = util.get_id(child)
    end

    return table.concat(ids, "|")
end

---@param node Rates.Node.Any
result.gui_default = function(node)
    if (node.details) then
        return util.gui_default(node.details)
    end

    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "virtual-signal/signal-anything" },
        name = util.get_id(node)
    }
end

return result
