do
    --- A rocket carrying items to a space platform (using the rocket lift weight).
    ---@class (exact) Rates.Node.SendToPlatform : Rates.Node.Base
    ---@field type "send-to-platform"
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "send-to-platform", creator = creator } ---@type Rates.Node.Type

---@return Rates.Node.SendToPlatform
creator.send_to_platform = function()
    return {}
end

---@param node Rates.Node.SendToPlatform
result.gui_default = function(node)
    return { sprite = "utility/space_age_icon" }
end

return result
