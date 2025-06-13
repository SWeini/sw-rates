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
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "utility/space_age_icon" },
        name = { "sw-rates-node.send-to-orbit" },
        tooltip = { "", "1 ", { "sw-rates-node.stack" } },
    }
end

return result
