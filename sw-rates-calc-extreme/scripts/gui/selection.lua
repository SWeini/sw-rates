local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local library = require("scripts.library")

---@alias Rates.Gui.SelectionEvent
--- | defines.events.on_player_selected_area
--- | defines.events.on_player_reverse_selected_area
--- | defines.events.on_player_alt_selected_area
--- | defines.events.on_player_alt_reverse_selected_area
--- | defines.events.on_player_super_forced_selected_area

---@alias Rates.Gui.SelectionEventData
--- | EventData.on_player_selected_area
--- | EventData.on_player_reverse_selected_area
--- | EventData.on_player_alt_selected_area
--- | EventData.on_player_alt_reverse_selected_area
--- | EventData.on_player_super_forced_selected_area

---@alias Rates.Gui.SelectionModeAction fun(entity: LuaEntity, unit_number: integer, entities: table<integer, Rates.Data.Sheet.SelectedEntity>): boolean

---@type table<Rates.Gui.SelectionEvent, Rates.Gui.SelectionModeAction>
local selection_modes = {}

selection_modes[defines.events.on_player_selected_area] = function(entity, unit_number, entities)
    local entry = entities[unit_number]
    if (not entry) then
        entities[unit_number] = { entity = entity, count = 1 }
        return true
    end

    return false
end

selection_modes[defines.events.on_player_reverse_selected_area] = function(entity, unit_number, entities)
    if (entities[unit_number]) then
        entities[unit_number] = nil
        return true
    end

    return false
end

selection_modes[defines.events.on_player_alt_selected_area] = function(entity, unit_number, entities)
    local entry = entities[unit_number]
    if (entry) then
        entry.count = entry.count + 1
    else
        entities[unit_number] = { entity = entity, count = 1 }
    end

    return true
end

selection_modes[defines.events.on_player_alt_reverse_selected_area] = function(entity, unit_number, entities)
    local entry = entities[unit_number]
    if (entry) then
        if (entry.count > 1) then
            entry.count = entry.count - 1
        else
            entities[unit_number] = nil
        end

        return true
    end

    return false
end

selection_modes[defines.events.on_player_super_forced_selected_area] =
    selection_modes[defines.events.on_player_selected_area]

---@param event Rates.Gui.SelectionEventData
---@param sheet Rates.Data.Sheet
---@return integer
local function apply_selection_to_sheet(event, sheet)
    local name = event.name
    local mode = selection_modes[name]
    local changed = 0
    local selected_entities = sheet.selection.entities
    for _, entity in ipairs(event.entities) do
        if (mode(entity, entity.unit_number, selected_entities)) then
            changed = changed + 1
        end
    end

    return changed
end

