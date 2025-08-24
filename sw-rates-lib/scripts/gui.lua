---GUI description for a node.
---@class (exact) Rates.Gui.NodeDescription
---@field element? ElemID
---@field icon? { sprite: SpritePath, quality: LuaQualityPrototype? }
---@field name? LocalisedString
---@field qualifier? Rates.Gui.NodeQualifier
---@field tooltip? LocalisedString
---@field number_format? Rates.Node.NumberFormat

---Information about how to format an amount of a node
---@class Rates.Node.NumberFormat
---@field factor number
---@field unit "/s" | "/m" | "/h" | "J" | "W" | "N" | "#"

---GUI description for a button
---@class Rates.Gui.ButtonDescription
---@field sprite SpritePath
---@field quality? LuaQualityPrototype
---@field tooltip? LocalisedString
---@field elem_tooltip? ElemID
---@field qualifier? Rates.Gui.NodeQualifier

---Data extracted from an ElemID
---@class DecomposedElemId
---@field name LocalisedString
---@field rich_text? LocalisedString
---@field sprite? SpritePath
---@field quality? LuaQualityPrototype

---@alias Rates.Gui.NodeQualifier
--- | Rates.Gui.NodeQualifier.Base
---
--- | Rates.Gui.NodeQualifier.Temperature
--- | Rates.Gui.NodeQualifier.TemperatureRange
--- | Rates.Gui.NodeQualifier.Neighbours

---Qualifier for nodes.
---@class Rates.Gui.NodeQualifier.Base
---@field type string
---@field text LocalisedString

---@class Rates.Gui.NodeQualifier.Temperature : Rates.Gui.NodeQualifier.Base
---@field type "temperature"
---@field temperature number

---@class Rates.Gui.NodeQualifier.TemperatureRange : Rates.Gui.NodeQualifier.Base
---@field type "temperature-range"
---@field min_temperature? number
---@field max_temperature? number

---@class Rates.Gui.NodeQualifier.Neighbours : Rates.Gui.NodeQualifier.Base
---@field type "neighbours"
---@field neighbours integer

---@param color Color
---@return string
local function rich_text_quality_color(color)
    return "[color=" .. (color.r or color[1]) .. "," .. (color.g or color[2]) .. "," .. (color.b or color[3]) .. "]"
end

---@param amount number
---@param number_format Rates.Node.NumberFormat
---@return { amount: number, unit: string? }
local function scale_number(amount, number_format)
    amount = amount * number_format.factor
    local unit = number_format.unit

    if (unit == "/s" and math.abs(amount) < 0.1) then
        amount = amount * 60
        unit = "/m"
    end

    if (unit == "/m" and math.abs(amount) < 0.1) then
        amount = amount * 60
        unit = "/h"
    end

    if (unit == "#") then
        unit = "" ---@diagnostic disable-line: cast-local-type
    end

    return { amount = amount, unit = unit }
end

local suffix_list = {
    { "Q", 1e30, "quetta" },
    { "R", 1e27, "ronna" },
    { "Y", 1e24, "yotta" },
    { "Z", 1e21, "zetta" },
    { "E", 1e18, "exa" },
    { "P", 1e15, "peta" },
    { "T", 1e12, "tera" },
    { "G", 1e9,  "giga" },
    { "M", 1e6,  "mega" },
    { "k", 1e3,  "kilo" },
}

---@param amount number
---@param max_precision? integer
---@return string
local function format_number(amount, max_precision)
    max_precision = max_precision or 3
    local suffix = ""
    for _, data in ipairs(suffix_list) do
        if (math.abs(amount) >= data[2]) then
            amount = amount / data[2]
            suffix = data[1]
            break
        end
    end

    local len_before = #tostring(math.floor(math.abs(amount)))
    local len_after = math.max(0, max_precision - len_before)
    local trimmed
    if (len_after > 0) then
        local formatted = string.format("%." .. len_after .. "f", amount)
        trimmed = string.gsub(formatted, "%.?0*$", "")
        if (trimmed == "0" and amount ~= 0) then
            trimmed = string.format("%.0e", amount)
        end
    else
        trimmed = string.format("%.0f", amount)
    end

    return trimmed .. suffix
end

