math.randomseed(os.time())

---@param first { price: integer }
---@param second { price: integer }
local function sortByPrice(first, second)
    return first.price < second.price
end

table.sort(Config.fishingRods, sortByPrice)
table.sort(Config.baits, sortByPrice)

-- Merge outside fish with zone fish if includeOutside is true
for _, zone in ipairs(Config.fishingZones) do
    if zone.includeOutside then
        for _, fishName in ipairs(Config.outside.fishList) do
            table.insert(zone.fishList, fishName)
        end
    end
end

-- Weather system
local currentServerWeather = 'CLEAR'
local weatherChangeTimer = 0
local weatherDuration = 600000 -- 10 minutes per weather cycle

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

-- FIXED: Enhanced: Calculate environmental effects using CLIENT TIME
local function calculateEnvironmentalEffects(currentZone, clientHour)
    -- Use client-provided hour instead of server os.date
    local hour = clientHour or 12 -- fallback to noon if no hour provided
    
    print('[DEBUG] Server using client hour:', hour)
    
    local timePeriod = 'day'
    local timeData = { waitMultiplier = 1.0, chanceBonus = 0, message = 'Standard fishing conditions.' }
    
    -- Use the same logic as client
    if hour >= 5 and hour <= 7 then
        timePeriod = 'dawn'
        timeData = Config.timeEffects.dawn
    elseif hour >= 8 and hour <= 11 then
        timePeriod = 'morning'
        timeData = Config.timeEffects.morning
    elseif hour >= 12 and hour <= 14 then
        timePeriod = 'noon'
        timeData = Config.timeEffects.noon
    elseif hour >= 15 and hour <= 17 then
        timePeriod = 'afternoon'
        timeData = Config.timeEffects.afternoon
    elseif hour >= 18 and hour <= 20 then
        timePeriod = 'dusk'
        timeData = Config.timeEffects.dusk
    elseif hour >= 21 or hour <= 4 then
        timePeriod = 'night'
        timeData = Config.timeEffects.night
    end
    
    print('[DEBUG] Server calculated time period:', timePeriod)
    
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
            
            -- Seasonal bonuses
            local season, seasonData = getCurrentSeason()
            if seasonData.fishBonus then
                for _, bonusFish in ipairs(seasonData.fishBonus) do
                    if fishName == bonusFish then
                        weight = weight * 1.3
                        break
                    end
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

---@param player Player
---@return FishingBait?
local function getBestBait(player)
    for i = #Config.baits, 1, -1 do
        local bait = Config.baits[i]

        if player:getItemCount(bait.name) > 0 then
            return bait
        end
    end
end

---@type table<integer, boolean>
local busy = {}

-- FIXED: Enhanced fishing rod usage with CLIENT TIME synchronization
for _, rod in ipairs(Config.fishingRods) do
    Framework.registerUsableItem(rod.name, function(source)
        local player = Framework.getPlayerFromId(source)

        if not player or player:getItemCount(rod.name) == 0 or busy[source] then return end

        busy[source] = true

        ---@type boolean, { index: integer, locationIndex: integer }?
        local hasWater, currentZone = lib.callback.await('lunar_fishing:getCurrentZone', source)

        if not hasWater then
            busy[source] = nil
            return
        end

        -- Check if player is in valid zone
        if currentZone then
            local data = Config.fishingZones[currentZone.index]
            local coords = data.locations[currentZone.locationIndex]

            if #(GetEntityCoords(GetPlayerPed(source)) - coords) > data.radius then
                busy[source] = nil
                return
            end
        end

        local fishList = currentZone and Config.fishingZones[currentZone.index].fishList or Config.outside.fishList
        local bait = getBestBait(player)

        if not bait then
            TriggerClientEvent('lunar_fishing:showNotification', source, locale('no_bait'), 'error')
            busy[source] = nil
            return
        end
        
        -- FIXED: GET CLIENT TIME FIRST
        local clientHour = lib.callback.await('lunar_fishing:getClientHour', source)
        print('[DEBUG] Got client hour from client:', clientHour)
        
        -- Enhanced: Use weather-aware fish selection WITH CLIENT TIME
        local environmentalEffects = calculateEnvironmentalEffects(
            currentZone and Config.fishingZones[currentZone.index] or nil, 
            clientHour
        )
        local fishName = getWeatherAwareFish(fishList, environmentalEffects, currentZone and Config.fishingZones[currentZone.index] or nil)

        if not player:canCarryItem(fishName, 1) then
            TriggerClientEvent('lunar_fishing:showNotification', source, 'Inventory full!', 'error')
            busy[source] = nil
            return
        end
            
        player:removeItem(bait.name, 1)
        
        local success = lib.callback.await('lunar_fishing:itemUsed', source, bait, Config.fish[fishName], environmentalEffects)

        if success then
            player:addItem(fishName, 1)
            AddPlayerLevel(player, Config.progressPerCatch)
            
            -- Calculate fish value for notifications
            local fish = Config.fish[fishName]
            local fishValue = type(fish.price) == 'number' and fish.price or math.random(fish.price.min, fish.price.max)
            
            -- Enhanced notification based on rarity
            local rarityEmojis = {
                common = '🐟',
                uncommon = '🐠', 
                rare = '🌟',
                epic = '💎',
                legendary = '👑',
                mythical = '🔮'
            }
            
            local emoji = rarityEmojis[fish.rarity] or '🐟'
            local message = ('%s Caught a %s %s! ($%d)'):format(
                emoji,
                fish.rarity:upper(),
                Utils.getItemLabel(fishName),
                fishValue
            )
            
            TriggerClientEvent('lunar_fishing:showNotification', source, message, 'success')
            TriggerClientEvent('lunar_fishing:fishCaught', source, fishName, fish.rarity, fishValue)
            
            Utils.logToDiscord(source, player, ('Caught a %s %s (Rarity: %s, Weather: %s)'):format(
                Utils.getItemLabel(fishName),
                fish.rarity,
                currentZone and Config.fishingZones[currentZone.index].blip.name or 'Open Waters',
                currentServerWeather
            ))
            
        elseif math.random(100) <= rod.breakChance then
            player:removeItem(rod.name, 1)
            TriggerClientEvent('lunar_fishing:showNotification', source, locale('rod_broke'), 'error')
        end

        busy[source] = nil
    end)
