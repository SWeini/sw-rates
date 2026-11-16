local styles = data.raw["gui-style"].default

styles["tool_button_simple"] = {
    type = "button_style",
    parent = "control_settings_section_button",
    default_graphical_set = {},
}

styles["slot_button_simple"] = {
    type = "button_style",
    parent = "slot_button",
    width = 32,
    height = 32,
    default_graphical_set = {},
}

styles["expand_collapse_button"] = {
    type = "button_style",
    parent = "control_settings_section_button",
    default_graphical_set = {},
    minimal_width = 20,
    natural_height = 20,
    height = 20,
}

styles["expanded_line"] = {
    type = "line_style",
    parent = "line",
    border = {
        border_width = 16,
        vertical_line = { position = { 448, 604 }, size = { 8, 1 }, tint = { 225, 225, 225 } },
    }
}

styles["expanded_line_last"] = {
    type = "line_style",
    parent = "expanded_line",
    border = {
        border_width = 16,
        vertical_line = { position = { 448, 604 }, size = { 8, 1 }, tint = { 225, 225, 225 } },
        bottom_end = { position = { 448, 611 }, size = { 8, 8 }, tint = { 225, 225, 225 } }
    }
}
