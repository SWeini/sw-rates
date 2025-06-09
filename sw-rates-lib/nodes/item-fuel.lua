do
    --- Energy provided by a specific fuel category.
    ---@class (exact) Rates.Node.ItemFuel : Rates.Node.Base
    ---@field type "item-fuel"
    ---@field category LuaFuelCategoryPrototype
end

do
    --- Energy provided by a set of fuel categories.
    ---@class (exact) Rates.Node.Any.Details.ItemFuel : Rates.Node.Base
    ---@field type "any-item-fuel"
    ---@field categories LuaFuelCategoryPrototype[]
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "item-fuel", creator = creator } ---@type Rates.Node.Type
local result_any = { type = "any-item-fuel" } ---@type Rates.Node.Type

---@param category LuaFuelCategoryPrototype
---@return Rates.Node.ItemFuel
creator.item_fuel = function(category)
    return {
        category = category
    }
end

---@param categories LuaFuelCategoryPrototype[]
---@return Rates.Node.ItemFuel | Rates.Node.Any
creator.item_fuels = function(categories)
    if (#categories == 1) then
        return {
            category = categories[1]
        }
    end

    local nodes = {} ---@type Rates.Node.ItemFuel[]
    for _, category in ipairs(categories) do
        local node = { type = "item-fuel", category = category }
        node.id = "item-fuel/" .. result.get_id(node)
        nodes[#nodes + 1] = node
    end

    ---@type Rates.Node.Any.Details.ItemFuel
    local details = {
        type = "any-item-fuel",
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        categories = categories
    }
    details.id = "any-item-fuel/" .. result_any.get_id(details)

    return {
        type = "any",
        children = nodes,
        details = details
    }
end

---@param node Rates.Node.ItemFuel
result.get_id = function(node)
    return node.category.name
end

---@param node Rates.Node.Any.Details.ItemFuel
result_any.get_id = function(node)
    local result = ""
    for i, category in ipairs(node.categories) do
        if (i > 1) then
            result = result .. "|"
        end

        result = result .. category.name
    end

    return result
end

---@param node Rates.Node.ItemFuel
result.gui_default = function(node)
    local specific = "tooltip-category-" .. node.category.name
    if (helpers.is_valid_sprite_path(specific)) then
        return { sprite = specific }
    end

    return { sprite = "tooltip-category-consumes" }
end

---@param node Rates.Node.Any.Details.ItemFuel
result_any.gui_default = function(node)
    return { sprite = "tooltip-category-consumes" }
end

---@param category LuaFuelCategoryPrototype
---@param options Rates.Node.GuiTextOptions
---@return LocalisedString
local function gui_text(category, options)
    local image = "tooltip-category-" .. category.name
    if (not helpers.is_valid_sprite_path(image)) then
        image = "tooltip-category-consumes"
    end

    return { "", "[img=" .. image .. "] ", { "fuel-category-name." .. category.name } }
end

---@param node Rates.Node.ItemFuel
result.gui_text = function(node, options)
    return gui_text(node.category, options)
end

---@param node Rates.Node.Any.Details.ItemFuel
result_any.gui_text = function(node, options)
    local result = { "" } ---@type LocalisedString
    for i, category in ipairs(node.categories) do
        if (i > 1) then
            result[#result + 1] = " / "
        end

        result[#result + 1] = gui_text(category, options)
    end

    return result
end

---@param node Rates.Node.ItemFuel
result.gui_number_format = function(node)
    return { factor = 1e6, unit = "W" }
end

---@param node Rates.Node.Any.Details.ItemFuel
result_any.gui_number_format = function(node)
    return { factor = 1e6, unit = "W" }
end

return { types = { result, result_any } }
