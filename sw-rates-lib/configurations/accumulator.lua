do
    ---@class (exact) Rates.Configuration.Accumulator : Rates.Configuration.Base
    ---@field type "accumulator"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")

local logic = { type = "accumulator" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("accumulator")

---@param conf Rates.Configuration.Accumulator
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "virtual-signal/signal-battery-full" },
        name = { "sw-rates-node.electric-buffer" }
    }
end

---@param conf Rates.Configuration.Accumulator
logic.get_production = function(conf, result, options)
    result[#result + 1] = {
        tag = "product",
        node = node.create.electric_buffer(),
        amount = conf.entity.electric_energy_source_prototype.buffer_capacity * (1 + conf.quality.level) /
            configuration.energy_factor
    }
end

---@param result Rates.Configuration.Accumulator[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = entity,
            quality = prototypes.quality.normal
        }
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "accumulator") then
        return
    end

    ---@type Rates.Configuration.Accumulator
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality
    }
end

return logic
