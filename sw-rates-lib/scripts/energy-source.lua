local node = require("node")

---@param burner LuaBurner?
---@return Rates.Configuration.ItemFuel?
local function get_fuel_from_burner(burner)
    if (not burner) then
        return
    end

    local inventory = burner.inventory

    local filter = inventory.get_filter(1)
    if (filter) then
        if (filter.comparator ~= "=") then
            -- fuel value doesn't go up with quality, so this could theoretically be supported, but it isn't yet
            return
        end

        for i = 2, #inventory do
            local other_filter = inventory.get_filter(i)
            if (not other_filter) then
                return
            end

            if (filter.name ~= other_filter.name) then
                return
            end

            if (filter.quality ~= other_filter.quality) then
                return
            end

            if (filter.comparator ~= other_filter.comparator) then
                return
            end
        end
    else
        for i = 2, #inventory do
            if (inventory.get_filter(i)) then
                return
            end
        end
    end

    if (filter) then
        return {
            type = "item-fuel",
            item = prototypes.item[filter.name],
            quality = prototypes.quality[filter.quality]
        } --[[@as Rates.Configuration.ItemFuel]]
    end

    local item = burner.currently_burning --[[@as { name: LuaItemPrototype, quality: LuaQualityPrototype }?]]

    for i = 1, #inventory do
        local slot = inventory[i]
        if (slot.valid_for_read) then
            if (item) then
                if (item.name.name ~= slot.name or item.quality.name ~= slot.quality.name) then
                    return
                end
            else
                item = { name = prototypes.item[slot.name], quality = slot.quality }
            end
        end
    end

    if (item) then
        return {
            type = "item-fuel",
            item = item.name,
            quality = item.quality
        } --[[@as Rates.Configuration.ItemFuel]]
    end
end

---@param fluidbox LuaFluidBox
---@param index integer
---@return Fluid?
local function get_fluid_with_index(fluidbox, index)
    for i = 1, #fluidbox do
        local proto = fluidbox.get_prototype(i)
        if (proto.index == index) then
            return fluidbox[i]
        end
    end
end

---@param entity LuaEntity
---@param conf Rates.Configuration
---@param options Rates.Configuration.FromEntityOptions.Internal
---@return Rates.Configuration.Fuel?
local function get_from_entity(entity, conf, options)
    local prototype = conf.entity
    if (not prototype) then
        return
    end

    local fuel ---@type Rates.Configuration.Fuel?
    if (prototype.burner_prototype) then
        fuel = get_fuel_from_burner(entity.burner)
    elseif (prototype.fluid_energy_source_prototype) then
        if (entity.type ~= "entity-ghost") then
            local fluid = get_fluid_with_index(entity.fluidbox, 1)
            if (fluid) then
                fuel = {
                    type = "fluid-fuel",
                    fluid = prototypes.fluid[fluid.name],
                    temperature = fluid.temperature
                } --[[@as Rates.Configuration.FluidFuel]]
            end
        end
    end

    return fuel
end

---@param result Rates.Configuration.Amount[]
---@param entity LuaEntityPrototype
---@param energy_usage number
local function get_production(result, entity, energy_usage)
    local burner = entity.burner_prototype
    if (burner ~= nil) then
        local amount = energy_usage * 60 / burner.effectivity

        local categories = {} ---@type LuaFuelCategoryPrototype[]
        for category, _ in pairs(burner.fuel_categories) do
            categories[#categories + 1] = prototypes.fuel_category[category]
        end
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.item_fuels(categories),
            amount = -amount
        }

        return
    end

    local fluid = entity.fluid_energy_source_prototype
    if (fluid ~= nil) then
        local filter = fluid.fluid_box.filter
        if (filter == nil) then
            local amount = energy_usage * 60 / fluid.effectivity

            result[#result + 1] = {
                tag = "energy-source-input",
                node = node.create.fluid_fuel(),
                amount = -amount
            }
        elseif (fluid.burns_fluid) then
            result[#result + 1] = {
                tag = "energy-source-input",
                node = node.create.fluid(filter, {}),
                amount = -energy_usage * 60 / fluid.effectivity / filter.fuel_value
            }
        else
            local fluid_usage_per_tick = entity.fluid_usage_per_tick
            if (fluid_usage_per_tick ~= nil) then
                result[#result + 1] = {
                    tag = "energy-source-input",
                    node = node.create.fluid(filter, {}),
                    amount = -fluid_usage_per_tick * 60
                }
            else
                result[#result + 1] = {
                    tag = "energy-source-input",
                    node = node.create.fluid(filter, {}),
                    amount = -1
                }
            end
        end

        return
    end

    local heat = entity.heat_energy_source_prototype
    if (heat ~= nil) then
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.heat({ min = heat.min_working_temperature }),
            amount = -energy_usage * 60
        }

        return
    end

    local electric = entity.electric_energy_source_prototype
    if (electric) then
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.electric_power(),
            amount = -(energy_usage + electric.drain) * 60
        }

        return
    end
end

---@param result Rates.Configuration.Amount[]
---@param fuel_amounts Rates.Configuration.Amount[]
---@param fuel Rates.Configuration.ItemFuel | Rates.Configuration.FluidFuel
---@param options Rates.Configuration.ProductionOptions
local function apply_fuel_to_production(result, fuel_amounts, fuel, options)
    local i = 1
    while (result[i].tag ~= "energy-source-input") do
        i = i + 1
    end

    local j = 1
    while (fuel_amounts[j].tag ~= "product") do
        j = j + 1
    end

    local energy_usage = result[i].amount
    local fuel_usage = -energy_usage / fuel_amounts[j].amount

    table.remove(result, i)

    for k, amount in ipairs(fuel_amounts) do
        if (k ~= j) then
            table.insert(result, i, {
                tag = amount.tag,
                tag_extra = amount.tag_extra,
                node = amount.node,
                amount = amount.amount * fuel_usage
            } --[[@as Rates.Configuration.Amount]])
            i = i + 1
        end
    end
end

return {
    get_from_entity = get_from_entity,
    get_production = get_production,
    apply_fuel_to_production = apply_fuel_to_production,
}
