local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local api = require("__sw-rates-lib__.api-usage")
local configuration = require("__sw-rates-lib__.scripts.configuration-util")
local component = require("component")
local component_configuration = require("component_configuration")
local component_rate = require("component_rate")
local component_location = require("component_location")
local expander = require("component_expander")
local tostring = require("tostring")
local quality_util = require("__sw-rates-lib__.scripts.quality")
local sheet_manipulation = require("scripts.sheet_manipulation")

do
    ---@class Rates.Gui.PageDescription.SelectedNode : Rates.Gui.PageDescription.Base
    ---@field type "selected-node"
    ---@field node Rates.Node
    ---@field location Rates.Data.LocationIndex
end

do
    ---@class (exact) Rates.Gui.Component.LocationList : Rates.Gui.Component
    ---@field locations Rates.Data.LocationIndex[]
end

local page = { left_panel = {}, right_panel = {} } ---@type Rates.Gui.PagePresenter
presenter.pages["selected-node"] = page

local handlers = {}

---@param data Rates.Gui.WindowDataFull
---@param node Rates.Node
---@param location Rates.Data.LocationIndex
---@return {configuration: Rates.Sheet.Configuration, produced: number, consumed: number, tag: Rates.Configuration.AmountTagExtra?}[], Rates.Node?
local function find_configurations(data, node, location)
    ---@type {configuration: Rates.Sheet.Configuration, produced: number, consumed: number, tag: Rates.Configuration.AmountTagExtra?}[]
    local result = {}
    local id = api.node.get_id(node)
    local rates = data.window.sheet_rates
    if (rates) then
        local any_factors = {} ---@type table<string, number>
        any_factors[location .. "/" .. id] = 1
        local any_data = rates.nodes[location .. "/" .. id]
        if (any_data) then
            if (any_data.any_produced) then
                for other_id, num in pairs(any_data.any_produced) do
                    if (num == 0) then
                        any_factors[other_id] = 0
                    else
                        local sum = 0
                        for _, x in pairs(rates.nodes[other_id].any_consumed) do
                            sum = sum + x
                        end
                        any_factors[other_id] = num / sum
                    end
                end
            end

            if (any_data.any_consumed) then
                for other_id, num in pairs(any_data.any_consumed) do
                    if (num == 0) then
                        any_factors[other_id] = 0
                    else
                        local sum = 0
                        for _, x in pairs(rates.nodes[other_id].any_produced) do
                            sum = sum + x
                        end
                        any_factors[other_id] = num / sum
                    end
                end
            end
        end
        for _, configuration in ipairs(rates.configurations) do
            local produced = 0
            local consumed = 0
            ---@type Rates.Configuration.AmountTag
            local tag = nil
            for _, amount in ipairs(configuration.amounts) do
                local loc = configuration.location
                if (amount.tag == "import") then
                    loc = amount.tag_extra --[[@as Rates.Data.LocationIndex]]
                end
                if (loc == location) then
                    local node_id = api.node.get_id(amount.node)
                    local factor = any_factors[location .. "/" .. node_id]
                    if (factor) then
                        tag = amount.tag
                        if (amount.amount > 0) then
                            produced = produced + amount.amount * factor
                        else
                            consumed = consumed - amount.amount * factor
                        end
                    end
                end
            end

            if (produced > 0 or consumed > 0) then
                result[#result + 1] = {
                    configuration = configuration,
                    produced = produced,
                    consumed = consumed,
                    tag = tag,
                }
            end
        end
    end

    return result
end

