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
                        
                        -- New: Show zone fishing info
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

-- New: Enhanced rod object creation with rod type detection
local function createRodObject(rodName)
    local model = `prop_fishing_rod_01`
    
    -- Different rod models based on type (if you have custom props)
    if rodName == 'carbon_fiber_rod' then
        -- model = `prop_fishing_rod_carbon` -- Custom prop if available
    elseif rodName == 'legendary_rod' then
        -- model = `prop_fishing_rod_legendary` -- Custom prop if available
    end

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

-- New: Enhanced fishing with weather and time effects
---@param bait FishingBait
---@param fish Fish
---@param waitTimeMultiplier number
lib.callback.register('lunar_fishing:itemUsed', function(bait, fish, waitTimeMultiplier)
    local zone = currentZone and Config.fishingZones[currentZone.index] or Config.outside

    local object = createRodObject('basic_rod') -- You can pass actual rod name from server
    lib.requestAnimDict('mini@tennis')
    lib.requestAnimDict('amb@world_human_stand_fishing@idle_a')
    setCanRagdoll(false)
    
    -- New: Enhanced UI with weather info
    local weather = GetCurrentWeatherType()
    local weatherEffect = Config.weatherEffects[weather]
    local weatherText = weatherEffect and 
        (weatherEffect.chanceBonus > 0 and ' (Weather Bonus!)' or weatherEffect.chanceBonus < 0 and ' (Weather Penalty)' or '') or ''
    
    ShowUI(locale('cancel') .. weatherText, 'ban')

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

        -- Apply wait time multiplier
        local baseWaitTime = math.random(zone.waitTime.min, zone.waitTime.max)
        local adjustedWaitTime = math.floor(baseWaitTime / bait.waitDivisor * waitTimeMultiplier * 1000)
        
        if not wait(adjustedWaitTime) then return end

        -- New: Different bite notifications based on fish rarity
        local biteMessages = {
            common = locale('felt_bite'),
            uncommon = locale('felt_strong_bite'),
            rare = locale('felt_powerful_bite'),
            epic = locale('felt_epic_bite'),
            legendary = locale('felt_legendary_bite'),
            mythical = locale('felt_mythical_bite')
        }
        
        ShowNotification(biteMessages[fish.rarity] or locale('felt_bite'), 'warn')
        HideUI()

        if interval then
            ClearInterval(interval)
            interval = nil
        end

        if not wait(math.random(2000, 4000)) then return end

        -- New: Enhanced skillcheck with rarity-based difficulty
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
                uncommon = locale('catch_failed_uncommon'),
                rare = locale('catch_failed_rare'),
                epic = locale('catch_failed_epic'),
                legendary = locale('catch_failed_legendary'),
                mythical = locale('catch_failed_mythical')
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

-- New: Tournament event handlers
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
    
    local playerPos = nil
    local playerIdentifier = GetPlayerServerId(PlayerId()) -- You might need to adjust this
    
    for i, entry in ipairs(leaderboard) do
        if entry.identifier == playerIdentifier then
            playerPos = i
            break
        end
    end
    
    if playerPos then
        if playerPos <= 3 then
            ShowNotification(('🏆 Tournament finished! You placed #%d!'):format(playerPos), 'success')
        else
            ShowNotification(('Tournament finished! You placed #%d'):format(playerPos), 'inform')
        end
    else
        ShowNotification('Tournament finished!', 'inform')
    end
end)

RegisterNetEvent('lunar_fishing:updateTournamentProgress', function(progress)
    if activeTournament then
        activeTournament.myProgress = progress
    end
end)

RegisterNetEvent('lunar_fishing:contractsRefreshed', function(contracts)
    activeContracts = contracts
    ShowNotification('📋 New fishing contracts available!', 'inform')
end)

