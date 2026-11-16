---@class Rates.Gui.Presenter
local presenter = {}

---@class (exact) Rates.Gui.ChangedProperties
---@field library? true
---@field selected_sheet? true
---@field metadata? true
---@field selection? true
---@field configurations? true
---@field ui_configuration? true

presenter.pages = {} ---@type table<string, Rates.Gui.PagePresenter>

local event_handlers = {} ---@type table<string, fun(event: GuiEventData)>
local event_handler_names = {} ---@type table<fun(event: GuiEventData), string>

---@param handlers table<string, fun(event: GuiEventData)> The table of handlers for the presenter to call.
---@param namespace? string (Optional) The namespace for the handler, so multiple handlers from the same mod can share names and not overwrite each other.
function presenter.register_handlers(handlers, namespace)
    for name, handler in pairs(handlers) do
        if (namespace) then
            name = namespace .. "." .. name
        end

        event_handlers[name] = handler
        event_handler_names[handler] = name
    end
end

---@param handler_name string
---@return fun(event: GuiEventData)
function presenter.get_handler(handler_name)
    local result = event_handlers[handler_name]
    if (not result) then
        error("no event handler for " .. handler_name)
    end

    return result
end

---@param handler fun(event: GuiEventData)
---@return string
function presenter.get_handler_name(handler)
    local result = event_handler_names[handler]
    if (not result) then
        error("handler is not registered")
    end

    return result
end

return presenter
