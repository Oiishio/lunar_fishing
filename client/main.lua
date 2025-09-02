---@param first { price: integer }
---@param second { price: integer }
local function sortByPrice(first, second)
    return first.price < second.price
end

table.sort(Config.fishingRods, sortByPrice)
table.sort(Config.baits, sortByPrice)

---@type { normal: number, radius: number }[], CZone[]
local blips, zones = {}, {}
---@type { index: integer, locationIndex: integer }?
local currentZone

-- New: Tournament and contract data
local activeTournament = nil
local activeContracts = {}
local playerContracts = {}

-- New: Weather and time display
local weatherDisplay = nil
local timeDisplay = nil

-- Enhanced: Server-synced weather system
local serverWeather = 'CLEAR'

-- Enhanced: Use server weather instead of client detection
local function getCurrentWeatherType()
    return serverWeather
end

-- FIXED: Get current time period (client-side) - CONSISTENT WITH SERVER
local function getCurrentTimePeriod()
    local hour = GetClockHours()
    
    print('[DEBUG] Client hour:', hour) -- Debug line
    
    if hour >= 5 and hour <= 7 then
        print('[DEBUG] Client time period: dawn')
        return 'dawn', Config.timeEffects.dawn
    elseif hour >= 8 and hour <= 11 then
        print('[DEBUG] Client time period: morning')
        return 'morning', Config.timeEffects.morning
    elseif hour >= 12 and hour <= 14 then
        print('[DEBUG] Client time period: noon')
        return 'noon', Config.timeEffects.noon
    elseif hour >= 15 and hour <= 17 then
        print('[DEBUG] Client time period: afternoon')
        return 'afternoon', Config.timeEffects.afternoon
    elseif hour >= 18 and hour <= 20 then
        print('[DEBUG] Client time period: dusk')
        return 'dusk', Config.timeEffects.dusk
    elseif hour >= 21 or hour <= 4 then
        print('[DEBUG] Client time period: night')
        return 'night', Config.timeEffects.night
    else
        print('[DEBUG] Client time period: fallback day')
        return 'day', { waitMultiplier = 1.0, chanceBonus = 0, message = 'Standard fishing conditions.' }
    end
end

-- FIXED: NEW CALLBACK - Send client time to server
lib.callback.register('lunar_fishing:getClientHour', function()
    local hour = GetClockHours()
    print('[DEBUG] Client sending hour to server:', hour)
    return hour
end)

-- Enhanced: Weather change notifications with detailed effects - DEFINED BEFORE USE
local function showWeatherChangeEffect(weather)
    local effect = Config.weatherEffects[weather]
    if not effect then return end
    
    local message = effect.message
    local details = {}
    
    if effect.waitMultiplier ~= 1.0 then
        local speedChange = math.floor((1 - effect.waitMultiplier) * 100)
        if speedChange > 0 then
            table.insert(details, ('⚡ %d%% faster fishing'):format(speedChange))
        else
            table.insert(details, ('🐌 %d%% slower fishing'):format(math.abs(speedChange)))
        end
    end
    
    if effect.chanceBonus ~= 0 then
        table.insert(details, ('🎯 %s%d%% catch rate'):format(effect.chanceBonus > 0 and '+' or '', effect.chanceBonus))
    end
    
    if #details > 0 then
        message = message .. ' (' .. table.concat(details, ', ') .. ')'
    end
    
    ShowNotification(message, effect.chanceBonus >= 0 and 'success' or 'warn')
end

-- NOW the event handlers can use the function
RegisterNetEvent('lunar_fishing:weatherChanged', function(weather)
    local oldWeather = serverWeather
    serverWeather = weather
    
    -- Show weather change notification with effects
    if oldWeather ~= weather then
        showWeatherChangeEffect(weather)
    end
end)

