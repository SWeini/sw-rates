local event_handler = require("__core__.lualib.event_handler")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter


---@param elem ElemID
---@return FactoriopediaID?
local function prototype_of_elem_id(elem)
    if (elem.type == "item" or elem.type == "item-with-quality") then
        return prototypes.item[elem.name]
    elseif (elem.type == "fluid") then
        return prototypes.fluid[elem.name]
    elseif (elem.type == "entity" or elem.type == "entity-with-quality") then
        return prototypes.entity[elem.name]
    elseif (elem.type == "recipe" or elem.type == "recipe-with-quality") then
        return prototypes.recipe[elem.name]
    elseif (elem.type == "asteroid-chunk") then
        return prototypes.asteroid_chunk[elem.name]
    end
end

---@param event EventData.on_gui_click
---@return boolean
function presenter.open_factoriopedia(event)
    local element = event.element
    if (event.button == defines.mouse_button_type.left and not event.shift and event.alt and not event.control) then
        local elem = element.elem_tooltip
        if (elem) then
            local player = game.get_player(event.player_index) ---@cast player -nil
            local proto = prototype_of_elem_id(elem)
            if (proto) then
                player.open_factoriopedia_gui(proto)
                return true
            end
        end
    end

    return false
end
