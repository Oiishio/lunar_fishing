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

-- New: Get current season based on month
local function getCurrentSeason()
    local month = tonumber(os.date('%m'))
    for season, data in pairs(Config.seasons) do
        for _, seasonMonth in ipairs(data.months) do
            if month == seasonMonth then
                return season
            end
        end
    end
    return 'spring' -- fallback
end

-- New: Get current time period
local function getCurrentTimePeriod()
    local hour = tonumber(os.date('%H'))
    
    if hour >= 5 and hour <= 7 then
        return 'dawn'
    elseif hour >= 17 and hour <= 19 then
        return 'dusk'
    elseif hour >= 22 or hour <= 4 then
        return 'night'
    else
        return 'day'
    end
end

-- New: Enhanced fish selection with weather, time, and season effects
---@param fishList string[]
---@param playerLevel integer
---@param zone FishingZone?
local function getRandomFish(fishList, playerLevel, zone)
    local currentSeason = getCurrentSeason()
    local currentTime = getCurrentTimePeriod()
    local weather = GetCurrentWeatherType()
    
    local availableFish = {}
    local totalWeight = 0
    
    for _, fishName in ipairs(fishList) do
        local fish = Config.fish[fishName]
        if fish then
            local weight = fish.chance
            
            -- Apply seasonal modifiers
            if fish.season and not fish.season[currentSeason] then
                weight = weight * 0.3 -- Reduce chance for out-of-season fish
            end
            
            -- Apply time preferences
            if fish.timePreference and fish.timePreference[currentTime] then
                weight = weight * 1.5 -- Increase chance during preferred times
            end
            
            -- Apply weather effects
            if Config.weatherEffects[weather] then
                local weatherBonus = Config.weatherEffects[weather].chanceBonus or 0
                weight = weight * (1 + weatherBonus / 100)
            end
            
            -- Apply zone rarity multipliers
            if zone and zone.rarityMultiplier and zone.rarityMultiplier[fish.rarity] then
                weight = weight * zone.rarityMultiplier[fish.rarity]
            end
            
            weight = math.max(weight, 1) -- Ensure minimum chance
            
            table.insert(availableFish, { name = fishName, weight = weight })
            totalWeight = totalWeight + weight
        end
    end
    
    if #availableFish == 0 then
        return 'anchovy' -- Fallback fish
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

-- New: Enhanced bait selection with rarity bonuses
---@param player Player
---@return FishingBait?, table<string, number>?
local function getBestBait(player)
    local bestBait = nil
    local rarityBonuses = {}
    
    for i = #Config.baits, 1, -1 do
        local bait = Config.baits[i]
        
        if player:getItemCount(bait.name) > 0 then
            bestBait = bait
            rarityBonuses = bait.rarityBonus or {}
            break
        end
    end
    
    return bestBait, rarityBonuses
end

-- New: Check player achievements
---@param player Player
---@param achievementData table
local function checkAchievements(player, achievementData)
    local identifier = player:getIdentifier()
    local playerStats = GetPlayerStats(identifier) -- You'll need to implement this
    
    for _, achievement in ipairs(Config.achievements) do
        if not playerStats.achievements[achievement.id] then
            local completed = false
            
            if achievement.requirement.type == 'total_caught' then
                completed = playerStats.totalCaught >= achievement.requirement.amount
            elseif achievement.requirement.type == 'rarity_caught' then
                local count = playerStats.rarityCounts[achievement.requirement.rarity] or 0
                completed = count >= achievement.requirement.amount
            elseif achievement.requirement.type == 'zones_visited' then
                completed = Utils.getTableSize(playerStats.zonesVisited) >= achievement.requirement.amount
            end
            
            if completed then
                -- Award achievement
                playerStats.achievements[achievement.id] = true
                
                if achievement.reward.xp then
                    AddPlayerLevel(player, achievement.reward.xp)
                end
                
                if achievement.reward.money then
                    player:addAccountMoney('money', achievement.reward.money)
                end
                
                if achievement.reward.items then
                    for itemName, amount in pairs(achievement.reward.items) do
                        player:addItem(itemName, amount)
                    end
                end
                
                TriggerClientEvent('lunar_fishing:showNotification', player.source, 
                    ('Achievement Unlocked: %s'):format(achievement.title), 'success')
            end
        end
    end