-- FIXED: No double notification
RegisterNetEvent('lunar_fishing:weatherInfo', function(effects)
    -- Only show notification when explicitly requested via command
    if effects and effects.weather then
        local info = {}
        table.insert(info, '🌤️ Server Environmental Conditions:')
        table.insert(info, ('Weather: %s'):format(effects.weather))
        table.insert(info, ('Time: %s'):format(effects.time:upper()))
        table.insert(info, ('Season: %s'):format(effects.season:upper()))
        
        if effects.chanceMultiplier and effects.chanceMultiplier > 1.0 then
            table.insert(info, ('🌟 Total Bonus: +%d%% catch rate'):format(math.floor((effects.chanceMultiplier - 1) * 100)))
        elseif effects.chanceMultiplier and effects.chanceMultiplier < 1.0 then
            table.insert(info, ('⚠️ Total Penalty: %d%% catch rate'):format(math.floor((1 - effects.chanceMultiplier) * 100)))
        end
        
        if effects.waitMultiplier and effects.waitMultiplier < 1.0 then
            table.insert(info, ('⚡ Fishing Speed: +%d%%'):format(math.floor((1 - effects.waitMultiplier) * 100)))
        elseif effects.waitMultiplier and effects.waitMultiplier > 1.0 then
            table.insert(info, ('🐌 Fishing Speed: -%d%%'):format(math.floor((effects.waitMultiplier - 1) * 100)))
        end
        
        ShowNotification(table.concat(info, '\n'), 'inform')
    end
end)

---@param level number
local function updateBlips(level)
    for _, blip in ipairs(blips) do
        RemoveBlip(blip.normal)
        RemoveBlip(blip.radius)
    end

    table.wipe(blips)

    for _, zone in ipairs(Config.fishingZones) do
        if zone.blip and zone.minLevel <= level then
            for _, coords in ipairs(zone.locations) do
                local blip = Utils.createBlip(coords, {
                    name = zone.blip.name,
                    sprite = zone.blip.sprite,
                    color = zone.blip.color,
                    scale = zone.blip.scale
                })
                local radiusBlip = Utils.createRadiusBlip(coords, zone.radius, zone.blip.color)
                
                table.insert(blips, { normal = blip, radius = radiusBlip })
            end
        end
    end
end

---@param level number
local function updateZones(level)
    for _, zone in ipairs(zones) do
        zone:remove()
    end

    table.wipe(zones)

    for index, data in ipairs(Config.fishingZones) do
        if data.minLevel <= level then
            for locationIndex, coords in ipairs(data.locations) do
                local zone = lib.zones.sphere({
                    coords = coords,
                    radius = data.radius,
                    onEnter = function()
                        if currentZone?.index == index and currentZone?.locationIndex == locationIndex then return end

                        currentZone = { index = index, locationIndex = locationIndex }
    
                        if data.message then
                            ShowNotification(data.message.enter, 'success')
                        end
                        
                        -- Show zone fishing info
                        local zoneInfo = ('Zone: %s | Min Level: %d | Fish Types: %d'):format(
                            data.blip.name,
                            data.minLevel,
                            #data.fishList
                        )
                        ShowNotification(zoneInfo, 'inform')
                    end,
                    onExit = function()
                        if currentZone?.index ~= index
                        or currentZone?.locationIndex ~= locationIndex then return end
    
                        currentZone = nil

                        if data.message then
                            ShowNotification(data.message.exit, 'inform')
                        end
                    end
                })
    
                table.insert(zones, zone)
            end
        end
    end
end

---@param level integer
function Update(level)
    updateBlips(level)
    updateZones(level)
end

local function createRodObject()
    local model = `prop_fishing_rod_01`

    lib.requestModel(model)

    local coords = GetEntityCoords(cache.ped)
    local object = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    local boneIndex = GetPedBoneIndex(cache.ped, 18905)

    AttachEntityToEntity(object, cache.ped, boneIndex, 0.1, 0.05, 0.0, 70.0, 120.0, 160.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)

    return object
end

local function hasWaterInFront()
    if IsPedSwimming(cache.ped) or IsPedInAnyVehicle(cache.ped, true) then
        return false
    end
    
    local headCoords = GetPedBoneCoords(cache.ped, 31086, 0.0, 0.0, 0.0)
    local coords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 45.0, -27.5)
    local hasWater = TestProbeAgainstWater(headCoords.x, headCoords.y, headCoords.z, coords.x, coords.y, coords.z)

    if not hasWater then
        ShowNotification(locale('no_water'), 'error')
    end

    return hasWater
end

lib.callback.register('lunar_fishing:getCurrentZone', function()
    return hasWaterInFront(), currentZone
end)

local function setCanRagdoll(state)
    SetPedCanRagdoll(cache.ped, state)
    SetPedCanRagdollFromPlayerImpact(cache.ped, state)
    SetPedRagdollOnCollision(cache.ped, state)
end

