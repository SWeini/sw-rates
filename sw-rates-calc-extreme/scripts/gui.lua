local flib_gui = require("__flib__.gui")
local flib_format = require("__flib__.format")
local flib_math = require("__flib__.math")
local api = require("__sw-rates-lib__.api-usage")
local sheet = require("sheet")

local gui = {
    events = {}
}

local main_window_name = "sw-rates-calc-extreme_wnd_main"

---@class PerPlayerStorage
---@field gui? GuiElements
---@field is_pinned? true
---@field sheet? Rates.Sheet
---@field removed_constraints? table<string, true>

---@class GuiElements
---@field wnd_main LuaGuiElement
---@field button_pin LuaGuiElement
---@field button_close LuaGuiElement
---@field table_total LuaGuiElement
---@field table_buildings LuaGuiElement

---@param player LuaPlayer
---@return PerPlayerStorage
function gui.get_storage(player)
    if (not storage.players) then
        storage.players = {} --[[@as table<integer, PerPlayerStorage>]]
    end

    if (not storage.players[player.index]) then
        storage.players[player.index] = {}
    end

    return storage.players[player.index]
end

---@param player LuaPlayer
local function close_main_window(player)
    local window = player.gui.screen[main_window_name]
    if (window) then
        window.destroy()
    end

    gui.get_storage(player).gui = nil
end

---@param player LuaPlayer
function gui.force_close(player)
    close_main_window(player)
end

---@param e EventData.on_gui_closed
local function on_window_closed(e)
    local player = game.get_player(e.player_index) ---@cast player -nil
    local storage = gui.get_storage(player)
    if (storage.is_pinned) then
        return
    end

    close_main_window(player)
end

---@param e EventData.on_gui_click
local function on_pin_button_click(e)
    local player = game.get_player(e.player_index) ---@cast player -nil
    local storage = gui.get_storage(player)
    if (not storage.gui or not storage.gui.button_close) then
        return
    end

    local is_pinned = not storage.is_pinned
    storage.is_pinned = is_pinned or nil
    e.element.toggled = is_pinned
    if (is_pinned) then
        player.opened = nil
        storage.gui.button_close.tooltip = { "gui.close" }
    else
        player.opened = storage.gui.wnd_main
        storage.gui.button_close.tooltip = { "gui.close-instruction" }
    end
end

---@param e EventData.on_gui_click
local function on_close_button_click(e)
    local player = game.get_player(e.player_index) ---@cast player -nil
    close_main_window(player)
end

---@param e EventData.on_gui_click
local function on_constraint_button_click(e)
    local player = game.get_player(e.player_index) ---@cast player -nil
    local storage = gui.get_storage(player)
    local sheet_data = storage.sheet
    local node_id = e.element.tags.node_id
    if (not sheet_data or not node_id) then
        return
    end

    storage.removed_constraints[node_id] = true
    sheet_data.constraints[node_id] = nil
    sheet.solve_sheet(sheet_data)
    gui.add_table(storage.gui, sheet_data, player)
end

---@param player LuaPlayer
---@return number
local function get_max_height(player)
    return player.display_resolution.height / player.display_scale * 0.8
end

---@param player LuaPlayer
local function resize_main_window(player)
    local storage = gui.get_storage(player)
    if (storage.gui) then
        local wnd_main = storage.gui.wnd_main
        if (wnd_main) then
            wnd_main.style.maximal_height = get_max_height(player)
        end
    end
end

---@param e EventData.on_player_display_resolution_changed
function gui.events.on_player_display_resolution_changed(e)
    resize_main_window(game.get_player(e.player_index) --[[@as LuaPlayer]])
end

---@param e EventData.on_player_display_scale_changed
function gui.events.on_player_display_scale_changed(e)
    resize_main_window(game.get_player(e.player_index) --[[@as LuaPlayer]])
end

flib_gui.add_handlers({
    on_window_closed = on_window_closed,
    on_pin_button_click = on_pin_button_click,
    on_close_button_click = on_close_button_click,
    on_constraint_button_click = on_constraint_button_click
})

--- @param name string
--- @param sprite SpritePath
--- @param tooltip LocalisedString
--- @param handler flib.GuiElemHandler
--- @return flib.GuiElemDef
local function frame_action_button(name, sprite, tooltip, handler)
    return {
        type = "sprite-button",
        name = name,
        style = "frame_action_button",
        sprite = sprite,
        tooltip = tooltip,
        mouse_button_filter = { "left" },
        handler = { [defines.events.on_gui_click] = handler },
    }
end

