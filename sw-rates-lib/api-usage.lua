require("all-nodes")
require("all-configurations")

local location = require("scripts.location")
local node = require("scripts.node")
local configuration = require("scripts.configuration")
local temperatures = require("scripts.generated-temperatures")
local gui = require("scripts.gui")

return {
    location = location,
    node = node,
    configuration = configuration,
    temperatures = temperatures,
    gui = gui,
}
