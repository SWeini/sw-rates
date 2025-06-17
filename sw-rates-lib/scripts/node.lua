---A single thing that is used for rate calculation.
---@class Rates.Node.Base
---@field type string
---@field id? string

---Description for a type of node.
---@class (exact) Rates.Node.Type
---@field type string must be unique, please use a mod-specific prefix like "my-mod-"
---These methods are added to the builder pattern, they are not automatically shared with other mods
---@field creator? table<string, fun(...): Rates.Node>
---Generates the id field
---@field get_id? fun(node: Rates.Node): string?
---Used to provide GUI for this node
---@field gui_default? fun(node: Rates.Node): Rates.Gui.NodeDescription

---Creates any of the registered nodes.
---@class Rates.Node.Creator

local registry = require("node-registry")

---@param type string
---@return string
local function interface_name(type)
    return "sw-rates/node/" .. type
end

---@param type Rates.Node.Type
local function register_one(type)
    remote.add_interface(interface_name(type.type), {
        get_id = type.get_id,
        gui_default = type.gui_default,
    })
end

---@param types table<any, Rates.Node.Type | { types: Rates.Node.Type[] }>
local function register(types)
    registry.register(types)
    for _, type in pairs(types) do
        if (type.type) then
            register_one(type)
        elseif (type.types) then
            for _, type2 in ipairs(type.types) do
                if (type2.type) then
                    register_one(type2)
                else
                    error("registering something without a type")
                end
            end
        else
            error("registering something without a type")
        end
    end
end

---@param node Rates.Node
---@return string
local function get_id(node)
    local id = node.id
    if (id) then
        return id
    end

    local logic = registry.get(node.type)
    if (logic) then
        if (logic.get_id) then
            id = logic.get_id(node)
        end
    else
        local interface = interface_name(node.type)
        if (remote.interfaces[interface].get_id) then
            id = remote.call(interface, "get_id", node) --[[@as string]]
        end
    end

    if (id) then
        id = node.type .. "/" .. id
    else
        id = node.type
    end

    node.id = id
    return id
end

---@param node Rates.Node
---@return Rates.Gui.NodeDescription
local function gui_default(node)
    local logic = registry.get(node.type)
    if (logic) then
        if (logic.gui_default) then
            return logic.gui_default(node)
        end
    else
        local interface = interface_name(node.type)
        if (remote.interfaces[interface].gui_default) then
            return remote.call(interface, "gui_default", node) --[[@as Rates.Gui.NodeDescription]]
        end
    end

    ---@type Rates.Gui.NodeDescription
    return {
        name = get_id(node)
    }
end

return {
    create = registry.create, ---@type Rates.Node.Creator
    register = register,
    get_id = get_id,
    gui_default = gui_default,
}
