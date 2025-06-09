---@type string[]
local type_filters = {
    "fusion-generator",
    "fusion-reactor",
    "reactor",
}

---@type data.SelectionToolPrototype
local tool = {
    type = "selection-tool",
    name = "sw-rates-reactor-layout-tool",
    select = {
        border_color = { b = 1 },
        cursor_box_type = "entity",
        mode = { "buildable-type", "friend", "entity-ghost" },
        entity_type_filters = type_filters
    },
    alt_select = {
        border_color = { b = 1 },
        cursor_box_type = "entity",
        mode = { "buildable-type", "friend", "entity-ghost" },
        entity_type_filters = type_filters
    },
    stack_size = 1,
    flags = { "only-in-cursor", "spawnable", "not-stackable" },
    hidden = true,
    icon = "__sw-rates-reactor-layout__/graphics/shortcut-x32-black.png",
    icon_size = 32,
}

---@type data.ShortcutPrototype
local shortcut = {
    type = "shortcut",
    name = "sw-rates-reactor-layout-shortcut",
    action = "spawn-item",
    item_to_spawn = "sw-rates-reactor-layout-tool",
    icon = "__sw-rates-reactor-layout__/graphics/shortcut-x32-black.png",
    small_icon = "__sw-rates-reactor-layout__/graphics/shortcut-x24-black.png",
    icon_size = 32,
    small_icon_size = 24,
}

data:extend({ tool, shortcut })
