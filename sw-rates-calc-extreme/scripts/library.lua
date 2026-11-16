local storage_util = require("storage")

---@alias Rates.Data.SheetId integer

---@alias Rates.Data.LocationIndex integer

---@class (exact) Rates.Data.Sheet
---@field metadata Rates.Data.Sheet.Metadata
---@field locations Rates.Location[]
---@field selection Rates.Data.Sheet.Selection
---@field configurations Rates.Data.Sheet.Configuration[]
---@field configuration_adjustments table<string, Rates.Data.Sheet.ConfigurationAdjustment>
---@field nodes table<string, Rates.Data.Sheet.Node>

---@class (exact) Rates.Data.Sheet.Metadata
---@field id Rates.Data.SheetId
---@field name? string
---@field tick_created MapTick
---@field tick_modified MapTick
---@field owner integer

---@class (exact) Rates.Data.Sheet.SelectedEntity
---@field entity LuaEntity
---@field count integer

---@class (exact) Rates.Data.Sheet.Selection
---@field entities table<integer, Rates.Data.Sheet.SelectedEntity>
---@field use_ghosts boolean
---@field use_fuel boolean

---@class (exact) Rates.Data.Sheet.Configuration
---@field configuration Rates.Configuration
---@field location Rates.Data.LocationIndex
---@field force LuaForce
---@field count_max? number

---@class (exact) Rates.Data.Sheet.ConfigurationAdjustment
---@field count_infinite? boolean

---@class (exact) Rates.Data.Sheet.Node
---@field linked? boolean

---@class (exact) Rates.Data.Library
---@field sheets table<Rates.Data.SheetId, Rates.Data.Sheet>
---@field next_sheet_id Rates.Data.SheetId

local library = {}

---@return Rates.Data.Library
local function get_storage()
    local result = storage.library
    if (not result) then
        ---@type Rates.Data.Library
        result = {
            sheets = {},
            next_sheet_id = 1,
        }
        storage.library = result
    end

    return result
end

---@param id Rates.Data.SheetId
---@return Rates.Data.Sheet?
function library.try_get_sheet(id)
    local store = get_storage()
    return store.sheets[id]
end

---@param id Rates.Data.SheetId
---@return Rates.Data.Sheet
function library.get_sheet(id)
    local result = library.try_get_sheet(id)
    if (not result) then
        error("no sheet with id " .. id)
    end

    return result
end

---@param player LuaPlayer
---@return Rates.Data.Sheet[]
function library.get_sheets(player)
    local player_index = player.index
    local store = get_storage()
    local result = {} ---@type Rates.Data.Sheet[]
    for _, sheet in pairs(store.sheets) do
        if (sheet.metadata.owner == player_index) then
            result[#result + 1] = sheet
        end
    end

    return result
end

---@return Rates.Data.Sheet[]
function library.get_all_sheets()
    local store = get_storage()
    local result = {} ---@type Rates.Data.Sheet[]
    for _, sheet in pairs(store.sheets) do
        result[#result + 1] = sheet
    end

    return result
end

---@param player LuaPlayer
function library.create_sheet(player)
    local tick = game.ticks_played
    ---@type Rates.Data.Sheet
    local sheet = {
        metadata = {
            id = 0,
            owner = player.index,
            tick_created = tick,
            tick_modified = tick
        },
        locations = {},
        selection = {
            entities = {},
            use_fuel = true,
            use_ghosts = true,
        },
        selected_configurations = {},
        configurations = {},
        configuration_adjustments = {},
        nodes = {},
    }
    return sheet
end

---@param player LuaPlayer
function library.clean(player)
    local sheets = library.get_sheets(player)
    local unnamed_sheets = {} ---@type Rates.Data.Sheet[]
    for _, sheet in ipairs(sheets) do
        if (not sheet.metadata.name) then
            unnamed_sheets[#unnamed_sheets + 1] = sheet
        end
    end

    local max = storage_util.get_storage_player(player).settings.unnamed_sheets_max_count
    if (#unnamed_sheets <= max) then
        return
    end

    table.sort(unnamed_sheets, function(a, b)
        return a.metadata.tick_modified > b.metadata.tick_modified
    end)

    local is_open = storage_util.get_opened_sheet_ids()
    for i = max + 1, #unnamed_sheets do
        local sheet = unnamed_sheets[i]
        if (not is_open[sheet.metadata.id]) then
            library.delete_sheet(sheet)
        end
    end
end

---@param sheet Rates.Data.Sheet
---@return Rates.Data.SheetId
function library.save_sheet(sheet)
    local id = sheet.metadata.id
    if (id == 0) then
        local store = get_storage()
        id = store.next_sheet_id
        store.next_sheet_id = id + 1
        sheet.metadata.id = id
        store.sheets[id] = sheet

        local player = game.get_player(sheet.metadata.owner) ---@cast player -nil
        library.clean(player)
    end

    return id
end

---@param sheet Rates.Data.Sheet
function library.delete_sheet(sheet)
    local id = sheet.metadata.id
    if (id == 0) then
        return
    end

    local store = get_storage()
    store.sheets[id] = nil
end

return library
