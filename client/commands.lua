-- Enhanced fishing commands system
-- Create this as a new file: client/commands.lua

-- Get current weather from the global variable set in main.lua
local function getCurrentWeatherType()
    return serverWeather or 'CLEAR'
end

-- Get current time period client-side (fixed order)
local function getCurrentTimePeriod()
    local hour = GetClockHours()
    
    -- Check in the correct order to avoid midnight range conflicts
    local timeOrder = { 'dawn', 'morning', 'noon', 'afternoon', 'dusk', 'night' }
    
    for _, period in ipairs(timeOrder) do
        local data = Config.timeEffects[period]
        if data then
            if data.startHour <= data.endHour then
                -- Normal time range (e.g., 8-11)
                if hour >= data.startHour and hour <= data.endHour then
                    return period, data
                end
            else
                -- Time range that crosses midnight (e.g., 21-4)  
                if hour >= data.startHour or hour <= data.endHour then
                    return period, data
                end
            end
        end
    end
    
    return 'day', { waitMultiplier = 1.0, chanceBonus = 0, message = 'Standard fishing conditions.' }
end

-- Get current season client-side
local function getCurrentSeason()
    local month = GetClockMonth()
    
    for season, data in pairs(Config.seasons) do
        for _, seasonMonth in ipairs(data.months) do
            if month == seasonMonth then
                return season, data
            end
        end
    end
    return 'spring', Config.seasons.spring
end

-- Command to show fishing zones and their requirements
RegisterCommand('fishzones', function()
    local playerLevel = GetCurrentLevel()
    local options = {}
    
    for i, zone in ipairs(Config.fishingZones) do
        local isUnlocked = zone.minLevel <= playerLevel
        local distance = currentZone and currentZone.index == i and 0 or 
                        #(GetEntityCoords(cache.ped) - zone.locations[1])
        
        local statusIcon = isUnlocked and '✅' or '🔒'
        local distanceText = distance > 0 and (' (%.0fm away)'):format(distance) or ' (Current Zone)'
        
        table.insert(options, {
            title = statusIcon .. ' ' .. zone.blip.name,
            description = ('Level %d+ | %d fish species%s'):format(
                zone.minLevel, 
                #zone.fishList,
                distanceText
            ),
            disabled = not isUnlocked,
            metadata = isUnlocked and {
                { label = 'Fish Species', value = table.concat(zone.fishList, ', ') },
                { label = 'Wait Time', value = zone.waitTime.min .. '-' .. zone.waitTime.max .. 's' },
                { label = 'Radius', value = zone.radius .. 'm' }
            } or {
                { label = 'Unlock Level', value = zone.minLevel }
            }
        })
    end
    
    lib.registerContext({
        id = 'fishing_zones_info',
        title = '🗺️ Fishing Zones',
        options = options
    })
    
    lib.showContext('fishing_zones_info')
end, false)

-- Command to show current fishing conditions in detail
RegisterCommand('fishconditions', function()
    local weather = getCurrentWeatherType()
    local hour = GetClockHours()
    local minute = GetClockMinutes()
    local currentLevel = GetCurrentLevel()
    local zone = currentZone and Config.fishingZones[currentZone.index]
    
    -- Calculate current time period
    local timePeriod, timeData = getCurrentTimePeriod()
    
    local info = {}
    table.insert(info, '🎣 Current Fishing Conditions:')
    table.insert(info, ('⏰ Time: %02d:%02d (%s)'):format(hour, minute, timePeriod:upper()))
    table.insert(info, ('🌤️ Weather: %s'):format(weather))
    table.insert(info, ('⭐ Your Level: %d'):format(currentLevel))
    
    if zone then
        table.insert(info, ('📍 Zone: %s'):format(zone.blip.name))
    else
        table.insert(info, '📍 Zone: Open Waters')
    end
    
    -- Weather effects
    local weatherEffect = Config.weatherEffects[weather]
    if weatherEffect then
        if weatherEffect.chanceBonus > 0 then
            table.insert(info, ('🌟 Weather Bonus: +%d%% catch rate'):format(weatherEffect.chanceBonus))
        elseif weatherEffect.chanceBonus < 0 then
            table.insert(info, ('⚠️ Weather Penalty: %d%% catch rate'):format(weatherEffect.chanceBonus))
        end
        
        if weatherEffect.waitMultiplier < 1.0 then
            table.insert(info, ('⚡ Faster Fishing: %d%% speed boost'):format(math.floor((1 - weatherEffect.waitMultiplier) * 100)))
        elseif weatherEffect.waitMultiplier > 1.0 then
            table.insert(info, ('🐌 Slower Fishing: %d%% speed reduction'):format(math.floor((weatherEffect.waitMultiplier - 1) * 100)))
        end
    end
    
    -- Time effects
    if timeData.chanceBonus and timeData.chanceBonus ~= 0 then
        if timeData.chanceBonus > 0 then
            table.insert(info, ('🌅 Time Bonus: +%d%% catch rate'):format(timeData.chanceBonus))
        else
            table.insert(info, ('🌙 Time Penalty: %d%% catch rate'):format(timeData.chanceBonus))
        end
    end
    
    ShowNotification(table.concat(info, '\n'), 'inform')
end, false)

