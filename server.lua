-- Initialize variables
local Framework = nil
local rentedVehicles = {} -- Track rented vehicles per player

-- Framework detection
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

-- Get player from source
function GetPlayer(source)
    if Config.Framework == 'esx' then
        return Framework.GetPlayerFromId(source)
    elseif Config.Framework == 'qbcore' then
        return Framework.Functions.GetPlayer(source)
    end
    return nil
end

-- Get player money
function GetPlayerMoney(player, account)
    if Config.Framework == 'esx' then
        if account == 'cash' then
            return player.getMoney()
        else
            return player.getAccount(account).money
        end
    elseif Config.Framework == 'qbcore' then
        if account == 'cash' then
            return player.PlayerData.money['cash']
        elseif account == 'bank' then
            return player.PlayerData.money['bank']
        end
    end
    return 0
end

-- Remove player money
function RemovePlayerMoney(player, account, amount)
    if Config.Framework == 'esx' then
        if account == 'cash' then
            player.removeMoney(amount)
        else
            player.removeAccountMoney(account, amount)
        end
        return true
    elseif Config.Framework == 'qbcore' then
        if account == 'cash' then
            return player.Functions.RemoveMoney('cash', amount)
        elseif account == 'bank' then
            return player.Functions.RemoveMoney('bank', amount)
        end
    end
    return false
end

-- Add player money
function AddPlayerMoney(player, account, amount)
    if Config.Framework == 'esx' then
        if account == 'cash' then
            player.addMoney(amount)
        else
            player.addAccountMoney(account, amount)
        end
        return true
    elseif Config.Framework == 'qbcore' then
        if account == 'cash' then
            return player.Functions.AddMoney('cash', amount)
        elseif account == 'bank' then
            return player.Functions.AddMoney('bank', amount)
        end
    end
    return false
end

-- Send notification to player
function SendNotification(source, message, type)
    if Config.Framework == 'esx' then
        TriggerClientEvent('esx:showNotification', source, message)
    elseif Config.Framework == 'qbcore' then
        TriggerClientEvent('QBCore:Notify', source, message, type or 'primary')
    else
        TriggerClientEvent('chatMessage', source, message)
    end
end

-- Rent vehicle event
RegisterNetEvent('car-rental:server:rentVehicle')
AddEventHandler('car-rental:server:rentVehicle', function(vehicleData, locationIndex)
    local src = source
    local player = GetPlayer(src)

    if not player then
        return
    end

    -- Get player identifier
    local identifier = nil
    if Config.Framework == 'esx' then
        identifier = player.identifier
    elseif Config.Framework == 'qbcore' then
        identifier = player.PlayerData.citizenid
    end

    -- Check if player already has max rentals
    if Config.Settings.maxRentalsPerPlayer > 0 then
        if rentedVehicles[identifier] and #rentedVehicles[identifier] >= Config.Settings.maxRentalsPerPlayer then
            SendNotification(src, Config.Lang.maxRentals, 'error')
            return
        end
    end

    -- Calculate total cost (rental price + deposit)
    local totalCost = vehicleData.price + vehicleData.deposit

    -- Check if player has enough money (try bank first, then cash)
    local hasMoney = false
    local accountUsed = nil

    if GetPlayerMoney(player, 'bank') >= totalCost then
        hasMoney = true
        accountUsed = 'bank'
    elseif GetPlayerMoney(player, 'cash') >= totalCost then
        hasMoney = true
        accountUsed = 'cash'
    end

    if not hasMoney then
        SendNotification(src, Config.Lang.notEnoughMoney, 'error')
        return
    end

    -- Remove money from player
    if RemovePlayerMoney(player, accountUsed, totalCost) then
        -- Initialize player rentals table if needed
        if not rentedVehicles[identifier] then
            rentedVehicles[identifier] = {}
        end

        -- Add rental to tracking
        table.insert(rentedVehicles[identifier], {
            model = vehicleData.model,
            deposit = vehicleData.deposit,
            locationIndex = locationIndex,
            timestamp = os.time()
        })

        -- Trigger client to spawn vehicle
        TriggerClientEvent('car-rental:client:spawnVehicle', src, vehicleData, locationIndex)

        -- Log rental (optional)
        print(string.format('[Car Rental] Player %s rented a %s for $%s (Deposit: $%s)', identifier, vehicleData.model, vehicleData.price, vehicleData.deposit))
    else
        SendNotification(src, Config.Lang.notEnoughMoney, 'error')
    end
end)

