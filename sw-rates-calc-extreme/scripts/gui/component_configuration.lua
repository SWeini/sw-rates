local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local api = require("__sw-rates-lib__.api-usage")
local component = require("component")
local sheet = require("scripts.sheet")

local handlers = {}

local module_inventories = {
    ["agricultural-tower"] = defines.inventory.agricultural_tower_modules,
    ["assembling-machine"] = defines.inventory.crafter_modules,
    ["rocket-silo"] = defines.inventory.crafter_modules,
    ["furnace"] = defines.inventory.crafter_modules,
    ["lab"] = defines.inventory.lab_modules,
    ["mining-drill"] = defines.inventory.mining_drill_modules,
    ["beacon"] = defines.inventory.beacon_modules,
}

---@param entity LuaEntityPrototype
---@param quality LuaQualityPrototype
---@return ItemStackIndex?
local function get_module_slots(entity, quality)
    local type = entity.type
    local inventory = module_inventories[entity.type]
    if (not inventory) then
        return nil
    end

    return entity.get_inventory_size(inventory, quality)
end

---@param conf Rates.Configuration
---@param annotations Rates.Configuration.Annotation[]?
---@return GuiElemDef?
local function define_annotation_symbol(conf, annotations)
    if (annotations == nil or #annotations == 0) then
        return nil
    end

    local severity = 0
    local tips = { "" } ---@type LocalisedString
    for _, annotation in ipairs(annotations) do
        local gui = api.configuration.gui_annotation(annotation, conf)
        if (gui.severity == "error") then
            severity = math.max(severity, 3)
        elseif (gui.severity == "warning") then
            severity = math.max(severity, 2)
        elseif (gui.severity == "information") then
            severity = math.max(severity, 1)
        end
        if (#tips > 1) then
            tips[#tips + 1] = "\n\n"
        end
        if (gui.icon) then
            tips[#tips + 1] = "[img=" .. gui.icon.sprite .. "]  "
        end
        tips[#tips + 1] = gui.text
    end

    local sprite
    if (severity == 3) then
        sprite = "virtual-signal/signal-no-entry"
    elseif (severity == 2) then
        sprite = "utility/warning_icon"
    else
        sprite = "virtual-signal/signal-info"
    end

    ---@type GuiElemDef
    local result = {
        args = {
            type = "sprite",
            sprite = sprite,
            tooltip = tips
        },
        style_mods = {
            stretch_image_to_widget_size = true,
        },
    }

    return result
end

local button_style = "slot_button_simple"

---@param conf Rates.Configuration
---@param location Rates.Data.LocationIndex
---@param force LuaForce
---@param entity_count number?
---@param entity_font_color Color.0
---@param annotations Rates.Configuration.Annotation[]
---@return GuiElemDef[]
local function define_recipe_and_entity(conf, location, force, entity_count, entity_font_color, annotations)
    ---@type GuiElemDef[]
    local result = {}

    local ui_annotation = define_annotation_symbol(conf, annotations)
    local ui_entity = api.configuration.gui_entity(conf)
    local ui_recipe = api.configuration.gui_recipe(conf)

    if (ui_recipe) then
        local gui = api.gui.gui_button(ui_recipe)

        ---@type Rates.Gui.ActionTooltips
        local actions = {}
        if (gui.elem_tooltip) then
            actions.left_alt = { "action-sw-rates-calc-extreme.open-factoriopedia" }
        end
        local tooltip = presenter.create_action_tooltip(gui.tooltip, actions)

        result[#result + 1] = {
            args = {
                type = "sprite-button",
                style = button_style,
                sprite = gui.sprite,
                quality = gui.quality and gui.quality.name,
                elem_tooltip = gui.elem_tooltip,
                tooltip = tooltip,
            },
            style_mods = {
            },
            _click = handlers.on_click_factoriopedia,
        }
    end

    if (ui_entity) then
        local gui = api.gui.gui_button(ui_entity)

        ---@type Rates.Gui.ActionTooltips
        local actions = {}
        actions.left = { "action-sw-rates-calc-extreme.open" }
        if (gui.elem_tooltip) then
            actions.left_alt = { "action-sw-rates-calc-extreme.open-factoriopedia" }
        end
        if (entity_count) then
            actions.right = { "action-sw-rates-calc-extreme.toggle-building-count" }
        end
        local tooltip = presenter.create_action_tooltip(gui.tooltip, actions)

        result[#result + 1] = {
            args = {
                type = "sprite-button",
                style = button_style,
                sprite = gui.sprite,
                quality = gui.quality and gui.quality.name,
                elem_tooltip = gui.elem_tooltip,
                tooltip = tooltip,
            },
            style_mods = {
            },
            _click = handlers.on_click_entity,
        }

        if (ui_annotation) then
            ui_annotation.style_mods.size = 16
            ui_annotation.style_mods.margin = { 0, 52, 0, -72 }
            result[#result + 1] = ui_annotation
        end

        if (entity_count) then
            result[#result + 1] = {
                args = {
                    type = "label",
                    caption = entity_count,
                    ignored_by_interaction = true,
                },
                style_mods = {
                    font = "item-count",
                    font_color = entity_font_color,
                    width = 68,
                    horizontal_align = "right",
                    margin = { 16, 0, -16, -72 },
                    right_padding = -1,
                },
            }
        end
    end

    local qualifier = (ui_entity and ui_entity.qualifier) or (ui_recipe and ui_recipe.qualifier)
    if (qualifier) then
        result[#result + 1] = {
            args = {
                type = "label",
                caption = qualifier.text,
                ignored_by_interaction = true,
            },
            style_mods = {
                font = "sw-rates-calc-extreme-qualifier-font",
                horizontal_align = "right",
                width = 68,
                margin = { -4, 0, -4, -72 },
            },
        }
    end

    return result
end

---@param conf Rates.Configuration
---@return GuiElemDef[]
local function define_fuel(conf)
    ---@type GuiElemDef[]
    local result = {}
    local ui_fuel = api.configuration.gui_fuel(conf)

    if (ui_fuel) then
        local gui = api.gui.gui_button(ui_fuel)

        ---@type Rates.Gui.ActionTooltips
        local actions = {}
        if (gui.elem_tooltip) then
            actions.left_alt = { "action-sw-rates-calc-extreme.open-factoriopedia" }
        end
        local tooltip = presenter.create_action_tooltip(gui.tooltip, actions)

        result[#result + 1] = {
            args = {
                type = "sprite-button",
                style = button_style,
                sprite = gui.sprite,
                quality = gui.quality and gui.quality.name,
                elem_tooltip = gui.elem_tooltip,
                tooltip = tooltip,
            },
            _click = handlers.on_click_factoriopedia,
        }
    end

    return result
end

---@param conf Rates.Configuration
---@return GuiElemDef[]
local function define_module_effects(conf)
    ---@type GuiElemDef[]
    local result = {}

    local effects = conf.module_effects
    if (effects) then
        local local_effect = effects.local_effect

        if (local_effect and table_size(local_effect) > 0) then
            local tooltip = { "", "[font=default-bold][color=255,230,192]Scripted effects:[/color][/font]" } ---@type LocalisedString
            for name, value in pairs(local_effect) do
                tooltip[#tooltip + 1] = { "", "\n", { "description." .. name .. "-bonus" }, ": " ..
                string.format("%+.2f", value * 100) .. "%" }
            end
            result[#result + 1] = {
                args = {
                    type = "sprite-button",
                    style = button_style,
                    sprite = "utility/change_recipe",
                    tooltip = tooltip,
                },
            }
        end

        local modules = effects.modules
        if (modules) then
            if (#modules == 1 and modules[1].count == get_module_slots(conf.entity, conf.quality)) then
                local module = modules[1]
                result[#result + 1] = {
                    args = {
                        type = "sprite-button",
                        style = button_style,
                        sprite = "item." .. module.module.name,
                        quality = module.quality.name,
                        elem_tooltip = { type = "item-with-quality", name = module.module.name, quality = module.quality.name },
                    },
                }
            else
                for i, module in ipairs(modules) do
                    result[#result + 1] = {
                        args = {
                            type = "sprite-button",
                            style = button_style,
                            sprite = "item." .. module.module.name,
                            quality = module.quality.name,
                            elem_tooltip = { type = "item-with-quality", name = module.module.name, quality = module.quality.name },
                            number = module.count,
                        },
                        style_mods = {
                            margin = { 0, 0, 0, (i > 1 and -4 or 0) },
                        },
                    }
                end
            end
        end

        local beacons = effects.beacons
        if (beacons) then
            for _, beacon in ipairs(beacons) do
                local modules = beacon.per_beacon_modules
                local hidden = beacon.beacon.hidden
                local module_slots = hidden and 1 or get_module_slots(beacon.beacon, beacon.quality)
                if (not hidden) then
                    result[#result + 1] = {
                        args = {
                            type = "sprite-button",
                            style = button_style,
                            sprite = "entity." .. beacon.beacon.name,
                            quality = beacon.quality.name,
                            elem_tooltip = { type = "entity-with-quality", name = beacon.beacon.name, quality = beacon.quality.name },
                            number = beacon.count ~= 1 and beacon.count or nil
                        },
                    }
                end
                for _, module in ipairs(modules) do
                    local count = (hidden and beacon.count or 1) * module.count
                    result[#result + 1] = {
                        args = {
                            type = "sprite-button",
                            style = button_style,
                            sprite = "item." .. module.module.name,
                            quality = module.quality.name,
                            elem_tooltip = { type = "item-with-quality", name = module.module.name, quality = module.quality.name },
                            number = count ~= module_slots and count or nil,
                        },
                        style_mods = {
                            margin = { 0, 0, 0, -4 },
                        },
                    }
                end
            end
        end
    end

    return result
end

---@class (exact) Rates.Gui.Component.Configuration : Rates.Gui.Component
---@field conf Rates.Configuration
---@field location Rates.Data.LocationIndex
---@field force LuaForce

---@param conf Rates.Configuration
---@param location Rates.Data.LocationIndex
---@param force LuaForce
---@param entity_count number?
---@param entity_font_color Color.0
---@param annotations Rates.Configuration.Annotation[]
---@return GuiElemDef
local function define_configuration_row(conf, location, force, entity_count, entity_font_color, annotations)
    ---@type GuiElemDef[]
    local children = {}

    for _, e in ipairs(define_recipe_and_entity(conf, location, force, entity_count, entity_font_color, annotations)) do
        children[#children + 1] = e
    end

    for _, e in ipairs(define_fuel(conf)) do
        children[#children + 1] = e
    end

    for _, e in ipairs(define_module_effects(conf)) do
        children[#children + 1] = e
    end

    ---@type GuiElemDef
    return {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        style_mods = {
            vertically_stretchable = false,
        },
        children = children,
        callback = function(element)
            ---@type Rates.Gui.Component.Configuration
            local element_data = {
                conf = conf,
                location = location,
                force = force,
            }
            component.set_element_data(element, element_data)
        end,
    }
end

---@param ui_entity Rates.Gui.NodeDescription?
---@param ui_recipe Rates.Gui.NodeDescription?
---@param entity_count number?
---@param entity_font_color Color.0
---@return GuiElemDef
local function define_configuration_group_row(ui_entity, ui_recipe, entity_count, entity_font_color)
    ---@type GuiElemDef[]
    local children = {}

    if (ui_recipe) then
        local gui = api.gui.gui_button(ui_recipe)

        ---@type Rates.Gui.ActionTooltips
        local actions = {}
        if (gui.elem_tooltip) then
            actions.left_alt = { "action-sw-rates-calc-extreme.open-factoriopedia" }
        end
        local tooltip = presenter.create_action_tooltip(gui.tooltip, actions)

        children[#children + 1] = {
            args = {
                type = "sprite-button",
                style = button_style,
                sprite = gui.sprite,
                quality = gui.quality and gui.quality.name,
                elem_tooltip = gui.elem_tooltip,
                tooltip = tooltip,
            },
            style_mods = {
            },
            _click = handlers.on_click_factoriopedia,
        }
    else
        children[#children + 1] = {
            args = { type = "empty-widget" },
            style_mods = { width = 32 },
        }
    end

    if (ui_entity) then
        local gui = api.gui.gui_button(ui_entity)

        ---@type Rates.Gui.ActionTooltips
        local actions = {}
        if (gui.elem_tooltip) then
            actions.left_alt = { "action-sw-rates-calc-extreme.open-factoriopedia" }
        end
        local tooltip = presenter.create_action_tooltip(gui.tooltip, actions)

        children[#children + 1] = {
            args = {
                type = "sprite-button",
                style = button_style,
                sprite = gui.sprite,
                quality = gui.quality and gui.quality.name,
                elem_tooltip = gui.elem_tooltip,
                tooltip = tooltip,
            },
            style_mods = {
            },
            _click = handlers.on_click_factoriopedia,
        }

        if (entity_count) then
            children[#children + 1] = {
                args = {
                    type = "label",
                    caption = entity_count,
                    ignored_by_interaction = true,
                },
                style_mods = {
                    font = "item-count",
                    font_color = entity_font_color,
                    width = 68,
                    horizontal_align = "right",
                    margin = { 16, 0, -16, -72 },
                    right_padding = -1,
                },
            }
        end
    end

    ---@type GuiElemDef
    return {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        style_mods = {
            vertically_stretchable = false,
        },
        children = children,
    }
end

---@param event EventData.on_gui_click
function handlers.on_click_factoriopedia(event)
    if (presenter.open_factoriopedia(event)) then
        return
    end
end

---@param event EventData.on_gui_click
function handlers.on_click_entity(event)
    local element = event.element
    local container = element.parent ---@cast container -nil
    local element_data = component.get_element_data(container) --[[@as Rates.Gui.Component.Configuration]]

    local conf = element_data.conf
    local location = element_data.location
    local force = element_data.force
    local window = gui_util.find_top(event.element)

    if (presenter.open_factoriopedia(event)) then
        return
    end

    local id = sheet.get_full_configuration_id(conf, location, force)
    if (event.button == defines.mouse_button_type.left) then
        if (not event.shift and not event.alt and not event.control) then
            presenter.open_page(window, { type = "selected-entity", conf = conf, location = location, force = force })
        end
    elseif (event.button == defines.mouse_button_type.right) then
        if (not event.shift and not event.alt and not event.control) then
            presenter.run_undo_action(window, function(context)
                local adjustments = context.sheet.configuration_adjustments
                local entry = adjustments[id]
                if (not entry) then
                    entry = {}
                    adjustments[id] = entry
                end

                entry.count_infinite = not entry.count_infinite
                context.changed.configurations = true
                context.description = "ignore building count"
            end)
        elseif (event.shift and not event.alt and event.control) then
            local data = presenter.get_window_data(window)
            local configurations = data.window.sheet_rates.configurations
            presenter.run_undo_action(window, function(context)
                local adjustments = context.sheet.configuration_adjustments
                for _, conf in ipairs(configurations) do
                    local other_id = sheet.get_full_configuration_id(conf.configuration, conf.location, conf.force)
                    if (conf.count_max < math.huge) then
                        local entry = adjustments[other_id]
                        if (not entry) then
                            entry = {}
                            adjustments[other_id] = entry
                        end

                        entry.count_infinite = true
                    end
                end

                local entry = adjustments[id]
                if (entry) then
                    entry.count_infinite = false
                end

                context.changed.configurations = true
                context.description = "ignore building counts"
            end)
        end
        return
    end
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "component_configuration")

return {
    define_recipe_and_entity = define_recipe_and_entity,
    define_fuel = define_fuel,
    define_module_effects = define_module_effects,
    define_configuration_row = define_configuration_row,
    define_configuration_group_row = define_configuration_group_row,
}