-- FIXED: Enhanced fishing with proper status display using CLIENT TIME
lib.callback.register('lunar_fishing:itemUsed', function(bait, fish, envEffects)
    local zone = currentZone and Config.fishingZones[currentZone.index] or Config.outside

    local object = createRodObject()
    lib.requestAnimDict('mini@tennis')
    lib.requestAnimDict('amb@world_human_stand_fishing@idle_a')
    setCanRagdoll(false)
    
    -- FIXED: Enhanced environmental information display using CLIENT TIME
    local weather = getCurrentWeatherType()
    local weatherEffect = Config.weatherEffects[weather]
    
    -- Get the actual current time period from the client
    local timePeriod, timeData = getCurrentTimePeriod()
    
    print('[DEBUG] Fishing UI - Current time period:', timePeriod)
    
    local statusText = locale('cancel')
    local bonusTexts = {}
    
    -- Weather bonus
    if weatherEffect and weatherEffect.chanceBonus ~= 0 then
        local bonusText = weatherEffect.chanceBonus > 0 and '+' or ''
        table.insert(bonusTexts, ('Weather: %s%d%%'):format(bonusText, weatherEffect.chanceBonus))
    end
    
    -- Time bonus - use the actual current time period from CLIENT
    if timeData and timeData.chanceBonus and timeData.chanceBonus ~= 0 then
        local bonusText = timeData.chanceBonus > 0 and '+' or ''
        table.insert(bonusTexts, ('%s: %s%d%%'):format(timePeriod:upper(), bonusText, timeData.chanceBonus))
    elseif timePeriod and timePeriod ~= 'day' then
        table.insert(bonusTexts, timePeriod:upper())
    end
    
    if #bonusTexts > 0 then
        statusText = statusText .. ' | ' .. table.concat(bonusTexts, ' | ')
    end
    
    ShowUI(statusText, 'ban')

    local p = promise.new()

    local interval = SetInterval(function()
        if IsControlPressed(0, 38)
        or (not IsEntityPlayingAnim(cache.ped, 'mini@tennis', 'forehand_ts_md_far', 3)
        and not IsEntityPlayingAnim(cache.ped, 'amb@world_human_stand_fishing@idle_a', 'idle_c', 3)) then
            HideUI()
            p:resolve(false)
        end
    end, 100) --[[@as number?]]

    local function wait(milliseconds)
        Wait(milliseconds)
        return p.state == 0
    end

    CreateThread(function()
        TaskPlayAnim(cache.ped, 'mini@tennis', 'forehand_ts_md_far', 3.0, 3.0, 1.0, 16, 0, false, false, false)

        if not wait(1500) then return end

        TaskPlayAnim(cache.ped, 'amb@world_human_stand_fishing@idle_a', 'idle_c', 3.0, 3.0, -1, 11, 0, false, false, false)

        -- Enhanced: Apply environmental effects to wait time
        local baseWaitTime = math.random(zone.waitTime.min, zone.waitTime.max)
        local weatherMultiplier = envEffects.waitMultiplier or 1.0
        local finalWaitTime = math.floor(baseWaitTime / bait.waitDivisor * weatherMultiplier * 1000)
        
        if not wait(finalWaitTime) then return end

        -- Different bite notifications based on fish rarity
        local biteMessages = {
            common = locale('felt_bite'),
            uncommon = 'Something strong is pulling on your line!',
            rare = 'A powerful fish has taken your bait!',
            epic = 'An epic fish is fighting on your line!',
            legendary = 'A legendary creature has taken your bait!',
            mythical = 'Something mythical lurks beneath the waters!'
        }
        
        ShowNotification(biteMessages[fish.rarity] or locale('felt_bite'), 'warn')
        HideUI()

        if interval then
            ClearInterval(interval)
            interval = nil
        end

        if not wait(math.random(2000, 4000)) then return end

        -- Enhanced skillcheck with rarity-based difficulty
        local skillcheckKeys = { 'e' }
        if fish.rarity == 'epic' then
            skillcheckKeys = { 'e', 'q' }
        elseif fish.rarity == 'legendary' or fish.rarity == 'mythical' then
            skillcheckKeys = { 'e', 'q', 'r' }
        end

        local success = lib.skillCheck(fish.skillcheck, skillcheckKeys)

        if not success then
            local failMessages = {
                common = locale('catch_failed'),
                uncommon = 'The fish broke free from your line!',
                rare = 'The rare fish was too strong and escaped!',
                epic = 'The epic fish overpowered you and got away!',
                legendary = 'The legendary fish proved too mighty to catch!',
                mythical = 'The mythical creature vanished into the depths!'
            }
            ShowNotification(failMessages[fish.rarity] or locale('catch_failed'), 'error')
        end

        p:resolve(success)
    end)

    local success = Citizen.Await(p)

    if interval then
        ClearInterval(interval)
        interval = nil
    end

    DeleteEntity(object)
    ClearPedTasks(cache.ped)
    setCanRagdoll(true)

    return success
end)

