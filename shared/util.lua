DJERP = DJERP or {}

function DJERP.Debug(...)
    if Config and Config.Debug then
        print('[dj-erp]', ...)
    end
end

function DJERP.IsEmoteKey(key)
    return type(key) == 'string' and #key >= 1 and #key <= 48 and key:match('^[%w_]+$') ~= nil
end

function DJERP.Clamp(value, minimum, maximum)
    local number = tonumber(value)
    if not number then return nil end
    if number < minimum then return minimum end
    if number > maximum then return maximum end
    return number
end

function DJERP.IsSnowflake(value)
    if type(value) ~= 'string' or not value:match('^%d+$') then
        return false
    end
    return #value >= 16 and #value <= 22
end

function DJERP.CopyList(list)
    local copy = {}
    if type(list) ~= 'table' then return copy end
    for index, value in ipairs(list) do
        copy[index] = value
    end
    return copy
end
