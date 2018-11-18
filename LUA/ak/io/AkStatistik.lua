require "ak.io.AkWebServerIo"
os = require "os"
json = require("ak.io.dkjson")

local AkEepTime = require 'ak.model.ak_eep_time'
local AkEepVersion = require 'ak.model.ak_eep_version'


AkStatistik = {}
local MAX_SIGNALS = 1000
local MAX_TRACKS = 50000
local MAX_STRUCTURES = 50000
local data = {}

local function fillTime()
    data["time"] = AkEepTime.new(EEPTime,
        EEPTimeH,
        EEPTimeM,
        EEPTimeS)
end

local function fillEEPVersion()
    data["eep-version"] = AkEepVersion.new(EEPVer)
end

local function fillSaveSlots()
    data["save-slots"] = {}
    for i = 1, 1000 do
        local hResult, saved = EEPLoadData(i)
        if hResult then
            local o = {
                id = i,
                data = saved,
            }
            table.insert(data["save-slots"], o)
        end
    end
end

local function fillSignals()
    data["signals"] = {}
    data["waiting-on-signals"] = {}
    for i = 1, MAX_SIGNALS do
        local val = EEPGetSignal(i)
        if val > 0 then
            local waitingVehiclesCount = EEPGetSignalTrainsCount(i)
            local o = {}
            o.id = i
            o.position = val
            o.waitingVehiclesCount = waitingVehiclesCount
            table.insert(data["signals"], o)

            if (waitingVehiclesCount > 0) then
                for position = 1, waitingVehiclesCount do
                    local vehicleName = EEPGetSignalTrainName(i, position)
                    local waiting = {
                        id = o.id .. "-" .. position,
                        signalId = o.id,
                        waitingPosition = position,
                        vehicleName = vehicleName,
                        waitingCount = waitingVehiclesCount
                    }
                    table.insert(data["waiting-on-signals"], waiting)
                end
            end
        end
    end
end

local function fillSwitches()
    data["switches"] = {}
    for i = 1, MAX_SIGNALS do
        local val = EEPGetSignal(i)
        if val > 0 then
            local o = {}
            o.id = i
            o.position = val
            table.insert(data["switches"], o)
        end
    end
end

local function registerTracksBy(registerFunktion, trackName)
    data[trackName] = {}
    for i = 1, MAX_TRACKS do
        local exists = registerFunktion(i)
        if exists then
            local o = {}
            o.id = i
            --o.position = val
            data[trackName][tostring(o.id)] = o
        end
    end
end

local function registerTracks()
    registerTracksBy(EEPRegisterAuxiliaryTrack, "auxiliary-tracks")
    registerTracksBy(EEPRegisterControlTrack, "control-tracks")
    registerTracksBy(EEPRegisterRoadTrack, "road-tracks")
    registerTracksBy(EEPRegisterRailTrack, "rail-tracks")
    registerTracksBy(EEPRegisterTramTrack, "tram-tracks")
end



