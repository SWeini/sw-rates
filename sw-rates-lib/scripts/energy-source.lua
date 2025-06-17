local node = require("node")
local generated_temperatures = require("generated-temperatures")

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
    while (conf.type == "meta") do
        conf = conf.children[1]
    end

    local prototype = conf.entity
    if (not prototype) then
        return
    end

    local burner = prototype.burner_prototype
    if (burner) then
        return get_fuel_from_burner(entity.burner)
    end

    local fluid_energy_source = prototype.fluid_energy_source_prototype
    if (fluid_energy_source) then
        if (entity.type == "entity-ghost") then
            return
        end

        local fluidbox = get_fluid_with_index(entity.fluidbox, 1)
        if (not fluidbox) then
            return
        end

        local fluid = prototypes.fluid[fluidbox.name]
        local temperature = fluidbox.temperature ---@cast temperature -nil
        if (fluid_energy_source.burns_fluid) then
            if (fluid.fuel_value > 0) then
                ---@type Rates.Configuration.FluidFuel
                return {
                    type = "fluid-fuel",
                    fluid = fluid,
                    temperature = temperature
                }
            end
        else
            if (temperature > fluid.default_temperature) then
                ---@type Rates.Configuration.FluidFuelHeat
                return {
                    type = "fluid-fuel-heat",
                    fluid = fluid,
                    temperature = temperature
                }
            end
        end
    end
end

---@param result Rates.Configuration.Amount[]
---@param entity LuaEntityPrototype
---@param energy_usage number
---@param pollutant LuaAirbornePollutantPrototype?
---@param pollution_multiplier number
local function get_production(result, entity, energy_usage, pollutant, pollution_multiplier)
    local burner = entity.burner_prototype
    if (burner) then
        local fuel_usage = energy_usage * 60 / burner.effectivity

        local categories = {} ---@type LuaFuelCategoryPrototype[]
        for category, _ in pairs(burner.fuel_categories) do
            categories[#categories + 1] = prototypes.fuel_category[category]
        end
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.item_fuels(categories),
            amount = -fuel_usage,
            fuel_usage = fuel_usage
        }

        if (pollutant) then
            local emission = burner.emissions_per_joule[pollutant.name]
            if (emission and emission ~= 0) then
                result[#result + 1] = {
                    tag = "pollution",
                    tag_extra = "depends-on-fuel",
                    node = node.create.pollution(pollutant),
                    amount = energy_usage * 60
                        * emission * (pollution_multiplier or 1)
                }
            end
        end

        return
    end

    local fluid = entity.fluid_energy_source_prototype
    if (fluid) then
        local filter = fluid.fluid_box.filter
        local fuel_usage = energy_usage * 60 / fluid.effectivity

        if (fluid.burns_fluid) then
            if (filter) then
                result[#result + 1] = {
                    tag = "energy-source-input",
                    node = node.create.fluid(filter, {}),
                    amount = -fuel_usage / filter.fuel_value,
                    fuel_usage = fuel_usage
                }

                if (pollutant) then
                    local emission = fluid.emissions_per_joule[pollutant.name]
                    if (emission and emission ~= 0) then
                        result[#result + 1] = {
                            tag = "pollution",
                            node = node.create.pollution(pollutant),
                            amount = energy_usage * 60
                                * emission * (pollution_multiplier or 1)
                                * filter.emissions_multiplier
                        }
                    end
                end
            else
                result[#result + 1] = {
                    tag = "energy-source-input",
                    node = node.create.fluid_fuel(),
                    amount = -fuel_usage,
                    fuel_usage = fuel_usage
                }

                if (pollutant) then
                    local emission = fluid.emissions_per_joule[pollutant.name]
                    if (emission and emission ~= 0) then
                        result[#result + 1] = {
                            tag = "pollution",
                            tag_extra = "depends-on-fuel",
                            node = node.create.pollution(pollutant),
                            amount = energy_usage * 60
                                * emission * (pollution_multiplier or 1)
                        }
                    end
                end
            end
        else
            if (filter) then
                if (fluid.fluid_usage_per_tick > 0 and not fluid.scale_fluid_usage) then
                    result[#result + 1] = {
                        tag = "energy-source-input",
                        node = node.create.fluid(filter, {}),
                        amount = -fluid.fluid_usage_per_tick * 60,
                        fuel_usage = fuel_usage
                    }
                else
                    local default_temperature = filter.default_temperature
                    local temperatures = generated_temperatures.get_generated_fluid_temperatures(filter,
                        function(temperature)
                            return temperature > default_temperature
                        end)
                    if (#temperatures == 1) then
                        local temperature = temperatures[1]
                        local fuel_value = filter.heat_capacity * (temperature - default_temperature)
                        result[#result + 1] = {
                            tag = "energy-source-input",
                            node = node.create.fluid(filter, temperature),
                            amount = -fuel_usage / fuel_value,
                            fuel_usage = fuel_usage
                        }
                    else
                        result[#result + 1] = {
                            tag = "energy-source-input",
                            node = node.create.fluid_fuel_heat(filter),
                            amount = -fuel_usage,
                            fuel_usage = fuel_usage
                        }
                    end
                end

                if (pollutant) then
                    local emission = fluid.emissions_per_joule[pollutant.name]
                    if (emission and emission ~= 0) then
                        result[#result + 1] = {
                            tag = "pollution",
                            node = node.create.pollution(pollutant),
                            amount = energy_usage * 60
                                * emission * (pollution_multiplier or 1)
                                * filter.emissions_multiplier
                        }
                    end
                end
            else
                -- TODO: fluid energy source from any heated fluid
            end
        end

        return
    end

    local heat = entity.heat_energy_source_prototype
    if (heat) then
        local fuel_usage = energy_usage * 60
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.heat({ min = heat.min_working_temperature }),
            amount = -fuel_usage,
            fuel_usage = fuel_usage
        }

        return
    end

    local electric = entity.electric_energy_source_prototype
    if (electric) then
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.electric_power(),
            amount = -energy_usage * 60
        }

        if (electric.drain ~= 0) then
            result[#result + 1] = {
                tag = "energy-source-input",
                tag_extra = "drain",
                node = node.create.electric_power(),
                amount = -electric.drain * 60
            }
        end

        if (pollutant) then
            local emission = electric.emissions_per_joule[pollutant.name]
            if (emission and emission ~= 0) then
                result[#result + 1] = {
                    tag = "pollution",
                    node = node.create.pollution(pollutant),
                    amount = energy_usage * 60
                        * emission * (pollution_multiplier or 1)
                }
            end
        end

        return
    end
