local Config = lib.require('Config.client')
local Shared = lib.require('Config.shared')
local Utils  = lib.require('Client.cl-utils')

local hasJobVehicleOut = false

local function pulloutVehicle(source, plate, isJobVehicle)
    Utils.hideNUI()

    if IsPedInAnyVehicle(cache.ped, false) then
        Utils.notify('Du har allerede et køretøj ude', 'error')
        return
    end

    if not source or not plate then
        Utils.notify('Du kunne ikke hente dette køretøj', 'error')
        return
    end

    local data

    if isJobVehicle then
        for _, garages in pairs(Config.JobGarages) do
            for _, garage in pairs(garages) do
                for _, veh in pairs(garage.vehicles) do
                    if veh.carModel == plate then
                        hasJobVehicleOut = true
                        data = {
                            vehicle = veh.carModel,
                            vehicle_plate = "POL"..math.random(10000,99999),
                            vehicle_data = {}
                        }
                        break
                    end
                end
            end
        end
    else
        data = lib.callback.await('vald_garage:server:getVehicleData', false, plate)
    end

    if not data then
        Utils.notify('Køretøj ikke fundet', 'error')
        return
    end

    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)

    local spawnCoords = coords + (forward * 3.0)

    local isClear = true
    local radius = 3.0

    for _, veh in pairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(veh) - spawnCoords) < radius then
            isClear = false
            break
        end
    end

    if not isClear then
        Utils.notify('Området er ikke frit til at tage køretøjet ud', 'error')
        return
    end

    if not isJobVehicle then
        local stored = lib.callback.await('vald_garage:server:takeOutVehicle', false, plate)

        if not stored then
            Utils.notify('Køretøj fejl', 'error')
            return
        end
    end

    local model = joaat(data.vehicle)

    lib.requestModel(model)

    while not HasModelLoaded(model) do
        Wait(10)
    end

    local vehicle = CreateVehicle(
        model,
        spawnCoords.x,
        spawnCoords.y,
        spawnCoords.z,
        GetEntityHeading(ped),
        true,
        false
    )

    SetVehicleNumberPlateText(vehicle, data.vehicle_plate)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)

    if data.vehicle_data then
        lib.setVehicleProperties(vehicle, data.vehicle_data)
    end

    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    SetModelAsNoLongerNeeded(model)

    Utils.notify('Du hentede dit køretøj', 'success')
end

local function storeVehicle(source)
    local veh = GetVehiclePedIsIn(source, false)

    if veh == 0 then
        Utils.notify('Du er ikke i et køretøj', 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    local props = lib.getVehicleProperties(veh)

    local success = lib.callback.await('vald_garage:server:storeVehicle', false, props)

    if success then
        TaskLeaveVehicle(cache.ped, veh)

        Wait(1000)

        DeleteEntity(veh)

        Utils.notify('Køretøj parkeret', 'success')
    end
end

local function openMenu(isJobGarage, garageVehicles)
    local formatted = {}

    if isJobGarage then
        for _, veh in pairs(garageVehicles or {}) do
            formatted[#formatted+1] = {
                name = veh.carName,
                plate = veh.carModel,
                fuel = 100,
                vehicleBody = 1000,
                out = false,
                isJobVehicle = true
            }
        end
    else
        local vehicles = lib.callback.await('vald_garage:server:fetchcars', false)

        for _, v in pairs(vehicles) do
            local data = {}

            if type(v.data) == "table" then
                data = v.data
            end

            formatted[#formatted+1] = {
                name = v.name,
                plate = v.plate,
                fuel = data.fuelLevel or math.random(10,100),
                vehicleBody = data.bodyHealth or 1000,
                out = v.out,
                isJobVehicle = false
            }
        end
    end

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = "open",
        vehicles = formatted,
        isJobGarage = isJobGarage or false
    })
end

