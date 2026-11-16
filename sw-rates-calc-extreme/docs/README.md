# Production Rates Calculator Extreme

## Basic Usage
At its heart Production Rates Calculator Extreme (PRCE) is a rate calculator mod, like many others. Pick the ![PRCE-button](../graphics/shortcut-x32-black.png) tool from the shortcut bar or use the keyboard control (default `Alt+X`). This gives you a selection tool to select some buildings.

![](basic-select.png)

If you do so, you will see the production rates of the selected buildings.
On the left side you can see all products and ingredients. Each section is sorted by type (roughly: power, weird stuff, items, then fluids), then by rate.
On the right side you can see all selected buildings, one line per "identical" building.

![](basic-rates.png)

Factorio already shows the production rates of a single machine, but if you are interested in more than 1 building you have to do some math in your head, and even though module requests and ghost beacons are respected in 2.1 there are still some scenarios that don't show the final numbers.

![](basic-vanilla.png)

The main toolbar hosts some very important buttons. Left-click the first icon to navigate back one step, or right-click for navigating all the way back to the overview. The undo/redo buttons interact with any changes you make to the selection or settings. You can give a name to the sheet if you want to keep it for longer.

![](basic-rename.png)

The library gives you access to all your named sheets as well as the last 5 unnamed sheets. The first click gives you a preview, the second click opens the sheet. The time you can see next to each sheet is the playtime of the last change.

![](basic-library.png)

 Configure how you want to see item/fluid rates using the dropdown. `Automatic` displays rates per second `/s` by default, with a fallback to minutes (`/m`) or hours (`/h`) for small numbers.

![](basic-timescale.png)

To add to (or remove from) your selected buildings, click-drag using the left (or right) mouse button. When holding shift you can increase (or decrease) how often the selected buildings are counted. By holding control+shift you start a new sheet from scratch instead of modifying your current sheet.

Selecting the tool while it is already active opens the window with the last sheet.

Multi-selecting buildings using shift is just one way of many. You can also build ghosts and select those (good to get a feeling for the space requirements) or ignore building counts completely (explained later).

![](basic-ghosts.png)

PRCE keeps track of the buildings, which allows you to make small changes (manually or via undo/redo) and then update everything by reopening the window. As an example, here I have upgraded all 6 buildings and then updated PRCE.

The selected buildings are only evaluated when the window opens or the selection changes. This keeps the navigation smooth when doing other changes.

![](basic-upgrade.png)

Everything gets a lot more interesting with more than just one building type. Intermediates are things that are produced by some buildings and consumed by others.

![](basic-intermediates.png)

Let's add some modules into the mix! Suddenly the ratio isn't perfect anymore. The right side tells you that there are 3 buildings for copper cable and 2 buildings for electronic circuits, but of the former only 2.78 are actually running (on average). They produce 8.1/s copper cable which is exactly the amount you need for the electronic circuits. If the building count is white there is still headroom left, if orange all the buildings are used - not necessarily a bad thing.

![](basic-balanced.png)

By default, intermediates are automatically balanced (lock icon is locked), but it's possible to not balance (lock icon is unlocked). Right-click the icon to change between the two modes. Even if an intermediate is not forced to be balanced it might still be balanced because the rates turned out that way.

Here the copper cables are unbalanced and PRCE tells you that 8.1/s are used internally and another 0.65/s can be exported. These are the numbers that most other mods calculate, but with no way to switch to balanced intermediates. The belts just exist to showcase a scenario where this makes sense.

![](basic-override.png)

Let's have a closer look at the right side of the window. Every row shows the effective building count, the used recipe, the used building, the number of buildings (in orange for 100% utilization), the used fuel (if configured) the used modules (and their number per building), and the used beacons with modules (per beacon). Beacons without a count mean 1 beacon, modules without a count mean the full building/beacon.

If buildings are not exactly the same they go into two different rows. All of these buildings produce copper cables, but they are all different. Some similar buildings might be automatically grouped, you can expand those to get the full view.

![](basic-configurations.png)

If you don't know how many buildings you need you can assume an infinite number by right-clicking the building icon. This should be simpler than increasing the number by shift-selecting multiple times or a massive amount of ghosts. In this example all building counts except for the transport belts are ignored (number shown in grey).

![](basic-building-count.png)

In vanilla factorio the assembling machines are the most important type of building, with furnaces being a close second. Especially in early game you are building furnace stacks to smelt your ores into plates.

Who knows what those two (small) furnace stacks produce?

![](basic-furnace-ghost.png)

That was a trick question, no one knows, not even PRCE. However, you can connect the belts properly and PRCE can figure it out.
Here the left furnace stack is smelting iron ore into plates, the filtered inserter was enough to indicate that (you have to select the inserter though). The right furnace stack is connected to at least one mining drill on the stone patch.

PRCE does not analyze belt throughput and connectivity, it is "only" determining the set of items that can sit on any given piece of belt, moved by an inserter or loader, filtered by a splitter, ...

For example, 8 of the 10 mining drills are not connected, and PRCE still shows the ratio as if all stone from mining drills will reach the stone furnaces. You still have to design a proper build, with full connectivity and enough throughput on belts/inserters. PRCE is a rate calculator, and the item detection exists to help with furnace ghosts.

This system isn't perfect yet, e.g. spoilage is not respected, but in most cases it is working very well. If not, one well-placed inserter with a filter should be enough to select the recipe and calculate ratios.

![](basic-item-tracking.png)

By the way, the above example shows burnable fuel as an ingredient. This is the fuel category accepted by the stone furnace. If you want to use coal you can set a filter on the fuel inventory. There is no item detection for fuels to minimize the performance-heavy belt tracing.

![](basic-fuel.png)