end

---@param amounts Rates.Configuration.Amount[]
---@param tag string
---@param tag_extra string?
---@return integer?
local function find_tag(amounts, tag, tag_extra)
    for i, amount in ipairs(amounts) do
        if (amount.tag == tag and amount.tag_extra == tag_extra) then
            return i
        end
    end
end

---@param destination Rates.Configuration.Amount[]
---@param destination_index integer
---@param source Rates.Configuration.Amount[]
---@param source_index integer
---@param factor number
local function replace_fuel_amounts(destination, destination_index, source, source_index, factor)
    table.remove(destination, destination_index)
    for k, amount in ipairs(source) do
        if (k ~= source_index) then
            table.insert(destination, destination_index, {
                tag = amount.tag,
                tag_extra = amount.tag_extra,
                node = amount.node,
                amount = amount.amount * factor
            } --[[@as Rates.Configuration.Amount]])
            destination_index = destination_index + 1
        end
    end
end

---@param result Rates.Configuration.Amount[]
---@param fuel_amounts Rates.Configuration.Amount[]
---@param entity LuaEntityPrototype
---@param fuel Rates.Configuration.Fuel
---@param options Rates.Configuration.ProductionOptions
local function apply_fuel_to_production(result, fuel_amounts, entity, fuel, options)
    local burner = entity.burner_prototype
    if (burner) then
        if (fuel.type ~= "item-fuel") then
            error("invalid type of fuel for burner: " .. fuel.type)
        end

        local destination_index = find_tag(result, "energy-source-input")
        local source_index = find_tag(fuel_amounts, "product")
        if (not destination_index or not source_index) then
            error("production amounts didn't match expected structure")
        end

        local factor = -result[destination_index].amount / fuel_amounts[source_index].amount
        replace_fuel_amounts(result, destination_index, fuel_amounts, source_index, factor)

        local pollution = find_tag(result, "pollution", "depends-on-fuel")
        if (pollution) then
            local amount = result[pollution]
            amount.amount = amount.amount * fuel.item.fuel_emissions_multiplier
        end

        return
    end

    local fluid_energy_source = entity.fluid_energy_source_prototype
    if (fluid_energy_source) then
        if (fuel.type ~= "fluid-fuel" and fuel.type ~= "fluid-fuel-heat") then
            error("invalid type of fuel for fluid energy source: " .. fuel.type)
        end

        local destination_index = find_tag(result, "energy-source-input")
        local source_index = find_tag(fuel_amounts, "product")
        if (not destination_index or not source_index) then
            error("production amounts didn't match expected structure")
        end

        local fluid_per_second = -result[destination_index].amount
        if (result[destination_index].node.type ~= "fluid") then
            fluid_per_second = fluid_per_second / fuel_amounts[source_index].amount
        end

        local max_fluid_per_tick = fluid_energy_source.fluid_usage_per_tick
        if (max_fluid_per_tick > 0) then
            if (fluid_energy_source.scale_fluid_usage) then
                fluid_per_second = math.min(fluid_per_second, max_fluid_per_tick * 60)
            else
                fluid_per_second = max_fluid_per_tick * 60
            end
        end

        local generated_energy = fuel_amounts[source_index].amount * fluid_per_second

        -- this value is sneakily passed via energy-source-input, written in get_production
        local fuel_usage = result[destination_index].fuel_usage --[[@as number]]

        replace_fuel_amounts(result, destination_index, fuel_amounts, source_index, fluid_per_second)

        if (generated_energy < fuel_usage) then
            local factor = generated_energy / fuel_usage
            for _, amount in ipairs(result) do
                if (amount.tag ~= "energy-source-input" and amount.tag_extra ~= "drain") then
                    amount.amount = amount.amount * factor
                end
            end
        end

        local pollution = find_tag(result, "pollution", "depends-on-fuel")
        if (pollution) then
            local amount = result[pollution]
            amount.amount = amount.amount * fuel.fluid.emissions_multiplier
        end

        return
    end
end

return {
    get_from_entity = get_from_entity,
    get_production = get_production,
    apply_fuel_to_production = apply_fuel_to_production,
}
