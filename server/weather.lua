-- Add these functions to your server/main.lua file

-- Enhanced: Get current time period (server-side)
local function getCurrentTimePeriod()
    local hour = tonumber(os.date('%H'))
    
    for period, data in pairs(Config.timeEffects) do
        if data.startHour <= data.endHour then
            if hour >= data.startHour and hour <= data.endHour then
                return period, data
            end
        else
            if hour >= data.startHour or hour <= data.endHour then
                return period, data
            end
        end
    end
    
    return 'day', { waitMultiplier = 1.0, chanceBonus = 0, message = 'Standard fishing conditions.' }
end

-- Enhanced: Get current season (server-side)  
local function getCurrentSeason()
    local month = tonumber(os.date('%m'))
    for season, data in pairs(Config.seasons) do
        for _, seasonMonth in ipairs(data.months) do
            if month == seasonMonth then
                return season, data
            end
        end
    end
    return 'spring', Config.seasons.spring
end

-- Enhanced: Calculate environmental effects
local function calculateEnvironmentalEffects(currentZone)
    local timePeriod, timeData = getCurrentTimePeriod()
    local season, seasonData = getCurrentSeason()
    local weather = currentServerWeather
    
    local effects = {
        weather = weather,
        time = timePeriod,
        season = season,
        waitMultiplier = 1.0,
        chanceMultiplier = 1.0,
        weatherMessage = nil,
        timeMessage = timeData.message,
        seasonMessage = seasonData.message
    }
    
    -- Apply weather effects
    if Config.weatherEffects[weather] then
        local weatherEffect = Config.weatherEffects[weather]
        effects.waitMultiplier = effects.waitMultiplier * weatherEffect.waitMultiplier
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + (weatherEffect.chanceBonus or 0) / 100)
        effects.weatherMessage = weatherEffect.message
    end
    
    -- Apply time effects  
    if timeData.waitMultiplier then
        effects.waitMultiplier = effects.waitMultiplier * timeData.waitMultiplier
    end
    if timeData.chanceBonus then
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + timeData.chanceBonus / 100)
    end
    
    return effects
end

-- Enhanced: Weather-aware fish selection
local function getWeatherAwareFish(fishList, effects, currentZone)
    local availableFish = {}
    local totalWeight = 0
    
    for _, fishName in ipairs(fishList) do
        local fish = Config.fish[fishName]
        if fish then
            local weight = fish.chance
            
            -- Apply environmental multipliers
            weight = weight * effects.chanceMultiplier
            
            -- Apply zone rarity multipliers if available
            if currentZone and currentZone.rarityMultiplier and currentZone.rarityMultiplier[fish.rarity] then
                weight = weight * currentZone.rarityMultiplier[fish.rarity]
            end
            
            -- Weather-specific fish bonuses
            if effects.weather == 'RAIN' or effects.weather == 'THUNDER' then
                if fish.rarity == 'rare' or fish.rarity == 'epic' then
                    weight = weight * 1.2
                end
            elseif effects.weather == 'CLEAR' then
                if fish.rarity == 'common' then
                    weight = weight * 1.1
                end
            end
            
            weight = math.max(weight, 0.1)
            
            table.insert(availableFish, { name = fishName, weight = weight })
            totalWeight = totalWeight + weight
        end
    end
    
    if #availableFish == 0 then
        return 'anchovy'
    end
    
    local randomValue = math.random() * totalWeight
    local currentWeight = 0
    
    for _, fish in ipairs(availableFish) do
        currentWeight = currentWeight + fish.weight
        if randomValue <= currentWeight then
            return fish.name
        end
    end
    
    return availableFish[1].name
end

local currentServerWeather = 'CLEAR'
local weatherChangeTimer = 0
local weatherDuration = 600000 -- 10 minutes per weather cycle

-- Weather transition system
local weatherCycle = {
    'CLEAR',
    'CLOUDY', 
    'OVERCAST',
    'RAIN',
    'CLEARING',
    'CLEAR',
    'FOGGY',
    'CLEAR'
}

local weatherIndex = 1