-- Return vehicle event
RegisterNetEvent('car-rental:server:returnVehicle')
AddEventHandler('car-rental:server:returnVehicle', function(deposit)
    local src = source
    local player = GetPlayer(src)

    if not player then
        return
    end

    -- Get player identifier
    local identifier = nil
    if Config.Framework == 'esx' then
        identifier = player.identifier
    elseif Config.Framework == 'qbcore' then
        identifier = player.PlayerData.citizenid
    end

    -- Calculate refund amount
    local refundAmount = math.floor(deposit * (Config.Settings.refundPercentage / 100))

    -- Add money back to player (bank account)
    AddPlayerMoney(player, 'bank', refundAmount)

    -- Remove from rented vehicles tracking
    if rentedVehicles[identifier] then
        -- Remove the first rental (assuming FIFO)
        table.remove(rentedVehicles[identifier], 1)

        -- Clean up if no more rentals
        if #rentedVehicles[identifier] == 0 then
            rentedVehicles[identifier] = nil
        end
    end

    -- Notify player
    SendNotification(src, string.format(Config.Lang.vehicleReturned, refundAmount), 'success')

    -- Log return (optional)
    print(string.format('[Car Rental] Player %s returned vehicle (Refund: $%s)', identifier, refundAmount))
end)

-- Get player rental status (for future features)
RegisterNetEvent('car-rental:server:getRentalStatus')
AddEventHandler('car-rental:server:getRentalStatus', function()
    local src = source
    local player = GetPlayer(src)

    if not player then
        return
    end

    local identifier = nil
    if Config.Framework == 'esx' then
        identifier = player.identifier
    elseif Config.Framework == 'qbcore' then
        identifier = player.PlayerData.citizenid
    end

    local rentals = rentedVehicles[identifier] or {}
    TriggerClientEvent('car-rental:client:receiveRentalStatus', src, rentals)
end)

-- Cleanup on player disconnect
AddEventHandler('playerDropped', function(reason)
    local src = source
    local player = GetPlayer(src)

    if player then
        local identifier = nil
        if Config.Framework == 'esx' then
            identifier = player.identifier
        elseif Config.Framework == 'qbcore' then
            identifier = player.PlayerData.citizenid
        end

        -- Clean up rented vehicles tracking
        if rentedVehicles[identifier] then
            print(string.format('[Car Rental] Cleaning up rentals for disconnected player %s', identifier))
            rentedVehicles[identifier] = nil
        end
    end
end)

-- Admin command to check all active rentals (optional)
if Config.Framework == 'esx' then
    Framework.RegisterCommand('checkrentals', 'admin', function(xPlayer, args, showError)
        local count = 0
        for k, v in pairs(rentedVehicles) do
            count = count + #v
        end
        xPlayer.showNotification(string.format('Active rentals: %s', count))
    end, false, {help = 'Check active car rentals'})
elseif Config.Framework == 'qbcore' then
    Framework.Commands.Add('checkrentals', 'Check active car rentals (Admin Only)', {}, false, function(source, args)
        local src = source
        local count = 0
        for k, v in pairs(rentedVehicles) do
            count = count + #v
        end
        SendNotification(src, string.format('Active rentals: %s', count), 'primary')
    end, 'admin')
end

-- Print startup message
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    print('^2[Car Rental]^7 Script loaded successfully!')
    print('^2[Car Rental]^7 Framework detected: ^3' .. (Config.Framework or 'Unknown') .. '^7')
    print('^2[Car Rental]^7 Rental locations: ^3' .. #Config.RentalLocations .. '^7')
    print('^2[Car Rental]^7 Available vehicles: ^3' .. #Config.Vehicles .. '^7')
end)
