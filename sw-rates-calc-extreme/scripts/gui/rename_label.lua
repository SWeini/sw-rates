local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local result = {}

local handlers = {}

---@param text string?
---@param label_style string?
---@param fallback_text string?
---@param handler fun(event: GuiEventData)
---@return GuiElemDef
function result.define(text, label_style, fallback_text, handler)
    ---@type GuiElemDef
    return {
        args = {
            type = "flow",
            direction = "horizontal",
            tags = {
                fallback_text = fallback_text or "",
                empty_text = text == nil,
                on_rename = presenter.get_handler_name(handler),
            },
        },
        style_mods = {
            vertical_align = "center",
        },
        children = {
            {
                args = {
                    type = "label",
                    style = label_style or "subheader_caption_label",
                    caption = text or fallback_text or "",
                },
            },
            {
                args = {
                    type = "textfield",
                    icon_selector = true,
                    visible = false,
                },
                _confirmed = handlers.on_confirmed,
                _text_changed = handlers.on_text_changed,
            },
            {
                args = {
                    type = "sprite-button",
                    sprite = "utility/rename_icon",
                    style = "mini_button_aligned_to_text_vertically_when_centered",
                },
                _click = handlers.on_click,
            },
        }
    }
end

---@param element LuaGuiElement
local function toggle_rename(element)
    local children = element.children
    local label = children[1]
    local textfield = children[2]
    local tags = element.tags

    if (textfield.visible) then
        textfield.visible = false
        label.visible = true
        label.caption = textfield.text ~= "" and textfield.text or tags.fallback_text
        tags.empty_text = textfield.text == ""
        element.tags = tags
    else
        textfield.visible = true
        label.visible = false
        textfield.text = tags.empty_text and "" or label.caption --[[@as string]]
        textfield.select_all()
        textfield.focus()
    end
end

---@param event EventData.on_gui_click
function handlers.on_click(event)
    toggle_rename(event.element.parent)
end

---@param event EventData.on_gui_confirmed
function handlers.on_confirmed(event)
    toggle_rename(event.element.parent)
end

---@param event EventData.on_gui_text_changed
function handlers.on_text_changed(event)
    local parent = event.element.parent ---@cast parent -nil
    local handler_name = parent.tags["on_rename"] --[[@as string]]
    local handler = presenter.get_handler(handler_name)
    handler(event)
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "rename_label")

return result
