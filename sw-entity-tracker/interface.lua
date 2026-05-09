local event_names = {
    unit_number_changed = "sw-entity-tracker-unit-number-changed"
}

do
    ---@class EntityTracker.EventData.UnitNumberChanged : EventData
    ---@field name "sw-entity-tracker-unit-number-changed"
    ---@field entity LuaEntity the new entity
    ---@field from_unit_number uint64 the unit_number of the original entity
end

---@param handler fun(event: EntityTracker.EventData.UnitNumberChanged)
local function on_unit_number_changed(handler)
    script.on_event(event_names.unit_number_changed, handler)
end

return {
    event_names = event_names,
    on_unit_number_changed = on_unit_number_changed
}
