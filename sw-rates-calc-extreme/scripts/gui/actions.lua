local event_handler = require("__core__.lualib.event_handler")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

---@alias Rates.Gui.ActionName
--- | "left"
--- | "left_shift"
--- | "left_control"
--- | "left_alt"
--- | "right"
--- | "right_shift"
--- | "right_control"
--- | "right_alt"

---@alias Rates.Gui.ActionTooltips table<Rates.Gui.ActionName, LocalisedString>

---@type { name: Rates.Gui.ActionName, localization_key: string }[]
local possible_actions = {
    { name = "left",          localization_key = "action-sw-rates-calc-extreme.left" },
    { name = "left_shift",    localization_key = "action-sw-rates-calc-extreme.left-shift" },
    { name = "left_control",  localization_key = "action-sw-rates-calc-extreme.left-ctrl" },
    { name = "left_alt",      localization_key = "action-sw-rates-calc-extreme.left-alt" },
    { name = "right",         localization_key = "action-sw-rates-calc-extreme.right" },
    { name = "right_shift",   localization_key = "action-sw-rates-calc-extreme.right-shift" },
    { name = "right_control", localization_key = "action-sw-rates-calc-extreme.right-ctrl" },
    { name = "right_alt",     localization_key = "action-sw-rates-calc-extreme.right-alt" },
}

---@param tooltip LocalisedString?
---@param actions Rates.Gui.ActionTooltips
---@return LocalisedString?
function presenter.create_action_tooltip(tooltip, actions)
    if (table_size(actions) == 0) then
        return tooltip
    end

    ---@type LocalisedString
    local result = { "" }
    if (tooltip) then
        result[#result + 1] = tooltip
        result[#result + 1] = "\n\n"
    end

    local first = true
    for _, action in ipairs(possible_actions) do
        local text = actions[action.name]
        if (text) then
            if (first) then
                first = false
            else
                result[#result + 1] = "\n"
            end
            result[#result + 1] = { "action-sw-rates-calc-extreme.action", { action.localization_key }, text }
        end
    end

    return result
end