local function fillTracksBy(besetztFunktion, trackName, trainList, rollingStockList)
    local trains = {}
    local belegte = {}
    belegte.tracks = {}

    for _, track in pairs(data[trackName]) do
        local trackId = track.id
        local exists, occupied, trainName = besetztFunktion(trackId, true)
        track.occupied = occupied
        track.occupiedBy = trainName
        if occupied then
            local key = trackName .. "_track_" .. trackId
            belegte.tracks[key] = {}
            belegte.tracks[key].trackId = trackId
            belegte.tracks[key].occupied = occupied
            belegte.tracks[key].vehicle = trainName

            trains[trainName] = trains[trainName] or {}
            trains[trainName].trackType = trackName
            trains[trainName].onTrack = trackId
            trains[trainName].occupiedTacks = trains[trainName].occupiedTacks or {}
            trains[trainName].occupiedTacks[tostring(trackId)] = trackId
        end
    end

    data[trainList] = {}
    data[rollingStockList] = {}
    for trainName, train in pairs(trains) do
        local haveSpeed, speed = EEPGetTrainSpeed(trainName)
        local haveRoute, route = EEPGetTrainRoute(trainName)
        local rollingStockCount = EEPGetRollingstockItemsCount(trainName)

        local o = {
            id = trainName,
            occupiedTracks = train.occupiedTracks,
            trackType = train.trackType,
            onTrackId = train.onTrack,
            speed = haveSpeed and speed or 0,
            route = haveRoute and route or '',
            rollingStockCount = rollingStockCount,
        }
        data[trainList][tostring(o.id)] = o

        for i = 0, (rollingStockCount - 1) do
            local rollingStockName = EEPGetRollingstockItemName(trainName, i)
            local _, couplingFront = EEPRollingstockGetCouplingFront(rollingStockName)
            local _, couplingRear = EEPRollingstockGetCouplingRear(rollingStockName)
                local length = -1
                local propelled = true
                local trackId = -1
                local trackDistance = -1
                local trackDirection = -1
                local trackSystem = -1
                local modelType = -1
            if EEPVer >= 15 then
                _, length = EEPRollingstockGetLength(rollingStockName)
                _, propelled = EEPRollingstockGetMotor(rollingStockName)
                _, trackId, trackDistance, trackDirection, trackSystem = EEPRollingstockGetTrack(rollingStockName)
                _, modelType = EEPRollingstockGetModelType(rollingStockName)
            end

            local o = {
                name = rollingStockName,
                trainName = trainName,
                positionInTrain = i,
                couplingFront = couplingFront,
                couplingRear = couplingRear,
                length = length,
                propelled = propelled,
                trackId = trackId,
                trackDistance = trackDistance,
                trackDirection = trackDirection,
                trackSystem = trackSystem,
                modelType = modelType,
            }
            data[rollingStockList][o.name] = o
        end
    end
end

local function fillTracks()
    fillTracksBy(EEPIsAuxiliaryTrackReserved, "auxiliary-tracks", "auxiliary-trains", "auxiliary-rolling-stock")
    fillTracksBy(EEPIsControlTrackReserved, "control-tracks", "control-trains", "control-rolling-stock")
    fillTracksBy(EEPIsRoadTrackReserved, "road-tracks", "road-trains", "road-rolling-stock")
    fillTracksBy(EEPIsRailTrackReserved, "rail-tracks", "rail-trains", "rail-rolling-stock")
    fillTracksBy(EEPIsTramTrackReserved, "tram-tracks", "tram-trains", "tram-rolling-stock")
end

local function fillStructures()
    data["structures"] = {}
    for i = 0, MAX_STRUCTURES do
        local name = "#" .. tostring(i)
        local t = true
        local t, pos_x, pos_y, pos_z = false, 0, 0, 0
        local t, modelType = false, 0
        if (EEPVer >= 15) then
            t, pos_x, pos_y, pos_z = EEPStructureGetPosition(name)
            t, modelType = EEPStructureGetModelType(name)
        end

        if (t) then
            local t, light = EEPStructureGetLight(name)
            local t, smoke = EEPStructureGetSmoke(name)
            local t, fire = EEPStructureGetFire(name)

            local o = {
                name = name,
                light = light,
                smoke = smoke,
                fire = fire,
                pos_x = pos_x,
                pos_y = pos_y,
                pos_z = pos_z,
                modelType = modelType,
            }
            table.insert(data["structures"], o)
        end
    end
end

local function fillTrainYards()
    -- TODO
end

local function initialize()
    registerTracks()
end

local i = -1
local writeLater = {}
function AkStatistik.statistikAusgabe()
    if i == -1 then
        initialize();
    end

    -- Increase
    i = i + 1

    -- Do nothing
    if i % 5 == 0 then
        local t1 = os.time()
        fillTime()
        fillEEPVersion()
        fillStructures()

        fillSignals()
        fillSwitches()
        fillTracks()
        fillTrainYards()

        fillSaveSlots()

        for key, value in pairs(writeLater) do
            data[key] = value
        end

        local sortedKeys = {}
        for k in pairs(data) do
            table.insert(sortedKeys, k)
        end
        table.sort(sortedKeys)

        AkWebServerIo.send("eep-web-server", json.encode(data, {
            keyorder = sortedKeys,
        }))
        writeLater = {}
        local t2 = os.time()
        print(os.difftime(t2, t1))
    end
end

function AkStatistik.writeLater(key, value)
    writeLater[key] = value
end
