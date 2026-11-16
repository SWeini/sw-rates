---@param handler function
---@return function
local function safe_event_handler(handler)
    return function(event)
        local ok, result = xpcall(handler, debug.traceback, event)
        if (ok) then
            return result
        end

        game.print({ "gui.sw-rates-calc-extreme-error-message" })
        log(result)
    end
end

---@param event EventData
---@param handler function
local function safe_event_handler_glib(event, handler)
    local ok, result = xpcall(handler, debug.traceback, event)
    if (ok) then
        return result
    end

    game.print({ "gui.sw-rates-calc-extreme-error-message" })
    log(result)
end

return {
    safe_event_handler = safe_event_handler,
    safe_event_handler_glib = safe_event_handler_glib,
}
