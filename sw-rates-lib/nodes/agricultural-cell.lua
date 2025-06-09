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

---@param node Rates.Node.AgriculturalCell
result.gui_default = function(node)
    return { sprite = "entity/" .. node.plant.name }
end

---@param tile_restrictions AutoplaceSpecificationRestriction[]?
---@return LocalisedString
local function format_tile_restrictions(tile_restrictions)
    if (not tile_restrictions) then
        return { "sw-rates-node.agricultural-cell-unrestricted" }
    end

    local result = { "" }
    for _, restriction in ipairs(tile_restrictions) do
        local tile = restriction.first
        if (tile) then
            result[#result + 1] = "[img=tile." .. tile .. "]"
        end
    end

    return result
end

---@param node Rates.Node.AgriculturalCell
result.gui_text = function(node, options)
    local plant = "[entity=" .. node.plant.name .. "]"
    local restriction = format_tile_restrictions(node.plant.autoplace_specification and
        node.plant.autoplace_specification.tile_restriction)
    local result = { "sw-rates-node.agricultural-cell-format", plant, restriction }
    return result
end

return result
