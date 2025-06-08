# sw-rates
Production Rates for Factorio

## How to Use

### Determine whether two entities are "the same"
```lua
local api = require("__sw-rates-lib__.api-usage")

---@param a LuaEntity
---@param b LuaEntity
function process(a, b)
    local configuration_a = api.configuration.get_from_entity(a, {}) -- can pass options here
    local configuration_b = api.configuration.get_from_entity(b, {})

    if (configuration_a.id == nil or configuration_b.id == nil) then
        error("failed to get something useful from the entities")
    end

    if (configuration_a.id == configuration_b.id) then
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

Defaults to `true`.

### Get the production rates of an entity
```lua
local api = require("__sw-rates-lib__.api-usage")

---@param entity LuaEntity
function process(entity)
    local configuration = api.configuration.get_from_entity(entity, {})

    local production = api.configuration.get_production(configuration, {})

    for _, amount in ipairs(production) do
        game.print(amount.node.id .. ": " .. amount.amount .. "/s")
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

If not set, will not apply any of these modifiers.

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
If `false`: Products will always be use the quality of the ingredients

```lua
solar_panel_mode: "average-and-buffer" | "day-and-night"
```
If `"average-and-buffer"`: Solar panels produce the average power output. Accumulators can directly provide the required energy buffer.
\
If `"day-and-night"`: Solar panels produce day-only power output. Maximal power output is more visible.
\
Defaults to `"average-and-buffer"`.

### GUI Integration

The API should provide enough information to show nodes and configurations in a basic way inside some GUI. You can always add extra logic basic on `type`. Just don't do too much with this, because you will not be able to support modded nodes/configurations this way.

There are two special types you should know about, and add special handling for:

A node with `type="any"` describes alternative inputs. For example fluids of different temperature or multiple fuel categories for burner energy sources.

A configuration with `type="meta"` is a wrapper around other configuration(s). Using this wrapper it is possible to select a fluid/heat temperature or specify the burner/fluid energy source. Another use of the `meta` configuration is providing alternatives that are too distinct to put into `any` nodes. This is the case for unfiltered asteroid collectors or ambiguous agricultural towers.

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

local logic = { type = "my-mod-super-special-entity" } ---@type Rates.Configuration.Type

---@param conf Rates.Configuration.MyModSuperSpecialEntity
logic.gui_recipe = function(conf)
    -- entity makes power, so let's show the electricity symbol
    return { sprite = "tooltip-category-electricity" }
end

---@param conf Rates.Configuration.MyModSuperSpecialEntity
logic.get_production = function(conf, result, options)
    -- electric energy interface will produce 5 MW on average
    result[#result + 1] = {
        tag = "product",
        node = api.node.create.electric_power(),
        amount = 5
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