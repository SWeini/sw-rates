local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local library = require("scripts.library")
local sheet_solver = require("scripts.sheet")
local main_toolbar = require("main_toolbar")
local storage = require("scripts.storage")

local main_window_name = "sw-rates-calc-extreme_wnd_main"

local handlers = {}

---@class (exact) Rates.Gui.WindowDataFull
---@field player LuaPlayer
---@field player_data Rates.Gui.DataPerPlayer
---@field player_settings Rates.Gui.SettingsPerPlayer
---@field window Rates.Gui.DataPerWindow
---@field page Rates.Gui.NavigationEntry
---@field sheet Rates.Data.Sheet

presenter.get_storage_player = storage.get_storage_player

---@param player LuaPlayer
---@param name string
local function remove_storage_window(player, name)
    local store = storage.get_storage_player(player)
    local all_windows = store.windows
    if (all_windows) then
        all_windows[name] = nil
    end
end

---@param data Rates.Gui.WindowDataFull
---@return GuiElemDef
local function define_main_window(data)
    local sheet = data.sheet

    ---@type GuiElemDef[]
    local children = {
        {
            args = {
                type = "label",
                caption = { "gui.sw-rates-calc-extreme-title" },
                style = "frame_title",
                ignored_by_interaction = true,
            },
            style_mods = {
                top_margin = -3,
                bottom_margin = 3,
            },
        },
        {
            args = {
                type = "empty-widget",
                style = "draggable_space_header",
                ignored_by_interaction = true,
            },
            style_mods = {
                height = 24,
                right_margin = 4,
                horizontally_stretchable = true,
            },
        },
    }

    -- children[#children + 1] = {
    --     args = {
    --         name = "settings_button",
    --         type = "sprite-button",
    --         mouse_button_filter = { "left" },
    --         style = "frame_action_button",
    --         sprite = "utility/change_recipe",
    --         tooltip = "Settings",
    --     },
    --     _click = handlers.on_click_settings,
    -- }

    children[#children + 1] = {
        args = {
            name = "pin_button",
            type = "sprite-button",
            mouse_button_filter = { "left" },
            style = "frame_action_button",
            sprite = "glib-pin",
            tooltip = { "factoriopedia.pin-tooltip" },
        },
        _click = handlers.on_click_pin,
    }

    children[#children + 1] = {
        args = {
            name = "close_button",
            type = "sprite-button",
            mouse_button_filter = { "left" },
            style = "close_button",
            sprite = "utility/close",
        },
        _click = handlers.on_click_close,
    }

    ---@type GuiElemDef
    local titlebar = {
        args = {
            name = "titlebar",
            type = "flow",
            style = "frame_header_flow"
        },
        style_mods = {
            bottom_padding = 0,
            minimal_width = 441, -- add 32 for each button added
        },
        drag_target = main_window_name,
        _click = handlers.on_click_titlebar,
        children = children,
    }

    ---@type GuiElemDef
    local toolbar = {
        args = {
            type = "frame",
            style = "inside_shallow_frame",
            direction = "vertical",
            -- visible = false,
        },
        style_mods = {
            bottom_margin = 2,
        },
        children = {
            {
                args = {
                    name = "toolbar",
                    type = "frame",
                    style = "subheader_frame"
                },
                style_mods = {
                    horizontally_stretchable = true,
                },
                children = main_toolbar.define_toolbar(data),
            },
        },
    }

    ---@type GuiElemDef
    local window = {
        args = {
            name = main_window_name,
            type = "frame",
            direction = "vertical",
            tags = { sheet_id = sheet.metadata.id },
        },
        _closed = handlers.on_closed,
        children =
        {
            titlebar,
            toolbar,
            {
                args = {
                    name = "main_panels",
                    type = "flow",
                    style = "inset_frame_container_horizontal_flow",
                },
                children = {
                    presenter.define_page(data, data.page.page_id, data.page.state, "left"),
                    presenter.define_page(data, data.page.page_id, data.page.state, "right"),
                }
            },
        }
    }

    return window
end

