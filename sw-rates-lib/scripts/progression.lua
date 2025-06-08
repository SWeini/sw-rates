local temperatures = require("generated-temperatures")

local location_creator = {}

---@param planet string
---@return Rates.Progression.SingleItem
function location_creator.planet(planet)
    return "planet-" .. planet
end

---@param surface string
---@return Rates.Progression.SingleItem
function location_creator.space(surface)
    return "space-" .. surface
end

---@class Progression.Creator
local creator = {}

---@param category string
---@param location string
---@return Rates.Progression.SingleItem
function creator.ammo(category, location)
    return "ammo/" .. category .. "/" .. location
end

---@param category string
---@param location string
---@return Rates.Progression.SingleItem
function creator.burner(category, location)
    return "burner/" .. category .. "/" .. location
end

---@param location string
---@return Rates.Progression.SingleItem
function creator.can_build(location)
    return "can-build/" .. location
end

---@param location string
---@return Rates.Progression.SingleItem
function creator.can_collect_asteroid(location)
    return "can-collect-asteroid/" .. location
end

---@param location string
---@return Rates.Progression.SingleItem
function creator.damage(location)
    return "damage/" .. location
end

---@param location string
---@return Rates.Progression.SingleItem
function creator.electric_power(location)
    return "electric-power/" .. location
end

