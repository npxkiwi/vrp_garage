local Shared = lib.require('Config.shared')
---@class Utils -> Utils Class
local Utils = {}

Utils.debug = function(...)
    if not Shared.DevMode then
        return
    end

    print(("[Debug]: %s"):format(tostring(...)))
end

Utils.notify = function(_message, _type)
    if not type(_message) == "string" or not type(_type) =="string" then
        return
    end

    lib.notify({
        title = 'Garage',
        description = _message,
        type = _type
    })
end

Utils.hideNUI = function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

Utils.getPlayerVehicles = function()
    return lib.callback.await('vald_garage:server:fetchcars', false)
end

Utils.isPlayerVehicleOwner = function(source, vehiclePlate)
    if not source or not vehiclePlate then
        return false
    end

    return lib.callback.await('vald_garage:server:isCarOwner', false, vehiclePlate)
end

return Utils