---@param str LocalisedString
---@return LocalisedString
local function compress_string(str)
    local type = type(str)
    if (type ~= "table") then
        return str
    end

    for i = 2, #str do
        str[i] = compress_string(str[i])
    end

    if (#str > 20 and str[1] == "") then
        local new_str = { "" } ---@type LocalisedString
        local i = 2
        while i <= #str do
            local part = { "" } ---@type LocalisedString
            for j = 0, 19 do
                part[#part + 1] = str[i + j]
            end
            new_str[#new_str + 1] = part
            i = i + 20
        end

        return new_str
    end

    return str
end

---@param element ElemID
---@return DecomposedElemId
local function gui_element_default(element)
    return {
        name = prototypes[element.type][element.name].localised_name,
        rich_text = "[" .. element.type .. "=" .. element.name .. "]",
        sprite = element.type .. "/" .. element.name
    }
end

---@param element ElemID
---@return DecomposedElemId
local function gui_element_default_with_quality(element)
    local type = string.sub(element.type, 1, #(element.type) - 13)
    local quality_name = element.quality
    if (not quality_name or quality_name == "normal") then
        return {
            name = prototypes[type][element.name].localised_name,
            rich_text = "[" .. type .. "=" .. element.name .. "]",
            sprite = type .. "/" .. element.name
        }
    end

    local quality = prototypes.quality[quality_name]
    local color = rich_text_quality_color(quality.color)
    return {
        name = { "", color, prototypes[type][element.name].localised_name, " (", quality.localised_name, ")[/color]" },
        rich_text = "[" .. type .. "=" .. element.name .. ",quality=" .. quality_name .. "]",
        sprite = type .. "/" .. element.name,
        quality = quality
    }
end

local gui_element_decompose = {} ---@type table<string, fun(element: ElemID): DecomposedElemId>
gui_element_decompose["entity"] = gui_element_default
gui_element_decompose["fluid"] = gui_element_default
gui_element_decompose["item"] = gui_element_default
gui_element_decompose["recipe"] = gui_element_default
gui_element_decompose["technology"] = gui_element_default
gui_element_decompose["tile"] = gui_element_default
gui_element_decompose["item-with-quality"] = gui_element_default_with_quality
gui_element_decompose["entity-with-quality"] = gui_element_default_with_quality
gui_element_decompose["recipe-with-quality"] = gui_element_default_with_quality
gui_element_decompose["asteroid-chunk"] = function(element)
    return {
        name = prototypes.asteroid_chunk[element.name].localised_name,
        sprite = "asteroid-chunk/" .. element.name
    }
end

---@param element ElemID
---@return DecomposedElemId
local function gui_element(element)
    local decomposer = gui_element_decompose[element.type]
    if (decomposer) then
        return decomposer(element)
    end

    return { name = element.type .. "/" .. element.name }
end

---@param gui Rates.Gui.NodeDescription
---@param amount? number
---@return LocalisedString
local function gui_message(gui, amount)
    local data ---@type DecomposedElemId
    if (gui.element) then
        data = gui_element(gui.element)
    else
        data = {}
    end

    if (gui.icon) then
        data.sprite = gui.icon.sprite
        data.quality = gui.icon.quality
    end

    if (gui.name) then
        data.name = gui.name
    end

    if (not data.rich_text) then
        if (data.sprite) then
            data.rich_text = { "", "[img=" .. data.sprite .. "] ", data.name }
        else
            data.rich_text = data.name
        end
    end

    if (gui.qualifier) then
        data.rich_text = { "", data.rich_text, " (", gui.qualifier.text, ")" }
    end

    if (not amount) then
        return data.rich_text
    end

    local number_format = gui.number_format or { factor = 1, unit = "/s" }
    local scaled = scale_number(amount, number_format)

    return { "", data.rich_text, ": ", format_number(scaled.amount), scaled.unit }
end

---@param gui Rates.Gui.NodeDescription
---@return Rates.Gui.ButtonDescription
local function gui_button(gui)
    local data ---@type DecomposedElemId
    if (gui.element) then
        data = gui_element(gui.element)
    else
        data = {}
    end

    local icon = gui.icon or {}
    local sprite = icon.sprite or data.sprite
    local quality = icon.quality or data.quality
    local name = gui.name or data.name
    local tooltip ---@type LocalisedString?
    local elem_tooltip ---@type ElemID?

    if (gui.tooltip) then
        tooltip = compress_string(gui.tooltip)
    elseif (gui.element) then
        elem_tooltip = gui.element
    else
        tooltip = name
    end

    return {
        sprite = sprite,
        quality = quality,
        tooltip = tooltip,
        elem_tooltip = elem_tooltip,
        qualifier = gui.qualifier
    }
end

---@param gui Rates.Gui.NodeDescription
---@param amount? number
---@return { button: Rates.Gui.ButtonDescription, text: LocalisedString }
local function gui_button_and_text(gui, amount)
    local button = gui_button(gui)
    button.qualifier = nil
    if (not gui.tooltip) then
        button.tooltip = nil
    end

    local data ---@type DecomposedElemId
    if (gui.element) then
        data = gui_element(gui.element)
    else
        data = {}
    end

    local name = gui.name or data.name
    if (gui.qualifier) then
        name = { "", name, " (", gui.qualifier.text, ")" }
    end

    if (not amount) then
        return { button = button, text = name }
    end

    local number_format = gui.number_format or { factor = 1, unit = "/s" }
    local scaled = scale_number(amount, number_format)
    local amount_text = { "",
        "[font=item-count]",
        format_number(scaled.amount), scaled.unit,
        "[/font]" }
    local text = { "", amount_text, "  ", name }
    return { button = button, text = text }
end

return {
    scale_number = scale_number,
    format_number = format_number,
    compress_string = compress_string,
    gui_message = gui_message,
    gui_button = gui_button,
    gui_button_and_text = gui_button_and_text,
}
