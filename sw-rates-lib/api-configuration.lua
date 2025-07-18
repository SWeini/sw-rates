require("all-nodes")
if (script.mod_name ~= "sw-rates-lib") then
    require("all-configurations")
end

local location = require("scripts.location")
local progression = require("scripts.progression")
local node = require("scripts.node")
local configuration = require("scripts.configuration-util")

return {
    location = location,
    progression = progression,
    node = node,
    configuration = configuration,
}
