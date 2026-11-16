local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local configuration = require("__sw-rates-lib__.scripts.configuration-util")

do
    ---@class Rates.Gui.PageDescription.Selection : Rates.Gui.PageDescription.Base
    ---@field type "selection"
end

local page = { left_panel = {}, right_panel = {} } ---@type Rates.Gui.PagePresenter
presenter.pages["selection"] = page

local handlers = {}

page.left_panel.define_toolbar = function(data, page)
    ---@type GuiElemDef[]
    return {
        {
            args = {
                type = "label",
                caption = { "gui.sw-rates-calc-extreme-settings" },
                style = "subheader_caption_label",
            },
        },
        {
            args = { type = "empty-widget" },
            style_mods = { horizontally_stretchable = true },
        },
    }
end

page.left_panel.define_content = function(data, page, state)
    local selection = data.sheet.selection

    ---@type GuiElemDef[]
    local children = {}

    children[#children + 1] = {
        args = {
            type = "checkbox",
            caption = { "", { "gui.sw-rates-calc-extreme-selection-ghosts" }, " [img=info]" },
            state = selection.use_ghosts,
            tooltip = { "gui.sw-rates-calc-extreme-selection-ghosts-desc" },
        },
        _checked_state_changed = handlers.on_change_ghosts,
    }

    children[#children + 1] = {
        args = {
            type = "checkbox",
            caption = { "", { "gui.sw-rates-calc-extreme-selection-fuel" }, " [img=info]" },
            state = selection.use_fuel,
            tooltip = { "gui.sw-rates-calc-extreme-selection-fuel-desc" },
        },
        _checked_state_changed = handlers.on_change_fuel,
    }

    return children
end

page.right_panel.define_toolbar = function(data, page)
    ---@type GuiElemDef[]
    return {
        {
            args = {
                type = "label",
                caption = { "gui.sw-rates-calc-extreme-selection" },
                style = "subheader_caption_label",
            },
        },
        {
            args = { type = "empty-widget" },
            style_mods = { horizontally_stretchable = true },
        },
    }
end

---@param entity LuaEntityPrototype?
---@param quality LuaQualityPrototype?
---@return { sprite: string, name: LocalisedString }
local function get_entity_icon_and_name(entity, quality)
    if (entity and quality) then
        return {
            sprite = "[entity=" .. entity.name .. ",quality=" .. quality.name .. "]",
            name = entity.localised_name,
        }
    else
        return {
            sprite = "[item=deconstruction-planner]",
            name = "Removed entity",
        }
    end
end

---@param entity LuaEntityPrototype?
---@param quality LuaQualityPrototype?
---@param count integer
---@return GuiElemDef
local function define_entity_with_count(entity, quality, count)
    local entity_data = get_entity_icon_and_name(entity, quality)

    ---@type GuiElemDef
    return {
        args = {
            type = "flow",
            direction = "horizontal",
        },
        children = {
            {
                args = {
                    type = "label",
                    caption = count,
                },
                style_mods = {
                    width = 40,
                    horizontal_align = "right",
                },
            },
            {
                args = {
                    type = "label",
                    caption = { "", entity_data.sprite, " ", entity_data.name },
                },
            },
        },
    }
end

local default_entity_sort_order = 0
---@type table<string, number>
local entity_sort_order = {
    ["assembling-machine"] = 1,
    ["furnace"] = 1,
    ["inserter"] = 2,
    ["loader"] = 3,
    ["loader-1x1"] = 3,
}

---@param page Rates.Gui.PageDescription.SelectedEntity
page.right_panel.define_content = function(data, page)
    ---@type GuiElemDef[]
    local children = {}

    local selection = data.sheet.selection
    local use_ghosts = selection.use_ghosts

    ---@type table<string, { entity: LuaEntityPrototype, quality: LuaQualityPrototype, count: integer }>
    local entities = {}
    local num_deleted_entities = 0
    for _, entity in pairs(selection.entities) do
        if (entity.entity.valid) then
            local data = configuration.get_useful_entity_data(entity.entity, use_ghosts)
            if (data) then
                local name = data.entity.name .. '/' .. data.quality.name
                local entry = entities[name]
                if (not entry) then
                    entry = { entity = data.entity, quality = data.quality, count = 0 }
                    entities[name] = entry
                end
                entry.count = entry.count + entity.count
            end
        else
            num_deleted_entities = num_deleted_entities + entity.count
        end
    end

    if (num_deleted_entities > 0) then
        children[#children + 1] = define_entity_with_count(nil, nil, num_deleted_entities)
    end

    ---@type { entity: LuaEntityPrototype, quality: LuaQualityPrototype, count: integer }[]
    local entities_list = {}
    for _, entity_data in pairs(entities) do
        entities_list[#entities_list + 1] = entity_data
    end

    table.sort(entities_list, function(a, b)
        local a_order = entity_sort_order[a.entity.type] or default_entity_sort_order
        local b_order = entity_sort_order[b.entity.type] or default_entity_sort_order
        if (a_order ~= b_order) then
            return a_order < b_order
        elseif (a.count ~= b.count) then
            return a.count > b.count
        elseif (a.entity.name ~= b.entity.name) then
            return a.entity.name < b.entity.name
        else
            return a.quality.name < b.quality.name
        end
    end)

    for _, entity_data in ipairs(entities_list) do
        children[#children + 1] = define_entity_with_count(entity_data.entity, entity_data.quality, entity_data.count)
    end

    return children
end

---@param event EventData.on_gui_checked_state_changed
function handlers.on_change_ghosts(event)
    local element = event.element
    local window = gui_util.find_top(element)
    presenter.run_undo_action(window, function(context)
        local selection = context.sheet.selection
        selection.use_ghosts = element.state
        context.changed = { selection = true }
        context.description = "toggle ghost selection"
    end)
end

---@param event EventData.on_gui_checked_state_changed
function handlers.on_change_fuel(event)
    local element = event.element
    local window = gui_util.find_top(element)
    presenter.run_undo_action(window, function(context)
        local selection = context.sheet.selection
        selection.use_fuel = element.state
        context.changed = { selection = true }
        context.description = "toggle fuel selection"
    end)
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "selection")
