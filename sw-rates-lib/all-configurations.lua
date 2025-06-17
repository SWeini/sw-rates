local registry = require("scripts.configuration-registry")

---@diagnostic disable: undefined-doc-name

---@alias Rates.Configuration
--- | Rates.Configuration.Base
--- | Rates.Configuration.Extension alias this type in your mod to extend Rates.Configuration to your own types
--- | Rates.Configuration.Meta
---
--- | Rates.Configuration.Accumulator
--- | Rates.Configuration.AgriculturalTower
--- | Rates.Configuration.AsteroidChunk
--- | Rates.Configuration.AsteroidCollector
--- | Rates.Configuration.Boiler
--- | Rates.Configuration.BurnerGenerator
--- | Rates.Configuration.CraftingMachine
--- | Rates.Configuration.FluidFuel
--- | Rates.Configuration.FusionGenerator
--- | Rates.Configuration.FusionReactor
--- | Rates.Configuration.Generator
--- | Rates.Configuration.ItemFuel
--- | Rates.Configuration.ItemSpoil
--- | Rates.Configuration.Lab
--- | Rates.Configuration.MiningDrill
--- | Rates.Configuration.OffshorePump
--- | Rates.Configuration.Reactor
--- | Rates.Configuration.Recipe
--- | Rates.Configuration.SolarPanel
--- | Rates.Configuration.SpaceLocation
--- | Rates.Configuration.Thruster

---@alias Rates.Configuration.Fuel
--- | Rates.Configuration.ItemFuel
--- | Rates.Configuration.FluidFuel

---@diagnostic enable: undefined-doc-name

registry.register({
    require("configurations.meta"),
    require("configurations.accumulator"),
    require("configurations.agricultural-tower"),
    require("configurations.ammo"),
    require("configurations.asteroid-chunk"),
    require("configurations.asteroid-collector"),
    require("configurations.asteroid"),
    require("configurations.boiler"),
    require("configurations.burner-generator"),
    require("configurations.capture-robot"),
    require("configurations.character"),
    require("configurations.crafting-machine"),
    require("configurations.entity-with-health"),
    require("configurations.entity"),
    require("configurations.fluid-fuel"),
    require("configurations.fusion-generator"),
    require("configurations.fusion-reactor"),
    require("configurations.generator"),
    require("configurations.gun"),
    require("configurations.item-fuel"),
    require("configurations.item-spoil"),
    require("configurations.lab"),
    require("configurations.mining-drill"),
    require("configurations.offshore-pump"),
    require("configurations.reactor"),
    require("configurations.recipe"),
    require("configurations.send-to-orbit"),
    require("configurations.send-to-platform"),
    require("configurations.solar-panel"),
    require("configurations.space-connection"),
    require("configurations.space-location"),
    require("configurations.space-platform-starter-pack"),
    require("configurations.space-platform"),
    require("configurations.technology-effects"),
    require("configurations.technology-trigger"),
    require("configurations.thruster"),
    require("configurations.unit-spawner"),
})