-- Enhanced: Weather and time monitoring system
local lastWeather = nil
local lastTimePeriod = nil

-- Enhanced: Environmental change monitoring (reduced notifications)
CreateThread(function()
    while true do
        local currentWeather = getCurrentWeatherType()
        local currentTimePeriod, timeData = getCurrentTimePeriod()
        
        -- Only show weather change notifications when weather actually changes (not on first load)
        if lastWeather and lastWeather ~= currentWeather then
            -- Only show weather change notifications, not during fishing
            local weatherEffect = Config.weatherEffects[currentWeather]
            if weatherEffect and weatherEffect.message and not IsPedUsingAnyScenario(cache.ped) then
                showWeatherChangeEffect(currentWeather)
            end
        end
        
        -- Don't show time period change notifications when fishing
        if lastTimePeriod and lastTimePeriod ~= currentTimePeriod then
            -- Only show if not currently fishing and message is significant
            if timeData.message and timeData.message ~= 'Standard fishing conditions.' and not IsPedUsingAnyScenario(cache.ped) then
                -- Only show for prime fishing times (dawn/dusk)
                if currentTimePeriod == 'dawn' or currentTimePeriod == 'dusk' then
                    ShowNotification('⏰ ' .. timeData.message, 'inform')
                end
            end
        end
        
        lastWeather = currentWeather
        lastTimePeriod = currentTimePeriod
        
        -- Update weather display
        local hour = GetClockHours()
        local minute = GetClockMinutes()
        
        local bonusIndicator = ''
        if Config.weatherEffects[currentWeather] then
            local bonus = Config.weatherEffects[currentWeather].chanceBonus
            if bonus > 0 then
                bonusIndicator = ' ↑'
            elseif bonus < 0 then
                bonusIndicator = ' ↓'
            end
        end
        
        weatherDisplay = ('Weather: %s%s | Time: %02d:%02d (%s)'):format(
            currentWeather, bonusIndicator, hour, minute, currentTimePeriod:upper()
        )
        
        Wait(30000) -- Check every 30 seconds instead of 10 to reduce spam
    end
end)

-- New: HUD display for tournament and weather info
CreateThread(function()
    while true do
        if timeDisplay or weatherDisplay then
            SetTextFont(4)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            
            local yOffset = 0.02
            
            if timeDisplay then
                SetTextEntry('STRING')
                AddTextComponentString(timeDisplay)
                DrawText(0.02, yOffset)
                yOffset = yOffset + 0.025
            end
            
            if weatherDisplay then
                SetTextEntry('STRING')
                AddTextComponentString(weatherDisplay)
                DrawText(0.02, yOffset)
            end
        end
        
        Wait(0)
    end
end)

-- New: Contract tracking
local function updateContractProgress(fishName, fishRarity, fishValue)
    for contractId, contract in pairs(playerContracts) do
        if contract.type == 'catch_specific' and contract.target.fish == fishName then
            contract.progress = (contract.progress or 0) + 1
            
            if contract.progress >= contract.target.amount then
                ShowNotification(('📋 Contract completed: %s'):format(contract.title), 'success')
                playerContracts[contractId] = nil
            else
                ShowNotification(('📋 Progress: %d/%d %s caught'):format(
                    contract.progress, contract.target.amount, Utils.getItemLabel(fishName)
                ), 'inform')
            end
            
        elseif contract.type == 'catch_rarity' and contract.target.rarity == fishRarity then
            contract.progress = (contract.progress or 0) + 1
            
            if contract.progress >= contract.target.amount then
                ShowNotification(('📋 Contract completed: %s'):format(contract.title), 'success')
                playerContracts[contractId] = nil
            end
            
        elseif contract.type == 'catch_value' then
            contract.progress = (contract.progress or 0) + fishValue
            
            if contract.progress >= contract.target.value then
                ShowNotification(('📋 Contract completed: %s'):format(contract.title), 'success')
                playerContracts[contractId] = nil
            end
        end
    end
end

