local global = _G
local api = global.api
local ipairs = global.ipairs
local table = global.table
local database = api.database

local DB = "ModularScenery"
local PS = "Mod_Degridded_ModularScenery"
local SUFFIX = "_SurfaceScaling"

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

-- creates non gridded variants
function DegriddedDBManager.CreateVariants()
    if DegriddedDBManager._bInserted then
        return
    end
    BindStatements()

    local _tGridItems = Query("DGGetAllSceneryPiecesByPrefabType", "OnGrid")
    if _tGridItems == nil then
        return
    end

    local _nInserted = 0
    local _tNames = {}
    local SCENERY_PREFAB_TYPE_COLUMN = 3
    local SCENERY_PREFAB_COLUMN = 2
    local SCENERY_PREFAB_NAME_COLUMN = 1
    local PROPUI_ICON_COLUMN = 4
    local PROPUI_PREFAB_NAME_COLUMN = 1
    local SIMULATION_PREFAB_NAME_COLUMN = 1
    local THEMING_PREFAB_NAME_COLUMN = 1

    for _, _tPart in ipairs(_tGridItems) do
        local _sOriginal = _tPart[SCENERY_PREFAB_NAME_COLUMN]
        local _tUIData = Query("DGGetSceneryUIDataOfPart", _sOriginal)[1]
        local _tSimulation = Query("DGGetScenerySimulationData", _sOriginal)[1]
        local _tTheming = Query("DGGetSceneryThemingData", _sOriginal)
        local _tTags = Query("DGGetSceneryMetadataTags", _sOriginal)

        _tPart[SCENERY_PREFAB_TYPE_COLUMN] = "SurfaceScaling"
        _tPart[SCENERY_PREFAB_COLUMN] = _sOriginal
        _tPart[SCENERY_PREFAB_NAME_COLUMN] = _sOriginal .. SUFFIX
        local _sVariant = _tPart[SCENERY_PREFAB_NAME_COLUMN]
        Query("DGAddModularSceneryPart", _tPart[1], _tPart[2], _tPart[3], _tPart[4], _tPart[5], _tPart[6], _tPart[7],
            _tPart[8])

        if _tSimulation ~= nil then
            _tSimulation[SIMULATION_PREFAB_NAME_COLUMN] = _sVariant
            Query("DGAddScenerySimulationData", _tSimulation[1], _tSimulation[2], _tSimulation[3], _tSimulation[4],
                _tSimulation[5])
        end

        if _tTheming ~= nil and #_tTheming > 0 then
            _tTheming = _tTheming[1]
            _tTheming[THEMING_PREFAB_NAME_COLUMN] = _sVariant
            Query("DGAddSceneryThemingData", _tTheming[1], _tTheming[2], _tTheming[3], _tTheming[4])
        end

        if _tUIData ~= nil then
            _tUIData[PROPUI_ICON_COLUMN] = _tUIData[PROPUI_PREFAB_NAME_COLUMN]
            _tUIData[PROPUI_PREFAB_NAME_COLUMN] = _sVariant
            Query("DGAddSceneryUIData", _tUIData[1], _tUIData[2], _tUIData[3], _tUIData[4], _tUIData[5])
            table.insert(_tNames, _sVariant)
        end

        if _tTags ~= nil then
            for _, _tTag in ipairs(_tTags) do
                if _tTag[2] == "Filter_GridProperty_Grid" then
                    _tTag[2] = "Filter_GridProperty_OffGrid"
                end
                _tTag[1] = _tTag[1] .. SUFFIX
                Query("DGAddSceneryTag", _tTag[1], _tTag[2])
            end
        end

        _nInserted = _nInserted + 1
    end

    if _nInserted > 0 then
        DegriddedDBManager._bInserted = true
        global.pcall(DegriddedDBManager.AddVariantsToBrowser, _tNames)
    end
end

return DegriddedDBManager
