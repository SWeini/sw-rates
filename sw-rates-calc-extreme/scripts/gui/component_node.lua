local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local api = require("__sw-rates-lib__.api-usage")
local component = require("component")
local expander = require("component_expander")
local component_rate = require("component_rate")
local sheet_manipulation = require("scripts.sheet_manipulation")

local handlers = {}

---@class (exact) Rates.Gui.Component.NodeStatus
---@field link? boolean
---@field fuel? boolean
---@field spoil? boolean

---@class (exact) Rates.Gui.Component.Node : Rates.Gui.Component
---@field node Rates.Node
---@field location Rates.Data.LocationIndex
---@field amount number
---@field status Rates.Gui.Component.NodeStatus

---@type Rates.Node.NumberFormat
local default_number_format = {
    unit = "/s",
    factor = 1,
}

---@param data Rates.Gui.WindowDataFull
---@param node Rates.Node
---@param location Rates.Data.LocationIndex
---@param amount number
---@param status Rates.Gui.Component.NodeStatus
---@return GuiElemDef
local function define(data, node, location, amount, status)
    local gui = api.node.gui_default(node)
    local ui = api.gui.gui_button_and_text(gui)
    local ui_node = ui.button

    ---@type GuiElemDef[]
    local children = {}

    ---@type Rates.Gui.ActionTooltips
    local actions = {}

    ---@type LocalisedString?
    local tooltip = ui_node.tooltip or gui.name
    actions.left = { "action-sw-rates-calc-extreme.open" }

    ---@type GuiElemDef
    local button = {
        args = {
            type = "sprite-button",
            style = "slot_button_simple",
            sprite = ui_node.sprite,
            quality = ui_node.quality and ui_node.quality.name,
            elem_tooltip = ui_node.elem_tooltip,
        },
        style_mods = {
            size = 24,
        },
        children = children,
        _click = handlers.on_click,
    }

    if (status.link and amount == 0) then
        button.args.style = "red_slot_button"
        button.style_mods.padding = -4
    end

    if (ui_node.elem_tooltip) then
        actions.left_alt = { "action-sw-rates-calc-extreme.open-factoriopedia" }
    end

    if (status.spoil ~= nil) then
        button.children[#button.children + 1] = {
            args = {
                type = "sprite",
                sprite = status.spoil and "virtual-signal/signal-clock" or "virtual-signal/signal-clock",
            },
            style_mods = {
                size = 24,
                right_margin = -24,
                padding = { 0, 14, 14, 0 },
                stretch_image_to_widget_size = true,
            },
        }
        actions.left_shift = { "action-sw-rates-calc-extreme.toggle-spoilage" }
    end

    if (status.link ~= nil) then
        button.children[#button.children + 1] = {
            args = {
                type = "sprite",
                sprite = status.link and "virtual-signal/signal-lock" or "virtual-signal/signal-unlock",
            },
            style_mods = {
                size = 24,
                right_margin = -24,
                padding = { 14, 0, 0, 14 },
                stretch_image_to_widget_size = true,
            },
        }
        actions.right = { "action-sw-rates-calc-extreme.toggle-link" }
    end

    if (status.fuel ~= nil) then
        button.children[#button.children + 1] = {
            args = {
                type = "sprite",
                sprite = status.fuel and "virtual-signal/signal-fire" or "virtual-signal/signal-fire",
            },
            style_mods = {
                size = 24,
                right_margin = -24,
                padding = { 0, 0, 14, 14 },
                stretch_image_to_widget_size = true,
            },
        }
        actions.right_shift = { "action-sw-rates-calc-extreme.toggle-fuel" }
    end

    button.args.tooltip = presenter.create_action_tooltip(tooltip, actions)

    local rate = component_rate.define(data, gui.number_format or default_number_format, amount)
    rate.style_mods = {
        width = 70,
        height = 24,
        horizontal_align = "right",
        vertical_align = "center",
    }

    ---@type GuiElemDef
    return {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        children = {
            rate,
            button,
            {
                args = {
                    type = "label",
                    caption = ui.text,
                },
                style_mods = {
                    margin = { 2, 0, 2, 0 },
                },
            },
        },
        callback = function(element)
            ---@type Rates.Gui.Component.Node
            local element_data = {
                node = node,
                location = location,
                amount = amount,
                status = status,
            }
            component.set_element_data(element, element_data)
        end,
    }
end