end

-- New: Enhanced rod durability system
local rodDurability = {} -- Store rod durability per player

---@param player Player
---@param rodName string
local function checkRodDurability(player, rodName)
    local identifier = player:getIdentifier()
    
    if not rodDurability[identifier] then
        rodDurability[identifier] = {}
    end
    
    if not rodDurability[identifier][rodName] then
        -- Find rod config for durability
        for _, rod in ipairs(Config.fishingRods) do
            if rod.name == rodName then
                rodDurability[identifier][rodName] = rod.durability
                break
            end
        end
    end
    
    rodDurability[identifier][rodName] = rodDurability[identifier][rodName] - 1
    
    if rodDurability[identifier][rodName] <= 0 then
        player:removeItem(rodName, 1)
        rodDurability[identifier][rodName] = nil
        TriggerClientEvent('lunar_fishing:showNotification', player.source, locale('rod_broke'), 'error')
        return false
    end
    
    -- Warn player when rod is getting low on durability
    if rodDurability[identifier][rodName] <= 10 then
        TriggerClientEvent('lunar_fishing:showNotification', player.source, 
            ('Your rod is wearing out! Durability: %d'):format(rodDurability[identifier][rodName]), 'warn')
    end
    
    return true
end

---@type table<integer, boolean>
local busy = {}

-- Enhanced fishing rod usage with new features
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

        local zone = currentZone and Config.fishingZones[currentZone.index] or nil
        local fishList = zone and zone.fishList or Config.outside.fishList
        local bait, rarityBonuses = getBestBait(player)

        if not bait then
            TriggerClientEvent('lunar_fishing:showNotification', source, locale('no_bait'), 'error')
            busy[source] = nil
            return
        end
        
        -- Enhanced fish selection with new system
        local fishName = getRandomFish(fishList, GetPlayerLevel(player), zone)
        local fish = Config.fish[fishName]

        if not player:canCarryItem(fishName, 1) then
            TriggerClientEvent('lunar_fishing:showNotification', source, locale('inventory_full'), 'error')
            busy[source] = nil
            return
        end
            
        player:removeItem(bait.name, 1)
        
        -- Apply weather effects to wait time
        local waitTimeMultiplier = 1.0
        local weather = GetCurrentWeatherType()
        if Config.weatherEffects[weather] then
            waitTimeMultiplier = Config.weatherEffects[weather].waitMultiplier
        end
        
        -- Apply time effects
        local currentTime = getCurrentTimePeriod()
        if Config.timeEffects[currentTime] then
            waitTimeMultiplier = waitTimeMultiplier * Config.timeEffects[currentTime].waitMultiplier
        end
        
        -- Apply rod catch bonus to fish skillcheck
        local enhancedFish = table.clone(fish)
        if rod.catchBonus > 1.0 then
            -- Make skillcheck slightly easier with better rods
            local skillcheckCopy = table.clone(fish.skillcheck)
            if #skillcheckCopy > 1 and math.random() < (rod.catchBonus - 1.0) then
                table.remove(skillcheckCopy) -- Remove one difficulty level
            end
            enhancedFish.skillcheck = skillcheckCopy
        end
        
        local success = lib.callback.await('lunar_fishing:itemUsed', source, bait, enhancedFish, waitTimeMultiplier)

        if success then
            -- Calculate dynamic price
            local price = type(fish.price) == 'number' and fish.price or math.random(fish.price.min, fish.price.max)
            
            player:ad