---@return flib.GuiElemDef
local function build_pane_total()
    ---@type flib.GuiElemDef
    return {
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical",
        {
            type = "frame",
            style = "subheader_frame",
            {
                type = "label",
                style = "subheader_caption_label",
                caption = { "gui.sw-rates-calc-extreme-pane-total" }
            },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            -- toolbar buttons for pane_total
            -- {
            --     type = "sprite-button",
            --     name = "show_hide_total",
            --     style = "flib_selected_frame_action_button",
            --     sprite = "virtual-signal/up-arrow",
            --     tooltip = "Show/hide total production"
            -- }
        },
        {
            type = "scroll-pane",
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto-and-reserve-space",
            style = "flib_naked_scroll_pane",
            style_mods = {
                top_padding = 8,
                bottom_padding = 8
            },
            {
                type = "table",
                name = "table_total",
                column_count = 1,
                style_mods = {
                    minimal_width = 300
                },
                {
                }
            }
        }
    }
end

---@return flib.GuiElemDef
local function build_pane_buildings()
    ---@type flib.GuiElemDef
    return {
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical",
        {
            type = "frame",
            style = "subheader_frame",
            {
                type = "label",
                style = "subheader_caption_label",
                caption = { "gui.sw-rates-calc-extreme-pane-buildings" }
            },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            -- toolbar buttons for pane_buildings
            -- frame_action_button("search_button", "utility/search",
            --     { "gui.search-with-focus", "__CONTROL__search-focus__" },
            --     on_search_button_click),
            -- {
            --     type = "sprite-button",
            --     sprite = "virtual-signal/signal-ghost",
            --     style = "flib_selected_frame_action_button"
            -- },
            -- {
            --     type = "sprite-button",
            --     sprite = "virtual-signal/signal-white",
            --     style = "frame_action_button"
            -- },
        },
        {
            type = "scroll-pane",
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto-and-reserve-space",
            style = "flib_naked_scroll_pane",
            style_mods = {
                top_padding = 8,
                bottom_padding = 8
            },
            {
                type = "table",
                name = "table_buildings",
                column_count = 4,
                style_mods = {
                    minimal_width = 300
                },
                {
                }
            }
        }
    }
end