-- Enhanced weather info command
RegisterCommand('fishweather', function()
    TriggerServerEvent('lunar_fishing:requestWeatherInfo')
end, false)

-- Command to show fish rarity guide
RegisterCommand('fishrarity', function()
    local rarityInfo = {
        '🐟 COMMON - Easy to catch, low value (20-120$)',
        '🐠 UNCOMMON - Moderately rare, decent value (120-250$)', 
        '🌟 RARE - Hard to find, good money (280-480$)',
        '💎 EPIC - Very rare, high value (450-1500$)',
        '👑 LEGENDARY - Extremely rare, massive value (2000-4000$)',
        '🔮 MYTHICAL - Ultra rare, legendary value (5000-7500$)'
    }
    
    local message = '🎣 Fish Rarity Guide:\n\n' .. table.concat(rarityInfo, '\n')
    ShowNotification(message, 'inform')
end, false)

-- Command to show current inventory of fish
RegisterCommand('fishstats', function()
    local fishCount = {}
    local totalValue = 0
    local totalFish = 0
    
    for fishName, fish in pairs(Config.fish) do
        if Framework.hasItem(fishName) then
            local count = 1 -- Basic count - you might want to get actual inventory count
            fishCount[fish.rarity] = (fishCount[fish.rarity] or 0) + count
            totalFish = totalFish + count
            
            local fishValue = type(fish.price) == 'number' and fish.price or 
                             math.floor((fish.price.min + fish.price.max) / 2)
            totalValue = totalValue + (fishValue * count)
        end
    end
    
    if totalFish == 0 then
        ShowNotification('🎣 No fish in your inventory!', 'inform')
        return
    end
    
    local stats = {}
    table.insert(stats, '🎣 Fish Inventory Stats:')
    table.insert(stats, ('📊 Total Fish: %d'):format(totalFish))
    table.insert(stats, ('💰 Estimated Value: $%d'):format(totalValue))
    
    local rarityOrder = { 'mythical', 'legendary', 'epic', 'rare', 'uncommon', 'common' }
    for _, rarity in ipairs(rarityOrder) do
        if fishCount[rarity] and fishCount[rarity] > 0 then
            local rarityEmojis = {
                mythical = '🔮',
                legendary = '👑', 
                epic = '💎',
                rare = '🌟',
                uncommon = '🐠',
                common = '🐟'
            }
            table.insert(stats, ('%s %s: %d'):format(rarityEmojis[rarity], rarity:upper(), fishCount[rarity]))
        end
    end
    
    ShowNotification(table.concat(stats, '\n'), 'success')
end, false)

-- Command to get fishing tips based on current conditions
RegisterCommand('fishtips', function()
    local weather = getCurrentWeatherType()
    local hour = GetClockHours()
    local currentLevel = GetCurrentLevel()
    local zone = currentZone and Config.fishingZones[currentZone.index]
    
    local tips = {}
    
    -- Weather-based tips
    if weather == 'RAIN' or weather == 'THUNDER' then
        table.insert(tips, '🌧️ Great weather for fishing! Fish are more active in the rain.')
    elseif weather == 'FOGGY' then
        table.insert(tips, '🌫️ Foggy conditions make fishing harder. Consider waiting for better weather.')
    elseif weather == 'CLEAR' then
        table.insert(tips, '☀️ Clear weather provides standard fishing conditions.')
    end
    
    -- Time-based tips
    if hour >= 5 and hour <= 7 then
        table.insert(tips, '🌅 Dawn is one of the best times to fish! Fish are very active.')
    elseif hour >= 18 and hour <= 20 then
        table.insert(tips, '🌆 Dusk is another prime fishing time!')
    elseif hour >= 12 and hour <= 14 then
        table.insert(tips, '☀️ Midday heat makes fish less active. Try early morning or evening.')
    elseif hour >= 22 or hour <= 4 then
        table.insert(tips, '🌙 Night fishing is challenging but can yield unique catches.')
    end
    
    -- Level-based tips
    if currentLevel <= 2 then
        table.insert(tips, '📚 New to fishing? Start in Shallow Waters with basic equipment.')
        table.insert(tips, '💡 Buy better bait to catch fish faster!')
    elseif currentLevel <= 4 then
        table.insert(tips, '🌊 Try the Coral Reef zone for more valuable fish!')
        table.insert(tips, '🎣 Upgrade to a Graphite or Titanium rod for better success.')
    else
        table.insert(tips, '🌊 You can access Deep Waters now - big fish await!')
        table.insert(tips, '🎯 Use Premium or Legendary lures for rare fish.')
    end
    
    -- Zone-specific tips
    if zone then
        if zone.blip.name == 'Coral Reef' then
            table.insert(tips, '🪸 Coral Reefs have tropical fish like Mahi Mahi and Red Snapper.')
        elseif zone.blip.name == 'Deep Waters' then
            table.insert(tips, '🌊 Deep Waters contain the largest and most valuable fish.')
        elseif zone.blip.name == 'Mysterious Swamp' then
            table.insert(tips, '🐊 Swamps are dangerous but contain unique species like Piranha.')
        elseif zone.blip.name == 'Abyssal Depths' then
            table.insert(tips, '🕳️ The Abyss holds mythical creatures - bring your best equipment!')
        end
    else
        table.insert(tips, '🗺️ Explore different fishing zones for unique fish species!')
    end
    
    -- Equipment tips
    table.insert(tips, '🔧 Better rods break less often and have higher success rates.')
    table.insert(tips, '🪱 Different baits affect fishing speed - experiment to find what works!')
    
    if #tips > 0 then
        ShowNotification('💡 Fishing Tips:\n\n' .. table.concat(tips, '\n\n'), 'inform')
    else
        ShowNotification('💡 Keep fishing and experimenting to discover more tips!', 'inform')
    end
end, false)

