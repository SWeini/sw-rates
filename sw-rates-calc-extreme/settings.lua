---@type data.BoolSettingPrototype
local remember_window_position = {
    type = "bool-setting",
    name = "sw-rates-calc-extreme-remember-window-position",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a"
}

data:extend({ remember_window_position })
