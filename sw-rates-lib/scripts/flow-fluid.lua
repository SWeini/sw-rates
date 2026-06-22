local base = require("base-util")
local configuration = require("api-usage").configuration

local get_entity_type = base.get_entity_type

---@type table<string, true>
local type_is_pipe = {
    ["pipe"] = true,
    ["pipe-to-ground"] = true,
    ["storage-tank"] = true
}

---@param entity LuaEntity
---@param outputs Rates.Analyzer.EntityOutputs
local function debug_fluidbox(entity, outputs)
    local dbg = { entity = entity, unit_number = entity.unit_number, fluidboxes = entity.fluids_count, outputs = outputs }
    for i = 1, entity.fluids_count do
        dbg[i] = { content = entity.get_fluid(i), filter = entity.get_fluid_filter(i) }
    end
    game.print(serpent.line(dbg))
end

---@param connection Rates.Analyzer.FluidBoxConnection
---@return Rates.Analyzer.FluidLocation
local function fluidbox_connection_id(connection)
    return connection.entity.unit_number .. "/" .. connection.index .. "/" .. connection.pipe
end

---@param connection Rates.Analyzer.FluidBoxConnection
---@return PipeConnection
local function get_pipe_connection(connection)
    return connection.entity.get_fluid_box_pipe_connections(connection.index)[connection.pipe]
end

---@param connection Rates.Analyzer.FluidBoxConnection
---@return table<Rates.Analyzer.FluidLocation, Rates.Analyzer.FluidBoxConnection>
local function fluidbox_trace_segment(connection)
    local result = {} ---@type table<Rates.Analyzer.FluidLocation, Rates.Analyzer.FluidBoxConnection>
    local queue = {} ---@type table<Rates.Analyzer.FluidLocation, Rates.Analyzer.FluidBoxConnection>

    ---@param connection Rates.Analyzer.FluidBoxConnection
    local function pass_through(connection)
        local pipe_connections = connection.entity.get_fluid_box_pipe_connections(connection.index)
        local pipe_connection = pipe_connections[connection.pipe]
        if (pipe_connection.flow_direction == "input-output") then
            for pipe, pipe_connection in ipairs(pipe_connections) do
                if (pipe ~= connection.pipe and pipe_connection.flow_direction == "input-output") then
                    ---@type Rates.Analyzer.FluidBoxConnection
                    local conn = { entity = connection.entity, index = connection.index, pipe = pipe }
                    local id = fluidbox_connection_id(conn)
                    if (not result[id]) then
                        result[id] = conn
                        if (pipe_connection.target) then
                            ---@type Rates.Analyzer.FluidBoxConnection
                            local target_connection = {
                                entity = pipe_connection.target,
                                index = pipe_connection.target_fluidbox_index,
                                pipe = pipe_connection.target_pipe_connection_index
                            }
                            local id = fluidbox_connection_id(target_connection)
                            if (not result[id]) then
                                result[id] = target_connection
                                queue[id] = target_connection
                            end
                        end
                    end
                end
            end
        end
    end

    local id = fluidbox_connection_id(connection)
    result[id] = connection
    local pipe_connection = get_pipe_connection(connection)
    if (pipe_connection.flow_direction == "input-output") then
        queue[id] = connection
    end
    if (pipe_connection.target) then
        ---@type Rates.Analyzer.FluidBoxConnection
        local target_connection = {
            entity = pipe_connection.target,
            index = pipe_connection.target_fluidbox_index,
            pipe = pipe_connection.target_pipe_connection_index
        }
        local id = fluidbox_connection_id(target_connection)
        result[id] = target_connection
        local target_pipe_connection = get_pipe_connection(target_connection)
        if (target_pipe_connection.flow_direction == "input-output") then
            queue[id] = target_connection
        end
    end

    while (true) do
        local id, next_connection = next(queue)
        if (id == nil) then
            break
        end

        ---@cast next_connection -nil
        queue[id] = nil
        pass_through(next_connection)
    end

    return result
end

---@param entity LuaEntity
---@param outputs Rates.Analyzer.EntityOutputs
---@param connections table<Rates.Analyzer.FluidLocation, Rates.Analyzer.FluidBoxConnection>
---@return boolean
local function entity_outputs_into_segment(entity, outputs, connections)
    for index = 1, entity.fluids_count do
        -- TODO: only count as output if outputs indicates an output into the fluidbox
        local pipe_connections = entity.get_fluid_box_pipe_connections(index)
        for pipe, pipe_connection in ipairs(pipe_connections) do
            if (pipe_connection.flow_direction ~= "input") then
                ---@type Rates.Analyzer.FluidBoxConnection
                local connection = { entity = entity, index = index, pipe = pipe }
                local id = fluidbox_connection_id(connection)
                if (connections[id]) then
                    return true
                end
            end
        end
    end

    return false
end

---@param dirty_entities table<uint64, LuaEntity>
---@param context Rates.Analyzer.Context
---@param connections table<Rates.Analyzer.FluidLocation, Rates.Analyzer.FluidBoxConnection>
---@return integer
local function create_fluid_segment(dirty_entities, context, connections)
    local segment_id = #context.fluid_segments + 1
    ---@type Rates.Analyzer.FluidSegment
    local segment = {
        content = {},
        dependent_entities = {},
        filtered_forward_segments = {}
    }
    context.fluid_segments[segment_id] = segment

    local entities = {} ---@type table<uint64, LuaEntity>
    for id, connection in pairs(connections) do
        context.fluid_boxes[id] = segment_id
        local entity = connection.entity
        local unit_number = entity.unit_number ---@cast unit_number -nil
        entities[unit_number] = entity
    end

    for unit_number, entity in pairs(entities) do
        local type = get_entity_type(entity)
        if (not type_is_pipe[type]) then
            local outputs = context.entities[unit_number]
            if (not outputs) then
                outputs = configuration.analyze_flow(entity, {})
                context.entities[unit_number] = { entity = entity, outputs = outputs }
            end

            local outputs_into_segment = entity_outputs_into_segment(entity, outputs, connections)
            if (outputs_into_segment) then
                dirty_entities[unit_number] = entity
            end
        end
    end

    return segment_id
end

return {
    fluidbox_connection_id = fluidbox_connection_id,
    fluidbox_trace_segment = fluidbox_trace_segment,
    create_fluid_segment = create_fluid_segment,
}
