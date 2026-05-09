local interface = require("interface")

---@param entity LuaEntity
---@param from_unit_number uint64
local function raise_unit_number_changed(entity, from_unit_number)
    script.raise_event(interface.event_names.unit_number_changed,
        { entity = entity, from_unit_number = from_unit_number })
end

local tag_name_ghost_unit_number = "sw-ghost-unit-number"

---@alias EntityMiningData { tick: uint32, surface: LuaSurface, position: MapPosition.0, prototype: LuaEntityPrototype, quality: LuaQualityPrototype, unit_number: integer }
local last_player_mining_events = {} ---@type { [uint32]: EntityMiningData }
local last_robot_mining_events = {} ---@type { [uint64]: EntityMiningData }

---@param mining_event EntityMiningData
---@param entity LuaEntity
---@return boolean
local function is_compatible_build(mining_event, entity)
    if (entity.surface.name ~= mining_event.surface.name) then
        return false
    end
    if ((entity.position.x ~= mining_event.position.x) or (entity.position.y ~= mining_event.position.y)) then
        return false
    end

    return true
end

script.on_event(defines.events.on_built_entity, function(event)
    local tick = event.tick
    for key, value in pairs(last_player_mining_events) do
        if (value.tick ~= tick) then
            last_player_mining_events[key] = nil
        end
    end

    local from_ghost_number = (event.tags or {})[tag_name_ghost_unit_number] --[[@as uint64?]]

    local entity = event.entity
    if (entity.type == "entity-ghost") then
        -- save unit_number into ghost tags
        local tags = entity.tags or {}
        tags[tag_name_ghost_unit_number] = entity.unit_number
        entity.tags = tags
    end

    if (from_ghost_number) then
        -- player building an entity from a ghost
        raise_unit_number_changed(entity, from_ghost_number)
        return
    end

    local mining_event = last_player_mining_events[event.player_index]
    if (not mining_event) then
        return
    end

    last_player_mining_events[event.player_index] = nil
    if (is_compatible_build(mining_event, entity)) then
        -- player upgrading an entity
        raise_unit_number_changed(entity, mining_event.unit_number)
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    local tick = event.tick
    for key, value in pairs(last_robot_mining_events) do
        if (value.tick ~= tick) then
            last_robot_mining_events[key] = nil
        end
    end

    local from_ghost_number = (event.tags or {})[tag_name_ghost_unit_number] --[[@as uint64?]]

    local entity = event.entity

    if (from_ghost_number) then
        -- construction bot building an entity from a ghost
        raise_unit_number_changed(entity, from_ghost_number)
        return
    end

    local mining_event = last_robot_mining_events[event.robot.unit_number]
    if (not mining_event) then
        return
    end

    last_robot_mining_events[event.robot.unit_number] = nil
    if (is_compatible_build(mining_event, entity)) then
        -- construction bot upgrading an entity
        raise_unit_number_changed(entity, mining_event.unit_number)
    end
end)

script.on_event(defines.events.on_player_setup_blueprint, function(event)
    -- strip ghost unit numbers from blueprints
    local stack = event.stack
    if (stack and stack.is_blueprint) then
        local entity_count = stack.get_blueprint_entity_count()
        for i = 1, entity_count do
            stack.set_blueprint_entity_tag(i, tag_name_ghost_unit_number, nil)
        end
    end

    local record = event.record
    if (record and record.valid_for_write) then
        local entity_count = record.get_blueprint_entity_count()
        for i = 1, entity_count do
            record.set_blueprint_entity_tag(i, tag_name_ghost_unit_number, nil)
        end
    end
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    -- save data for player upgrading an entity
    local entity = event.entity
    ---@type EntityMiningData
    local mining_event = {
        tick = event.tick,
        surface = entity.surface,
        position = entity.position,
        prototype = entity.prototype,
        quality = entity.quality,
        unit_number = entity.unit_number
    }
    if (entity.type == "entity-ghost") then
        mining_event.prototype = entity.ghost_prototype --[[@as LuaEntityPrototype]]
    end
    last_player_mining_events[event.player_index] = mining_event
end)

script.on_event(defines.events.on_robot_mined_entity, function(event)
    -- save data for construction bot upgrading an entity
    local entity = event.entity
    ---@type EntityMiningData
    local mining_event = {
        tick = event.tick,
        surface = entity.surface,
        position = entity.position,
        prototype = entity.prototype,
        quality = entity.quality,
        unit_number = entity.unit_number
    }
    last_robot_mining_events[event.robot.unit_number] = mining_event
end)
