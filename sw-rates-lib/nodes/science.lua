do
    --- Science while researching a specific technology.
    ---@class (exact) Rates.Node.Science : Rates.Node.Base
    ---@field type "science"
    ---@field technology LuaTechnologyPrototype
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "science", creator = creator } ---@type Rates.Node.Type

---@param technology LuaTechnologyPrototype
---@return Rates.Node.Science
creator.unlock_technology = function(technology)
    return {
        technology = technology
    }
end

---@param node Rates.Node.Science
result.get_id = function(node)
    return node.technology.name
end

---@param node Rates.Node.Science
result.gui_default = function(node)
    return { sprite = "technology/" .. node.technology.name }
end

return result