RegisterNUICallback('takeOutVehicle', function(data, cb)
    if not data or not data.plate then
        cb('error')
        return
    end

    isOpen = false

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = "close"
    })

    Wait(100)

    pulloutVehicle(
        cache.ped,
        data.plate,
        data.isJobVehicle
    )

    cb('ok')
end)

RegisterNUICallback('renameVehicle', function(data, cb)
    if not data or not data.plate or not data.newName then
        cb('error')
        return
    end

    local success = lib.callback.await('vald_garage:server:changeName', false, data)

    if success then
        cb('ok')
        return
    end
end)

RegisterNUICallback('close', function(_, cb)
    isOpen = false

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = "close"
    })

    cb('ok')
end)

CreateThread(function()

    for _, v in pairs(Config.Garages) do
        local currentState = nil

        local blip = AddBlipForCoord(v.pos.x, v.pos.y, v.pos.z)

        SetBlipSprite(blip, 357)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 3)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Garage')
        EndTextCommandSetBlipName(blip)

        lib.zones.sphere({
            coords = v.pos,
            radius = 5,

            inside = function()

                DrawMarker(
                    36,
                    v.pos.x, v.pos.y, v.pos.z - 0.2,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    0.8, 0.8, 0.8,
                    288, 137, 34, 255,
                    false, true, 2, nil, nil, false
                )

                local ped = cache.ped
                local inVeh = IsPedInAnyVehicle(ped, false)

                if currentState ~= inVeh then
                    currentState = inVeh

                    lib.removeRadialItem('garage_access')

                    if inVeh then
                        lib.addRadialItem({
                            id = 'garage_access',
                            icon = 'warehouse',
                            label = 'Parker',
                            onSelect = function()
                                storeVehicle(ped)
                            end
                        })
                    else
                        lib.addRadialItem({
                            id = 'garage_access',
                            icon = 'warehouse',
                            label = 'Åben garage',
                            onSelect = function()
                                openMenu(false)
                            end
                        })
                    end
                end
            end,

            onExit = function()
                lib.removeRadialItem('garage_access')
                currentState = nil
            end
        })
    end

    for jobName, garages in pairs(Config.JobGarages) do
        for _, garage in pairs(garages) do
            local currentState = nil

            lib.zones.sphere({
                coords = garage.pos,
                radius = 5,

                inside = function()

                    DrawMarker(
                        36,
                        garage.pos.x, garage.pos.y, garage.pos.z - 0.2,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.8, 0.8, 0.8,
                        50, 150, 255, 255,
                        false, true, 2, nil, nil, false
                    )

                    local ped = cache.ped
                    local inVeh = IsPedInAnyVehicle(ped, false)

                    if currentState ~= inVeh then
                        currentState = inVeh

                        lib.removeRadialItem('job_garage_access')

                        if not inVeh then
                            lib.addRadialItem({
                                id = 'job_garage_access',
                                icon = 'warehouse',
                                label = 'Åben garage',

                                onSelect = function()

                                    local hasJob = lib.callback.await(
                                        'vald_garage:server:hasJob',
                                        false,
                                        jobName
                                    )

                                    if not hasJob then
                                        Utils.notify('Du har ikke adgang til denne garage', 'error')
                                        return
                                    end

                                    if hasJobVehicleOut then
                                        Utils.notify('Du har allerede et køretøj ude!', 'error')
                                        return
                                    end

                                    openMenu(true, garage.vehicles)
                                end
                            })
                        else
                            lib.addRadialItem({
                                id = 'job_garage_access',
                                icon = 'warehouse',
                                label = 'Parker',

                                onSelect = function()
                                    local veh = GetVehiclePedIsIn(cache.ped, false)

                                    TaskLeaveVehicle(cache.ped, veh)

                                    Wait(1000)

                                    DeleteEntity(veh)

                                    hasJobVehicleOut = false

                                    Utils.notify('Køretøjet er parkeret', 'success')
                                end
                            })
                        end
                    end
                end,

                onExit = function()
                    lib.removeRadialItem('job_garage_access')
                    currentState = nil
                end
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    lib.hideTextUI()
end)