end

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
        
        -- Announce weather changes
        local weatherEffect = Config.weatherEffects[newWeather]
        if weatherEffect and weatherEffect.message then
            TriggerClientEvent('lunar_fishing:showNotification', -1, '🌤️ ' .. weatherEffect.message, 'inform')
        end
        
        print(('[FISHING] Weather changed to: %s'):format(newWeather))
    end
end)

-- Weather system callbacks
lib.callback.register('lunar_fishing:getCurrentWeather', function(source)
    return currentServerWeather
end)

-- FIXED: Environmental effects now use client time
lib.callback.register('lunar_fishing:getEnvironmentalEffects', function(source)
    local clientHour = lib.callback.await('lunar_fishing:getClientHour', source)
    return calculateEnvironmentalEffects(nil, clientHour)
end)

-- Admin weather control
RegisterNetEvent('lunar_fishing:setWeather', function(weather)
    local source = source
    local player = Framework.getPlayerFromId(source)
    
    if not player then return end
    
    -- Check admin permissions (adjust based on your system)
    local hasPermission = true -- For testing - implement proper permission check
    
    if not hasPermission then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'No permission', 'error')
        return
    end
    
    currentServerWeather = weather
    TriggerClientEvent('lunar_fishing:weatherChanged', -1, weather)
    TriggerClientEvent('lunar_fishing:showNotification', source, ('Weather set to: %s'):format(weather), 'success')
    
    print(('[FISHING] Admin %s changed weather to: %s'):format(GetPlayerName(source), weather))
end)

-- FIXED: Weather info request using client time
RegisterNetEvent('lunar_fishing:requestWeatherInfo', function()
    local source = source
    
    -- Get client time first
    local clientHour = lib.callback.await('lunar_fishing:getClientHour', source)
    local effects = calculateEnvironmentalEffects(nil, clientHour)
    
    -- Send data back to client
    TriggerClientEvent('lunar_fishing:weatherInfo', source, effects)
end)

-- Simple contract system
local activeContracts = {}

-- Register the callback that was missing
lib.callback.register('lunar_fishing:getActiveContracts', function(source)
    return activeContracts
end)

-- Register tournament info callback  
lib.callback.register('lunar_fishing:getTournamentInfo', function(source)
    return nil -- No tournament system for now
end)

-- Simple contract generation
local function generateSimpleContracts()
    activeContracts = {
        {
            id = 'contract_1',
            title = 'Catch 5 Fish',
            description = 'Catch any 5 fish for a bonus reward.',
            type = 'catch_any',
            target = { amount = 5 },
            reward = { money = 500, xp = 0.1 }
        },
        {
            id = 'contract_2', 
            title = 'Catch Valuable Fish',
            description = 'Catch fish worth at least $1000 total.',
            type = 'catch_value',
            target = { value = 1000 },
            reward = { money = 800, xp = 0.15 }
        },
        {
            id = 'contract_3',
            title = 'Rare Fish Hunter',
            description = 'Catch 3 rare or better fish.',
            type = 'catch_rarity',
            target = { rarity = 'rare', amount = 3 },
            reward = { money = 1200, xp = 0.2 }
        }
    }
end

-- Initialize contracts
CreateThread(function()
    Wait(5000)
    generateSimpleContracts()
    
    -- Refresh contracts every hour
    SetInterval(function()
        generateSimpleContracts()
        TriggerClientEvent('lunar_fishing:contractsRefreshed', -1, activeContracts)
    end, 3600000)
end)

-- Export functions for other resources
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