---@param player LuaPlayer
---@return GuiElements
function gui.build(player)
    local storage = gui.get_storage(player)
    if (storage.gui) then
        storage.gui.table_total.clear()
        storage.gui.table_buildings.clear()
        return storage.gui
    end

    ---@type GuiElements
    local named_gui_elements = flib_gui.add(player.gui.screen, {
        type = "frame",
        name = main_window_name,
        handler = { [defines.events.on_gui_closed] = on_window_closed },
        style_mods = {
            maximal_height = get_max_height(player)
        },
        direction = "vertical",
        {
            type = "flow",
            style = "flib_titlebar_flow",

            drag_target = main_window_name,
            {
                type = "label",
                style = "flib_frame_title",
                caption = { "gui.sw-rates-calc-extreme-title" },
                ignored_by_interaction = true
            },
            { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
            frame_action_button("button_pin", "flib_pin_white", { "gui.flib-keep-open" }, on_pin_button_click),
            frame_action_button("button_close", "utility/close", { "gui.close-instruction" }, on_close_button_click)
        },
        {
            type = "flow",
            style = "inset_frame_container_horizontal_flow",
            direction = "horizontal",
            build_pane_total(),
            build_pane_buildings(),
        }
    })

    named_gui_elements.table_buildings.style.column_alignments[1] = "right"

    named_gui_elements.wnd_main = named_gui_elements[main_window_name]
    named_gui_elements[main_window_name] = nil

    named_gui_elements.wnd_main.auto_center = true

    return named_gui_elements
end

---@param player LuaPlayer
---@param ui GuiElements
function gui.show(player, ui)
    local storage = gui.get_storage(player)
    storage.gui = ui
    if (storage.is_pinned) then
        ui.button_pin.toggled = true
        ui.button_close.tooltip = { "gui.close" }
    else
        player.opened = ui.wnd_main
    end
    ui.wnd_main.bring_to_front()
end

---@param text LocalisedString
---@return flib.GuiElemDef
local function create_count_label(text)
    return {
        type = "label",
        caption = text,
        ignored_by_interaction = true,
        style_mods = {
            width = 36,
            height = 36,
            left_margin = -35,
            right_margin = -1,
            bottom_margin = -4,
            font = "item-count",
            horizontal_align = "right",
            vertical_align = "bottom",
            single_line = true
        },
    }
end

---@param text LocalisedString
---@return flib.GuiElemDef
local function create_count_qualifier(text)
    return {
        type = "label",
        caption = text,
        ignored_by_interaction = true,
        style_mods = {
            width = 36,
            height = 36,
            left_margin = -35,
            right_margin = -1,
            font = "default-tiny-bold",
            horizontal_align = "right",
            vertical_align = "top",
            single_line = true
        },
    }
end

---@param button Rates.Gui.ButtonDescription
---@return flib.GuiElemDef
local function create_node_icon_direct(button)
    ---@type flib.GuiElemDef
    local flow = {
        type = "flow",
        style = "packed_horizontal_flow"
    }

    flow.elem_tooltip = button.elem_tooltip
    flow.tooltip = button.tooltip

    if (button.sprite) then
        flow[#flow + 1] = {
            type = "sprite-button",
            style = "transparent_slot",
            ignored_by_interaction = true,
            sprite = button.sprite,
            quality = button.quality and button.quality.name,
        }
    elseif (button.qualifier) then
        flow[#flow + 1] = {
            type = "sprite-button",
            style = "transparent_slot",
            ignored_by_interaction = true,
            sprite = "virtual-signal/signal-question-mark"
        }
    end

    if (button.qualifier) then
        flow[#flow + 1] = create_count_qualifier(button.qualifier)
    end

    return flow
end

---@param ui Rates.Gui.NodeDescription
---@param count LocalisedString?
---@return flib.GuiElemDef
local function create_node_icon(ui, count)
    ---@type flib.GuiElemDef
    local flow = {
        type = "flow",
        style = "packed_horizontal_flow"
    }

    local button = api.gui.gui_button(ui)
    flow.elem_tooltip = button.elem_tooltip
    flow.tooltip = button.tooltip

    if (button.sprite) then
        flow[#flow + 1] = {
            type = "sprite-button",
            style = "transparent_slot",
            ignored_by_interaction = true,
            sprite = button.sprite,
            quality = button.quality and button.quality.name,
        }
    elseif (count or button.qualifier) then
        flow[#flow + 1] = {
            type = "sprite-button",
            style = "transparent_slot",
            ignored_by_interaction = true,
            sprite = "virtual-signal/signal-question-mark"
        }
    end

    if (count) then
        flow[#flow + 1] = create_count_label(count)
    end

    if (button.qualifier) then
        flow[#flow + 1] = create_count_qualifier(button.qualifier)
    end

    return flow
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

---@param a { node: Rates.Node, produced: number, consumed: number }
---@param b { node: Rates.Node, produced: number, consumed: number }
local function compare_nodes(a, b)
    local a_type = node_type(a.node)
    local b_type = node_type(b.node)
    if (a_type ~= b_type) then
        return a_type < b_type
    end

    return math.abs(a.produced + a.consumed) > math.abs(b.produced + b.consumed)
end

---@param row Rates.Row
---@return flib.GuiElemDef
local function cell_buildings_count(row)
    ---@type flib.GuiElemDef
    local result = {
        type = "label",
        caption = api.gui.format_number(row.count_effective) .. " × ",
        style_mods = {
            font = "item-count",
            horizontal_align = "right"
        }
    }

    if (math.abs((row.count_max - row.count_effective) / row.count_max) < 1e-10) then
        result.style_mods.font_color = { r = 1 }
    end

    return result
end

---@param row Rates.Row
---@return flib.GuiElemDef
local function cell_buildings_recipe(row)
    local ui = api.configuration.gui_recipe(row.configuration)
    return create_node_icon(ui)
end

---@param row Rates.Row
---@return flib.GuiElemDef
local function cell_buildings_entity(row)
    local ui = api.configuration.gui_entity(row.configuration)
    local flow = {
        type = "flow",
        style = "packed_horizontal_flow",
        create_node_icon(ui, tostring(row.count_max))
    }

    local conf = row.configuration ---@type Rates.Configuration
    if (conf.type == "meta") then
        conf = conf.children[1]
    end

    local module_effects = conf.module_effects
    if (module_effects) then
        for _, module in ipairs(module_effects.modules or {}) do
            flow[#flow + 1] = create_node_icon(api.node.gui_default(api.node.create.item(module.module, module.quality)))
            flow[#flow + 1] = create_count_label(tostring(module.count))
        end
        for _, beacon in ipairs(module_effects.beacons or {}) do
            if (not beacon.beacon.hidden) then
                flow[#flow + 1] = create_node_icon(api.node.gui_default(api.node.create.map_entity(beacon.beacon,
                    beacon.quality)))
                flow[#flow + 1] = create_count_label(tostring(beacon.count))
            end

            for _, module in ipairs(beacon.per_beacon_modules) do
                flow[#flow + 1] = create_node_icon(api.node.gui_default(api.node.create.item(module.module,
                    module.quality)))
                flow[#flow + 1] = create_count_label(tostring(module.count))
            end
        end
    end

    return flow
end

---@param row Rates.Row
---@return flib.GuiElemDef
local function cell_buildings_extra(row)
    return {
        type = "label",
        caption = ""
    }
end

---@param produced number
---@param consumed number
---@return boolean
local function is_balanced(produced, consumed)
    local delta = math.abs(produced + consumed)
    local scale = math.max(1, math.max(produced, -consumed))
    return delta < 1e-10 * scale
end

---@param ui GuiElements
---@param sheet_data Rates.Sheet
---@param player LuaPlayer
function gui.add_table(ui, sheet_data, player)
    local total = sheet.get_total_production(sheet_data, sheet_data.block.location, player.force --[[@as LuaForce]])
    gui.get_storage(player).sheet = sheet_data

    ui.table_buildings.clear()
    ui.table_total.clear()

    for i, row in ipairs(sheet_data.block.rows) do
        flib_gui.add(ui.table_buildings, {
            cell_buildings_count(row),
            cell_buildings_recipe(row),
            cell_buildings_entity(row),
            cell_buildings_extra(row)
        })
    end

    local total_i = {} ---@type { node: Rates.Node, produced: number, consumed: number }[]
    for _, subtotal in pairs(total) do
        total_i[#total_i + 1] = subtotal
    end
    table.sort(total_i, compare_nodes)
    local total_in = {} ---@type flib.GuiElemDef[]
    local total_out = {} ---@type flib.GuiElemDef[]
    local zero = {} ---@type flib.GuiElemDef[]
    for _, subtotal in ipairs(total_i) do
        local ui = api.node.gui_default(subtotal.node)
        if (not is_balanced(subtotal.produced, subtotal.consumed)) then
            local amount_net = subtotal.produced + subtotal.consumed
            local data = api.gui.gui_button_and_text(ui, math.abs(amount_net))
            local icon = create_node_icon_direct(data.button)
            local target ---@type flib.GuiElemDef[]
            if (amount_net > 0) then
                target = total_out
            else
                target = total_in
            end

            ---@type flib.GuiElemDef
            local label = {
                type = "label",
                caption = data.text,
                style_mods = {
                    vertical_align = "center",
                    height = 32,
                    left_margin = 8
                }
            }

            target[#target + 1] = {
                type = "flow",
                style = "packed_horizontal_flow",
                icon,
                label
            }
        else
            local icon = create_node_icon(ui)
            local button = icon[1] ---@type flib.GuiElemDef
            local node_id = api.node.get_id(subtotal.node)
            if (sheet_data.constraints[node_id]) then
                button.style = "flib_slot_button_red"
                button.ignored_by_interaction = false
                button.handler = { [defines.events.on_gui_click] = on_constraint_button_click }
                button.tags = { node_id = node_id }
            else
                button.style = "slot_button"
            end
            zero[#zero + 1] = icon
        end
    end

    local needs_line = false
    local function add_line()
        if (needs_line) then
            flib_gui.add(ui.table_total, {
                type = "line",
                direction = "horizontal",
                style_mods = {
                    top_margin = 4,
                    bottom_margin = 4
                }
            })
        end

        needs_line = true
    end

    if (#total_out > 0) then
        add_line()
        flib_gui.add(ui.table_total, {
            type = "label",
            caption = { "gui.sw-rates-calc-extreme-products" },
            style = "caption_label"
        })
        for _, icon in ipairs(total_out) do
            flib_gui.add(ui.table_total, icon)
        end
    end

    if (#total_in > 0) then
        add_line()
        flib_gui.add(ui.table_total, {
            type = "label",
            caption = { "gui.sw-rates-calc-extreme-ingredients" },
            style = "caption_label"
        })
        for _, icon in ipairs(total_in) do
            flib_gui.add(ui.table_total, icon)
        end
    end

    if (#zero > 0) then
        add_line()
        flib_gui.add(ui.table_total, {
            type = "label",
            caption = { "gui.sw-rates-calc-extreme-constraints" },
            style = "caption_label"
        })
        ---@type flib.GuiElemDef
        local row
        for i, icon in ipairs(zero) do
            if ((i - 1) % 8 == 0) then
                if (row) then
                    flib_gui.add(ui.table_total, row)
                end
                row = {
                    type = "flow",
                    style = "packed_horizontal_flow"
                }
            end

            row[#row + 1] = icon
        end

        flib_gui.add(ui.table_total, row)
    end
end

return gui
