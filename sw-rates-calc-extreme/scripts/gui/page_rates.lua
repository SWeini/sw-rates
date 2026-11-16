local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local api = require("__sw-rates-lib__.api-usage")
local component_rate = require("component_rate")
local component_node = require("component_node")
local component_configuration = require("component_configuration")
local component_location = require("component_location")
local expander = require("component_expander")
local sheet_manipulation = require("scripts.sheet_manipulation")

do
    ---@class Rates.Gui.PageDescription.Rates : Rates.Gui.PageDescription.Base
    ---@field type "rates"
end

local page = { left_panel = {}, right_panel = {} } ---@type Rates.Gui.PagePresenter
presenter.pages["rates"] = page

local handlers = {}

page.left_panel.define_toolbar = function(data, page)
    ---@type GuiElemDef[]
    return {
        { args = { type = "label", style = "subheader_caption_label", caption = { "gui.sw-rates-calc-extreme-rates" } } },
        {
            args = { type = "empty-widget" },
            style_mods = { horizontally_stretchable = true },
        },
        component_rate.define_toolbar(data),
    }
end

---@param node Rates.Node
---@return integer
local function node_type(node)
    if (node.type == "agricultural-cell") then
        return -1
    end
    if (node.type == "electric-power") then
        return 0
    end
    if (node.type == "electric-buffer") then
        return 1
    end
    if (node.type == "heat") then
        return 5
    end
    if (node.type == "fluid-fuel") then
        return 6
    end
    if (node.type == "item-fuel") then
        return 7
    end

    if (node.type == "item") then
        return 10
    end
    if (node.type == "fluid") then
        return 11
    end

    if (node.type == "any") then
        local details = node.details
        if (details) then
            if (details.type == "any-fluid") then
                return 11
            end

            if (details.type == "any-heat") then
                return 5
            end
            if (details.type == "any-item-fuel") then
                return 7
            end
        end
    end

    return 100
end

---@param produced number
---@param consumed number
---@return boolean
local function is_balanced(produced, consumed)
    local delta = math.abs(produced + consumed)
    local scale = math.max(1, math.max(produced, -consumed))
    return delta < 1e-10 * scale
end

---@type table<string, boolean>
local environment_node_types = {
    ["agricultural-cell"] = true,
    ["asteroid-chunk"] = true,
    ["map-entity"] = true,
    ["pollution"] = false,
}

---@param node Rates.Node
---@return boolean?
local function is_environment(node)
    return environment_node_types[node.type]
end

---@param a { node: Rates.Node, amount: number }
---@param b { node: Rates.Node, amount: number }
local function compare_nodes(a, b)
    local a_type = node_type(a.node)
    local b_type = node_type(b.node)
    if (a_type ~= b_type) then
        return a_type < b_type
    end

    return a.amount > b.amount
end

