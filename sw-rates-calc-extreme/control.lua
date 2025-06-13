local api = require("__sw-rates-lib__.api-usage")

local gui = require("scripts.gui")
local sheet = require("scripts.sheet")
local handler = require("__core__.lualib.event_handler")
local flib_gui = require("__flib__.gui")

handler.add_libraries({
    flib_gui,
    gui
})

---@type { [integer]: LuaEntity }
local selected_entities = {}

---@param e EventData.on_player_selected_area | EventData.on_player_alt_selected_area | EventData.on_player_alt_reverse_selected_area
local function on_player_selected_area(e)
    local player = game.players[e.player_index]
    local storage = gui.get_storage(player)
    if (e.item ~= "sw-rates-calc-extreme-tool") then
        return
    end

    if (e.name == defines.events.on_player_selected_area) then
        selected_entities = {}
        storage.removed_constraints = {}
    end

    if (e.name == defines.events.on_player_alt_reverse_selected_area) then
        for _, entity in ipairs(e.entities) do
            selected_entities[entity.unit_number] = nil
        end
    else
        for _, entity in ipairs(e.entities) do
            selected_entities[entity.unit_number] = entity
        end
    end

    local entities = {}
    for _, entity in pairs(selected_entities) do
        entities[#entities + 1] = entity
    end

    local sheet_data = sheet.build_from_entities(e.surface, entities)
    for node_id, _ in pairs(storage.removed_constraints or {}) do
        sheet_data.constraints[node_id] = nil
    end

    sheet.solve_sheet(sheet_data)

    local ui = gui.build(player)
    gui.add_table(ui, sheet_data, player)
    gui.show(player, ui)
end

script.on_event({
    defines.events.on_player_selected_area,
    defines.events.on_player_alt_selected_area,
    defines.events.on_player_alt_reverse_selected_area
}, on_player_selected_area)