---@param player LuaPlayer
---@return LuaGuiElement?
function presenter.find_main_window(player)
    return player.gui.screen[main_window_name]
end

---@param player LuaPlayer
---@param sheet Rates.Data.Sheet
---@param reset boolean
---@return LuaGuiElement
function presenter.open_window(player, sheet, reset)
    local window = presenter.find_main_window(player)
    if (window) then
        remove_storage_window(player, window.name)
        window.destroy()
    elseif (reset) then
        remove_storage_window(player, main_window_name)
    end

    local player_storage = storage.get_storage_player(player)
    local window_storage = storage.get_storage_window(player_storage, main_window_name)
    ---@type Rates.Gui.WindowDataFull
    local data = {
        player = player,
        player_settings = player_storage.settings,
        player_data = player_storage,
        window = window_storage,
        page = window_storage.navigation_stack[#window_storage.navigation_stack],
        sheet = sheet,
    }

    data.window.sheet_rates = sheet_solver.calculate(player, sheet)

    window = glib.add(player.gui.screen, define_main_window(data))
    player_storage.last_sheet = sheet.metadata.id
    return window
end

---@param player LuaPlayer
---@return number
local function get_max_height(player)
    return player.display_resolution.height / player.display_scale * 0.8
end

---@param player LuaPlayer
---@param window LuaGuiElement
local function set_max_height(player, window)
    -- local player = game.get_player(window.player_index) ---@cast player -nil
    window.style.maximal_height = get_max_height(player)
end

---@param window LuaGuiElement
function presenter.position_main_window(window)
    local player = game.get_player(window.player_index) ---@cast player -nil
    local position = settings.get_player_settings(player)["sw-rates-calc-extreme-window-open-position"]
    if (position.value == "center") then
        window.auto_center = true
    elseif (position.value == "top-left") then
        window.location = { x = 15, y = 58 + 15 }
    end

    set_max_height(player, window)
end

---@param window LuaGuiElement
---@param sheet Rates.Data.Sheet
function presenter.open_sheet(window, sheet)
    glib.set_tag(window, "sheet_id", sheet.metadata.id)
    local data = presenter.get_window_data(window)
    data.window.sheet_rates = nil
    data.window.undo_stack = {}
    data.window.redo_stack = {}
    data.window.navigation_stack = {
        {
            page_id = { type = "rates" },
            state = {
                expanders = {},
                rate_configs = {},
            }
        }
    }

    local page = data.window.navigation_stack[1]

    if (sheet.metadata.id == 0) then
        page.page_id = { type = "library" }
    else
        data.player_data.last_sheet = sheet.metadata.id
    end

    data.window.sheet_rates = data.sheet and sheet_solver.calculate(data.player, data.sheet)

    presenter.update_main_toolbar(window, data)

    local container = window.children[3]
    container.clear()

    local content_left = presenter.define_page(data, page.page_id, page.state, "left")
    glib.add(container, content_left)

    local content_right = presenter.define_page(data, page.page_id, page.state, "right")
    glib.add(container, content_right)
end

---@param window LuaGuiElement
---@param data Rates.Gui.WindowDataFull
function presenter.update_main_toolbar(window, data)
    local toolbar = window.children[2].children[1]
    toolbar.clear()
    for _, part in ipairs(main_toolbar.define_toolbar(data)) do
        glib.add(toolbar, part)
    end
end

---@param window LuaGuiElement
---@param changed Rates.Gui.ChangedProperties
function presenter.update_window(window, changed)
    local data = presenter.get_window_data(window)

    if (changed.selected_sheet) then
        changed.selection = true
    end

    if (changed.selection) then
        changed.configurations = true
    end

    if (changed.configurations) then
        local selected_configurations ---@type Rates.Sheet.Configuration[]?
        if (not changed.selection) then
            selected_configurations = data.window.sheet_rates and data.window.sheet_rates.selected_configurations
        end
        data.window.sheet_rates = data.sheet and sheet_solver.calculate(data.player, data.sheet, selected_configurations)
    end

    local is_rename = changed.metadata and table_size(changed) == 1
    if (not is_rename) then
        presenter.update_main_toolbar(window, data)
    end

    local container = window.children[3]
    local page = data.page.page_id
    local page_presenter = presenter.pages[page.type]

    for i = 1, 2 do
        local element = container.children[i]
        local panel_presenter = i == 1 and page_presenter.left_panel or page_presenter.right_panel
        local update = panel_presenter.update_panel
        local updated = false
        if (update) then
            updated = update(element, data, changed)
        end

        if (not updated) then
            presenter.update_page(element, data, page, panel_presenter)
        end
    end
end

---@param window LuaGuiElement
---@return Rates.Data.Sheet
function presenter.get_sheet_of_window(window)
    local sheet_id = window.tags.sheet_id --[[@as Rates.Data.SheetId?]]
    if (sheet_id == nil or sheet_id == 0) then
        local player = game.get_player(window.player_index) ---@cast player -nil
        return library.create_sheet(player)
    end
    return library.get_sheet(sheet_id)
end

---@param window LuaGuiElement
---@return Rates.Gui.WindowDataFull
function presenter.get_window_data(window)
    local player = game.get_player(window.player_index) ---@cast player -nil
    local player_storage = storage.get_storage_player(player)
    local window_storage = storage.get_storage_window(player_storage, main_window_name)
    ---@type Rates.Gui.WindowDataFull
    return {
        player = player,
        player_settings = player_storage.settings,
        player_data = player_storage,
        window = window_storage,
        page = window_storage.navigation_stack[#window_storage.navigation_stack],
        sheet = presenter.get_sheet_of_window(window),
    }
end

---@param event EventData.on_gui_closed
function handlers.on_closed(event)
    local element = event.element ---@cast element -nil
    local pin_button = gui_util.find_child(element, "pin_button")
    local is_pinned = pin_button.toggled
    if (is_pinned) then
        return
    end

    element.destroy()
end

---@param event EventData.on_gui_click
function handlers.on_click_close(event)
    local window = gui_util.find_top(event.element)
    window.destroy()
end

---@param event EventData.on_gui_click
function handlers.on_click_pin(event)
    local player = game.get_player(event.player_index) ---@cast player -nil
    local element = event.element
    local is_pinned = not element.toggled
    element.toggled = is_pinned

    local window = gui_util.find_top(element)
    local close_button = gui_util.find_child(window, "close_button")

    if (is_pinned) then
        close_button.tooltip = { "gui.close" }
        player.opened = nil
    else
        close_button.tooltip = { "gui.close-instruction" }
        player.opened = window
    end
end

---@param event EventData.on_gui_click
function handlers.on_click_titlebar(event)
    if (event.button == defines.mouse_button_type.middle) then
        local window = gui_util.find_top(event.element)
        presenter.position_main_window(window)
    end
end

---@param event EventData.on_gui_click
function handlers.on_click_settings(event)
    local element = event.element
    local enabled = not element.toggled
    element.toggled = enabled
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "main_window")

---@param e ConfigurationChangedData
local function on_configuration_changed(e)
    if (e.mod_changes["sw-rates-calc-extreme"]) then
        for _, player in pairs(game.players) do
            local wnd = presenter.find_main_window(player)
            if (wnd) then
                wnd.destroy()
            end
        end
    end
end

---@param event EventData.on_player_display_density_scale_changed | EventData.on_player_display_resolution_changed | EventData.on_player_display_scale_changed
local function on_player_display_changed(event)
    local player = game.get_player(event.player_index) ---@cast player -nil
    local window = presenter.find_main_window(player)
    if (window) then
        set_max_height(player, window)
    end
end

event_handler.add_lib { on_configuration_changed = error_handling.safe_event_handler(on_configuration_changed),
    events = {
        [defines.events.on_player_display_density_scale_changed] = error_handling.safe_event_handler(on_player_display_changed),
        [defines.events.on_player_display_resolution_changed] = error_handling.safe_event_handler(on_player_display_changed),
        [defines.events.on_player_display_scale_changed] = error_handling.safe_event_handler(on_player_display_changed),
    } }

return presenter