-- Fishing season information
RegisterCommand('fishseason', function()
    local month = GetClockMonth()
    local season = 'spring' -- default
    
    for seasonName, data in pairs(Config.seasons) do
        for _, seasonMonth in ipairs(data.months) do
            if month == seasonMonth then
                season = seasonName
                break
            end
        end
    end
    
    local seasonInfo = {
        spring = '🌸 Spring: Fish are active after winter. Great for Salmon and Trout.',
        summer = '☀️ Summer: Warm waters bring tropical species. Perfect for Mahi Mahi.',
        autumn = '🍂 Autumn: Migration season. Many fish are moving to warmer waters.',
        winter = '❄️ Winter: Cold waters. Northern fish like Cod and Haddock are more common.'
    }
    
    local currentSeasonInfo = seasonInfo[season] or 'Standard fishing season.'
    ShowNotification(('🗓️ Current Season: %s\n\n%s'):format(season:upper(), currentSeasonInfo), 'inform')
end, false)

-- Quick equipment check command
RegisterCommand('fishgear', function()
    local hasRod = false
    local rodType = 'None'
    local hasBait = false
    local baitType = 'None'
    
    -- Check for rods (from best to worst)
    for i = #Config.fishingRods, 1, -1 do
        local rod = Config.fishingRods[i]
        if Framework.hasItem(rod.name) then
            hasRod = true
            rodType = Utils.getItemLabel(rod.name)
            break
        end
    end
    
    -- Check for bait (from best to worst)
    for i = #Config.baits, 1, -1 do
        local bait = Config.baits[i]
        if Framework.hasItem(bait.name) then
            hasBait = true
            baitType = Utils.getItemLabel(bait.name)
            break
        end
    end
    
    local gearStatus = {}
    table.insert(gearStatus, '🎣 Current Fishing Gear:')
    table.insert(gearStatus, ('🎯 Rod: %s %s'):format(hasRod and '✅' or '❌', rodType))
    table.insert(gearStatus, ('🪱 Bait: %s %s'):format(hasBait and '✅' or '❌', baitType))
    
    if not hasRod then
        table.insert(gearStatus, '\n💡 Visit SeaTrade Corp to buy a fishing rod!')
    end
    
    if not hasBait then
        table.insert(gearStatus, '\n💡 You need bait to fish! Buy some worms to get started.')
    end
    
    if hasRod and hasBait then
        table.insert(gearStatus, '\n🎣 You\'re ready to fish!')
    end
    
    ShowNotification(table.concat(gearStatus, '\n'), hasRod and hasBait and 'success' or 'warn')
end, false)

