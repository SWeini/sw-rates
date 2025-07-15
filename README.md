# Production Rates Library
The purpose of this mod is to provide a common framework that brings together content mods and tool mods.

Tools using this framework:
- [Production Rates Calculator](https://mods.factorio.com/mod/sw-rates-calc)
- [Production Rates Calculator Extreme](https://mods.factorio.com/mod/sw-rates-calc-extreme)
- [Reactor Layout](https://mods.factorio.com/mod/sw-rates-reactor-layout)

Content supporting this framework:
- Vanilla (built-in)
- Space Age (built-in)
- Py Alternative Energy (via [Production Rates for Pyanodons Alternative Energy](https://mods.factorio.com/mod/sw-rates-pyalternativeenergy))

If you are a tool mod author and want to calculate something, look [here](#how-to-use).
\
If you are a content mod author and want to provide support, look [here](#how-to-extend).

The API is already many iterations old, so I hope it is stable and extensible now. I still consider this mod in beta phase, so be prepared for some breaking changes.

## Features
- Get configuration from an entity
  - Optionally respect ghosts - including planned upgrade, module changes and ghosted beacons
  - Collects all modules & beacons respecting `allowed_effects` and `allowed_module_categories`
  - Calculates neighbour bonus for reactor / fusion-reactor (assumes everything is running)
  - Gets fluid ingredient temperature if available
  - Gets specific fluid fuel if fluidbox is not empty
  - Gets specific item fuel if fuel inventory is filtered or burner is currently burning
- Calculate production rates from a configuration
  - Uses modifiers from force and surface
  - Respects all modifiers, including quality (optional)

## Supported entity types
- `accumulator` (100%)
- `agricultural-tower` (95%; hardcoded grid size)
- `asteroid-collector` (100%; speed is just a good approximation)
- `beacon` (not as separate entity, but providing effects to other buildings)
- `boiler` (95%; uses default temperature if the fluidbox is empty, or ghost; does not work with `boiler_mode="heat-fluid-inside"`)
- `burner-generator` (100%)
- `crafting-machine`
  - `assembling-machine` (100%)
  - `rocket-silo` (90%; item being sent to orbit is not detected yet; does not respect time for rocket launch animation)
  - `furnace` (95%; can't do anything if there is no recipe)
- `fusion-generator` (95%; uses default temperature if the fluidbox is empty, or ghost)
- `fusion-reactor` (100%)
- `generator` (95%; uses maximum temperature if the fluidbox is empty, or ghost)
- `lab` (100%; must be researching a technology)
- `lightning-attractor` (0%, not started)
- `mining-drill` (100%)
- `offshore-pump` (100%)
- `reactor` (100%)
- `solar-panel` (95%; does not respect modded day-night-cycles)
- `thruster` (100%)

## Planned Features
- More use of `meta` configuration
- More GUI integration features
  - provide warnings for a configuration
- API required for exploration tools (mods like FNEI / Recipe Book)
  - list all configurations that consume/produce items/fluids/things
  - list requirements of configuration
  - milestone calculation (what items/fluids/buildings become available with what science pack?)
- API required for planning tools (mods like Helmod / Factory Planner)
  - list all ways in which a configuration can be changed
  - virtual location (instead of `LuaSurface`) for `get_production`
  - check validity of configuration (especially in combination with location)

Some of this is already started, but not yet in a stable state, so it's not documented here. Currently it's on hold because I first want to polish the mod that uses this library.

## How to Use

### Determine whether two entities are "the same"
```lua
local api = require("__sw-rates-lib__.api-usage")

---@param a LuaEntity
---@param b LuaEntity
function process(a, b)
    local configuration_a = api.configuration.get_from_entity(a, {}) -- can pass options here
    local configuration_b = api.configuration.get_from_entity(b, {})

    if (configuration_a == nil or configuration_b == nil) then
        error("failed to get something useful from the entities")
    end

    if (api.configuration.get_id(configuration_a) == api.configuration.get_id(configuration_b)) then
        game.print("a and b are equal")
    else
        -- different entity or quality or recipe or modules or beacons or anything else that is relevant
        game.print("there is some difference between a and b")
        game.print(tostring(a) .. ": " .. configuration_a.id)
        game.print(tostring(b) .. ": " .. configuration_b.id)
    end
end
```

### Options for `get_from_entity`
```lua
use_ghosts: boolean
```
If `true`: Respect deconstruction markers, upgrade markers, ghosts, module removal & insertion plans, ghost beacons.
\
If `false`: Uses everything exactly as it is right now.
\
Defaults to `true`.

### Get the production rates of an entity
```lua
local api = require("__sw-rates-lib__.api-usage")

---@param entity LuaEntity
function process(entity)
    local configuration = api.configuration.get_from_entity(entity, {})
    -- missing nil check here

    local production = api.configuration.get_production(configuration, {})

    for _, amount in ipairs(production) do
        game.print(api.node.get_id(amount.node) .. ": " .. amount.amount .. "/s")
    end
end
```

### Options for `get_production`
```lua
force: LuaForce
```
The force will influence the production rates by:
- recipe productivity bonus
- research productivity bonus
- research speed bonus
- mining productivity bonus
- unlocked qualities

If not set, will not apply any of these modifiers (and assume all qualities unlocked).

```lua
surface: LuaSurface
```
The surface will influence the production rates by:
- global effects
- solar power

If not set, will not apply any of these modifiers (and assume "default" solar power).

```lua
apply_quality: boolean
```
If `true`: When using quality modules, split products according to quality distribution.
\
If `false`: Products will always use the quality of the ingredients.
\
Defaults to `false`.

```lua
solar_panel_mode: "average-and-buffer" | "day-and-night"
```
If `"average-and-buffer"`: Solar panels produce the average power output. Accumulators can directly provide the required energy buffer.
\
If `"day-and-night"`: Solar panels produce day-only power output. Maximal power output is more visible. Makes sense if you have mods that provide night-only power, because the combination doesn't need an energy buffer.
\
Defaults to `"average-and-buffer"`.

### GUI Integration

The API should provide enough information to show nodes and configurations in a basic way inside some GUI. You can always add extra logic based on `type`. Just don't do too much of that, because you will not be able to support modded nodes/configurations this way.

The main way is to use `api.node.gui_default`, `api.configuration.gui_recipe` and `api.configuration.gui_entity`. You can always ask for extending this interface.

There are two special types you should know about, you probably want to add special handling for them:

A node with `type="any"` describes alternative inputs. For example fluids of different temperature or multiple fuel categories for burner energy sources.

A configuration with `type="meta"` is a wrapper around other configuration(s). Using this wrapper it is possible to select a fluid/heat temperature or specify the burner/fluid energy source. Another use of the `meta` configuration is providing alternatives that are too distinct to put into `any` nodes. For example, this is used for unfiltered asteroid collectors or ambiguous agricultural towers.

## How to Extend

This snippet will register your configuration types with the library. Also, it will set up remote interfaces to handle requests about your configurations. All of this will be hidden from you. You just have to implement the configuration type.
```lua
local handler = require("__core__.lualib.event_handler")
local api = require("__sw-rates-lib__.api-configuration")

local configurations = {
    require("configurations.my-mod-super-special-entity"),
}

handler.add_libraries({ {
    add_remote_interface = function()
        api.configuration.register(configurations)
    end
} })
```

This is an example of a customized configuration type. It's possible to define a few more methods, but that's it for the beginning.
```lua
-- Contents of configurations/my-mod-super-special-entity.lua --

do
    ---@class Rates.Configuration.MyModSuperSpecialEntity : Rates.Configuration.Base
    ---@field type "my-mod-super-special-entity"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
end

local api = require("__sw-rates-lib__.api-configuration")

-- prefix the type with your mod name to avoid name clashes
local logic = { type = "my-mod-super-special-entity" } ---@type Rates.Configuration.Type

---@param conf Rates.Configuration.MyModSuperSpecialEntity
logic.gui_recipe = function(conf)
    -- entity makes power, so let's show the electricity symbol
    return {
        icon = { sprite = "tooltip-category-electricity" },
        name = { "sw-rates-node.electric-power" }
    }
end

---@param conf Rates.Configuration.MyModSuperSpecialEntity
logic.get_production = function(conf, result, options)
    -- electric energy interface will vary, but it's scripted to produce 5 MW on average
    result[#result + 1] = {
        tag = "product",
        node = api.node.create.electric_power(),
        amount = 5000000
    }
end

logic.get_from_entity = function(entity, options)
    -- entity is the selected entity, but it can be a ghost or marked for upgrade
    -- therefore options.entity and options.quality contain the "real" prototypes

    if (options.entity.name == "my-mod-super-special-entity") then
        -- type and id will be filled automatically using logic.type and logic.get_id
        ---@type Rates.Configuration.MyModSuperSpecialEntity
        return {
            entity = options.entity,
            quality = options.quality
        }
    end
end

return logic
```

For more examples please look at the implementation of the standard entity types - they are not different from modded content.

##