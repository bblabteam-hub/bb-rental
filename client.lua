-- Initialize variables
local Framework = nil
local PlayerData = {}
local currentRental = nil
local spawnedNPCs = {}
local currentLocation = nil

-- Framework detection
Citizen.CreateThread(function()
    if Config.Framework == 'esx' then
        Framework = exports['es_extended']:getSharedObject()
    elseif Config.Framework == 'qbcore' then
        Framework = exports['qb-core']:GetCoreObject()
    else
        -- Auto-detect framework
        if GetResourceState('es_extended') == 'started' then
            Framework = exports['es_extended']:getSharedObject()
            Config.Framework = 'esx'
        elseif GetResourceState('qb-core') == 'started' then
            Framework = exports['qb-core']:GetCoreObject()
            Config.Framework = 'qbcore'
        end
    end

    -- Wait for player data
    while Framework == nil do
        Citizen.Wait(100)
    end

    if Config.Framework == 'esx' then
        while Framework.GetPlayerData().job == nil do
            Citizen.Wait(10)
        end
        PlayerData = Framework.GetPlayerData()
    elseif Config.Framework == 'qbcore' then
        PlayerData = Framework.Functions.GetPlayerData()
    end
end)

-- Register player data updates
if Config.Framework == 'esx' then
    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
    end)

    RegisterNetEvent('esx:setJob')
    AddEventHandler('esx:setJob', function(job)
        PlayerData.job = job
    end)
elseif Config.Framework == 'qbcore' then
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
    AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
        PlayerData = Framework.Functions.GetPlayerData()
    end)

    RegisterNetEvent('QBCore:Client:OnJobUpdate')
    AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
        PlayerData.job = JobInfo
    end)
end

