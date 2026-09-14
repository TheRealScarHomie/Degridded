local global = _G
local api = global.api
local require = global.require
local module = global.module
local Mutators = require("Environment.ModuleMutators")
local DegriddedDBManager = require("Database.Mod_Degridded.DegriddedDBManager")

local DegriderManager = module(..., Mutators.Manager())

function DegriderManager.Init(self, _tProperties, _tEnvironment)
    global.pcall(DegriddedDBManager.CreateVariants)
end

function DegriderManager.Advance(self, _nDeltaTime, _tData) end

function DegriderManager.Activate(self)
    global.pcall(DegriddedDBManager.CreateVariants)
end

function DegriderManager.Deactivate(self) end

function DegriderManager.Shutdown(self) end

Mutators.VerifyManagerModule(DegriderManager)