---@param event Rates.Gui.SelectionEventData
local function on_player_selected_area(event)
    if (event.item ~= "sw-rates-calc-extreme-tool") then
        return
    end

    local player = game.get_player(event.player_index) ---@cast player -nil

    ---@type Rates.Gui.ChangedProperties
    local changed = {
        metadata = true,
        selection = true,
    }

    local store = presenter.get_storage_player(player)
    local sheet ---@type Rates.Data.Sheet?
    if (store.tool_sheet == 0 and store.last_sheet ~= 0 and event.name == defines.events.on_player_alt_selected_area) then
        store.tool_sheet = store.last_sheet
        event.name = defines.events.on_player_selected_area
    end
    if (store.tool_sheet ~= 0 and event.name ~= defines.events.on_player_super_forced_selected_area) then
        sheet = library.try_get_sheet(store.tool_sheet)
    end
    if (not sheet) then
        sheet = library.create_sheet(player)
        store.tool_sheet = sheet.metadata.id
    end

    local window = presenter.find_main_window(player)
    if (window) then
        if (sheet.metadata.id == 0) then
            local num_changed = apply_selection_to_sheet(event, sheet)
            if (num_changed == 0) then
                return
            end

            local id = library.save_sheet(sheet)
            glib.set_tag(window, "sheet_id", id)
            changed.library = true

            local data = presenter.get_window_data(window)
            data.window.undo_stack = {}
            data.window.redo_stack = {}
            local navigation = data.window.navigation_stack
            data.window.navigation_stack = { navigation[1] }
            if (navigation[#navigation].page_id.type == "library") then
                data.window.navigation_stack[2] = navigation[#navigation]
            end
            presenter.update_window(window, changed)
        else
            glib.set_tag(window, "sheet_id", sheet.metadata.id)
            presenter.run_undo_action(window, function(context)
                local num_changed = apply_selection_to_sheet(event, context.sheet)
                if (num_changed == 0) then
                    context.skip = true
                    return
                end
                if (event.name == defines.events.on_player_selected_area or event.name == defines.events.on_player_alt_selected_area) then
                    context.description = "add " .. num_changed .. " entities to selection"
                else
                    context.description = "remove " .. num_changed .. " entities from selection"
                end
                context.changed = changed
            end)
        end
    else
        local num_changed = apply_selection_to_sheet(event, sheet)
        if (num_changed > 0) then
            if (sheet.metadata.id == 0) then
                changed.library = true
            else
                sheet.metadata.tick_modified = game.ticks_played
            end
            library.save_sheet(sheet)
        end

        window = presenter.open_window(player, sheet, changed.library == true)
        presenter.position_main_window(window)
        player.opened = window
    end

    store.tool_sheet = sheet.metadata.id
end

---@param player LuaPlayer
local function select_tool(player)
    if (not player.clear_cursor()) then
        return
    end

    local cursor = player.cursor_stack ---@cast cursor -nil
    cursor.set_stack("sw-rates-calc-extreme-tool")
    local store = presenter.get_storage_player(player)
    local window = presenter.find_main_window(player)
    if (window) then
        local sheet = presenter.get_sheet_of_window(window)
        store.tool_sheet = sheet.metadata.id
    else
        store.tool_sheet = 0
    end
end

---@param player LuaPlayer
local function open_window(player)
    local store = presenter.get_storage_player(player)
    local window = presenter.find_main_window(player)
    if (window) then
        store.tool_sheet = presenter.get_sheet_of_window(window).metadata.id
        return
    end

    local last_sheet = store.last_sheet
    local sheet ---@type Rates.Data.Sheet?
    if (last_sheet and last_sheet ~= 0) then
        sheet = library.try_get_sheet(last_sheet)
    end

    if (not sheet) then
        sheet = library.create_sheet(player)
    end

    store.tool_sheet = sheet.metadata.id
    window = presenter.open_window(player, sheet, false)
    presenter.position_main_window(window)
    player.opened = window
end

---@param player LuaPlayer
local function activate_shortcut(player)
    local cursor = player.cursor_stack
    if (not cursor) then
        return
    end

    if (cursor.valid_for_read and cursor.name == "sw-rates-calc-extreme-tool") then
        open_window(player)
        cursor.clear()
    else
        select_tool(player)
    end
end

---@param event EventData.CustomInputEvent
local function on_custom_input(event)
    local player = game.get_player(event.player_index) ---@cast player -nil
    activate_shortcut(player)
end

---@param event EventData.on_lua_shortcut
local function on_lua_shortcut(event)
    if (event.prototype_name ~= "sw-rates-calc-extreme-shortcut") then
        return
    end

    local player = game.get_player(event.player_index) ---@cast player -nil
    activate_shortcut(player)
end

---@param player LuaPlayer
function presenter.stop_selection_tool(player)
    local cursor = player.cursor_stack
    if (not cursor) then
        return
    end

    if (cursor.valid_for_read and cursor.name == "sw-rates-calc-extreme-tool") then
        cursor.clear()
    end
end

event_handler.add_lib {
    events = {
        [defines.events.on_player_selected_area] = error_handling.safe_event_handler(on_player_selected_area),
        [defines.events.on_player_reverse_selected_area] = error_handling.safe_event_handler(on_player_selected_area),
        [defines.events.on_player_alt_selected_area] = error_handling.safe_event_handler(on_player_selected_area),
        [defines.events.on_player_alt_reverse_selected_area] = error_handling.safe_event_handler(on_player_selected_area),
        [defines.events.on_player_super_forced_selected_area] = error_handling.safe_event_handler(on_player_selected_area),
        [defines.events.on_lua_shortcut] = error_handling.safe_event_handler(on_lua_shortcut),
        ["sw-rates-calc-extreme-custom-input"] = error_handling.safe_event_handler(on_custom_input),
    },
}

return presenter