-- New: Weather and time display
CreateThread(function()
    while true do
        local hour = GetClockHours()
        local minute = GetClockMinutes()
        local weather = GetCurrentWeatherType()
        
        weatherDisplay = ('Weather: %s | Time: %02d:%02d'):format(weather, hour, minute)
        
        Wait(60000) -- Update every minute
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

-- New: Enhanced fishing rod detection
local currentRodName = nil

-- Hook into item usage to detect which rod is being used
AddEventHandler('lunar_fishing:rodUsed', function(rodName)
    currentRodName = rodName
end)

-- Enhanced rod object creation with rod-specific models
local function createRodObject()
    local model = `prop_fishing_rod_01`
    
    -- Use different models based on rod type if available
    if currentRodName == 'carbon_fiber_rod' then
        -- model = `prop_fishing_rod_carbon` -- If you have custom props
    elseif currentRodName == 'legendary_rod' then
        -- model = `prop_fishing_rod_legendary` -- If you have custom props
    end

    lib.requestModel(model)

    local coords = GetEntityCoords(cache.ped)
    local object = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    local boneIndex = GetPedBoneIndex(cache.ped, 18905)

    AttachEntityToEntity(object, cache.ped, boneIndex, 0.1, 0.05, 0.0, 70.0, 120.0, 160.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)

    return object
end

-- New: Contract tracking
local function updateContractProgress(fishName, fishRarity, fishValue)
    for contractId, contract in pairs(playerContracts) do
        if contract.type == 'catch_specific' and contract.target.fish == fishName then
            contract.progress = (contract.progress or 0) + 1
            
            if contract.progress >= contract.target.amount then
                -- Contract completed
                lib.callback('lunar_fishing:completeContract', false, contractId)
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
                lib.callback('lunar_fishing:completeContract', false, contractId)
                ShowNotification(('📋 Contract completed: %s'):format(contract.title), 'success')
                playerContracts[contractId] = nil
            end
            
        elseif contract.type == 'catch_value' then
            contract.progress = (contract.progress or 0) + fishValue
            
            if contract.progress >= contract.target.value then
                lib.callback('lunar_fishing:completeContract', false, contractId)
                ShowNotification(('📋 Contract completed: %s'):format(contract.title), 'success')
                playerContracts[contractId] = nil
            end
        end
    end
end

-- New: Fish caught event for contract tracking
RegisterNetEvent('lunar_fishing:fishCaught', function(fishName, fishRarity, fishValue)
    updateContractProgress(fishName, fishRarity, fishValue)
end)

-- New: Fishing information keybind
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
    
    local infoText = ('Level: %d (%.1f%% to next)'):format(currentLevel, progress)
    
    if zone then
        infoText = infoText .. ('\nZone: %s'):format(zone.blip.name)
        infoText = infoText .. ('\nFish Types: %d'):format(#zone.fishList)
    else
        infoText = infoText .. '\nZone: Open Waters'
    end
    
    -- Weather info
    local weather = GetCurrentWeatherType()
    local weatherEffect = Config.weatherEffects[weather]
    if weatherEffect then
        local bonusText = weatherEffect.chanceBonus > 0 and '↑' or weatherEffect.chanceBonus < 0 and '↓' or '='
        infoText = infoText .. ('\nWeather: %s %s'):format(weather, bonusText)
    end
    
    ShowNotification(infoText, 'inform')
end)

-- New: Contract menu keybind
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
                if lib.callback.await('lunar_fishing:acceptContract', false, contract.id) then
                    playerContracts[contract.id] = contract
                    playerContracts[contract.id].progress = 0
                    ShowNotification(('📋 Contract accepted: %s'):format(contract.title), 'success')
                else
                    ShowNotification('❌ Failed to accept contract', 'error')
                end
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

-- New: Tournament leaderboard keybind
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

-- New: Initialize contracts and tournament info on player load
RegisterNetEvent('esx:playerLoaded', function()
    Wait(2000)
    activeContracts = lib.callback.await('lunar_fishing:getActiveContracts', false) or {}
    activeTournament = lib.callback.await('lunar_fishing:getTournamentInfo', false)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    activeContracts = lib.callback.await('lunar_fishing:getActiveContracts', false) or {}
    activeTournament = lib.callback.await('lunar_fishing:getTournamentInfo', false)
end)

-- New: Show helpful hints for new players
local function showFishingTips()
    if GetCurrentLevel() <= 2 then
        CreateThread(function()
            Wait(5000)
            ShowNotification('💡 Tip: Use better bait to catch fish faster!', 'inform')
            Wait(15000)
            ShowNotification('💡 Tip: Different zones have different fish - explore!', 'inform')
            Wait(15000)
            ShowNotification('💡 Tip: Weather affects your fishing success!', 'inform')
        end)
    end
end

-- Show tips when player loads
AddEventHandler('lunar_fishing:playerLoaded', showFishingTips)

-- New: Sound effects for different fish rarities
local function playFishCaughtSound(rarity)
    if rarity == 'legendary' or rarity == 'mythical' then
        -- Play special sound for legendary catches
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
    elseif rarity == 'epic' then
        PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
    elseif rarity == 'rare' then
        PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end

-- Enhanced catch notification
RegisterNetEvent('lunar_fishing:fishCaught', function(fishName, fishRarity, fishValue)
    playFishCaughtSound(fishRarity)
    
    -- Update tournament progress if active
    if activeTournament then
        activeTournament.myProgress.totalValue = activeTournament.myProgress.totalValue + fishValue
        activeTournament.myProgress.fishCaught = activeTournament.myProgress.fishCaught + 1
    end
end)
