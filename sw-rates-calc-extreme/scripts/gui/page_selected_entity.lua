local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local api = require("__sw-rates-lib__.api-usage")
local expander = require("component_expander")
local component = require("component")
local component_node = require("component_node")
local component_rate = require("component_rate")
local sheet = require("scripts.sheet")

do
    ---@class Rates.Gui.PageDescription.SelectedEntity : Rates.Gui.PageDescription.Base
    ---@field type "selected-entity"
    ---@field conf Rates.Configuration
    ---@field location Rates.Data.LocationIndex
    ---@field force LuaForce
end

local page = { left_panel = {}, right_panel = {} } ---@type Rates.Gui.PagePresenter
presenter.pages["selected-entity"] = page

local handlers = {}

---@param data Rates.Gui.WindowDataFull
---@param id string
---@return Rates.Sheet.Configuration?
local function find_configuration(data, id)
    local rates = data.window.sheet_rates
    if (rates) then
        for _, configuration in ipairs(rates.configurations) do
            if (configuration.id == id) then
                return configuration
            end
        end
    end
end

page.left_panel.define_toolbar = function(data, page)
    local conf = page.conf
    local ui_recipe = api.gui.gui_button(api.configuration.gui_recipe(conf))
    local ui_entity = api.gui.gui_button(api.configuration.gui_entity(conf))

    ---@type GuiElemDef[]
    return {
        {
            args = {
                type = "sprite-button",
                style = "transparent_slot",
                sprite = ui_recipe.sprite,
                quality = ui_recipe.quality and ui_recipe.quality.name,
                elem_tooltip = ui_recipe.elem_tooltip,
                tooltip = ui_recipe.tooltip,
            },
            style_mods = {
                size = 24,
                left_margin = 8,
            },
        },
        {
            args = {
                type = "sprite-button",
                style = "transparent_slot",
                sprite = ui_entity.sprite,
                quality = ui_entity.quality and ui_entity.quality.name,
                elem_tooltip = ui_entity.elem_tooltip,
                tooltip = ui_entity.tooltip,
            },
            style_mods = {
                size = 24,
            },
        },
        {
            args = {
                type = "label",
                caption = { "gui.sw-rates-calc-extreme-rates" },
                style = "subheader_caption_label",
            },
            style_mods = {
                left_padding = 4,
            }
        },
        {
            args = { type = "empty-widget" },
            style_mods = { horizontally_stretchable = true },
        },
        component_rate.define_toolbar(data),
    }
end

page.right_panel.define_toolbar = function(data, page)
    local conf = page.conf
    local gui_recipe = api.configuration.gui_recipe(conf)
    local ui_recipe = api.gui.gui_button(gui_recipe)
    local gui_entity = api.configuration.gui_entity(conf)
    local ui_entity = api.gui.gui_button(gui_entity)

    local real_conf = conf.type == "meta" and conf.children[1] or conf
    local label = { "" } ---@type LocalisedString
    if (real_conf.type == "crafting-machine") then
        label = real_conf.recipe.localised_name
    elseif (real_conf.entity) then
        label = real_conf.entity.localised_name
    else
        label = gui_recipe.name or gui_entity.name
    end

    ---@type GuiElemDef[]
    return {
        {
            args = {
                type = "sprite-button",
                style = "transparent_slot",
                sprite = ui_recipe.sprite,
                quality = ui_recipe.quality and ui_recipe.quality.name,
                elem_tooltip = ui_recipe.elem_tooltip,
                tooltip = ui_recipe.tooltip,
            },
            style_mods = {
                size = 24,
                left_margin = 8,
            },
        },
        {
            args = {
                type = "sprite-button",
                style = "transparent_slot",
                sprite = ui_entity.sprite,
                quality = ui_entity.quality and ui_entity.quality.name,
                elem_tooltip = ui_entity.elem_tooltip,
                tooltip = ui_entity.tooltip,
            },
            style_mods = {
                size = 24,
            },
        },
        {
            args = {
                type = "label",
                caption = label,
                style = "subheader_caption_label",
            },
            style_mods = {
                left_padding = 4,
            }
        },
        {
            args = { type = "empty-widget" },
            style_mods = { horizontally_stretchable = true },
        },
    }