Alternatively you can configure a burnable fuel by clicking its icon and adding any fuel you want (or multiple).

![](configure-fuel.png)

The environment section lists everything happening on the map, most importantly resource consumption and pollution. Productivity modules, mining productivity research and better mining drills with better (less) resource drain all influence resource consumption. This is one mighty mining drill!

![](basic-resource.png)

Sometimes the fluid (and their temperatures) are important. In those cases PRCE will follow the pipes if you connect them. If you don't, PRCE will shout in your face. In this instance it doesn't matter because the defaults were correct.

![](basic-steam.png)

Two fluids of different temperature are different things. They don't interact and you won't get the results you want. Steam turbines use a different default temperature.

![](basic-no-pipe-tracking.png)

Connecting the pipes does help. By the way, the water temperature does matter, but you normally don't create water with a temperature different from the default. Play overhaul mods and this might change. Connect the water pipes properly and that warning will also go away.

![](basic-pipe-tracking.png)

When it comes to Space Age, many buildings "just work". For example, here is my very first spaceship I built and the rates in PRCE - just one selection, nothing more.

![](basic-space.png)

A few notes about that:
- Electricity is not linked by default. If you have power-producing buildings, you are often interested in the surplus of energy.
- The calculated thrust is using the thrusters' efficiency profile.
- Solar panels use the solar power of Nauvis orbit (where this ship is currently sitting).
- I didn't filter the asteroid collectors, and so all 4 appear multiple times. (The same would happen if you feed a sushi belt into a recycler). At least they are automatically grouped.
- Rates of asteroid collectors are just a good guess, and they assume that there are always asteroid chunks to grab. Definitely build more than what PRCE thinks is a perfect ratio.

You can even select buildings from multiple surfaces. If you do so, PRCE keeps them separate and you can export products to different surfaces. Exporting from a platform is free, exporting from a planet costs rocket lauches (which are "produced" by rocket silos). To simplify things (and because 2.1 added mixed rockets) the rocket launches assume zero waste.

![](basic-multi-surface.png)

## Under The Hood

Sometimes it helps to understand how something works under the hood. With this knowledge and some thinking you might be able to figure out for yourself why some edge cases are not 100% as expected.

Here is how PRCE roughly works:

### Selection

You select specific buildings, and they stay selected. If you `Ctrl+X`,`Ctrl+V` them, they become different buildings. If you upgrade, downgrade, rotate, flip, change recipe, build them, they stay the same building.

### Detect Items and Fluids

This is a multi-step process. First, starting from all buildings that need detection, the source of items/fluids is traced back to its source. This follows pipes/belts/inserters, respects filters, and stops when it finds a definitive source. The output of this first step is a graph of how items/fluids move. Second, all definitive sources produce their items and fluids, and then those move forward in the graph. When a building with dynamic output (such as a furnace) is reached, it might put more items/fluids into the system. This continues until there are no more changes.

This is a quite involved step, and it covers a lot of edge cases (probably not all of them). Here are a few:
- Two separate belt lanes
- Sideloading into (underground) belts
- Splitter and filtered splitter
- Inserters and filtered inserters (even moving items from chest to chest or on the ground)
- Lane splitter (mod-only)
- Loaders (mod-only)
- Linked belts (mod-only)
- Infinity chests might be a source of items
- Item filters can be whitelist/blacklist
- Item filters can be a specific item/quality combination, or a specific item with quality filter or just a quality filter
- Pipes and underground pipes
- Pumps and filtered pumps
- Valves (mod-only)
- Linked pipes (mod-only)
- Infinity pipes might be a source of fluids

Not covered right now are:
- Spoilage
- Items sent to orbit in rocket silo
- Detection of item fuels (for performance reasons and because there are fuel inventory filters)

### Configurations

Every building is converted into a "configuration". This uses all the information available from the building itself, its surrounding beacons and the items/fluids detected in the previous step. One such configuration might be "Assembling machine 2 with copper cable recipe, 2 productivity modules 1, 2 beacons with 2 speed modules 1 each".

Then all buildings are grouped into identical configurations. Each of those groups becomes one row on the right side of the GUI.

### Rate Calculation

Every configuration has a fixed ratio of inputs and outputs. Calculating this should be straight forward, all the data is already there. However, there are a few challenges:
- Rounding of module effects (they are rounded, aggregated and clamped in a certain way by the engine)
- Buildings that can't run at 100% speed due to not having enough power
- Rocket silo launch animation affecting maximal speed of rocket silos (haven't done that yet)
- Thrusters don't have a fixed ratio due to their efficiency profile
- When a spaceship is moving their solar energy changes every second (PRCE instead uses the solar power at the midpoint)

### Balancing

PRCE calculates the used building numbers by optimizing a mathematical problem, that is defined by the production rates of each configuration with some further constraints:
- A configuration can't be running on a negative number of building
- A configuration can't be running on more buildings than were selected
- Each balanced intermediate must be balanced (sum of production equals zero - consumption counts negative)
- Non-balanced intermediates or pure products/ingredients don't appear at all

If you've used any tool for planning your factory you might miss the first step: Telling what to optimize for. In a planning tool the user might define the goal "produce 5/s electronic circuits". This will become another constraint, similar to a balanced intermediate (sum equals 5/s). The goal is to minimize the "cost" (e.g. total number of used buildings), and in return the building numbers don't have an upper limit.

In PRCE you never defined your production goal. Instead the goal is to maximize the number of used buildings. In most cases this leads to the expected result. When your selection has multiple near-identical buildings, PRCE will prefer the worst building, which might be unintuitive at first sight. Also, if you have barrel/unbarrel loops just for fun, PRCE will gladly use all those useless buildings.
