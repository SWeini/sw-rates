---@type data.ModDoubleSettingPrototype
local min_pivot_element = {
    type = "double-setting",
    name = "sw-rates-calc-extreme-simplex-min-pivot-element",
    setting_type = "runtime-per-user",
    default_value = 1e-8,
    allowed_values = { 0, 1e-7, 1e-8, 1e-9, 1e-10, 1e-11 },
}

data:extend({ min_pivot_element })
