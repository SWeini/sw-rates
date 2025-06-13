do
    --- A buffer of electric energy, as provided by accumulators.
    ---@class (exact) Rates.Node.AgriculturalCell : Rates.Node.Base
    ---@field type "agricultural-cell"
    ---@field plant LuaEntityPrototype
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "agricultural-cell", creator = creator } ---@type Rates.Node.Type

---@return Rates.Node.AgriculturalCell
---@param plant LuaEntityPrototype
creator.agricultural_cell = function(plant)
    return {
        plant = plant
    }
end

---@param node Rates.Node.AgriculturalCell
result.get_id = function(node)
    return node.plant.name
end

---@param plant LuaEntityPrototype
local function format_placement_tooltip(plant)
    local autoplace = plant.autoplace_specification
    if (not autoplace) then
        return
    end

    local tile_restriction = autoplace.tile_restriction
    if (not tile_restriction) then
        return
    end

    local tooltip = { "" } ---@type LocalisedString
    local plant_richtext = { "", "[entity=" .. plant.name .. "] ", plant.localised_name }
    tooltip[#tooltip + 1] = { "sw-rates-node.agricultural-cell-placement", plant_richtext }

    for _, restriction in ipairs(tile_restriction) do
        local tile = restriction.first
        if (tile) then
            tooltip[#tooltip + 1] = "\n[img=tile." .. tile .. "] "
            tooltip[#tooltip + 1] = prototypes.tile[tile].localised_name
        end
    end

    return tooltip
end

---@param node Rates.Node.AgriculturalCell
result.gui_default = function(node)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "entity", name = node.plant.name },
        name = { "sw-rates-node.agricultural-cell", node.plant.localised_name },
        tooltip = format_placement_tooltip(node.plant),
        number_format = { factor = 1, unit = "#" },
    }
end

return result
