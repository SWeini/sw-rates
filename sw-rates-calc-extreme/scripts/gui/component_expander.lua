local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local component = require("component")

local handlers = {}

---@class (exact) Rates.Gui.Component.Expander.Storage
---@field data table<string, boolean>
---@field index string

---@class (exact) Rates.Gui.Component.Expander : Rates.Gui.Component
---@field expander_storage? Rates.Gui.Component.Expander.Storage

---@param header GuiElemDef
---@param content GuiElemDef
---@param default_expanded boolean
---@param expander_storage Rates.Gui.Component.Expander.Storage?
---@return GuiElemDef
local function define(header, content, default_expanded, expander_storage)
    local expanded = default_expanded
    if (expander_storage) then
        local stored_expanded = expander_storage.data[expander_storage.index]
        if (stored_expanded ~= nil) then
            expanded = stored_expanded
        end
    end

    if (not expanded) then
        content.elem_mods = content.elem_mods or {}
        content.elem_mods.visible = false
    end

    ---@type GuiElemDef
    return {
        args = {
            type = "flow",
            direction = "vertical",
        },
        children = {
            {
                args = {
                    type = "flow",
                    direction = "horizontal",
                },
                style_mods = {
                    vertical_align = "center",
                },
                children = {
                    {
                        args = { type = "sprite-button", sprite = expanded and "utility/collapse" or "utility/expand", style = "expand_collapse_button" },
                        _click = handlers.on_click,
                        callback = function(element)
                            ---@type Rates.Gui.Component.Expander
                            local element_data = {
                                expander_storage = expander_storage,
                            }
                            component.set_element_data(element, element_data)
                        end,
                    },
                    header,
                }
            },
            content,
        }
    }
end

---@param event EventData.on_gui_click
function handlers.on_click(event)
    local element = event.element
    local element_data = component.get_element_data(element) --[[@as Rates.Gui.Component.Expander]]
    local expander_storage = element_data.expander_storage
    local content = element.parent.parent.children[2]
    if (element.sprite == "utility/expand") then
        element.sprite = "utility/collapse"
        content.visible = true
    else
        element.sprite = "utility/expand"
        content.visible = false
    end
    if (expander_storage) then
        expander_storage.data[expander_storage.index] = content.visible
    end
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "component_expander")

return {
    define = define,
}
