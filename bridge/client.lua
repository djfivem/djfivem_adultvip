local framework

local function detect()
    local mode = Config.Framework or 'auto'
    if mode ~= 'auto' then return mode end
    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return 'standalone'
end

local function feed(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

RegisterNetEvent('djerp:client:notify', function(message, kind)
    if type(message) ~= 'string' or message == '' then return end
    kind = kind or 'info'
    framework = framework or detect()

    local delivered = false
    if Config.Notify.UseOxLib and GetResourceState('ox_lib') == 'started' then
        local oxType = kind == 'error' and 'error' or kind == 'success' and 'success' or 'inform'
        delivered = pcall(function()
            exports.ox_lib:notify({ description = message, type = oxType })
        end)
    end

    if not delivered and (framework == 'qbcore' or framework == 'qbox') then
        local qbType = kind == 'error' and 'error' or kind == 'success' and 'success' or 'primary'
        delivered = pcall(function()
            TriggerEvent('QBCore:Notify', message, qbType)
        end)
    end

    if not delivered and framework == 'esx' then
        delivered = pcall(function()
            TriggerEvent('esx:showNotification', message)
        end)
    end

    if not delivered then
        feed(message)
    end

    SendNUIMessage({
        action = 'toast',
        message = message,
        kind = kind,
    })
end)
