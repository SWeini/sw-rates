if (not script.active_mods["sw-entity-tracker"]) then
    return
end

local entity_tracker = require("__sw-entity-tracker__.interface")
local library = require("library")

---@param from_unit_number integer
---@param entity LuaEntity
local function replace(from_unit_number, entity)
    local to_unit_number = entity.unit_number ---@cast to_unit_number -nil

    ---@param sheet Rates.Data.Sheet
    local function adjust(sheet)
        local selected_entities = sheet.selection.entities
        local entry = selected_entities[from_unit_number]
        if (entry) then
            selected_entities[from_unit_number] = nil
            selected_entities[to_unit_number] = { entity = entity, count = entry.count }
        end
    end

    local sheets = library.get_all_sheets()
    for _, sheet in ipairs(sheets) do
        adjust(sheet)
    end

    for _, player_storage in pairs(storage.players or {}) do
        for _, window_storage in pairs(player_storage.windows or {}) do
            for _, entry in ipairs(window_storage.undo_stack or {}) do
                adjust(entry.sheet)
            end
            for _, entry in ipairs(window_storage.redo_stack or {}) do
                adjust(entry.sheet)
            end
        end
    end
end

entity_tracker.on_unit_number_changed(function(event)
    replace(event.from_unit_number, event.entity)
end)
