local global = _G
local api = global.api
local ipairs = global.ipairs
local table = global.table
local database = api.database

local DB = "ModularScenery"
local PS = "Mod_Degridded_ModularScenery"
-- changed to new prefix but keeps old one in a goofy troop type of way to not mess with the couple parks saved in the short launch-compatfix period that was added for future freebuild and other mod compatability
local SUFFIX = "_ScalableScenery"

local DegriddedDBManager = {}

DegriddedDBManager._bInserted = false
DegriddedDBManager._bBrowserAdded = false

local function BindStatements()
    database.SetReadOnly(DB, false)
    local bSuccess = database.BindPreparedStatementCollection(DB, PS)
    database.SetReadOnly(DB, true)
    return bSuccess ~= nil and bSuccess ~= 0
end

-- prewritten sql query
local function Query(_sInstance, ...)
    local result = nil
    database.SetReadOnly(DB, false)
    local tArgs = table.pack(...)
    local cInstance = database.GetPreparedStatementInstance(DB, _sInstance)
    if cInstance ~= nil then
        for i = 1, tArgs.n do
            local v = tArgs[i]
            if v ~= nil then
                database.BindParameter(cInstance, i, v)
            end
        end
        database.BindComplete(cInstance)
        database.Step(cInstance)
        result = database.GetAllResults(cInstance, false) or nil
    end
    database.SetReadOnly(DB, true)
    return result
end

-- rebuilds browser entries for variants
function DegriddedDBManager.AddVariantsToBrowser(_tNames)
    if DegriddedDBManager._bBrowserAdded then
        return
    end
    local _tWanted = {}
    local _nWanted = 0
    for _, _sName in ipairs(_tNames or {}) do
        _tWanted[_sName] = true
        _nWanted = _nWanted + 1
    end
    if _nWanted == 0 then
        return
    end

    local _tTagsForPart = {}
    local _tTagRows = Query("GetAllSceneryTags") or {}
    for _i = 1, #_tTagRows do
        local _sPart = _tTagRows[_i][1]
        if _tWanted[_sPart] then
            if _tTagsForPart[_sPart] == nil then
                _tTagsForPart[_sPart] = {}
            end
            table.insert(_tTagsForPart[_sPart], _tTagRows[_i][2])
        end
    end

    local _tCustomFilterIDs = {}
    local _tFilterRows = Query("GetAllPartCustomFilterIDs") or {}
    for _i = 1, #_tFilterRows do
        local _sPart = _tFilterRows[_i][1]
        if _tWanted[_sPart] then
            if _tCustomFilterIDs[_sPart] == nil then
                _tCustomFilterIDs[_sPart] = {}
            end
            table.insert(_tCustomFilterIDs[_sPart], _tFilterRows[_i][2])
        end
    end

    local _tEntries = Query("GetAllBrowserEntries")
    if _tEntries == nil then
        return
    end

    local _nAdded = 0
    for _i = 1, #_tEntries do
        local _row = _tEntries[_i]
        local _sPart = _row[1]
        if _tWanted[_sPart] then
            local _bOK = global.pcall(function()
                local _tTags = _tTagsForPart[_sPart] or {}
                local _nResearchPack = _row[7]
                local _nCostPerMetre = _row[22]

                local _tFilterID = {}
                for _k = 1, #_tTags do
                    _tFilterID[_k] = _tTags[_k]
                end
                table.insert(_tFilterID, _row[12])
                local _tCustom = _tCustomFilterIDs[_sPart]
                if _tCustom ~= nil then
                    for _k = 1, #_tCustom do
                        table.insert(_tFilterID, _tCustom[_k])
                    end
                end
                table.insert(_tFilterID, "NonBlueprint")
                table.insert(_tFilterID, _sPart)

                local _tItem = {
                    label = _row[2],
                    description = _row[3],
                    icon = _row[4],
                    cost = _nCostPerMetre or _row[5],
                    dlcList = _row[8],
                    researchPacks = _nResearchPack and { _nResearchPack } or {},
                    tags = _tTags,
                    sortType = _row[11] or 0,
                    filterID = _tFilterID,
                    requiresSandboxUnlock = (_row[13] == 1),
                    tooltipFormat = _nCostPerMetre and 1 or 0,
                }
                local _cItem = api.ui2.CreateDataStoreContext(_tItem, "browser", "ModularScenery", "Items", _sPart)

                local _tParams = nil
                local _fnParam = function(_sParam, _nValue)
                    if _nValue then
                        _tParams = _tParams or {}
                        _tParams[_sParam] = _nValue
                    end
                end
                _fnParam("generatedPower", _row[16])
                _fnParam("generatedWater", _row[17])
                _fnParam("power", _row[14])
                _fnParam("water", _row[15])
                _fnParam("sceneryScore", _row[18])
                _fnParam("costPerPowerPerHour", _row[19])
                _fnParam("costPerWaterPerHour", _row[20])
                _fnParam("totalBreakdownTime", _row[21])
                if _tParams ~= nil then
                    api.ui2.CreateDataStoreContext(_tParams, _cItem, "params")
                end
                if _row[6] ~= nil then
                    api.ui2.SetDataStoreElement(_cItem, "gridCellXSize", _row[6])
                end
            end)
            if _bOK then
                _nAdded = _nAdded + 1
            end
        end
    end
    DegriddedDBManager._bBrowserAdded = _nAdded > 0
end

-- new name then older name
local GROUPS = { "Scalable", "Surface" }

-- creates non gridded variants
function DegriddedDBManager.CreateVariants()
    if DegriddedDBManager._bInserted then
        return
    end
    BindStatements()

    local _tNew = Query("DGGetNewVariantNames")
    DegriddedDBManager._bInserted = true

    for _, _sGroup in ipairs(GROUPS) do
        Query("DGAddTags" .. _sGroup)
        Query("DGAddTheming" .. _sGroup)
        Query("DGAddSimulation" .. _sGroup)
        Query("DGAddUIData" .. _sGroup)
        Query("DGAddParts" .. _sGroup)
    end

    local _tNames = {}
    if _tNew ~= nil then
        for _, _tRow in ipairs(_tNew) do
            table.insert(_tNames, _tRow[1] .. SUFFIX)
        end
    end
    global.pcall(DegriddedDBManager.AddVariantsToBrowser, _tNames)
end

return DegriddedDBManager