---@param entity LuaEntityPrototype
---@param location string
---@return Rates.Progression.SingleItem | Rates.Progression.MultiItemPre | nil
function creator.energy_source(entity, location)
    local burner = entity.burner_prototype
    if (burner) then
        local nodes = {} ---@type Rates.Progression.MultiItemPre
        for category, _ in pairs(burner.fuel_categories) do
            nodes[#nodes + 1] = creator.item_fuel(category, location)
        end

        return nodes
    end

    local fluid = entity.fluid_energy_source_prototype
    if (fluid) then
        local filter = fluid.fluid_box.filter
        if (filter) then
            return creator.fluid(filter.name, {}, location)
        else
            return creator.fluid_fuel(location)
        end
    end

    local heat = entity.heat_energy_source_prototype
    if (heat) then
        return creator.heat({ min = heat.min_working_temperature }, location)
    end

    if (entity.electric_energy_source_prototype) then
        return creator.electric_power(location)
    end
end

---@param item string
---@param location string
---@return Rates.Progression.SingleItem
function creator.item(item, location)
    return "item/" .. item .. "/" .. location
end

---@param category string
---@param location string
---@return Rates.Progression.SingleItem
function creator.item_fuel(category, location)
    return "item-fuel/" .. category .. "/" .. location
end

---@param fluid string
---@param temperature { min: number?, max: number? }
---@param location string
---@return Rates.Progression.SingleItem | Rates.Progression.MultiItemPre
---@overload fun(fluid: string, temperature: number, location: string): Rates.Progression.SingleItem
function creator.fluid(fluid, temperature, location)
    if (type(temperature) == "number") then
        return "fluid/" .. fluid .. "/" .. temperature .. "/" .. location
    end

    local nodes = {} ---@type Rates.Progression.MultiItemPre
    for _, temp in ipairs(temperatures.get_generated_fluid_temperatures(fluid, temperature)) do
        nodes[#nodes + 1] = "fluid/" .. fluid .. "/" .. temp .. "/" .. location
    end

    if (#nodes == 1) then
        return nodes[1]
    end

    return nodes
end

---@param location string
---@return Rates.Progression.SingleItem
function creator.fluid_fuel(location)
    return "fluid-fuel/" .. location
end

---@param temperature number | { min: number?, max: number? }
---@param location string
---@return Rates.Progression.SingleItem | Rates.Progression.MultiItemPre
function creator.heat(temperature, location)
    if (type(temperature) == "number") then
        return "heat/" .. temperature .. "/" .. location
    end

    local min = temperature and temperature.min
    local max = temperature and temperature.max
    local nodes = {} ---@type string[]
    for _, temp in ipairs(temperatures.get_generated_heat_temperatures(temperature)) do
        nodes[#nodes + 1] = "heat/" .. temp .. "/" .. location
    end

    if (#nodes == 1) then
        return nodes[1]
    end

    return nodes
end

---@param ingredients? Ingredient[]
---@param location string
---@return Rates.Progression.Pre
function creator.ingredients(ingredients, location)
    local result = {} ---@type (string | string[])[]
    for _, ingredient in ipairs(ingredients or {}) do
        if (ingredient.type == "item") then
            result[#result + 1] = creator.item(ingredient.name, location)
        elseif (ingredient.type == "fluid") then
            local temperature = { min = ingredient.minimum_temperature, max = ingredient.maximum_temperature }
            result[#result + 1] = creator.fluid(ingredient.name, temperature, location)
        end
    end

    return result
end

---@param entity string
---@param location string
---@return Rates.Progression.SingleItem
function creator.map_entity(entity, location)
    return "map-entity/" .. entity .. "/" .. location
end

---@param tile string
---@param location string
---@return Rates.Progression.SingleItem
function creator.map_tile(tile, location)
    return "map-tile/" .. tile .. "/" .. location
end

---@param products (ItemProduct | FluidProduct | ResearchProgressProduct)[]?
---@param location string
---@return Rates.Progression.MultiItemPost
function creator.products(products, location)
    local result = {} ---@type string[]
    for _, product in ipairs(products or {}) do
        if (product.type == "item") then
            result[#result + 1] = creator.item(product.name, location)
        elseif (product.type == "fluid") then
            local temperature = product.temperature or prototypes.fluid[product.name].default_temperature
            result[#result + 1] = creator.fluid(product.name, temperature, location)
        end
    end

    return result
end

---@param recipe string
---@param location string
---@return Rates.Progression.SingleItem
function creator.recipe_crafter(recipe, location)
    return "recipe/crafter/" .. recipe .. "/" .. location
end

---@param recipe string
---@param location string
---@return Rates.Progression.SingleItem
function creator.recipe_ingredients(recipe, location)
    return "recipe/ingredients/" .. recipe .. "/" .. location
end

---@param location string
---@return Rates.Progression.SingleItem
function creator.send_to_orbit(location)
    return "send-to-orbit/" .. location
end

---@param location string
---@return Rates.Progression.SingleItem
function creator.send_to_platform(location)
    return "send-to-platform/" .. location
end

---@param asteroid string
---@param location string
---@return Rates.Progression.SingleItem
function creator.space_asteroid(asteroid, location)
    return "space-asteroid/" .. asteroid .. "/" .. location
end

---@param space string
---@param location string
---@return Rates.Progression.SingleItem
function creator.space_travel(space, location)
    return "space-travel/" .. space .. "/" .. location
end

---@param location string
---@return Rates.Progression.SingleItem
function creator.thrust(location)
    return "thrust/" .. location
end

---@param space string
---@return Rates.Progression.SingleItem
function creator.unlock_location(space)
    return "unlock/location/" .. space
end

---@param quality string
---@return Rates.Progression.SingleItem
function creator.unlock_quality(quality)
    return "unlock/quality/" .. quality
end

---@param recipe string
---@return Rates.Progression.SingleItem
function creator.unlock_recipe(recipe)
    return "unlock/recipe/" .. recipe
end

---@return Rates.Progression.SingleItem
function creator.unlock_space()
    return "unlock/space"
end

---@param technology string
---@return Rates.Progression.SingleItem
function creator.unlock_technology(technology)
    return "unlock/technology/" .. technology
end

---@param location string
---@return boolean
local function is_planet(location)
    return string.sub(location, 1, 7) == "planet-"
end

---@param location string
---@return boolean
local function is_space_platform(location)
    return string.sub(location, 1, 6) == "space-"
end

---@param location string
---@param conditions SurfaceCondition[]?
local function has_surface_conditions(location, conditions)
    local properties
    if (is_planet(location)) then
        local planet = prototypes.space_location[string.sub(location, 8)]
        properties = planet.surface_properties or {}
    elseif (is_space_platform(location)) then
        local space = prototypes.surface[string.sub(location, 7)]
        properties = space and space.surface_properties or {}
    else
        properties = {}
    end

    for _, condition in ipairs(conditions or {}) do
        local name = condition.property
        local value = properties[name]
        if (value == nil) then
            value = prototypes.surface_property[name].default_value
        end

        if (value < condition.min or value > condition.max) then
            return false
        end
    end

    return true
end

---@param result Rates.Progression.Rules
---@param entity LuaEntityPrototype
---@param pre (string | string[])[]
---@param location string
---@param suffix? string
---@return Rates.Progression.Rule
local function add_burner(result, entity, pre, location, suffix)
    local burner = entity.burner_prototype
    if (not burner) then
        return {}
    end
    local id = "burner/" .. entity.name .. "/" .. (suffix and (suffix .. "/") or "") .. location
    pre[#pre + 1] = creator.map_entity(entity.name, location)
    local post = {} ---@type string[]
    for cat, _ in pairs(burner.fuel_categories) do
        post[#post + 1] = creator.burner(cat, location)
    end
    ---@type Rates.Progression.Rule
    local rule = {
        pre = pre,
        post = post
    }
    result[id] = rule
    return rule
end

return {
    create = creator,
    location = location_creator,
    is_planet = is_planet,
    is_space_platform = is_space_platform,
    has_surface_conditions = has_surface_conditions,
    add_burner = add_burner
}
