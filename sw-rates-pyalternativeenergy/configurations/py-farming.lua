do
    ---@class Rates.Configuration.Annotation.PyFarmingNoModules : Rates.Configuration.Annotation.Base
    ---@field type "py-farming/no-modules"
    ---@field domain "animal" | "plant" | "fungi"
    ---@field default_module? string
end

local logic = { type = "py-farming", stats = { priority = 100 } } ---@type Rates.Configuration.Type

---@type { [string]: { default_module: string, domain: "animal" | "plant" | "fungi" } }
local farm_buildings = require("__pyalienlife__/scripts/farming/farm-building-list")
for key, value in pairs(require("__pyalternativeenergy__/scripts/farming")) do
    farm_buildings[key] = value
end

---@param entity_name string
---@return { default_module: string, domain: "animal" | "plant" | "fungi" }?
local function get_farm(entity_name)
    local is_turd = not not entity_name:find("%-turd")
    local name = entity_name:gsub("%-mk..+", is_turd and "-turd" or "")
    return farm_buildings[name]
end

logic.get_annotations = function(conf)
    if (conf.type ~= "crafting-machine") then
        return
    end

    local farm = get_farm(conf.entity.name)
    if (not farm) then
        return
    end

    local modules = conf.module_effects.modules
    if (modules and #modules > 0) then
        return
    end

    return { {
        type = "py-farming/no-modules",
        domain = farm.domain,
        default_module = farm.default_module
    } }
end

logic.gui_annotation = function(annotation, conf)
    if (annotation.type == "py-farming/no-modules") then
        if (annotation.default_module) then
            ---@type Rates.Gui.AnnotationDescription
            return {
                severity = "error",
                text = { "sw-rates-annotation.py-farming-no-modules", { "", "[item=" .. annotation.default_module .. "] ", prototypes.item[annotation.default_module].localised_name } },
                icon = { sprite = "no_module_" .. annotation.domain }
            }
        end
        ---@type Rates.Gui.AnnotationDescription
        return {
            severity = "error",
            text = { "sw-rates-annotation.py-farming-no-modules-domain", annotation.domain },
            icon = { sprite = "no_module_" .. annotation.domain }
        }
    end
end

return logic
