require("styles")

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
    "inserter",
    "loader",
    "loader-1x1"
}

---@type data.SelectionToolPrototype
local tool = {
    type = "selection-tool",
    name = "sw-rates-calc-extreme-tool",
    select = {
        border_color = { g = 1 },
        cursor_box_type = "entity",
        mode = { "buildable-type", "friend", "entity-ghost" },
        entity_type_filters = type_filters
    },
    alt_select = {
        border_color = { r = 0.75, g = 1 },
        cursor_box_type = "entity",
        mode = { "buildable-type", "friend", "entity-ghost" },
        entity_type_filters = type_filters
    },
    reverse_select = {
        border_color = { r = 1 },
        cursor_box_type = "entity",
        mode = { "buildable-type", "friend", "entity-ghost" },
        entity_type_filters = type_filters
    },
    alt_reverse_select = {
        border_color = { r = 1, g = 0.75 },
        cursor_box_type = "entity",
        mode = { "buildable-type", "friend", "entity-ghost" },
        entity_type_filters = type_filters
    },
    super_forced_select = {
        border_color = { r = 0.5, b = 0.5 },
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
    action = "lua",
    icon = "__sw-rates-calc-extreme__/graphics/shortcut-x32-black.png",
    small_icon = "__sw-rates-calc-extreme__/graphics/shortcut-x24-black.png",
    icon_size = 32,
    small_icon_size = 24,
}

---@type data.CustomInputPrototype
local custom_input = {
    type = "custom-input",
    name = "sw-rates-calc-extreme-custom-input",
    action = "lua",
    key_sequence = "ALT + X"
}

---@type data.FontPrototype
local qualifier_font =
{
    type = "font",
    name = "sw-rates-calc-extreme-qualifier-font",
    from = "default-semibold",
    size = 9,
    border = true,
    border_color = { 0, 0, 0, 127 },
}

data:extend({ tool, shortcut, custom_input, qualifier_font })
