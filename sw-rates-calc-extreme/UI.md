## Left Pane - Total Production
- Always shows total production rates
- 1 line per node
- icon + long enough text for rate
- temperature text on top of fluid/heat icon
- one block per location:
  - location name
  - products
  - ingredients
  - net-zero constrained (quick action: remove constraint)
  - net-zero unconstrained
- clicking on a node selects it

## Middle Pane - Buildings
- 1 line per configuration
- count, recipe, entity, modules, infrastructure (agricultural tower square), extra text depending on configuration
- blocks possible
  - don't expand nested blocks
  - block breadcrumb on top (one line per block) with actions to go back
- clicking on configuration selects it

## Right Pane - Details / Adjustments
- switch to settings (starts there already)

### Selected Configuration
- Detailed information about configuration
  - entity count (add/remove constraint)
  - modules
  - beacons (and their profile efficiency)
  - recipe (assignment for furnaces possible)
  - fuel usage (change possible)
- Detailed production statistics for configuration
  - can toggle between per full building, per partial building and total
  - all products and ingredients
    - can change temperature of heat/fluid input
    - can change temperature of boiler/fusion-generator/...

### Selected Node
- Middle pane is filtered if toggle enabled (only show lines that have non-zero net production)
- Middle pane shows net production instead of count
- Set/Clear min/max constraint
- Add spoilage recipe
- Add transport between surfaces
- Add send-to-orbit
- Add burning as fuel (item/fluid)
- For any-nodes (fluid/heat) this might be a bit different

### Settings
- rate display for items
- rate display for fluids
- keep UI open in during selection: on/off
- highlight selected entities: on/off

## State
- all configurations with everything that was changed manually