local registry = require("scripts.node-registry")

---@diagnostic disable: undefined-doc-name

---@alias Rates.Node
--- | Rates.Node.Base
--- | Rates.Node.Extension alias this type in your mod to extend Rates.Node to your own types
--- | Rates.Node.Any
--- | Rates.Node.Any.Details
---
--- | Rates.Node.AgriculturalCell
--- | Rates.Node.ElectricBuffer
--- | Rates.Node.ElectricPower
--- | Rates.Node.FluidFuelHeat
--- | Rates.Node.FluidFuel
--- | Rates.Node.Fluid
--- | Rates.Node.Heat
--- | Rates.Node.ItemFuel
--- | Rates.Node.Item
--- | Rates.Node.MapEntity
--- | Rates.Node.Pollution
--- | Rates.Node.Science
--- | Rates.Node.SendToOrbit
--- | Rates.Node.SendToPlatform
--- | Rates.Node.Thrust

---@alias Rates.Node.Any.Details
--- | Rates.Node.Base
--- | Rates.Node.Any.Details.Extension alias this type in your mod to extend Rates.Node.Any.Details to your own types
---
--- | Rates.Node.Any.Details.Fluid
--- | Rates.Node.Any.Details.Heat
--- | Rates.Node.Any.Details.ItemFuel

---@diagnostic enable: undefined-doc-name

registry.register({
    require("nodes.any"),
    require("nodes.agricultural-cell"),
    require("nodes.electric-buffer"),
    require("nodes.electric-power"),
    require("nodes.fluid-fuel-heat"),
    require("nodes.fluid-fuel"),
    require("nodes.fluid"),
    require("nodes.heat"),
    require("nodes.item-fuel"),
    require("nodes.item"),
    require("nodes.map-entity"),
    require("nodes.pollution"),
    require("nodes.science"),
    require("nodes.send-to-orbit"),
    require("nodes.send-to-platform"),
    require("nodes.thrust"),
})
