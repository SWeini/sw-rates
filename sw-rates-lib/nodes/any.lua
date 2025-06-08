do
    --- Alternatives on the input side. Most importantly used for fluid/heat temperatures.
    ---@class (exact) Rates.Node.Any : Rates.Node.Base
    ---@field type "any"
    ---@field children Rates.Node[]
    ---@field details? Rates.Node.Any.Details
end

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

    local result = ""
    for i, child in ipairs(node.children) do
        if (i > 1) then
            result = result .. "|"
        end
        result = result .. child.id
    end

    return result
end

---@param node Rates.Node.Any
result.gui_default = function(node)
    return {
        sprite = "virtual-signal/signal-anything"
    }
end

return result
