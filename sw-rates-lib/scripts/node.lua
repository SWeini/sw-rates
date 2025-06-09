---A single thing that is used for rate calculation.
---@class Rates.Node.Base
---@field type string
---@field id string

---Description for a type of node.
---@class (exact) Rates.Node.Type
---@field type string must be unique, please use a mod-specific prefix like "my-mod-"
---These methods are added to the builder pattern, they are not automatically shared with other mods
---@field creator? table<string, fun(...): Rates.Node>
---Generates the id field
---@field get_id? fun(node: Rates.Node): string?
---Used to provide GUI for this node
---@field gui_default? fun(node: Rates.Node): Rates.Gui.NodeDescription
---Used to provide a printable representation for this node
---@field gui_text? fun(node: Rates.Node, options: Rates.Node.GuiTextOptions?): LocalisedString
---Used to provide information about how to format an amount of this node
---@field gui_number_format? fun(node: Rates.Node): Rates.Node.NumberFormat

---Creates any of the registered nodes.
---@class Rates.Node.Creator

---GUI description for a node.
---@class (exact) Rates.Gui.NodeDescription
---@field sprite? SpritePath
---@field quality? LuaQualityPrototype

---@class Rates.Node.GuiTextOptions
---@field mode? "icon-only" | "text-only" | "icon-and-text" -- defaults to "icon-and-text"

---@class Rates.Node.NumberFormat
---@field factor number
---@field unit? "J" | "W" | "N"

local registry = require("node-registry")

---@param type string
---@return string
local function interface_name(type)
    return "sw-rates/node/" .. type
end

---@param type Rates.Node.Type
local function register_one(type)
    remote.add_interface(interface_name(type.type), {
        gui_default = type.gui_default
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

    return {}
end

---@param node Rates.Node
---@param options Rates.Node.GuiTextOptions?
---@return LocalisedString
local function gui_text(node, options)
    local logic = registry.get(node.type)
    if (logic) then
        if (logic.gui_text) then
            return logic.gui_text(node, options)
        end
    else
        local interface = interface_name(node.type)
        if (remote.interfaces[interface].gui_text) then
            return remote.call(interface, "gui_text", node, options) --[[@as LocalisedString]]
        end
    end

    return node.id
end

---@param node Rates.Node
---@return { factor: number, unit: nil | "J" | "W" | "N" }
local function gui_number_format(node)
    local logic = registry.get(node.type)
    if (logic) then
        if (logic.gui_number_format) then
            return logic.gui_number_format(node)
        end
    else
        local interface = interface_name(node.type)
        if (remote.interfaces[interface].gui_number_format) then
            return remote.call(interface, "gui_number_format", node) --[[@as Rates.Node.NumberFormat]]
        end
    end

    return { factor = 1 }
end

return {
    create = registry.create, ---@type Rates.Node.Creator
    register = register,
    gui_default = gui_default,
    gui_text = gui_text,
    gui_number_format = gui_number_format,
}