page.left_panel.define_toolbar = function(data, page)
    local node = page.node
    local gui = api.gui.gui_button_and_text(api.node.gui_default(node))
    local ui_node = gui.button

    ---@type GuiElemDef[]
    return {
        {
            args = {
                type = "sprite-button",
                style = "transparent_slot",
                sprite = ui_node.sprite,
                quality = ui_node.quality and ui_node.quality.name,
                elem_tooltip = ui_node.elem_tooltip,
                tooltip = ui_node.tooltip,
            },
            style_mods = {
                size = 24,
                left_margin = 8,
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
    local node = page.node
    local gui = api.gui.gui_button_and_text(api.node.gui_default(node))
    local ui_node = gui.button

    ---@type GuiElemDef[]
    return {
        {
            args = {
                type = "sprite-button",
                style = "transparent_slot",
                sprite = ui_node.sprite,
                quality = ui_node.quality and ui_node.quality.name,
                elem_tooltip = ui_node.elem_tooltip,
                tooltip = ui_node.tooltip,
            },
            style_mods = {
                size = 24,
                left_margin = 8,
            },
        },
        {
            args = {
                type = "label",
                caption = gui.text,
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

---@param data Rates.Gui.WindowDataFull
---@param node Rates.Node.Item
---@param location Rates.Data.LocationIndex
---@return GuiElemDef[]
local function define_item_spoilage(data, node, location)
    local item = node.item
    local quality = node.quality

    local spoil_ticks = item.get_spoil_ticks(quality)
    if (spoil_ticks == 0) then
        return {}
    end

    local has_recipe = sheet_manipulation.has_item_spoilage(data.sheet, item.name, quality.name, location)

    local spoil_quality = quality_util.apply_quality_adjustments(quality,
        item.spoil_quality_min, item.spoil_quality_max, item.spoil_quality_change)
    local spoil_time = tostring.ticks_to_time(spoil_ticks)

    ---@type GuiElemDef[]
    local children = {}

    children[#children + 1] = {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        children = {
            {
                args = {
                    type = "checkbox",
                    state = has_recipe,
                },
                style_mods = {
                    margin = { 3, 0, 3, 0 },
                },
                _checked_state_changed = handlers.on_click_toggle_item_spoil,
                callback = function(element)
                    ---@type Rates.Gui.Component.Node
                    local element_data = {
                        node = node,
                        location = location,
                        amount = 0,
                    }
                    component.set_element_data(element, element_data)
                end,
            },
            {
                args = {
                    type = "sprite",
                    sprite = "utility/tooltip_category_spoilable",
                },
                style_mods = {
                    size = 20,
                    stretch_image_to_widget_size = true,
                },
            },
            {
                args = {
                    type = "label",
                    caption = { "tooltip-category.spoilable" },
                    style = "caption_label",
                },
            }
        },
    }

    children[#children + 1] = {
        args = {
            type = "flow",
            direction = "horizontal",
            style = "packed_horizontal_flow",
        },
        style_mods = {
            left_margin = 18,
        },
        children = {
            {
                args = {
                    type = "label",
                    caption = { "", { "description.spoil-time" }, ": " },
                    style = "semibold_caption_label"
                },
            },
            {
                args = {
                    type = "label",
                    caption = spoil_time,
                },
            },
        }
    }

    ---@type EntityPrototypeFilter[]
    local belt_filters = {}
    belt_filters[#belt_filters + 1] = { filter = "type", type = { "transport-belt" } }
    children[#children + 1] = {
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
                    caption = { "", { "gui.sw-rates-calc-extreme-node-spoil-belt-length" }, ":" },
                    style = "semibold_caption_label"
                },
            },
            {
                args = {
                    type = "choose-elem-button",
                    elem_type = "entity",
                    elem_filters = belt_filters,
                    tags = {
                        spoil_ticks = spoil_ticks,
                    }
                },
                style_mods = {
                    size = 20,
                    padding = -2,
                },
                _elem_changed = handlers.on_select_spoil_belt,
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

    local spoil_result = item.spoil_result
    if (spoil_result) then
        local spoil_result_node = api.node.create.item(spoil_result, spoil_quality)
        local gui = api.gui.gui_button_and_text(api.node.gui_default(spoil_result_node))
        local ui_node = gui.button
        children[#children + 1] = {
            args = {
                type = "flow",
                direction = "horizontal",
                style = "packed_horizontal_flow",
            },
            style_mods = {
                left_margin = 18,
            },
            children = {
                {
                    args = {
                        type = "label",
                        caption = { "", { "description.spoil-result" }, ": " },
                        style = "semibold_caption_label"
                    },
                },
                {
                    args = {
                        type = "sprite-button",
                        style = "transparent_slot",
                        sprite = ui_node.sprite,
                        quality = ui_node.quality and ui_node.quality.name,
                        elem_tooltip = ui_node.elem_tooltip,
                        tooltip = ui_node.tooltip,
                    },
                    style_mods = {
                        size = 20,
                    },
                },
                {
                    args = {
                        type = "label",
                        caption = { "", " ", gui.text }
                    },
                },
            }
        }
    end

    return children
end

---@param data Rates.Gui.WindowDataFull
---@param node Rates.Node.Item
---@param location Rates.Data.LocationIndex
---@return GuiElemDef[]
local function define_item_fuel(data, node, location)
    local item = node.item
    local quality = node.quality

    local fuel_value = item.fuel_value
    if (fuel_value == 0) then
        return {}
    end

    local has_recipe = sheet_manipulation.has_item_fuel(data.sheet, item.name, quality.name, location)

    local fuel_value_string = api.gui.format_number(fuel_value) .. "J"

    local fuel_categories = item.fuel_categories
    local fuel_category = fuel_categories and #fuel_categories == 1 and prototypes.fuel_category[fuel_categories[1]] or
        nil

    local sprite = "tooltip-category-" .. (fuel_category and fuel_category.name or "")
    if (not helpers.is_valid_sprite_path(sprite)) then
        sprite = "virtual-signal/signal-fire"
    end

    ---@type GuiElemDef[]
    local children = {}

    children[#children + 1] = {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        children = {
            {
                args = {
                    type = "checkbox",
                    state = has_recipe,
                },
                style_mods = {
                    margin = { 3, 0, 3, 0 },
                },
                _checked_state_changed = handlers.on_click_toggle_item_fuel,
                callback = function(element)
                    ---@type Rates.Gui.Component.Node
                    local element_data = {
                        node = node,
                        location = location,
                        amount = 0,
                    }
                    component.set_element_data(element, element_data)
                end,
            },
            {
                args = {
                    type = "sprite",
                    sprite = sprite,
                },
                style_mods = {
                    size = 20,
                    stretch_image_to_widget_size = true,
                },
            },
            {
                args = {
                    type = "label",
                    caption = fuel_category and fuel_category.localised_name or { "gui.fuel" },
                    style = "caption_label",
                },
            }
        },
    }

    children[#children + 1] = {
        args = {
            type = "flow",
            direction = "horizontal",
            style = "packed_horizontal_flow",
        },
        style_mods = {
            left_margin = 18,
        },
        children = {
            {
                args = {
                    type = "label",
                    caption = { "", { "description.fuel-value" }, ": " },
                    style = "semibold_caption_label"
                },
            },
            {
                args = {
                    type = "label",
                    caption = fuel_value_string,
                },
            },
        }
    }

    return children
end

---@param categories LuaFuelCategoryPrototype[]
---@param location Rates.Data.LocationIndex
---@return GuiElemDef[]
local function define_item_fuel_add(categories, location)
    ---@type GuiElemDef[]
    local children = {}

    if (#categories > 1) then
        children[#children + 1] = {
            args = {
                type = "label",
                caption = { "gui.sw-rates-calc-extreme-node-accepted-fuel-categories" },
                style = "caption_label",
            },
        }

        for _, category in ipairs(categories) do
            local sprite = "tooltip-category-" .. category.name
            if (not helpers.is_valid_sprite_path(sprite)) then
                sprite = "virtual-signal/signal-fire"
            end

            children[#children + 1] = {
                args = {
                    type = "flow",
                    direction = "horizontal",
                    style = "packed_horizontal_flow",
                },
                style_mods = {
                    left_margin = 18,
                },
                children = {
                    {
                        args = {
                            type = "sprite",
                            sprite = sprite,
                        },
                        style_mods = {
                            size = 20,
                            stretch_image_to_widget_size = true,
                        },
                    },
                    {
                        args = {
                            type = "label",
                            caption = { "", " ", category.localised_name },
                        },
                    },
                }
            }
        end

        children[#children + 1] = { args = { type = "line" } }
    end

    children[#children + 1] = {
        args = {
            type = "label",
            caption = { "gui.sw-rates-calc-extreme-node-add-item" },
            style = "caption_label",
        },
    }

    ---@type ItemPrototypeFilter[]
    local filters = {}
    for _, category in ipairs(categories) do
        filters[#filters + 1] = { filter = "fuel-category", ["fuel-category"] = category.name }
    end

    children[#children + 1] = {
        args = {
            type = "choose-elem-button",
            style = "slot_button_in_shallow_frame",
            elem_type = "item-with-quality",
            elem_filters = filters,
            tags = { location = location },
        },
        style_mods = {
            size = 32,
            left_margin = 18,
        },
        _elem_changed = handlers.on_select_item_fuel,
    }

    return children
end

---@param data Rates.Gui.WindowDataFull
---@param node Rates.Node.Item
---@param location Rates.Data.LocationIndex
---@return GuiElemDef[]
local function define_item_send_to_orbit(data, node, location)
    local item = node.item
    local quality = node.quality

    if (item.send_to_orbit_mode == "not-sendable") then
        return {}
    end

    local has_recipe = sheet_manipulation.has_item_send_to_orbit(data.sheet, item.name, quality.name, location)

    ---@type GuiElemDef[]
    local children = {}

    children[#children + 1] = {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        children = {
            {
                args = {
                    type = "checkbox",
                    state = has_recipe,
                },
                style_mods = {
                    margin = { 3, 0, 3, 0 },
                },
                _checked_state_changed = handlers.on_click_toggle_item_send_to_orbit,
                callback = function(element)
                    ---@type Rates.Gui.Component.Node
                    local element_data = {
                        node = node,
                        location = location,
                        amount = 0,
                    }
                    component.set_element_data(element, element_data)
                end,
            },
            {
                args = {
                    type = "sprite",
                    sprite = "utility/space_age_icon",
                },
                style_mods = {
                    size = 20,
                    stretch_image_to_widget_size = true,
                },
            },
            {
                args = {
                    type = "label",
                    caption = { "orbit" },
                    style = "caption_label",
                },
            }
        },
    }

    ---@type Rates.Configuration.Amount[]
    local amounts = {}
    configuration.calculate_products(amounts, quality, item.rocket_launch_products, 1, 0)

    if (#amounts > 0) then
        children[#children + 1] = {
            args = {
                type = "flow",
                direction = "horizontal",
                style = "packed_horizontal_flow",
            },
            style_mods = {
                left_margin = 18,
            },
            children = {
                {
                    args = {
                        type = "label",
                        caption = { "", { "description.rocket-launch-products" }, ": " },
                        style = "semibold_caption_label"
                    },
                },
            }
        }
    end

    for _, amount in ipairs(amounts) do
        local ui_amount = api.node.gui_default(amount.node)
        ui_amount.number_format = { unit = "#", factor = 1 }
        local gui = api.gui.gui_button_and_text(ui_amount, amount.amount)
        local ui_node = gui.button
        local text = gui.text
        text[3] = "[font=item-count] × [/font]"

        children[#children + 1] = {
            args = {
                type = "flow",
                direction = "horizontal",
                style = "packed_horizontal_flow",
            },
            style_mods = {
                left_margin = 18,
            },
            children = {
                {
                    args = {
                        type = "sprite-button",
                        style = "transparent_slot",
                        sprite = ui_node.sprite,
                        quality = ui_node.quality and ui_node.quality.name,
                        elem_tooltip = ui_node.elem_tooltip,
                        tooltip = ui_node.tooltip,
                    },
                    style_mods = {
                        size = 20,
                    },
                },
                {
                    args = {
                        type = "label",
                        caption = { "", " ", text }
                    },
                },
            }
        }
    end

    return children
end

---@type string[]
local send_to_orbit_items = {}
for name, item in pairs(prototypes.item) do
    if (item.send_to_orbit_mode ~= "not-sendable") then
        send_to_orbit_items[#send_to_orbit_items + 1] = name
    end
end

---@param location Rates.Data.LocationIndex
---@return GuiElemDef[]
local function define_item_send_to_orbit_add(location)
    ---@type GuiElemDef[]
    local children = {}

    children[#children + 1] = {
        args = {
            type = "label",
            caption = { "gui.sw-rates-calc-extreme-node-add-item" },
            style = "caption_label",
        },
    }

    ---@type ItemPrototypeFilter[]
    local filters = { { filter = "name", name = send_to_orbit_items } }

    children[#children + 1] = {
        args = {
            type = "choose-elem-button",
            style = "slot_button_in_shallow_frame",
            elem_type = "item-with-quality",
            elem_filters = filters,
            tags = { location = location }
        },
        style_mods = {
            size = 32,
            left_margin = 18,
        },
        _elem_changed = handlers.on_select_item_send_to_orbit,
    }

    return children
end

---@param data Rates.Gui.WindowDataFull
---@param node Rates.Node.Fluid
---@param location Rates.Data.LocationIndex
---@return GuiElemDef[]
local function define_fluid_fuel(data, node, location)
    local fluid = node.fluid
    local temperature = node.temperature

    local fuel_value = fluid.fuel_value
    if (fuel_value == 0) then
        return {}
    end

    local has_recipe = sheet_manipulation.has_fluid_fuel(data.sheet, fluid.name, temperature, location)

    local fuel_value_string = api.gui.format_number(fuel_value) .. "J"

    ---@type GuiElemDef[]
    local children = {}

    children[#children + 1] = {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        children = {
            {
                args = {
                    type = "checkbox",
                    state = has_recipe,
                },
                style_mods = {
                    margin = { 3, 0, 3, 0 },
                },
                _checked_state_changed = handlers.on_click_toggle_fluid_fuel,
                callback = function(element)
                    ---@type Rates.Gui.Component.Node
                    local element_data = {
                        node = node,
                        location = location,
                        amount = 0,
                    }
                    component.set_element_data(element, element_data)
                end,
            },
            {
                args = {
                    type = "sprite",
                    sprite = "tooltip-category-fuel",
                },
                style_mods = {
                    size = 20,
                    stretch_image_to_widget_size = true,
                },
            },
            {
                args = {
                    type = "label",
                    caption = { "gui.fuel" },
                    style = "caption_label",
                },
            }
        },
    }

    children[#children + 1] = {
        args = {
            type = "flow",
            direction = "horizontal",
            style = "packed_horizontal_flow",
        },
        style_mods = {
            left_margin = 18,
        },
        children = {
            {
                args = {
                    type = "label",
                    caption = { "", { "description.fuel-value" }, ": " },
                    style = "semibold_caption_label"
                },
            },
            {
                args = {
                    type = "label",
                    caption = fuel_value_string,
                },
            },
        }
    }

    return children
end

---@param location Rates.Data.LocationIndex
---@return GuiElemDef[]
local function define_fluid_fuel_add(location)
    ---@type GuiElemDef[]
    local children = {}

    children[#children + 1] = {
        args = {
            type = "label",
            caption = { "gui.sw-rates-calc-extreme-node-add-fluid" },
            style = "caption_label",
        },
    }

    ---@type FluidPrototypeFilter[]
    local filters = {}
    filters[#filters + 1] = { filter = "fuel-value", comparison = ">", value = 0 }

    children[#children + 1] = {
        args = {
            type = "flow",
            direction = "horizontal",
            tags = { location = location }
        },
        style_mods = {
            left_margin = 18,
        },
        children = {
            {
                args = {
                    type = "choose-elem-button",
                    style = "slot_button_in_shallow_frame",
                    elem_type = "fluid",
                    elem_filters = filters,
                },
                style_mods = {
                    size = 32,
                },
                _elem_changed = handlers.on_select_fluid_fuel,
            },
            {
                args = {
                    type = "drop-down",
                    items = {},
                    visible = false,
                },
                style_mods = {
                    minimal_width = 72,
                    margin = { 2, 0, 2, 0 },
                },
                _selection_state_changed = handlers.on_select_fluid_fuel_temperature,
            },
        },
    }

    return children
end

---@type Rates.Node.NumberFormat
local default_number_format = {
    unit = "/s",
    factor = 1,
}

page.left_panel.define_content = function(data, page)
    local node = page.node
    local location = page.location
    local rows = find_configurations(data, node, location)

    ---@type GuiElemDef[]
    local children = {}

    local gui_node = api.node.gui_default(node)

    ---@type GuiElemDef[]
    local produced_by = {}
    local total_produced = 0
    ---@type GuiElemDef[]
    local consumed_by = {}
    local total_consumed = 0

    for _, row in ipairs(rows) do
        local conf = row.configuration.configuration
        ---@type Color.0
        local font_color = { r = 1, g = 1, b = 1 }
        if (row.produced > 0) then
            local amount = row.produced * (row.configuration.count_effective or 0)
            local rate = component_rate.define(data, gui_node.number_format or default_number_format, amount)
            rate.style_mods = {
                width = 70,
                height = 32,
                horizontal_align = "right",
                vertical_align = "center",
            }
            total_produced = total_produced + amount
            local element = component_configuration.define_configuration_row(conf, row.configuration.location,
                row.configuration.force, nil, font_color, {})
            table.insert(element.children, 1, rate)
            produced_by[#produced_by + 1] = element
        end
        if (row.consumed > 0) then
            local amount = row.consumed * (row.configuration.count_effective or 0)
            local rate = component_rate.define(data, gui_node.number_format or default_number_format, amount)
            rate.style_mods = {
                width = 70,
                height = 32,
                horizontal_align = "right",
                vertical_align = "center",
            }
            total_consumed = total_consumed + amount
            local element = component_configuration.define_configuration_row(conf, row.configuration.location,
                row.configuration.force, nil, font_color, {})
            table.insert(element.children, 1, rate)
            consumed_by[#consumed_by + 1] = element
        end
    end

    if (#produced_by > 0) then
        local number = component_rate.define(data, gui_node.number_format or default_number_format,
            math.abs(total_produced))

        ---@type GuiElemDef
        local header = {
            args = {
                type = "flow",
                direction = "horizontal",
            },
            children = {
                {
                    args = {
                        type = "label",
                        caption = { "", { "gui.sw-rates-calc-extreme-produced-n", #produced_by }, ": " },
                        style = "caption_label"
                    }
                },
                number,
            },
        }

        ---@type GuiElemDef
        local container = {
            args = {
                type = "flow",
                direction = "vertical",
            },
            style_mods = {
                left_margin = 12,
            },
            children = produced_by,
        }
        children[#children + 1] = expander.define(header, container, true,
            { data = data.page.state.expanders, index = "produced_by" })
    end
    if (#consumed_by > 0) then
        local number = component_rate.define(data, gui_node.number_format or default_number_format,
            math.abs(total_consumed))

        ---@type GuiElemDef
        local header = {
            args = {
                type = "flow",
                direction = "horizontal",
            },
            children = {
                {
                    args = {
                        type = "label",
                        caption = { "", { "gui.sw-rates-calc-extreme-consumed-n", #consumed_by }, ": " },
                        style = "caption_label"
                    }
                },
                number,
            },
        }

        ---@type GuiElemDef
        local container = {
            args = {
                type = "flow",
                direction = "vertical",
            },
            style_mods = {
                left_margin = 12,
            },
            children = consumed_by,
        }
        children[#children + 1] = expander.define(header, container, true,
            { data = data.page.state.expanders, index = "consumed_by" })
    end

    return children
end

page.right_panel.define_content = function(data, page)
    local node = page.node
    local location = page.location
    local sheet = data.window.sheet_rates
    local rows = find_configurations(data, node, location)

    if (not sheet) then
        return {}
    end

    ---@type integer
    local num_produced_by = 0
    ---@type table<Rates.Data.LocationIndex, true>
    local exports = {}
    local total_produced = 0
    local num_produced = 0
    local total_consumed = 0
    local num_consumed = 0
    for _, row in ipairs(rows) do
        if (row.tag ~= "import" and row.produced - row.consumed > 0) then
            num_produced_by = num_produced_by + 1
        elseif (row.tag == "export" and row.consumed > 0) then
            local location = row.configuration.configuration.target --[[@as Rates.Data.LocationIndex]]
            exports[location] = true
        end
        local count = row.configuration.count_effective or 0
        if (row.produced > 0) then
            total_produced = total_produced + row.produced * count
            num_produced = num_produced + 1
        end
        if (row.consumed > 0) then
            total_consumed = total_consumed + row.consumed * count
            num_consumed = num_consumed + 1
        end
    end

    local id = location .. "/" .. api.node.get_id(node)
    local sheet_node = sheet.nodes[id]
    local is_forced_balanced = sheet_node and sheet_node.min == 0 and sheet_node.max == 0

    ---@type GuiElemDef[]
    local children = {}

    ---@param content GuiElemDef[]
    local function add_contents(content)
        if (#content == 0) then
            return
        end

        if (#children > 0) then
            children[#children + 1] = { args = { type = "line" } }
        end

        for _, child in ipairs(content) do
            children[#children + 1] = child
        end
    end

    local gui_node = api.node.gui_default(node)
    local number_format = gui_node.number_format or { unit = "/s", factor = 1 }

    ---@type GuiElemDef[]
    local amounts = {}

    if (num_produced > 0 and num_consumed > 0) then
        amounts[#amounts + 1] =
        {
            args = {
                type = "flow",
                direction = "horizontal",
            },
            children = {
                {
                    args = {
                        type = "checkbox",
                        state = is_forced_balanced,
                    },
                    style_mods = {
                        margin = { 3, 0, 3, 0 },
                        right_padding = 4,
                    },
                    _checked_state_changed = handlers.on_click_toggle_balanced,
                    callback = function(element)
                        ---@type Rates.Gui.Component.Node
                        local element_data = {
                            node = node,
                            location = location,
                            amount = 0,
                        }
                        component.set_element_data(element, element_data)
                    end,
                },
                {
                    args = {
                        type = "label",
                        caption = { "gui.sw-rates-calc-extreme-node-balanced" },
                        style = "caption_label",
                    },
                },
            },
        }

        if (not is_forced_balanced and total_produced > 0 and total_consumed > 0) then
            local total_net = total_produced - total_consumed
            local rate_net = component_rate.define(data, number_format, math.abs(total_net))
            local total_intermediate = math.min(total_produced, total_consumed)
            local rate_intermediate = component_rate.define(data, number_format, total_intermediate)
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
                            caption = { "", { total_net < 0 and "gui.sw-rates-calc-extreme-node-net-consumption" or "gui.sw-rates-calc-extreme-node-net-production" }, ":" },
                            style = "semibold_caption_label",
                        },
                    },
                    rate_net,
                },
            }

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
                            caption = { "", { "gui.sw-rates-calc-extreme-node-intermediate" }, ":" },
                            style = "semibold_caption_label",
                        },
                    },
                    rate_intermediate,
                },
            }
        end

        add_contents(amounts)
    end

    if (node.type == "item") then
        add_contents(define_item_spoilage(data, node, location))
        add_contents(define_item_fuel(data, node, location))
        add_contents(define_item_send_to_orbit(data, node, location))
    elseif (node.type == "fluid") then
        add_contents(define_fluid_fuel(data, node, location))
    elseif (node.type == "item-fuel") then
        add_contents(define_item_fuel_add({ node.category }, location))
    elseif (node.type == "any" and node.details and node.details.type == "any-item-fuel") then
        add_contents(define_item_fuel_add(node.details.categories, location))
    elseif (node.type == "fluid-fuel") then
        add_contents(define_fluid_fuel_add(location))
    elseif (node.type == "send-to-orbit") then
        add_contents(define_item_send_to_orbit_add(location))
    end

    local num_exports = table_size(exports)

    if (node.type == "item" and num_produced_by > 0 and #data.sheet.locations > 1) then
        ---@type GuiElemDef
        local header = {
            args = {
                type = "label",
                caption = { "", { "gui.sw-rates-calc-extreme-exports" }, " (", num_exports, ")" },
                style = "caption_label",
            },
        }

        ---@type GuiElemDef[]
        local content = {}
        local num_exports = 0

        ---@type LocalisedString[]
        local items = {}
        ---@type Rates.Data.LocationIndex[]
        local item_ids = {}
        for i, other_location in ipairs(data.sheet.locations) do
            if (i ~= location) then
                local gui_location = component_location.gui_location(other_location)
                local label = api.gui.gui_message(gui_location)
                if (exports[i]) then
                    num_exports = num_exports + 1
                    content[#content + 1] = {
                        args = {
                            type = "flow",
                            direction = "horizontal",
                        },
                        children = {
                            {
                                args = {
                                    type = "label",
                                    caption = label,
                                },
                            },
                            {
                                args = {
                                    type = "button",
                                    mouse_button_filter = { "left" },
                                    style = "slot_button_simple",
                                    caption = "×",
                                    tags = { location = i },
                                    tooltip = presenter.create_action_tooltip(nil, {
                                        left = "Remove export",
                                    }),
                                },
                                style_mods = {
                                    size = 20,
                                    font_color = { r = 1, g = 0, b = 0 },
                                    font = "default",
                                },
                                _click = handlers.on_click_export,
                            },
                        },
                    }
                else
                    items[#items + 1] = label
                    item_ids[#item_ids + 1] = i
                end
            end
        end

        if (#items > 0) then
            content[#content + 1] = {
                args = {
                    type = "drop-down",
                    items = items
                },
                _selection_state_changed = handlers.on_select_export,
                callback = function(element)
                    ---@type Rates.Gui.Component.LocationList
                    local element_data = { locations = item_ids }
                    component.set_element_data(element, element_data)
                end
            }
        end

        children[#children + 1] = expander.define(header, {
            args = {
                type = "flow",
                direction = "vertical",
            },
            children = content,
        }, num_exports > 0, { data = data.page.state.expanders, index = "exports" })
    end

    return children
end

---@param event EventData.on_gui_checked_state_changed
function handlers.on_click_toggle_balanced(event)
    local element = event.element
    local element_data = component.get_element_data(element) --[[@as Rates.Gui.Component.Node]]
    local window = gui_util.find_top(element)
    local link = not element.state
    presenter.run_undo_action(window, function(context)
        if (not sheet_manipulation.configure_node(context.sheet, api.node.get_id(element_data.node), element_data.location, not link)) then
            context.skip = true
        end

        local ui = api.gui.gui_message(api.node.gui_default(element_data.node))
        context.description = { "", link and "unlink " or "link ", ui }
        context.changed.configurations = true
    end)
end

---@param event EventData.on_gui_checked_state_changed
function handlers.on_click_toggle_item_spoil(event)
    local element = event.element
    local element_data = component.get_element_data(element) --[[@as Rates.Gui.Component.Node]]
    local window = gui_util.find_top(element)
    presenter.run_undo_action(window, function(context)
        local node = element_data.node --[[@as Rates.Node.Item]]
        local item = node.item
        local quality = node.quality
        ---@type Rates.Configuration.ItemSpoil
        local configuration = { type = "item-spoil", item = item, quality = quality }
        if (sheet_manipulation.toggle_configuration(context.sheet, configuration, element_data.location, context.player.force --[[@as LuaForce]])) then
            context.description = "add spoil recipe for [item=" .. item.name .. ",quality=" .. quality.name .. "]"
        else
            context.description = "remove spoil recipe for [item=" .. item.name .. ",quality=" .. quality.name .. "]"
        end
        context.changed.configurations = true
    end)
end

---@param event EventData.on_gui_elem_changed
function handlers.on_select_spoil_belt(event)
    local element = event.element
    local spoil_ticks = element.tags.spoil_ticks --[[@as number]]
    local label = element.parent.children[element.get_index_in_parent() + 1]
    local belt = element.elem_value --[[@as string]]
    if (belt) then
        local belt_speed = prototypes.entity[belt].belt_speed
        label.caption = string.format("%.2f", spoil_ticks * belt_speed)
    else
        label.caption = ""
    end
end

---@param event EventData.on_gui_click
function handlers.on_click_toggle_item_fuel(event)
    local element = event.element
    local element_data = component.get_element_data(element) --[[@as Rates.Gui.Component.Node]]
    local window = gui_util.find_top(element)
    presenter.run_undo_action(window, function(context)
        local node = element_data.node --[[@as Rates.Node.Item]]
        local item = node.item
        local quality = node.quality
        ---@type Rates.Configuration.ItemFuel
        local configuration = { type = "item-fuel", item = item, quality = quality, produce_burnt_result = true }
        if (sheet_manipulation.toggle_configuration(context.sheet, configuration, element_data.location, context.player.force --[[@as LuaForce]])) then
            context.description = "add fuel recipe for [item=" .. item.name .. ",quality=" .. quality.name .. "]"
        else
            context.description = "remove fuel recipe for [item=" .. item.name .. ",quality=" .. quality.name .. "]"
        end
        context.changed.configurations = true
    end)
end

---@param event EventData.on_gui_click
function handlers.on_click_toggle_item_send_to_orbit(event)
    local element = event.element
    local element_data = component.get_element_data(element) --[[@as Rates.Gui.Component.Node]]
    local window = gui_util.find_top(element)
    presenter.run_undo_action(window, function(context)
        local node = element_data.node --[[@as Rates.Node.Item]]
        local item = node.item
        local quality = node.quality
        ---@type Rates.Configuration.SendToOrbit
        local configuration = { type = "send-to-orbit", item = item, quality = quality }
        if (sheet_manipulation.toggle_configuration(context.sheet, configuration, element_data.location, context.player.force --[[@as LuaForce]])) then
            context.description = "add send-to-orbit recipe for [item=" ..
                item.name .. ",quality=" .. quality.name .. "]"
        else
            context.description = "remove send-to-orbit recipe for [item=" ..
                item.name .. ",quality=" .. quality.name .. "]"
        end
        context.changed.configurations = true
    end)
end

---@param event EventData.on_gui_click
function handlers.on_click_toggle_fluid_fuel(event)
    local element = event.element
    local element_data = component.get_element_data(element) --[[@as Rates.Gui.Component.Node]]
    local window = gui_util.find_top(element)
    presenter.run_undo_action(window, function(context)
        local node = element_data.node --[[@as Rates.Node.Fluid]]
        local fluid = node.fluid
        local temperature = node.temperature
        ---@type Rates.Configuration.FluidFuel
        local configuration = { type = "fluid-fuel", fluid = fluid, temperature = temperature }
        if (sheet_manipulation.toggle_configuration(context.sheet, configuration, element_data.location, context.player.force --[[@as LuaForce]])) then
            context.description = "add fuel recipe for [fluid=" .. fluid.name .. "] (" .. temperature .. "°C)"
        else
            context.description = "remove fuel recipe for [fluid=" .. fluid.name .. "] (" .. temperature .. "°C)"
        end
        context.changed.configurations = true
    end)
end

---@param event EventData.on_gui_elem_changed
function handlers.on_select_item_fuel(event)
    local element = event.element
    local value = element.elem_value
    if (not value) then
        return
    end

    local item = prototypes.item[value.name]
    local quality = prototypes.quality[value.quality]
    local location = gui_util.find_tag(element, "location") --[[@as Rates.Data.LocationIndex]]
    local window = gui_util.find_top(element)
    presenter.run_undo_action(window, function(context)
        ---@type Rates.Configuration.ItemFuel
        local configuration = { type = "item-fuel", item = item, quality = quality, produce_burnt_result = true }
        if (sheet_manipulation.has_configuration(context.sheet, configuration, location)) then
            context.skip = true
            element.elem_value = nil
            return
        end

        sheet_manipulation.toggle_configuration(context.sheet, configuration, location,
            context.player.force --[[@as LuaForce]])
        context.description = "add fuel recipe for [item=" .. item.name .. ",quality=" .. quality.name .. "]"
        context.changed.configurations = true
    end)
end

---@param element LuaGuiElement
---@param fluid LuaFluidPrototype
---@param temperature number
---@param location Rates.Data.LocationIndex
local function add_fluid_fuel(element, fluid, temperature, location)
    local idx = element.get_index_in_parent()
    local temp_dropdown = element.parent.children[idx + 2]
    local window = gui_util.find_top(element)
    presenter.run_undo_action(window, function(context)
        ---@type Rates.Configuration.FluidFuel
        local configuration = { type = "fluid-fuel", fluid = fluid, temperature = temperature }
        if (sheet_manipulation.has_configuration(context.sheet, configuration, location)) then
            context.skip = true
            element.elem_value = nil
            temp_dropdown.visible = false
            return
        end

        sheet_manipulation.toggle_configuration(context.sheet, configuration, location,
            context.player.force --[[@as LuaForce]])
        context.description = "add fuel recipe for [fluid=" .. fluid.name .. "] (" .. temperature .. "°C)"
        context.changed.configurations = true
    end)
end

---@param event EventData.on_gui_elem_changed
function handlers.on_select_fluid_fuel(event)
    local element = event.element
    local idx = element.get_index_in_parent()
    local temp_dropdown = element.parent.children[idx + 1]
    local value = element.elem_value
    if (not value) then
        temp_dropdown.visible = false
        return
    end

    local fluid = prototypes.fluid[value]
    local location = gui_util.find_tag(element, "location") --[[@as Rates.Data.LocationIndex]]
    local temperatures = api.temperatures.get_generated_fluid_temperatures(fluid)
    if (#temperatures == 1) then
        local temperature = temperatures[1]
        add_fluid_fuel(element, fluid, temperature, location)
        return
    end

    local idx = element.get_index_in_parent()
    local temp_dropdown = element.parent.children[idx + 1]
    local items = {} ---@type LocalisedString[]
    items[#items + 1] = { "", "???", "°C" }
    for _, temp in ipairs(temperatures) do
        items[#items + 1] = { "", temp, "°C" }
    end
    temp_dropdown.visible = true
    temp_dropdown.items = items
    temp_dropdown.selected_index = 1
end

---@param event EventData.on_gui_selection_state_changed
function handlers.on_select_fluid_fuel_temperature(event)
    local temp_dropdown = event.element
    local idx = temp_dropdown.get_index_in_parent()
    local element = temp_dropdown.parent.children[idx - 1]
    local value = element.elem_value
    local fluid = prototypes.fluid[value]
    local location = gui_util.find_tag(element, "location") --[[@as Rates.Data.LocationIndex]]
    local temperature = temp_dropdown.get_item(temp_dropdown.selected_index)[2] --[[@as string]]
    if (temperature == "???") then
        return
    end

    local temperature = tonumber(temperature) ---@cast temperature -nil

    add_fluid_fuel(element, fluid, temperature, location)
end

---@param event EventData.on_gui_elem_changed
function handlers.on_select_item_send_to_orbit(event)
    local element = event.element
    local value = element.elem_value
    if (not value) then
        return
    end

    local item = prototypes.item[value.name]
    local quality = prototypes.quality[value.quality]
    local location = gui_util.find_tag(element, "location") --[[@as Rates.Data.LocationIndex]]
    local window = gui_util.find_top(element)
    presenter.run_undo_action(window, function(context)
        ---@type Rates.Configuration.SendToOrbit
        local configuration = { type = "send-to-orbit", item = item, quality = quality }
        if (sheet_manipulation.has_configuration(context.sheet, configuration, location)) then
            context.skip = true
            element.elem_value = nil
            return
        end

        sheet_manipulation.toggle_configuration(context.sheet, configuration, location,
            context.player.force --[[@as LuaForce]])
        context.description = "add send-to-orbit recipe for [item=" .. item.name .. ",quality=" .. quality.name .. "]"
        context.changed.configurations = true
    end)
end

---@param event EventData.on_gui_click
function handlers.on_click_export(event)
    if (event.button == defines.mouse_button_type.left and not event.shift and not event.alt and not event.control) then
        local element = event.element
        local window = gui_util.find_top(element)
        local data = presenter.get_window_data(window)
        local page = data.page.page_id
        local node = page.node --[[@as Rates.Node.Item]]
        local location = page.location
        local surface = data.sheet.locations[location]
        local need_rocket = not surface.platform
        local target_location = element.tags.location --[[@as Rates.Data.LocationIndex]]
        local target_surface = api.gui.gui_message(component_location.gui_location(data.sheet.locations[target_location]))
        presenter.run_undo_action(window, function(context)
            ---@type Rates.Configuration.SendToPlatform
            local conf = {
                type = "send-to-platform",
                item = node.item,
                quality = node.quality,
                need_rocket = need_rocket,
                target = target_location,
            }
            sheet_manipulation.toggle_configuration(context.sheet, conf, location,
                context.player.force --[[@as LuaForce]])

            context.description = { "",
                "remove export of [item=" .. node.item.name .. ",quality=" .. node.quality.name .. "] to ",
                target_surface }
            context.changed.configurations = true
        end)
    end
end

---@param event EventData.on_gui_selection_state_changed
function handlers.on_select_export(event)
    local element = event.element
    local window = gui_util.find_top(element)
    local data = presenter.get_window_data(window)
    local page = data.page.page_id
    local node = page.node --[[@as Rates.Node.Item]]
    local location = page.location
    local surface = data.sheet.locations[location]
    local need_rocket = not surface.platform
    local element_data = component.get_element_data(element) --[[@as Rates.Gui.Component.LocationList]]
    local target_location = element_data.locations[element.selected_index]
    local target_surface = api.gui.gui_message(component_location.gui_location(data.sheet.locations[target_location]))
    presenter.run_undo_action(window, function(context)
        ---@type Rates.Configuration.SendToPlatform
        local conf = {
            type = "send-to-platform",
            item = node.item,
            quality = node.quality,
            need_rocket = need_rocket,
            target = target_location,
        }
        sheet_manipulation.toggle_configuration(context.sheet, conf, location, context.player.force --[[@as LuaForce]])

        context.description = { "",
            "add export of [item=" .. node.item.name .. ",quality=" .. node.quality.name .. "] to ",
            target_surface }
        context.changed.configurations = true
    end)
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "selected-node")
