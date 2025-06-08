local handler = require("__core__.lualib.event_handler")
local configuration = require("__sw-rates-lib__.scripts.configuration")

local configurations = {
    require("configurations.py-biofluid"),
    require("configurations.py-bitumenseep"),
    require("configurations.py-digsite"),
    require("configurations.py-power"),
    require("configurations.py-smartfarm"),
    require("configurations.py-solar"),
}

handler.add_libraries({ {
    add_remote_interface = function()
        configuration.register(configurations)
    end
} })
