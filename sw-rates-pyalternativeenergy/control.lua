local handler = require("__core__.lualib.event_handler")
local configuration = require("__sw-rates-lib__.scripts.configuration")

local configurations = {
    require("configurations.py-beacon"),
    require("configurations.py-biofluid"),
    require("configurations.py-bitumenseep"),
    require("configurations.py-digsite"),
    require("configurations.py-farming"),
    require("configurations.py-power"),
    require("configurations.py-smartfarm"),
    require("configurations.py-solar"),
}

local configuration_turd = require("configurations.py-turd")

handler.add_libraries({ {
    add_remote_interface = function()
        configuration.register(configurations)

        if (helpers.compare_versions(script.active_mods["pyalienlife"], "3.0.61") >= 0) then
            configuration.register({
                configuration_turd
            })
        end
    end
} })