-- Initialize weather system
CreateThread(function()
    Wait(5000) -- Wait for server to load
    
    -- Set initial weather
    currentServerWeather = 'CLEAR'
    TriggerClientEvent('lunar_fishing:weatherChanged', -1, currentServerWeather)
    
    -- Weather cycle loop
    while true do
        Wait(weatherDuration)
        
        -- Advance to next weather in cycle
        weatherIndex = weatherIndex + 1
        if weatherIndex > #weatherCycle then
            weatherIndex = 1
        end
        
        local newWeather = weatherCycle[weatherIndex]
        
        -- Small chance for special weather
        if math.random(100) <= 15 then -- 15% chance
            local specialWeathers = { 'THUNDER', 'SNOW', 'BLIZZARD' }
            newWeather = specialWeathers[math.random(#specialWeathers)]
        end
        
        currentServerWeather = newWeather
        
        -- Notify all players of weather change
        TriggerClientEvent('lunar_fishing:weatherChanged', -1, newWeather)
        
        -- Log weather change
        print(('[FISHING] Weather changed to: %s'):format(newWeather))
    end
end)

-- Get current server weather
lib.callback.register('lunar_fishing:getCurrentWeather', function(source)
    return currentServerWeather
end)

-- Admin command to change weather
RegisterNetEvent('lunar_fishing:setWeather', function(weather)
    local source = source
    local player = Framework.getPlayerFromId(source)
    
    if not player then return end
    
    -- Check if player has admin permissions (adjust based on your permission system)
    local hasPermission = false
    
    if Framework.name == 'es_extended' then
        -- hasPermission = player:hasGroup('admin') -- Uncomment if you have admin groups
        hasPermission = true -- For testing - remove this line and uncomment above
    elseif Framework.name == 'qb-core' then
        -- hasPermission = player:hasOneOfGroups({admin = true}) -- Uncomment if you have admin groups  
        hasPermission = true -- For testing - remove this line and uncomment above
    end
    
    if not hasPermission then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'No permission', 'error')
        return
    end
    
    currentServerWeather = weather
    TriggerClientEvent('lunar_fishing:weatherChanged', -1, weather)
    TriggerClientEvent('lunar_fishing:showNotification', source, ('Weather set to: %s'):format(weather), 'success')
    
    print(('[FISHING] Admin %s changed weather to: %s'):format(GetPlayerName(source), weather))
end)

-- Enhanced fishing with weather effects applied server-side
local function calculateEnvironmentalEffects(currentZone)
    local timePeriod, timeData = getCurrentTimePeriod()
    local season, seasonData = getCurrentSeason()
    local weather = currentServerWeather
    
    local effects = {
        weather = weather,
        time = timePeriod,
        season = season,
        waitMultiplier = 1.0,
        chanceMultiplier = 1.0,
        weatherMessage = nil,
        timeMessage = timeData.message,
        seasonMessage = seasonData.message
    }
    
    -- Apply weather effects
    if Config.weatherEffects[weather] then
        local weatherEffect = Config.weatherEffects[weather]
        effects.waitMultiplier = effects.waitMultiplier * weatherEffect.waitMultiplier
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + (weatherEffect.chanceBonus or 0) / 100)
        effects.weatherMessage = weatherEffect.message
    end
    
    -- Apply time effects
    if timeData.waitMultiplier then
        effects.waitMultiplier = effects.waitMultiplier * timeData.waitMultiplier
    end
    if timeData.chanceBonus then
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + timeData.chanceBonus / 100)
    end
    
    return effects
end

-- Weather-aware fish selection for server
local function getWeatherAwareFish(fishList, effects, currentZone)
    local availableFish = {}
    local totalWeight = 0
    
    for _, fishName in ipairs(fishList) do
        local fish = Config.fish[fishName]
        if fish then
            local weight = fish.chance
            
            -- Apply environmental multipliers
            weight = weight * effects.chanceMultiplier
            
            -- Apply zone rarity multipliers if available
            if currentZone and currentZone.rarityMultiplier and currentZone.rarityMultiplier[fish.rarity] then
                weight = weight * currentZone.rarityMultiplier[fish.rarity]
            end
            
            -- Weather-specific fish bonuses
            if effects.weather == 'RAIN' or effects.weather == 'THUNDER' then
                -- Rain favors certain fish
                if fish.rarity == 'rare' or fish.rarity == 'epic' then
                    weight = weight * 1.2
                end
            elseif effects.weather == 'CLEAR' then
                -- Clear weather is balanced
                if fish.rarity == 'common' then
                    weight = weight * 1.1
                end
            end
            
            weight = math.max(weight, 0.1) -- Ensure minimum chance
            
            table.insert(availableFish, { name = fishName, weight = weight })
            totalWeight = totalWeight + weight
        end
    end
    
    if #availableFish == 0 then
        return 'anchovy' -- Fallback
    end
    
    local randomValue = math.random() * totalWeight
    local currentWeight = 0
    
    for _, fish in ipairs(availableFish) do
        currentWeight = currentWeight + fish.weight
        if randomValue <= currentWeight then
            return fish.name
        end
    end
    
    return availableFish[1].name -- Fallback
end

-- Weather notification system
RegisterNetEvent('lunar_fishing:requestWeatherInfo', function()
    local source = source
    local effects = calculateEnvironmentalEffects(nil)
    
    TriggerClientEvent('lunar_fishing:weatherInfo', source, effects)
end)

-- Export functions for other resources to use
exports('getCurrentWeather', function()
    return currentServerWeather
end)

exports('setWeather', function(weather)
    currentServerWeather = weather
    TriggerClientEvent('lunar_fishing:weatherChanged', -1, weather)
end)

exports('getWeatherEffects', function()
    return Config.weatherEffects[currentServerWeather]
end)