end

---@param page Rates.Gui.PageDescription.SelectedEntity
page.left_panel.define_content = function(data, page)
    local id = sheet.get_full_configuration_id(page.conf, page.location, page.force)
    local row = find_configuration(data, id)
    if (not row) then
        return {}
    end

    local products = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
    local ingredients = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]

    for _, amount in ipairs(row.amounts) do
        local node = amount.node
        local count = row.count_effective or 0
        local loc = row.location
        if (amount.tag == "import") then
            loc = amount.tag_extra --[[@as Rates.Data.LocationIndex]]
        end
        if (amount.amount > 0) then
            products[#products + 1] = {
                node = node,
                location = loc,
                amount = amount.amount * count,
                status = {},
            }
        elseif (amount.amount < 0) then
            ingredients[#ingredients + 1] = {
                node = node,
                location = loc,
                amount = -amount.amount * count,
                status = {},
            }
        end
    end

    ---@type GuiElemDef[]
    local children = {}

    if (#products > 0) then
        ---@type LocalisedString
        local caption = { "gui.sw-rates-calc-extreme-products-n", #products }
        children[#children + 1] = component_node.define_list(data, products, page.location,
            caption, true, { data = data.page.state.expanders, index = "products" })
    end
    if (#ingredients > 0) then
        ---@type LocalisedString
        local caption = { "gui.sw-rates-calc-extreme-ingredients-n", #ingredients }
        children[#children + 1] = component_node.define_list(data, ingredients, page.location,
            caption, true, { data = data.page.state.expanders, index = "ingredients" })
    end

    return children
end

---@param gui Rates.Gui.AnnotationDescription
---@return GuiElemDef
local function define_annotation(gui)
    local sprite
    if (gui.icon) then
        sprite = gui.icon.sprite
    elseif (gui.severity == "error") then
        sprite = "virtual-signal/signal-no-entry"
    elseif (gui.severity == "warning") then
        sprite = "utility/warning_icon"
    else
        sprite = "virtual-signal/signal-info"
    end

    ---@type GuiElemDef
    return {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        children = {
            {
                args = {
                    type = "sprite",
                    sprite = sprite,
                },
                style_mods = {
                    stretch_image_to_widget_size = true,
                    size = 20,
                }
            },
            {
                args = {
                    type = "label",
                    caption = gui.text,
                },
                style_mods = {
                    single_line = false,
                },
            },
        },
    }
end

---@param page Rates.Gui.PageDescription.SelectedEntity
page.right_panel.define_content = function(data, page)
    local id = sheet.get_full_configuration_id(page.conf, page.location, page.force)
    local row = find_configuration(data, id)
    if (not row) then
        return {}
    end

    ---@type GuiElemDef[]
    local children = {}

    for _, annotation in ipairs(row.annotations) do
        local gui = api.configuration.gui_annotation(annotation, row.configuration)
        children[#children + 1] = define_annotation(gui)
    end

    local gui_entity = api.configuration.gui_entity(page.conf)
    local gui_icon = api.gui.gui_button(gui_entity)
    local amount = row.count_effective or 0
    local rate = component_rate.define(data, gui_entity.number_format, amount)

    ---@type GuiElemDef
    local header = {
        args = {
            type = "label",
            caption = { "gui.sw-rates-calc-extreme-configuration-amount" },
            style = "caption_label",
        },
    }

    ---@type GuiElemDef[]
    local amounts = {}

    amounts[#amounts + 1] =
    {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        style_mods = {
            left_margin = 18,
        },
        children = {
            {
                args = {
                    type = "label",
                    caption = { "", { "gui.sw-rates-calc-extreme-configuration-effective" }, ":" },
                    style = "semibold_caption_label",
                },
            },
            rate,
            {
                args = {
                    type = "sprite-button",
                    style = "transparent_slot",
                    sprite = gui_icon.sprite,
                    quality = gui_icon.quality and gui_icon.quality.name or nil,
                },
                style_mods = {
                    size = 20,
                },
            },
        },
    }

    local conf = page.conf
    if (conf.type == "item-spoil") then
        ---@type EntityPrototypeFilter[]
        local container_filters = {}
        container_filters[#container_filters + 1] = { filter = "type", type = { "container", "logistic-container", "cargo-wagon" } }

        amounts[#amounts + 1] = {
            args = {
                type = "flow",
                direction = "horizontal",
            },
            style_mods = {
                left_margin = 18,
            },
            children = {
                {
                    args = {
                        type = "label",
                        caption = { "", { "gui.sw-rates-calc-extreme-configuration-spoil-containers" }, ":" },
                        style = "semibold_caption_label",
                    }
                },
                {
                    args = {
                        type = "choose-elem-button",
                        elem_type = "entity-with-quality",
                        elem_filters = container_filters,
                        tags = {
                            num_stacks = amount * conf.item.get_spoil_ticks(conf.quality) / 60 / conf.item.stack_size,
                        }
                    },
                    style_mods = {
                        size = 20,
                        padding = -2,
                    },
                    _elem_changed = handlers.on_select_spoil_container,
                },
                {
                    args = {
                        type = "label",
                    },
                    style_mods = {
                        font = "item-count",
                    }
                }
            }
        }
    end

    local count = row.count_max
    if (row.count_groups) then
        for _, group_count in pairs(row.count_groups) do
            count = count + group_count
        end
    end

    if (count < math.huge) then
        amounts[#amounts + 1] = {
            args = {
                type = "checkbox",
                caption = { "", { "gui.sw-rates-calc-extreme-configuration-maximum" }, ": ", "[font=item-count]", count, "[/font]" },
                state = not row.count_infinite,
            },
            style_mods = {
                left_margin = 18,
            },
            _click = handlers.on_click_ignore_count,
            callback = function(element)
                ---@type Rates.Gui.Component.Configuration
                local element_data = {
                    conf = page.conf,
                    location = page.location,
                    force = page.force,
                }
                component.set_element_data(element, element_data)
            end
        }
    end

    children[#children + 1] = expander.define(header,
        {
            args = {
                type = "flow",
                direction = "vertical",
            },
            children = amounts
        }, true, { data = data.page.state.expanders, index = "amount" })

    return children
end

---@param event EventData.on_gui_click
function handlers.on_click_node(event)
    local element = event.element
    local id = gui_util.find_tag(element, "node_id") --[[@as string]]
    local location = gui_util.find_tag(element, "location") --[[@as Rates.Data.LocationIndex]]
    local window = gui_util.find_top(element)
    presenter.open_page(window, { type = "selected-node", id = id, location = location })
end

---@param event EventData.on_gui_checked_state_changed
function handlers.on_click_ignore_count(event)
    local element = event.element
    local window = gui_util.find_top(element)
    local element_data = component.get_element_data(element) --[[@as Rates.Gui.Component.Configuration]]
    presenter.run_undo_action(window, function(context)
        local id = sheet.get_full_configuration_id(element_data.conf, element_data.location, element_data.force)
        local adjustments = context.sheet.configuration_adjustments
        local entry = adjustments[id]
        if (not entry) then
            entry = {}
            adjustments[id] = entry
        end

        entry.count_infinite = not element.state
        context.changed.configurations = true
        context.description = "ignore building count"
    end)
end

---@param event EventData.on_gui_elem_changed
function handlers.on_select_spoil_container(event)
    local element = event.element
    local num_stacks = element.tags.num_stacks --[[@as number]]
    local label = element.parent.children[element.get_index_in_parent() + 1]
    local container = element.elem_value --[[@as PrototypeWithQuality]]
    if (container) then
        local inventory_size = prototypes.entity[container.name].get_inventory_size(defines.inventory.item_main,
            container.quality)
        local amount = num_stacks / inventory_size
        label.caption = string.format("%.2f", amount)
    else
        label.caption = ""
    end
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "selected-entity")
