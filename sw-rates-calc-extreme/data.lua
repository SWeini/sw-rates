---@type string[]
local type_filters = {
    "accumulator",
    "agricultural-tower",
    "assembling-machine",
    "asteroid-collector",
    "boiler",
    "burner-generator",
    "electric-energy-interface",
    "furnace",
    "fusion-generator",
    "fusion-reactor",
    "generator",
    "heat-interface",
    "lab",
    "lightning-attractor",
    "mining-drill",
    "offshore-pump",
    "reactor",
    "rocket-silo",
    "simple-entity-with-owner",
    "simple-entity-with-force",
    "solar-panel",
    "thruster",
}

---@type data.SelectionToolPrototype
local tool = {
    type = "selection-tool",
    name = "sw-rates-calc-extreme-tool",
    select = {
        border_color = { b = 1 },
        cursor_box_type = "entity",
        mode = { "buildable-type", "friend", "entity-ghost" },
        entity_type_filters = type_filters
    },
    alt_select = {
        border_color = { g = 1 },
        cursor_box_type = "entity",
        mode = { "buildable-type", "friend", "entity-ghost" },
        entity_type_filters = type_filters
    },
    alt_reverse_select = {
        border_color = { r = 1 },
        cursor_box_type = "entity",
        mode = { "buildable-type", "friend", "entity-ghost" },
        entity_type_filters = type_filters
    },
    stack_size = 1,
    flags = { "only-in-cursor", "spawnable", "not-stackable" },
    hidden = true,
    icon = "__sw-rates-calc-extreme__/graphics/shortcut-x32-black.png",
    icon_size = 32
}

---@type data.ShortcutPrototype
local shortcut = {
    type = "shortcut",
    name = "sw-rates-calc-extreme-shortcut",
    action = "spawn-item",
    item_to_spawn = "sw-rates-calc-extreme-tool",
    icon = "__sw-rates-calc-extreme__/graphics/shortcut-x32-black.png",
    small_icon = "__sw-rates-calc-extreme__/graphics/shortcut-x24-black.png",
    icon_size = 32,
    small_icon_size = 24,
}

data:extend({ tool, shortcut })
