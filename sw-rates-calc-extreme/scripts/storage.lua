---@class (exact) Rates.Gui.DataPerPlayer
---@field windows table<string, Rates.Gui.DataPerWindow>
---@field settings Rates.Gui.SettingsPerPlayer
---@field last_sheet Rates.Data.SheetId
---@field tool_sheet Rates.Data.SheetId

---@class (exact) Rates.Gui.DataPerWindow
---@field element_data table<uint32, Rates.Gui.Component>
---@field settings Rates.Gui.SettingsPerWindow
---@field undo_stack Rates.Gui.UndoRedoStackEntry[]
---@field redo_stack Rates.Gui.UndoRedoStackEntry[]
---@field navigation_stack Rates.Gui.NavigationEntry[]
---@field sheet_rates? Rates.Sheet

---@class (exact) Rates.Gui.UndoRedoStackEntry
---@field sheet Rates.Data.Sheet
---@field action? LocalisedString

---@class (exact) Rates.Gui.NavigationEntry
---@field page_id Rates.Gui.PageDescription
---@field state Rates.Gui.PageVisualState.Base

---@class (exact) Rates.Gui.SettingsPerPlayer
---@field unnamed_sheets_max_count integer
---@field undo_stack_max_size integer
---@field navigation_stack_max_size integer
---@field show_settings boolean
---@field window_position_at_start "center" | "top-left"
---@field rate_formats Rates.Gui.SettingsRateFormat

---@class (exact) Rates.Gui.SettingsPerWindow
---@field show_settings boolean
---@field timescale? integer

---@class (exact) Rates.Gui.SettingsRateFormat
---@field default_timescale? integer

---@return Rates.Gui.DataPerPlayer
local function create_storage_player()
    return {}
end

---@param window Rates.Gui.DataPerWindow
local function sanitize_storage_window(window)
    if (not window.element_data) then
        window.element_data = {}
    end

    if (not window.undo_stack) then
        window.undo_stack = {}
    end

    if (not window.redo_stack) then
        window.redo_stack = {}
    end

    if (not window.navigation_stack or not window.navigation_stack[1] or window.navigation_stack[1].page_id.type ~= "rates") then
        window.navigation_stack = {
            {
                page_id = { type = "rates" },
                state = {
                    expanders = {},
                    rate_configs = {},
                },
            }
        }
    end

    if (not window.settings) then
        window.settings = {
            show_settings = false,
        }
    end
end

---@param settings Rates.Gui.SettingsPerPlayer
local function sanitize_storage_settings(settings)
    if (not settings.unnamed_sheets_max_count) then
        settings.unnamed_sheets_max_count = 5
    end

    if (not settings.undo_stack_max_size) then
        settings.undo_stack_max_size = 20
    end

    if (not settings.navigation_stack_max_size) then
        settings.navigation_stack_max_size = 10
    end

    if (not settings.show_settings) then
        settings.show_settings = false
    end

    if (not (settings.window_position_at_start == "center" or settings.window_position_at_start == "top-left")) then
        settings.window_position_at_start = "top-left"
    end

    if (not settings.rate_formats) then
        settings.rate_formats = {}
    end
end

---@param data Rates.Gui.DataPerPlayer
local function sanitize_storage_player(data)
    if (not data.windows) then
        data.windows = {}
    end

    if (not data.settings) then
        ---@diagnostic disable-next-line: missing-fields
        data.settings = {}
    end

    if (not data.tool_sheet) then
        data.tool_sheet = 0
    end

    if (not data.last_sheet) then
        data.last_sheet = 0
    end

    sanitize_storage_settings(data.settings)
end

---@param player LuaPlayer
---@return Rates.Gui.DataPerPlayer
local function get_storage_player(player)
    local all_players = storage.players
    if (not all_players) then
        ---@type table<integer, Rates.Gui.DataPerPlayer>
        all_players = {}
        storage.players = all_players
    end

    local result = all_players[player.index]
    if (not result) then
        result = create_storage_player()
        all_players[player.index] = result
    end

    sanitize_storage_player(result)
    return result
end

---@param player_storage Rates.Gui.DataPerPlayer
---@param name string
local function get_storage_window(player_storage, name)
    local windows = player_storage.windows
    local result = windows[name]
    if (not result) then
        ---@diagnostic disable-next-line: missing-fields
        result = {}
        windows[name] = result
    end

    sanitize_storage_window(result)
    return result
end

---@return table<Rates.Data.SheetId, true>
local function get_opened_sheet_ids()
    local result = {} ---@type table<Rates.Data.SheetId, true>
    local all_players = storage.players
    if (not all_players) then
        return result
    end

    for player_index, player_storage in pairs(all_players) do
        local player = game.get_player(player_index)
        if (player) then
            for window_name, _ in pairs(player_storage.windows or {}) do
                local window = player.gui.screen[window_name]
                if (window) then
                    local sheet_id = window.tags.sheet_id --[[@as Rates.Data.SheetId?]]
                    if (sheet_id and sheet_id ~= 0) then
                        result[sheet_id] = true
                    end
                end
            end
        end
    end
    return result
end

return {
    get_storage_player = get_storage_player,
    get_storage_window = get_storage_window,
    get_opened_sheet_ids = get_opened_sheet_ids,
}
