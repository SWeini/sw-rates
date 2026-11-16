local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter
require("__core__.lualib.util") -- need table.deepcopy

local handlers = {}

---@class (exact) Rates.Gui.ActionContext
---@field player LuaPlayer
---@field description? LocalisedString
---@field skip? true
---@field changed Rates.Gui.ChangedProperties
---@field sheet Rates.Data.Sheet

---@alias Rates.Gui.UndoableAction fun(context: Rates.Gui.ActionContext)

---@param window LuaGuiElement
---@param action Rates.Gui.UndoableAction
function presenter.run_undo_action(window, action)
    local data = presenter.get_window_data(window)
    local sheet = table.deepcopy(data.sheet)

    ---@type Rates.Gui.ActionContext
    local context = {
        player = data.player,
        sheet = sheet,
        changed = {}
    }
    action(context)
    if (context.skip) then
        return
    end

    sheet.metadata.tick_modified = game.ticks_played
    if (sheet.metadata.id == 0) then
        data.window.undo_stack = {}
        data.window.redo_stack = {}
        local id = storage.library.next_sheet_id
        sheet.metadata.id = id
        storage.library.next_sheet_id = id + 1
        window.tags.sheet_id = id
    else
        local undo_stack = data.window.undo_stack
        undo_stack[#undo_stack + 1] = {
            sheet = data.sheet,
            action = context.description,
        }
        data.window.redo_stack = {}
    end

    storage.library.sheets[sheet.metadata.id] = sheet

    presenter.update_window(window, context.changed)
end

---@param data Rates.Gui.WindowDataFull
---@return GuiElemDef
function presenter.define_undo_redo_buttons(data)
    ---@type GuiElemDef[]
    local children = {}

    ---@type GuiElemDef
    local undo = {
        args = {
            type = "sprite-button",
            sprite = "shortcut/undo",
            mouse_button_filter = { "left" },
            style = "tool_button",
        },
        _click = handlers.on_click_undo,
    }

    ---@type GuiElemDef
    local redo = {
        args = {
            type = "sprite-button",
            sprite = "shortcut/redo",
            mouse_button_filter = { "left" },
            style = "tool_button",
        },
        _click = handlers.on_click_redo,
    }

    local undo_stack = data.window.undo_stack
    local redo_stack = data.window.redo_stack

    children[#children + 1] = undo

    if (#undo_stack == 0) then
        undo.args.enabled = false
    else
        undo.args.tooltip = { "", "Undo: ", undo_stack[#undo_stack].action }

        children[#children + 1] = {
            args = {
                type = "label",
                caption = #undo_stack,
                ignored_by_interaction = true,
            },
            style_mods = {
                font = "sw-rates-calc-extreme-qualifier-font",
                width = 28,
                left_margin = -28,
                top_margin = -2,
                horizontal_align = "right",
                right_padding = 2,
            },
        }
    end

    children[#children + 1] = redo

    if (#redo_stack == 0) then
        redo.args.enabled = false
    else
        redo.args.tooltip = { "", "Redo: ", redo_stack[#redo_stack].action }

        children[#children + 1] = {
            args = {
                type = "label",
                caption = #redo_stack,
                ignored_by_interaction = true,
            },
            style_mods = {
                font = "sw-rates-calc-extreme-qualifier-font",
                width = 28,
                left_margin = -28,
                top_margin = -2,
                horizontal_align = "right",
                right_padding = 2,
            },
        }
    end

    ---@type GuiElemDef
    return {
        args = {
            type = "flow",
            direction = "horizontal",
            style = "packed_horizontal_flow",
        },
        children = children,
    }
end

---@param window LuaGuiElement
---@param from_name "undo_stack" | "redo_stack"
---@param to_name "undo_stack" | "redo_stack"
local function undo_redo(window, from_name, to_name)
    local data = presenter.get_window_data(window)
    local from_stack = data.window[from_name] ---@type Rates.Gui.UndoRedoStackEntry[]
    local to_stack = data.window[to_name] ---@type Rates.Gui.UndoRedoStackEntry[]
    local last = from_stack[#from_stack]
    from_stack[#from_stack] = nil
    to_stack[#to_stack + 1] = {
        sheet = data.sheet,
        action = last.action
    }
    local sheet = last.sheet
    storage.library.sheets[sheet.metadata.id] = sheet
    presenter.update_window(window, {
        metadata = true,
        selection = true,
        configurations = true,
    })
end

---@param event EventData.on_gui_click
function handlers.on_click_undo(event)
    local window = gui_util.find_top(event.element)
    undo_redo(window, "undo_stack", "redo_stack")
end

---@param event EventData.on_gui_click
function handlers.on_click_redo(event)
    local window = gui_util.find_top(event.element)
    undo_redo(window, "redo_stack", "undo_stack")
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "undo")
