local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local library = require("scripts.library")
local rename_label = require("rename_label")

local handlers = {}
local events = {}

---@param data Rates.Gui.WindowDataFull
---@return GuiElemDef[]
local function define_toolbar(data)
    local sheet = data.sheet

    ---@type GuiElemDef[]
    local result = {
        presenter.define_back_button(data),
        presenter.define_undo_redo_buttons(data),
        sheet.metadata.id ~= 0 and
        rename_label.define(sheet.metadata.name, "subheader_caption_label", "<Unnamed sheet>", events.on_sheet_rename) or
        {
            args = {
                type = "label",
                style = "subheader_caption_label",
                caption = { "gui.sw-rates-calc-extreme-new-sheet" },
            }
        },
        {
            args = { type = "empty-widget" },
            style_mods = { horizontally_stretchable = true }
        },
        {
            args = {
                type = "sprite-button",
                sprite = "utility/side_menu_factoriopedia_icon",
                mouse_button_filter = { "left" },
                style = "tool_button_blue",
                tooltip = presenter.create_action_tooltip(nil, { left = { "gui.sw-rates-calc-extreme-library-tooltip" } })
            },
            style_mods = {
                padding = -4
            },
            _click = handlers.on_click_library
        },
    }

    return result
end

---@param event EventData.on_gui_text_changed
function events.on_sheet_rename(event)
    local window = gui_util.find_top(event.element)
    local sheet = presenter.get_sheet_of_window(window)
    local metadata = sheet.metadata
    metadata.name = event.text ~= "" and event.text or nil
    metadata.tick_modified = game.ticks_played

    presenter.update_window(window, { metadata = true })
end

presenter.register_handlers(events, "page_entities")

---@param event EventData.on_gui_click
function handlers.on_click_library(event)
    local window = gui_util.find_top(event.element)
    presenter.open_page(window, { type = "library" })
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "main_toolbar")

return {
    define_toolbar = define_toolbar,
}
