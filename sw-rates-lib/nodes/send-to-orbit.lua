do
    --- An item slot in an old-style rocket silo to send items to orbit.
    ---@class (exact) Rates.Node.SendToOrbit : Rates.Node.Base
    ---@field type "send-to-orbit"
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "send-to-orbit", creator = creator } ---@type Rates.Node.Type

---@return Rates.Node.SendToOrbit
creator.send_to_orbit = function()
    return {}
end

---@param node Rates.Node.SendToOrbit
result.gui_default = function(node)
    return { sprite = "utility/space_age_icon" }
end

---@param node Rates.Node.SendToOrbit
result.gui_text = function(node, options)
    return "rocket to orbit"
end

return result