-- Tournament event handlers
RegisterNetEvent('lunar_fishing:tournamentStarted', function(endTime)
    activeTournament = {
        endTime = endTime,
        myProgress = { totalValue = 0, fishCaught = 0 }
    }
    
    ShowNotification('🏆 Fishing Tournament Started! Catch the most valuable fish to win!', 'success')
    
    -- Show tournament timer
    CreateThread(function()
        while activeTournament do
            local timeLeft = activeTournament.endTime - os.time()
            if timeLeft <= 0 then break end
            
            local minutes = math.floor(timeLeft / 60)
            local seconds = timeLeft % 60
            
            timeDisplay = ('Tournament: %02d:%02d'):format(minutes, seconds)
            Wait(1000)
        end
        
        timeDisplay = nil
    end)
end)

RegisterNetEvent('lunar_fishing:tournamentEnded', function(leaderboard)
    activeTournament = nil
    timeDisplay = nil
    ShowNotification('🏆 Tournament finished!', 'inform')
end)

RegisterNetEvent('lunar_fishing:updateTournamentProgress', function(progress)
    if activeTournament then
        activeTournament.myProgress = progress
    end
end)

RegisterNetEvent('lunar_fishing:contractsRefreshed', function(contracts)
    activeContracts = contracts or {}
    ShowNotification('📋 New fishing contracts available!', 'inform')
end)

-- Fish caught event for contract tracking
RegisterNetEvent('lunar_fishing:fishCaught', function(fishName, fishRarity, fishValue)
    updateContractProgress(fishName, fishRarity, fishValue)
    
    -- Play sound effects for different rarities
    if fishRarity == 'legendary' or fishRarity == 'mythical' then
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
    elseif fishRarity == 'epic' then
        PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
    elseif fishRarity == 'rare' then
        PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
    
    -- Update tournament progress if active
    if activeTournament then
        activeTournament.myProgress.totalValue = activeTournament.myProgress.totalValue + fishValue
        activeTournament.myProgress.fishCaught = activeTournament.myProgress.fishCaught + 1
    end
end)

-- Fishing information keybind
local infoKeybind = Utils.addKeybind({
    name = 'fishing_info',
    description = 'Show fishing information',
    defaultKey = 'F6',
    defaultMapper = 'keyboard'
})