---@param data Rates.Gui.WindowDataFull
---@param amounts { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
---@param base_location Rates.Data.LocationIndex?
---@param caption LocalisedString
---@param default_expanded boolean
---@param expander_storage Rates.Gui.Component.Expander.Storage?
---@return GuiElemDef
local function define_list(data, amounts, base_location, caption, default_expanded, expander_storage)
    ---@type GuiElemDef
    local header = { args = { type = "label", caption = caption, style = "caption_label" } }
    ---@type GuiElemDef[]
    local content = {}
    for _, amount in pairs(amounts) do
        content[#content + 1] = define(data, amount.node, amount.location, amount.amount, amount.status)
    end

    ---@type GuiElemDef
    local container = {
        args = {
            type = "flow",
            direction = "vertical",
        },
        style_mods = {
            left_margin = 12,
        },
        children = content,
    }
    return expander.define(header, container, default_expanded, expander_storage)
end

---@param event EventData.on_gui_click
function handlers.on_click(event)
    local element = event.element
    local container = element.parent ---@cast container -nil
    local element_data = component.get_element_data(container) --[[@as Rates.Gui.Component.Node]]
    local window = gui_util.find_top(container)

    if (presenter.open_factoriopedia(event)) then
        return
    end

    if (event.button == defines.mouse_button_type.left) then
        if (not event.shift and not event.alt and not event.control) then
            presenter.open_page(window,
                { type = "selected-node", node = element_data.node, location = element_data.location })
        elseif (event.shift and not event.alt and not event.control) then
            local spoil = element_data.status.spoil
            if (spoil ~= nil) then
                presenter.run_undo_action(window, function(context)
                    local node = element_data.node --[[@as Rates.Node.Item]]
                    local item = node.item
                    local quality = node.quality
                    ---@type Rates.Configuration.ItemSpoil
                    local configuration = { type = "item-spoil", item = item, quality = quality }
                    if (sheet_manipulation.toggle_configuration(context.sheet, configuration, element_data.location, context.player.force --[[@as LuaForce]])) then
                        context.description = "add spoil recipe for [item=" ..
                            item.name .. ",quality=" .. quality.name .. "]"
                    else
                        context.description = "remove spoil recipe for [item=" ..
                            item.name .. ",quality=" .. quality.name .. "]"
                    end
                    context.changed.configurations = true
                end)
            end
        end
    elseif (event.button == defines.mouse_button_type.right) then
        if (not event.shift and not event.alt and not event.control) then
            local link = element_data.status.link
            if (link ~= nil) then
                presenter.run_undo_action(window, function(context)
                    if (not sheet_manipulation.configure_node(context.sheet, api.node.get_id(element_data.node), element_data.location, not link)) then
                        context.skip = true
                    end

                    local ui = api.gui.gui_message(api.node.gui_default(element_data.node))
                    context.description = { "", link and "unlink " or "link ", ui }
                    context.changed.configurations = true
                end)
            end
        elseif (event.shift and not event.alt and not event.control) then
            local fuel = element_data.status.fuel
            if (fuel ~= nil) then
                presenter.run_undo_action(window, function(context)
                    local node = element_data.node
                    if (node.type == "item") then
                        local item = node.item
                        local quality = node.quality
                        ---@type Rates.Configuration.ItemFuel
                        local configuration = { type = "item-fuel", item = item, quality = quality, produce_burnt_result = true }
                        if (sheet_manipulation.toggle_configuration(context.sheet, configuration, element_data.location, context.player.force --[[@as LuaForce]])) then
                            context.description = "add fuel recipe for [item=" ..
                                item.name .. ",quality=" .. quality.name .. "]"
                        else
                            context.description = "remove fuel recipe for [item=" ..
                                item.name .. ",quality=" .. quality.name .. "]"
                        end
                    elseif (node.type == "fluid") then
                        local fluid = node.fluid
                        local temperature = node.temperature
                        ---@type Rates.Configuration.FluidFuel
                        local configuration = { type = "fluid-fuel", fluid = fluid, temperature = temperature }
                        if (sheet_manipulation.toggle_configuration(context.sheet, configuration, element_data.location, context.player.force --[[@as LuaForce]])) then
                            context.description = "add fuel recipe for [fluid=" ..
                                fluid.name .. "] (" .. temperature .. "°C)"
                        else
                            context.description = "remove fuel recipe for [fluid=" ..
                                fluid.name .. "] (" .. temperature .. "°C)"
                        end
                    end
                    context.changed.configurations = true
                end)
            end
        end
    end
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "component_node")

return {
    define = define,
    define_list = define_list,
}