page.left_panel.define_content = function(data, page)
    local sheet = data.window.sheet_rates
    if (not sheet) then
        return {}
    end

    ---@type table<string, { node: Rates.Node, location: Rates.Data.LocationIndex, produced: number?, consumed: number?, exported: table<Rates.Data.LocationIndex, number>?, imported: table<Rates.Data.LocationIndex, number>? }>
    local amounts = {}
    for _, row in ipairs(sheet.configurations) do
        for _, amount in ipairs(row.amounts) do
            local node = amount.node
            local location = row.location
            if (amount.tag == "import") then
                location = amount.tag_extra --[[@as Rates.Data.LocationIndex]]
            end
            local node_id = location .. "/" .. api.node.get_id(node)
            local entry = amounts[node_id]
            if (not entry) then
                entry = { node = node, location = location }
                amounts[node_id] = entry
            end

            local total_amount = amount.amount * (row.count_effective or 0)
            if (amount.amount > 0) then
                entry.produced = (entry.produced or 0) + total_amount
                if (amount.tag == "import") then
                    entry.imported = entry.imported or {}
                    local loc = row.location
                    entry.imported[loc] = (entry.imported[loc] or 0) + total_amount
                end
            elseif (amount.amount < 0) then
                entry.consumed = (entry.consumed or 0) - total_amount
                if (amount.tag == "export") then
                    entry.exported = entry.exported or {}
                    local loc = row.configuration.target
                    entry.exported[loc] = (entry.exported[loc] or 0) - total_amount
                end
            end
        end
    end

    for id, node in pairs(sheet.nodes) do
        local entry = amounts[id]
        if (entry) then
            if (node.any_produced) then
                local num = entry.produced or 0
                for _, any in pairs(node.any_produced) do
                    num = num + any
                end
                entry.produced = num
            elseif (node.has_positive) then
                entry.produced = entry.produced or 0
            end
            if (node.any_consumed) then
                local num = entry.consumed or 0
                for _, any in pairs(node.any_consumed) do
                    num = num + any
                end
                entry.consumed = num
            elseif (node.has_negative) then
                entry.consumed = entry.consumed or 0
            end
        end
    end

    local exports = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, other_location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
    local imports = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, other_location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
    local products = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
    local ingredients = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
    local intermediates = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
    local environment = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]

    ---@param id string
    ---@return boolean
    local function is_forced_balanced(id)
        local node = sheet.nodes[id]
        return node.min == 0 and node.max == 0
    end

    local has_forced_zero = {} ---@type table<Rates.Data.LocationIndex, true>
    for _, amount in pairs(amounts) do
        local id = amount.location .. "/" .. api.node.get_id(amount.node)
        ---@type Rates.Gui.Component.NodeStatus
        local status = {}
        local node = amount.node
        if (node.type == "item") then
            if (node.item.fuel_value > 0) then
                status.fuel = sheet_manipulation.has_item_fuel(data.sheet, node.item.name, node.quality.name,
                    amount.location)
            end
            if (node.item.get_spoil_ticks(node.quality) > 0) then
                status.spoil = sheet_manipulation.has_item_spoilage(data.sheet, node.item.name, node.quality.name,
                    amount.location)
            end
        elseif (node.type == "fluid") then
            if (node.fluid.fuel_value > 0) then
                status.fuel = sheet_manipulation.has_fluid_fuel(data.sheet, node.fluid.name, node.temperature,
                    amount.location)
            end
        end
        if (amount.node.type == "any" and is_forced_balanced(id)) then
            -- don't show balanced any-nodes
        else
            local exported, imported = amount.exported, amount.imported
            if (exported) then
                for loc, export in pairs(exported) do
                    exports[#exports + 1] = {
                        node = amount.node,
                        location = amount.location,
                        other_location = loc,
                        amount = export,
                        status = {},
                    }
                end
            end
            if (imported) then
                for loc, import in pairs(imported) do
                    imports[#imports + 1] = {
                        node = amount.node,
                        location = amount.location,
                        other_location = loc,
                        amount = import,
                        status = {},
                    }
                end
            end
            local produced, consumed = amount.produced, amount.consumed
            local env = is_environment(amount.node)
            if (env ~= nil) then
                if (produced and consumed) then
                    status.link = is_forced_balanced(id)
                end
                if (produced) then
                    environment[#environment + 1] = {
                        node = amount.node,
                        location = amount.location,
                        amount = produced * (env and -1 or 1),
                        status = status,
                    }
                end
                if (consumed) then
                    environment[#environment + 1] = {
                        node = amount.node,
                        location = amount.location,
                        amount = consumed * (env and 1 or -1),
                        status = status,
                    }
                end
            elseif (produced and not consumed) then
                products[#products + 1] = {
                    node = amount.node,
                    location = amount.location,
                    amount = produced,
                    status = status
                }
            elseif (consumed and not produced) then
                ingredients[#ingredients + 1] = {
                    node = amount.node,
                    location = amount.location,
                    amount = consumed,
                    status = status
                }
            elseif (produced and consumed) then
                local inout = math.min(produced, consumed)
                if (is_forced_balanced(id)) then
                    status.link = true
                    intermediates[#intermediates + 1] = {
                        node = amount.node,
                        location = amount.location,
                        amount = math.max(produced, consumed),
                        status = status,
                    }
                    if (inout == 0) then
                        has_forced_zero[amount.location] = true
                    end
                elseif (is_balanced(produced, consumed)) then
                    status.link = false
                    intermediates[#intermediates + 1] = {
                        node = amount.node,
                        location = amount.location,
                        amount = inout,
                        status = status,
                    }
                else
                    status.link = false
                    local net = produced - consumed
                    if (net > 0) then
                        products[#products + 1] = {
                            node = amount.node,
                            location = amount.location,
                            amount = net,
                            status = status,
                        }
                    elseif (net < 0) then
                        ingredients[#ingredients + 1] = {
                            node = amount.node,
                            location = amount.location,
                            amount = -net,
                            status = status,
                        }
                    end
                    if (inout > 0) then
                        intermediates[#intermediates + 1] = {
                            node = amount.node,
                            location = amount.location,
                            amount = inout,
                            status = status,
                        }
                    end
                end
            end
        end
    end

    table.sort(exports, compare_nodes)
    table.sort(imports, compare_nodes)
    table.sort(products, compare_nodes)
    table.sort(ingredients, compare_nodes)
    table.sort(intermediates, compare_nodes)
    table.sort(environment, compare_nodes)

    ---@type GuiElemDef[]
    local children = {}

    for location_index = 1, #sheet.data.locations do
        if (#sheet.data.locations > 1) then
            local location = data.sheet.locations[location_index]
            local gui_location = component_location.gui_location(location)
            local gui = api.gui.gui_button(gui_location)
            local district_name = gui_location.name
            local district_icon = gui.sprite

            ---@type GuiElemDef[]
            local flow = {}

            if (district_icon) then
                flow[#flow + 1] = {
                    args = {
                        type = "sprite",
                        sprite = district_icon,
                    },
                    style_mods = {
                        size = 24,
                        stretch_image_to_widget_size = true,
                    },
                }
            end

            flow[#flow + 1] = {
                args = {
                    type = "label",
                    caption = district_name,
                    style = "subheader_caption_label",
                },
            }

            children[#children + 1] = {
                args = {
                    type = "flow",
                    direction = "horizontal",
                },
                style_mods = {
                    vertically_stretchable = false,
                },
                children = flow,
            }
        end

        local local_exports = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
        local local_imports = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
        local local_products = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
        local local_ingredients = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
        local local_intermediates = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]
        local local_environment = {} ---@type { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number, status: Rates.Gui.Component.NodeStatus }[]

        for _, amount in ipairs(exports) do
            if (amount.location == location_index) then
                local_exports[#local_exports + 1] = {
                    node = amount.node,
                    location = amount.other_location,
                    amount = amount.amount,
                    status = {},
                }
            end
        end
        for _, amount in ipairs(imports) do
            if (amount.location == location_index) then
                local_imports[#local_imports + 1] = {
                    node = amount.node,
                    location = amount.other_location,
                    amount = amount.amount,
                    status = {},
                }
            end
        end
        for _, amount in ipairs(products) do
            if (amount.location == location_index) then
                local_products[#local_products + 1] = amount
            end
        end
        for _, amount in ipairs(ingredients) do
            if (amount.location == location_index) then
                local_ingredients[#local_ingredients + 1] = amount
            end
        end
        for _, amount in ipairs(intermediates) do
            if (amount.location == location_index) then
                local_intermediates[#local_intermediates + 1] = amount
            end
        end
        for _, amount in ipairs(environment) do
            if (amount.location == location_index) then
                local_environment[#local_environment + 1] = amount
            end
        end

        if (#local_exports > 0) then
            ---@type LocalisedString
            local caption = { "gui.sw-rates-calc-extreme-exports-n", #local_exports }
            children[#children + 1] = component_node.define_list(data, local_exports, location_index,
                caption, true, { data = data.page.state.expanders, index = location_index .. "/exports" })
        end
        if (#local_imports > 0) then
            ---@type LocalisedString
            local caption = { "gui.sw-rates-calc-extreme-imports-n", #local_imports }
            children[#children + 1] = component_node.define_list(data, local_imports, location_index,
                caption, true, { data = data.page.state.expanders, index = location_index .. "/imports" })
        end
        if (#local_products > 0) then
            ---@type LocalisedString
            local caption = { "gui.sw-rates-calc-extreme-products-n", #local_products }
            children[#children + 1] = component_node.define_list(data, local_products, location_index,
                caption, true, { data = data.page.state.expanders, index = location_index .. "/products" })
        end
        if (#local_ingredients > 0) then
            ---@type LocalisedString
            local caption = { "gui.sw-rates-calc-extreme-ingredients-n", #local_ingredients }
            children[#children + 1] = component_node.define_list(data, local_ingredients, location_index,
                caption, true, { data = data.page.state.expanders, index = location_index .. "/ingredients" })
        end
        if (#local_intermediates > 0) then
            ---@type LocalisedString
            local caption = { "gui.sw-rates-calc-extreme-intermediates-n", #local_intermediates }
            children[#children + 1] = component_node.define_list(data, local_intermediates, location_index,
                caption, has_forced_zero[location_index] == true,
                { data = data.page.state.expanders, index = location_index .. "/intermediates" })
        end
        if (#local_environment > 0) then
            ---@type LocalisedString
            local caption = { "gui.sw-rates-calc-extreme-environment-n", #local_environment }
            children[#children + 1] = component_node.define_list(data, local_environment, location_index,
                caption, false, { data = data.page.state.expanders, index = location_index .. "/environment" })
        end
    end

    return children
end

page.right_panel.define_toolbar = function(data, page)
    ---@type GuiElemDef[]
    return {
        { args = { type = "label", style = "subheader_caption_label", caption = { "gui.sw-rates-calc-extreme-recipes" } } },
        {
            args = { type = "empty-widget" },
            style_mods = { horizontally_stretchable = true },
        },
        {
            args = {
                type = "sprite-button",
                sprite = "utility/side_menu_blueprint_library_icon",
                mouse_button_filter = { "left" },
                style = "tool_button_blue",
                tooltip = presenter.create_action_tooltip(nil, {
                    left = { "gui.sw-rates-calc-extreme-selection-tooltip" },
                })
            },
            style_mods = {
                padding = -4
            },
            _click = handlers.on_click_selection
        },
    }
end

---@class (exact) Rates.Gui.EntityGroup
---@field id string
---@field configurations Rates.Sheet.Configuration[]
---@field count_max number
---@field count_effective? number
---@field recipe? Rates.Gui.NodeDescription
---@field entity? Rates.Gui.NodeDescription
---@field fuel? Rates.Gui.NodeDescription
---@field modules? Rates.Configuration.Module[]
---@field beacons? Rates.Configuration.Beacon[]

---@class (exact) Rates.Gui.EntityDistrict
---@field location Rates.Data.LocationIndex
---@field configurations Rates.Sheet.Configuration[]

---@param configurations Rates.Sheet.Configuration[]
---@return Rates.Gui.EntityGroup
local function create_group(configurations)
    local conf = configurations[1].configuration
    local group = api.configuration.gui_grouping(conf)
    local recipe = api.configuration.gui_recipe(conf) ---@type Rates.Gui.NodeDescription?
    local entity = api.configuration.gui_entity(conf) ---@type Rates.Gui.NodeDescription?
    local fuel = api.configuration.gui_fuel(conf) ---@type Rates.Gui.NodeDescription?
    local modules = (conf.module_effects and conf.module_effects.modules) or {} ---@type Rates.Configuration.Module[]?
    local beacons = (conf.module_effects and conf.module_effects.beacons) or {} ---@type Rates.Configuration.Beacon[]?
    local local_effect = (conf.module_effects and conf.module_effects.local_effect) or {}

    if (#configurations > 1) then
        local id

        id = serpent.line(recipe)
        for i = 2, #configurations do
            local conf = configurations[i].configuration
            local other_id = serpent.line(api.configuration.gui_recipe(conf))
            if (id ~= other_id) then
                recipe = nil
                break
            end
        end

        id = serpent.line(entity)
        for i = 2, #configurations do
            local conf = configurations[i].configuration
            local other_id = serpent.line(api.configuration.gui_entity(conf))
            if (id ~= other_id) then
                entity = nil
                break
            end
        end

        id = serpent.line(fuel)
        for i = 2, #configurations do
            local conf = configurations[i].configuration
            local other_id = serpent.line(api.configuration.gui_fuel(conf))
            if (id ~= other_id) then
                fuel = nil
                break
            end
        end

        id = serpent.line(modules)
        for i = 2, #configurations do
            local conf = configurations[i].configuration
            local other_id = serpent.line((conf.module_effects and conf.module_effects.modules) or {})
            if (id ~= other_id) then
                modules = nil
                break
            end
        end

        id = serpent.line(beacons)
        for i = 2, #configurations do
            local conf = configurations[i].configuration
            local other_id = serpent.line((conf.module_effects and conf.module_effects.beacons) or {})
            if (id ~= other_id) then
                beacons = nil
                break
            end
        end
    end

    recipe = group.recipe or recipe
    entity = group.entity or entity

    local count_max = 0
    local added_groups = {} ---@type table<string, true>
    local count_effective = 0
    for _, conf in ipairs(configurations) do
        count_max = count_max + conf.count_max
        if (conf.count_groups) then
            for name, count in pairs(conf.count_groups) do
                if (not added_groups[name]) then
                    added_groups[name] = true
                    count_max = count_max + count
                end
            end
        end
        count_effective = count_effective + (conf.count_effective or 0)
    end

    ---@type Rates.Gui.EntityGroup
    return {
        id = group.id,
        configurations = configurations,
        count_max = count_max,
        count_effective = count_effective,
        recipe = recipe,
        entity = entity,
        fuel = fuel,
        modules = modules,
        beacons = beacons
    }
end

---@param configurations Rates.Sheet.Configuration[]
---@return Rates.Gui.EntityGroup[]
local function group_configurations(configurations)
    ---@type table<string, Rates.Sheet.Configuration[]>
    local groups = {}
    ---@type table<string, number>
    local counts = {}
    ---@type {id: string, configurations: Rates.Sheet.Configuration[]}[]
    local groups_table = {}

    for _, row in ipairs(configurations) do
        local conf = row.configuration
        local id = api.configuration.gui_grouping(conf).id
        local group = groups[id]
        if (not group) then
            group = {}
            groups[id] = group
            groups_table[#groups_table + 1] = { id = id, configurations = group }
        end
        counts[id] = (counts[id] or 0) + row.count_max
        group[#group + 1] = row
    end

    table.sort(groups_table, function(a, b)
        return a.id < b.id
    end)

    ---@type Rates.Gui.EntityGroup[]
    local result = {}
    for _, group in ipairs(groups_table) do
        result[#result + 1] = create_group(group.configurations)
    end

    return result
end
---@param configurations Rates.Sheet.Configuration[]
---@return Rates.Gui.EntityDistrict[]
local function group_by_location(configurations)
    local mapping = {} ---@type table<string, Rates.Gui.EntityDistrict>
    for _, configuration in ipairs(configurations) do
        local key = configuration.location
        local entry = mapping[key]
        if (not entry) then
            entry = {
                location = configuration.location,
                configurations = {},
            }
            mapping[key] = entry
        end

        entry.configurations[#entry.configurations + 1] = configuration
    end

    ---@type Rates.Gui.EntityDistrict[]
    local result = {}

    for _, district in pairs(mapping) do
        result[#result + 1] = district
    end

    table.sort(result, function(a, b)
        return a.location < b.location
    end)

    return result
end

---@param amount number
---@param amount_max number
---@return boolean
local function is_at_limit(amount, amount_max)
    return amount_max - amount < 1e-8
end

page.right_panel.define_content = function(data, page, state)
    ---@type GuiElemDef[]
    local result = {}

    local rates = data.window.sheet_rates
    if (not rates) then
        return result
    end

    local districts = group_by_location(rates.configurations)
    for _, district in ipairs(districts) do
        if (#districts > 1) then
            local location = data.sheet.locations[district.location]
            local gui_location = component_location.gui_location(location)
            local gui = api.gui.gui_button(gui_location)
            local district_name = gui_location.name
            local district_icon = gui.sprite

            ---@type GuiElemDef[]
            local children = {}

            if (district_icon) then
                children[#children + 1] = {
                    args = {
                        type = "sprite",
                        sprite = district_icon,
                    },
                    style_mods = {
                        size = 24,
                        stretch_image_to_widget_size = true,
                    },
                }
            end

            children[#children + 1] = {
                args = {
                    type = "label",
                    caption = district_name,
                    style = "subheader_caption_label",
                },
            }

            result[#result + 1] = {
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
        local groups = group_configurations(district.configurations)
        for _, group in ipairs(groups) do
            ---@type GuiElemDef[]
            local container
            if (#group.configurations == 1) then
                container = result
            else
                ---@type Color.0
                local font_color = { r = 1, g = 1, b = 1 }
                if (is_at_limit(group.count_effective or 0, group.count_max)) then
                    font_color = { r = 1, g = 0.5, b = 0 }
                end

                local header = component_configuration.define_configuration_group_row(group.entity, group.recipe,
                    group.count_max, font_color)

                local amount = group.count_effective or 0
                ---@type GuiElemDef
                local effective_count = {
                    args = {
                        type = "label",
                        caption = string.format("%.2f", amount) .. " ×",
                        tooltip = amount,
                    },
                    style_mods = {
                        width = 70,
                        margin = { 6, 0, 6, 0 },
                        horizontal_align = "right",
                        vertical_align = "center",
                        font = "item-count",
                    },
                }

                table.insert(header.children, 1, effective_count)

                container = {}
                local expander_frame = expander.define(header, {
                    args = {
                        type = "flow",
                        direction = "vertical",
                    },
                    children = container,
                }, false, { data = state.expanders, index = group.id })
                result[#result + 1] = expander_frame
            end

            for i, row in pairs(group.configurations) do
                local conf = row.configuration
                local count_max = row.count_max
                if (row.count_groups) then
                    for _, count_in_group in pairs(row.count_groups) do
                        count_max = count_max + count_in_group
                    end
                end

                ---@type Color.0
                local font_color = { r = 1, g = 1, b = 1 }
                if (row.count_infinite == true) then
                    font_color = { r = 0.5, g = 0.5, b = 0.5 }
                elseif (is_at_limit(row.count_effective or 0, count_max)) then
                    font_color = { r = 1, g = 0.5, b = 0 }
                end

                local ui = component_configuration.define_configuration_row(conf, row.location, row.force,
                    count_max ~= math.huge and count_max or nil, font_color, row.annotations)

                local gui_entity = api.configuration.gui_entity(conf)
                local amount = row.count_effective or 0
                local rate = component_rate.define(data, gui_entity.number_format, amount)
                rate.style_mods = {
                    width = 70,
                    margin = { 6, 0, 6, 0 },
                    horizontal_align = "right",
                    vertical_align = "center",
                }

                table.insert(ui.children, 1, {
                    args = { type = "empty-widget" },
                    style_mods = { width = 20 },
                })
                table.insert(ui.children, 2, rate)

                if (#group.configurations > 1) then
                    ---@type GuiElemDef
                    local line = {
                        args = {
                            type = "line",
                            direction = "vertical",
                            style = "expanded_line",
                        },
                        style_mods = {
                            width = 8,
                            margin = { 0, -21, 0, 9 },
                            padding = { -10, 0, -10, 0 },
                        },
                    }
                    if (i == 1) then
                        line.style_mods.padding[1] = -18
                    end
                    if (i == #group.configurations) then
                        line.args.style = "expanded_line_last"
                        line.style_mods.padding[3] = 0
                    end
                    table.insert(ui.children, 1, line)
                end

                container[#container + 1] = ui
            end
        end
    end

    return result
end

page.right_panel.update_panel = function(element, data, changed)
    if (changed.selected_sheet or changed.configurations) then
        return false
    end

    if (changed.metadata and table_size(changed) == 1) then
        -- just a rename triggered by itself, everything is already up-to-date
        return true
    end

    return false
end

---@param event EventData.on_gui_click
function handlers.on_click_selection(event)
    local element = event.element
    local window = gui_util.find_top(element)
    presenter.open_page(window, { type = "selection" })
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "rates")
