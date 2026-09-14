local global = _G
local api = global.api
local pairs = global.pairs
local require = global.require
local table = require("Common.tableplus")

local Mod_DegriddedLuaDatabase = {}

Mod_DegriddedLuaDatabase.tManagers = {
    ["Environments.CPTEnvironment"] = {
        ["Managers.Mod_Degridded.DegriderManager"] = {},
    },
}

Mod_DegriddedLuaDatabase.AddLuaManagers = function(_fnAdd)
    for sManagerName, tParams in pairs(Mod_DegriddedLuaDatabase.tManagers) do
        _fnAdd(sManagerName, tParams)
    end
end

Mod_DegriddedLuaDatabase.AddContentToCall = function(_tContentToCall)
    table.insert(_tContentToCall, Mod_DegriddedLuaDatabase)
end

Mod_DegriddedLuaDatabase.Init = function() end

Mod_DegriddedLuaDatabase.Setup = function() end

Mod_DegriddedLuaDatabase.Shutdown = function() end

return Mod_DegriddedLuaDatabase