infoKeybind.addListener('show_info', function()
    local currentLevel = GetCurrentLevel()
    local progress = GetCurrentLevelProgress() * 100
    local zone = currentZone and Config.fishingZones[currentZone.index]
    local weather = getCurrentWeatherType()
    
    -- Get time period locally
    local timePeriod, timeData = getCurrentTimePeriod()
    
    local info = {}
    table.insert(info, ('🎣 Level: %d (%.1f%% to next)'):format(currentLevel, progress))
    
    if zone then
        table.insert(info, ('📍 Zone: %s'):format(zone.blip.name))
        table.insert(info, ('🐟 Fish Types: %d'):format(#zone.fishList))
    else
        table.insert(info, '📍 Zone: Open Waters')
    end
    
    -- Weather info
    local weatherEffect = Config.weatherEffects[weather]
    if weatherEffect then
        local bonusText = weatherEffect.chanceBonus > 0 and '↑' or weatherEffect.chanceBonus < 0 and '↓' or '='
        table.insert(info, ('🌤️ Weather: %s %s'):format(weather, bonusText))
    end
    
    -- Time info  
    table.insert(info, ('⏰ Time: %s'):format(timePeriod:upper()))
    
    ShowNotification(table.concat(info, '\n'), 'inform')
end)

-- Contract menu keybind
local contractKeybind = Utils.addKeybind({
    name = 'fishing_contracts',
    description = 'Open fishing contracts',
    defaultKey = 'F7',
    defaultMapper = 'keyboard'
})

contractKeybind.addListener('show_contracts', function()
    if #activeContracts == 0 then
        ShowNotification('📋 No contracts available right now.', 'inform')
        return
    end
    
    local options = {}
    
    for _, contract in ipairs(activeContracts) do
        local isActive = playerContracts[contract.id] ~= nil
        local progressText = ''
        
        if isActive then
            local progress = playerContracts[contract.id].progress or 0
            if contract.type == 'catch_specific' then
                progressText = (' (Progress: %d/%d)'):format(progress, contract.target.amount)
            elseif contract.type == 'catch_rarity' then
                progressText = (' (Progress: %d/%d)'):format(progress, contract.target.amount)
            elseif contract.type == 'catch_value' then
                progressText = (' (Progress: $%d/$%d)'):format(progress, contract.target.value)
            end
        end
        
        table.insert(options, {
            title = contract.title .. progressText,
            description = contract.description .. ('\nReward: $%d + %.1f XP'):format(contract.reward.money, contract.reward.xp),
            disabled = isActive,
            onSelect = function()
                playerContracts[contract.id] = contract
                playerContracts[contract.id].progress = 0
                ShowNotification(('📋 Contract accepted: %s'):format(contract.title), 'success')
            end
        })
    end
    
    lib.registerContext({
        id = 'fishing_contracts',
        title = '📋 Fishing Contracts',
        options = options
    })
    
    lib.showContext('fishing_contracts')
end)

-- Event handler for contract menu from ped
RegisterNetEvent('lunar_fishing:openContracts', function()
    contractKeybind.addListener('show_contracts', function() end) -- Trigger the same function
    if #activeContracts == 0 then
        ShowNotification('📋 No contracts available right now.', 'inform')
        return
    end
    
    local options = {}
    
    for _, contract in ipairs(activeContracts) do
        local isActive = playerContracts[contract.id] ~= nil
        local progressText = ''
        
        if isActive then
            local progress = playerContracts[contract.id].progress or 0
            if contract.type == 'catch_specific' then
                progressText = (' (Progress: %d/%d)'):format(progress, contract.target.amount)
            elseif contract.type == 'catch_rarity' then
                progressText = (' (Progress: %d/%d)'):format(progress, contract.target.amount)
            elseif contract.type == 'catch_value' then
                progressText = (' (Progress: $%d/$%d)'):format(progress, contract.target.value)
            end
        end
        
        table.insert(options, {
            title = contract.title .. progressText,
            description = contract.description .. ('\nReward: $%d + %.1f XP'):format(contract.reward.money, contract.reward.xp),
            disabled = isActive,
            onSelect = function()
                playerContracts[contract.id] = contract
                playerContracts[contract.id].progress = 0
                ShowNotification(('📋 Contract accepted: %s'):format(contract.title), 'success')
            end
        })
    end
    
    lib.registerContext({
        id = 'fishing_contracts',
        title = '📋 Fishing Contracts',
        options = options
    })
    
    lib.showContext('fishing_contracts')
end)

-- Tournament leaderboard keybind
local tournamentKeybind = Utils.addKeybind({
    name = 'tournament_info',
    description = 'Show tournament information',
    defaultKey = 'F8',
    defaultMapper = 'keyboard'
})

tournamentKeybind.addListener('show_tournament', function()
    if not activeTournament then
        ShowNotification('🏆 No active tournament', 'inform')
        return
    end
    
    local timeLeft = activeTournament.endTime - os.time()
    local minutes = math.floor(timeLeft / 60)
    local seconds = timeLeft % 60
    
    local info = ('🏆 Tournament Active\nTime Left: %02d:%02d\nYour Progress:\n  Value: $%d\n  Fish: %d'):format(
        minutes, seconds,
        activeTournament.myProgress.totalValue,
        activeTournament.myProgress.fishCaught
    )
    
    ShowNotification(info, 'success')
end)

-- Initialize contracts and tournament info on player load
RegisterNetEvent('esx:playerLoaded', function()
    Wait(2000)
    CreateThread(function()
        Wait(1000)
        if lib.callback then
            activeContracts = lib.callback.await('lunar_fishing:getActiveContracts', 1000) or {}
            activeTournament = lib.callback.await('lunar_fishing:getTournamentInfo', 1000)
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    CreateThread(function()
        Wait(1000)
        if lib.callback then
            activeContracts = lib.callback.await('lunar_fishing:getActiveContracts', 1000) or {}
            activeTournament = lib.callback.await('lunar_fishing:getTournamentInfo', 1000)
        end
    end)
end)

-- Best fishing times notification system
local bestTimesNotified = false

CreateThread(function()
    while true do
        local hour = GetClockHours()
        
        -- Notify about best fishing times
        if (hour == 5 or hour == 18) and not bestTimesNotified then
            if hour == 5 then
                ShowNotification('🌅 Dawn has arrived - perfect time for fishing!', 'success')
            else
                ShowNotification('🌆 Dusk is here - prime fishing time!', 'success')
            end
            bestTimesNotified = true
        elseif hour ~= 5 and hour ~= 18 then
            bestTimesNotified = false
        end
        
        Wait(60000) -- Check every minute
    end
end)