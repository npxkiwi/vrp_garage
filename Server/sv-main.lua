lib.require('@vrp.lib.utils')
local Proxy = require('@vrp.lib.Proxy')
local vRP = Proxy.getInterface('vRP')

lib.callback.register('vald_garage:server:fetchcars', function(source)
    local user_id = vRP.getUserId({source})
    if not user_id then return {} end

    local vehicles = {}

    local result = MySQL.query.await(
        'SELECT * FROM vrp_user_vehicles WHERE user_id = ?',
        { user_id }
    )

    for _, row in pairs(result or {}) do
        local data = nil

        if row.vehicle_data then
            data = json.decode(row.vehicle_data)
        end

        local fuel = 100

        if data then
            fuel = data.fuelLevel
        end

        vehicles[#vehicles+1] = {
            name = row.vehicle_name,
            plate = row.vehicle_plate,
            vehicle = row.vehicle,
            fuel = fuel,
            out = row.stored,
            data = data,
        }
    end

    return vehicles
end)

lib.callback.register('vald_garage:server:getVehicleData', function(source, plate)
    local user_id = vRP.getUserId({source})

    local result = MySQL.query.await(
        'SELECT vehicle, vehicle_data, vehicle_plate, stored FROM vrp_user_vehicles WHERE user_id = ? AND vehicle_plate = ? LIMIT 1',
        { user_id, plate }
    )

    if not result or not result[1] then return nil end

    local row = result[1]
    return {
        vehicle = row.vehicle,
        vehicle_data = row.vehicle_data and json.decode(row.vehicle_data) or nil,
        vehicle_plate = row.vehicle_plate,
        isout = row.stored
    }
end)

lib.callback.register('vald_garage:server:takeOutVehicle', function(source, plate)
    local user_id = vRP.getUserId({source})
    local plate = tostring(plate or ""):gsub("%s+", "")
    local rows = MySQL.update.await([[
        UPDATE vrp_user_vehicles
        SET stored = 1
        WHERE user_id = ? AND vehicle_plate = ?
    ]], {
        user_id,
        plate
    })
    return rows and rows > 0
end)

lib.callback.register('vald_garage:server:storeVehicle', function(source, props)
    local user_id = vRP.getUserId({source})

    if not props then
        print('[vald_garage]: Invalid props')
        return false
    end

    local plate = tostring(props.plate or ""):gsub("%s+", "")

    local rows = MySQL.update.await([[
        UPDATE vrp_user_vehicles
        SET vehicle_data = ?, stored = 0
        WHERE user_id = ? AND vehicle_plate = ?
    ]], {
        json.encode(props),
        user_id,
        plate
    })

    return rows and rows > 0
end)

lib.callback.register('vald_garage:server:changeName', function(source, data)
     local user_id = vRP.getUserId({source})

    if not data then
        print('[vald_garage]: Invalid props')
        return false
    end

    local plate = tostring(data.plate or ""):gsub("%s+", "")

    local rows = MySQL.update.await([[
        UPDATE vrp_user_vehicles
        SET vehicle_name = ?
        WHERE user_id = ? AND vehicle_plate = ?
    ]], {
        data.newName,
        user_id,
        plate
    })

    return rows and rows > 0
end)

lib.callback.register('vald_garage:server:hasJob', function(source, jobName)
    local user_id = vRP.getUserId({ source })

    if not user_id then
        return false
    end

    local hasGroup = vRP.hasGroup({
        user_id,
        jobName
    })

    return hasGroup or false
end)

local function FirstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    local rows = MySQL.update.await([[
            UPDATE vrp_user_vehicles
            SET stored = 0
            WHERE stored = 1
    ]])
    return
end)

local function addCarToPlayer(source, vehicle)
    if not source or not vehicle then
        return false
    end

    local user_id = vRP.getUserId({source})
    if not user_id then
        return false
    end

    local plate = "P"..math.random(1000000,9999999)
    MySQL.insert.await('INSERT INTO vrp_user_vehicles (user_id, vehicle, vehicle_name, vehicle_plate, stored) VALUES (?, ?, ?, ?, 0)', {
        user_id, vehicle, FirstToUpper(vehicle), plate
    })
    return true
end

exports('givePlayerVehicle', addCarToPlayer)

-- How to use export
-- exports['vald_garage']:givePlayerVehicle(source, 'neon')
-- Will return true if success and false if not