-- Enhanced: Detailed fishing information command
RegisterCommand('fishinfo', function()
    local currentLevel = GetCurrentLevel()
    local progress = GetCurrentLevelProgress() * 100
    local zone = currentZone and Config.fishingZones[currentZone.index]
    local weather = getCurrentWeatherType()
    
    -- Calculate current time period
    local timePeriod, timeData = getCurrentTimePeriod()
    
    local info = {}
    table.insert(info, ('🎣 Fishing Level: %d (%.1f%% to next)'):format(currentLevel, progress))
    
    if zone then
        table.insert(info, ('📍 Zone: %s (Level %d+)'):format(zone.blip.name, zone.minLevel))
        table.insert(info, ('🐟 Available Fish: %d species'):format(#zone.fishList))
    else
        table.insert(info, '📍 Zone: Open Waters')
    end
    
    -- Weather info
    local weatherEffect = Config.weatherEffects[weather]
    if weatherEffect then
        local bonusText = weatherEffect.chanceBonus > 0 and ('+' .. weatherEffect.chanceBonus .. '%') or 
                         weatherEffect.chanceBonus < 0 and (weatherEffect.chanceBonus .. '%') or 'No effect'
        table.insert(info, ('🌤️ Weather: %s (%s)'):format(weather, bonusText))
    end
    
    -- Time info
    if timeData.chanceBonus and timeData.chanceBonus ~= 0 then
        local bonusText = timeData.chanceBonus > 0 and ('+' .. timeData.chanceBonus .. '%') or (timeData.chanceBonus .. '%')
        table.insert(info, ('⏰ Time: %s (%s)'):format(timePeriod:upper(), bonusText))
    else
        table.insert(info, ('⏰ Time: %s'):format(timePeriod:upper()))
    end
    
    -- Season info
    local season, seasonData = getCurrentSeason()
    table.insert(info, ('🍂 Season: %s'):format(season:upper()))
    
    ShowNotification(table.concat(info, '\n'), 'inform')
end, false)

-- Help command for all fishing commands
RegisterCommand('fishhelp', function()
    local commands = {
        '/fishinfo - Show detailed fishing information',
        '/fishzones - View all fishing zones and requirements', 
        '/fishconditions - Check current weather and time effects',
        '/fishweather - Get detailed weather impact info',
        '/fishrarity - Learn about fish rarity system',
        '/fishstats - View your current fish inventory',
        '/fishtips - Get helpful fishing tips',
        '/fishseason - Check current fishing season info',
        '/fishgear - Check your current equipment',
        '/fishhelp - Show this help menu'
    }
    
    local keybinds = {
        'F6 - Quick fishing info',
        'F7 - Open contracts menu', 
        'F8 - Tournament information',
        'G - Anchor/raise anchor (in boats)',
        'E - Return boat (near dock)'
    }
    
    local helpText = '🎣 Fishing System Help:\n\n' ..
                    '📝 Commands:\n' .. table.concat(commands, '\n') .. '\n\n' ..
                    '⌨️ Keybinds:\n' .. table.concat(keybinds, '\n')
    
    ShowNotification(helpText, 'inform')
end, false)

-- Admin command to force weather (if player has permission)
RegisterCommand('setfishweather', function(source, args)
    if not args[1] then
        ShowNotification('Usage: /setfishweather [CLEAR|RAIN|THUNDER|FOGGY|SNOW]', 'error')
        return
    end
    
    local weather = args[1]:upper()
    local validWeathers = { 'CLEAR', 'RAIN', 'THUNDER', 'FOGGY', 'SNOW', 'CLOUDY', 'OVERCAST' }
    local isValid = false
    
    for _, validWeather in ipairs(validWeathers) do
        if weather == validWeather then
            isValid = true
            break
        end
    end
    
    if not isValid then
        ShowNotification('Invalid weather type! Valid: CLEAR, RAIN, THUNDER, FOGGY, SNOW, CLOUDY, OVERCAST', 'error')
        return
    end
    
    TriggerServerEvent('lunar_fishing:setWeather', weather)
    ShowNotification(('Weather change requested: %s'):format(weather), 'inform')
end, false)

-- Register chat suggestions for easier access
TriggerEvent('chat:addSuggestion', '/fishinfo', 'Show detailed fishing information')
TriggerEvent('chat:addSuggestion', '/fishzones', 'View all fishing zones')
TriggerEvent('chat:addSuggestion', '/fishconditions', 'Check current fishing conditions')
TriggerEvent('chat:addSuggestion', '/fishweather', 'Get detailed weather effects on fishing')
TriggerEvent('chat:addSuggestion', '/fishrarity', 'Learn about fish rarity system')
TriggerEvent('chat:addSuggestion', '/fishstats', 'View your fish inventory')
TriggerEvent('chat:addSuggestion', '/fishtips', 'Get helpful fishing tips')
TriggerEvent('chat:addSuggestion', '/fishseason', 'Check current fishing season')
TriggerEvent('chat:addSuggestion', '/fishgear', 'Check your current equipment')
TriggerEvent('chat:addSuggestion', '/fishhelp', 'Show all fishing commands')
TriggerEvent('chat:addSuggestion', '/setfishweather', 'Admin: Change fishing weather', {{name = 'weather', help = 'CLEAR|RAIN|THUNDER|FOGGY|SNOW'}})