-- Create blips for rental locations
Citizen.CreateThread(function()
    for k, location in pairs(Config.RentalLocations) do
        if location.blip.enabled then
            local blip = AddBlipForCoord(location.npc.coords.x, location.npc.coords.y, location.npc.coords.z)
            SetBlipSprite(blip, location.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, location.blip.scale)
            SetBlipColour(blip, location.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(location.blip.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Spawn NPCs at rental locations
Citizen.CreateThread(function()
    for k, location in pairs(Config.RentalLocations) do
        local model = GetHashKey(location.npc.model)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(1)
        end

        -- Adjust Z to ground level
        local x, y, z = location.npc.coords.x, location.npc.coords.y, location.npc.coords.z
        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z, 0)
        if foundGround then
            z = groundZ
        end

        local npc = CreatePed(4, model, x, y, z, location.npc.coords.w, false, true)
        SetEntityHeading(npc, location.npc.coords.w)
        FreezeEntityPosition(npc, true)
        SetEntityInvincible(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetPedCanRagdoll(npc, false)

        if location.npc.scenario then
            TaskStartScenarioInPlace(npc, location.npc.scenario, 0, true)
        end

        table.insert(spawnedNPCs, npc)
    end
end)


-- Interaction with NPCs (if not using target)
if not Config.Settings.useTarget then
    Citizen.CreateThread(function()
        while true do
            local sleep = 1000
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            for k, location in pairs(Config.RentalLocations) do
                local npcCoords = vector3(location.npc.coords.x, location.npc.coords.y, location.npc.coords.z)
                local distance = #(playerCoords - npcCoords)

                if distance < Config.Settings.interactDistance then
                    sleep = 0
                    DrawText3D(npcCoords.x, npcCoords.y, npcCoords.z + 1.0, Config.Lang.openMenu)

                    if IsControlJustReleased(0, Config.Keys.interact) then
                        currentLocation = k
                        OpenRentalMenu()
                    end
                end
            end

            Citizen.Wait(sleep)
        end
    end)
else
    -- Target system integration
    Citizen.CreateThread(function()
        if Config.Settings.targetResource == 'ox_target' then
            for k, location in pairs(Config.RentalLocations) do
                exports.ox_target:addBoxZone({
                    coords = vector3(location.npc.coords.x, location.npc.coords.y, location.npc.coords.z),
                    size = vec3(2, 2, 2),
                    rotation = location.npc.coords.w,
                    debug = false,
                    options = {
                        {
                            name = 'car_rental',
                            icon = 'fas fa-car',
                            label = 'Open Car Rental',
                            onSelect = function()
                                currentLocation = k
                                OpenRentalMenu()
                            end
                        }
                    }
                })
            end
        elseif Config.Settings.targetResource == 'qb-target' then
            for k, location in pairs(Config.RentalLocations) do
                exports['qb-target']:AddBoxZone("car_rental_" .. k, vector3(location.npc.coords.x, location.npc.coords.y, location.npc.coords.z), 2.0, 2.0, {
                    name = "car_rental_" .. k,
                    heading = location.npc.coords.w,
                    debugPoly = false,
                    minZ = location.npc.coords.z - 1,
                    maxZ = location.npc.coords.z + 2,
                }, {
                    options = {
                        {
                            type = "client",
                            icon = "fas fa-car",
                            label = "Open Car Rental",
                            action = function()
                                currentLocation = k
                                OpenRentalMenu()
                            end,
                        },
                    },
                    distance = 2.5
                })
            end
        end
    end)
end

-- Open rental menu
function OpenRentalMenu()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        ShowNotification(Config.Lang.alreadyInVehicle)
        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openMenu",
        vehicles = Config.Vehicles,
        hasRental = currentRental ~= nil
    })
end

-- Close rental menu
RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Rent vehicle
RegisterNUICallback('rentVehicle', function(data, cb)
    local vehicleData = Config.Vehicles[data.index]

    if vehicleData then
        -- Close NUI immediately
        SetNuiFocus(false, false)
        TriggerServerEvent('car-rental:server:rentVehicle', vehicleData, currentLocation)
    end

    cb('ok')
end)

-- Spawn rented vehicle
RegisterNetEvent('car-rental:client:spawnVehicle')
AddEventHandler('car-rental:client:spawnVehicle', function(vehicleData, locationIndex)
    local location = Config.RentalLocations[locationIndex]
    local spawnPoint = GetAvailableSpawnPoint(location.spawnPoints)

    if not spawnPoint then
        ShowNotification(Config.Lang.noSpawnPoint)
        return
    end

    -- Request vehicle model
    local modelHash = GetHashKey(vehicleData.model)
    RequestModel(modelHash)

    while not HasModelLoaded(modelHash) do
        Citizen.Wait(100)
    end

    -- Spawn vehicle
    local vehicle = CreateVehicle(modelHash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleNumberPlateText(vehicle, Config.Settings.platePrefix .. math.random(1000, 9999))
    SetVehicleFuelLevel(vehicle, 100.0)
    SetVehicleDirtLevel(vehicle, 0.0)

    -- Give keys (framework specific)
    local plate = GetVehicleNumberPlateText(vehicle)
    if Config.Framework == 'esx' then
        TriggerEvent('esx_vehiclelock:setVehicleLock', plate, false)
    elseif Config.Framework == 'qbcore' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end

    -- Store rental info
    currentRental = {
        vehicle = vehicle,
        plate = plate,
        model = vehicleData.model,
        deposit = vehicleData.deposit,
        locationIndex = locationIndex
    }

    -- Wait a moment for vehicle to fully spawn
    Citizen.Wait(500)

    -- Put player in vehicle
    local playerPed = PlayerPedId()
    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)

    ShowNotification(Config.Lang.vehicleRented)
end)

-- Return vehicle thread
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()

        if currentRental then
            local playerCoords = GetEntityCoords(playerPed)
            local vehicle = currentRental.vehicle

            -- Check if vehicle still exists
            if not DoesEntityExist(vehicle) then
                currentRental = nil
            else
                local location = Config.RentalLocations[currentRental.locationIndex]
                local returnCoords = location.returnPoint
                local distance = #(playerCoords - returnCoords)

                if distance < Config.Settings.returnDistance then
                    sleep = 0

                    if IsPedInAnyVehicle(playerPed, false) and GetVehiclePedIsIn(playerPed, false) == vehicle then
                        DrawText3D(returnCoords.x, returnCoords.y, returnCoords.z, "Press ~g~E~w~ to return vehicle")

                        if IsControlJustReleased(0, Config.Keys.interact) then
                            ReturnVehicle()
                        end
                    end
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- Return vehicle function
function ReturnVehicle()
    if not currentRental then
        return
    end

    local playerPed = PlayerPedId()
    local vehicle = currentRental.vehicle

    if IsPedInAnyVehicle(playerPed, false) and GetVehiclePedIsIn(playerPed, false) == vehicle then
        TriggerServerEvent('car-rental:server:returnVehicle', currentRental.deposit)

        TaskLeaveVehicle(playerPed, vehicle, 0)
        Citizen.Wait(2000)

        DeleteVehicle(vehicle)
        currentRental = nil
    end
end

-- Return vehicle via NUI
RegisterNUICallback('returnVehicle', function(data, cb)
    if currentRental then
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local location = Config.RentalLocations[currentRental.locationIndex]
        local returnCoords = location.returnPoint
        local distance = #(playerCoords - returnCoords)

        if distance > Config.Settings.returnDistance then
            ShowNotification(Config.Lang.tooFarFromReturn)
            cb('ok')
            return
        end

        if IsPedInAnyVehicle(playerPed, false) and GetVehiclePedIsIn(playerPed, false) == currentRental.vehicle then
            ReturnVehicle()
            SetNuiFocus(false, false)
        else
            ShowNotification(Config.Lang.notYourRental)
        end
    end

    cb('ok')
end)

-- Get available spawn point
function GetAvailableSpawnPoint(spawnPoints)
    for _, point in pairs(spawnPoints) do
        if IsSpawnPointClear(point) then
            return point
        end
    end
    return nil
end

-- Check if spawn point is clear
function IsSpawnPointClear(coords)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 70)
    return vehicle == 0
end

-- Draw 3D text
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
end

-- Show notification
function ShowNotification(msg)
    if Config.Framework == 'esx' then
        Framework.ShowNotification(msg)
    elseif Config.Framework == 'qbcore' then
        Framework.Functions.Notify(msg, 'primary')
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Delete spawned NPCs
        for _, npc in pairs(spawnedNPCs) do
            DeleteEntity(npc)
        end

        -- Delete rented vehicle
        if currentRental then
            DeleteVehicle(currentRental.vehicle)
        end

        SetNuiFocus(false, false)
    end
end)
