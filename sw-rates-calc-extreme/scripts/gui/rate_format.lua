local api = require("__sw-rates-lib__.api-usage")

---@param timescale integer?
---@param amount number
---@return number, string
local function apply_timescale(timescale, amount)
    if (timescale == nil) then
        local unit = "/s"
        if (math.abs(amount) < 0.1) then
            unit = "/m"
            amount = amount * 60
            if (math.abs(amount) < 0.1) then
                unit = "/h"
                amount = amount * 60
            end
        end
        return amount, unit
    elseif (timescale == second) then
        return amount, "/s"
    elseif (timescale == minute) then
        return amount * 60, "/m"
    elseif (timescale == hour) then
        return amount * 3600, "/h"
    else
        error("invalid timescale: " .. timescale)
    end
end

---@param timescale integer?
---@param amount number
---@param format Rates.Node.NumberFormat
---@param force LuaForce
---@return GuiElemDef[]
local function format(timescale, amount, format, force)
    ---@type LocalisedString
    local text
    if (format.unit == "/s") then
        local scaled_amount, unit = apply_timescale(timescale, amount * format.factor)
        text = { "", api.gui.format_number(scaled_amount), unit }
    else
        text = api.gui.gui_amount_text({ number_format = format }, amount)
    end
    ---@type GuiElemDef[]
    return {
        {
            args = {
                type = "label",
                caption = text,
            },
            style_mods = {
                font = "item-count",
            },
        },
    }
end

return {
    format = format,
}
