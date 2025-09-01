-- Enhanced PED interaction system with new features
-- client/enhanced_ped.lua

local function getRarityColor(rarity)
    local colors = {
        common = '#FFFFFF',
        uncommon = '#00FF00',
        rare = '#0080FF',
        epic = '#8000FF',
        legendary = '#FF8000',
        mythical = '#FF0080'
    }
    return colors[rarity] or '#FFFFFF'
end

local function getRarityIcon(rarity)
    local icons = {
        common = 'fish',
        uncommon = 'fish',
        rare = 'fish-symbol',
        epic = 'crown',
        legendary = 'gem',
        mythical = 'star'
    }
    return icons[rarity] or 'fish'
end

-- Enhanced sell function with rarity display
local function sell(fishName)
    local fish = Config.fish[fishName]
    local itemCount = Framework.hasItem and Framework.hasItem(fishName) and 1 or 0 -- You may need to get actual count
    
    if itemCount == 0 then
        ShowNotification(locale('no_fish_to_sell'), 'error')
        return
    end
    
    local heading = type(fish.price) == 'number' 
                    and locale('sell_fish_heading', Utils.getItemLabel(fishName), fish.price)
                    or locale('sell_fish_heading2', Utils.getItemLabel(fishName), fish.price.min, fish.price.max)
    
    local description = ('Rarity: %s | In Stock: %d'):format(fish.rarity:upper(), itemCount)
    
    local amount = lib.inputDialog(heading, {
        {
            type = 'number',
            label = locale('amount'),
            description = description,
            min = 1,
            max = itemCount,
            required = true
        }
    })?[1] --[[@as number?]]

    if not amount then
        lib.showContext('sell_fish')
        return
    end

    local success = lib.callback.await('lunar_fishing:sellFish', false, fishName, amount)

    if success then
        ShowProgressBar(locale('selling'), 3000, false, {
            dict = 'misscarsteal4@actor',
            clip = 'actor_berating_loop'
        })
        
        local totalValue = type(fish.price) == 'number' and fish.price * amount or 
                          math.random(fish.price.min, fish.price.max) * amount
        
        ShowNotification(locale('sold_fish_enhanced', amount, Utils.getItemLabel(fishName), totalValue), 'success')
    else
        ShowNotification(locale('not_enough_fish'), 'error')
    end
end

-- Enhanced sellFish function with better organization
local function sellFish()
    local options = {}
    local fishByRarity = {
        mythical = {},
        legendary = {},
        epic = {},
        rare = {},
        uncommon = {},
        common = {}
    }

    -- Organize fish by rarity
    for fishName, fish in pairs(Config.fish) do
        if Framework.hasItem(fishName) then
            local option = {
                title = Utils.getItemLabel(fishName),
                description = type(fish.price) == 'number' and locale('fish_price', fish.price)
                            or locale('fish_price2', fish.price.min, fish.price.max),
                image = GetInventoryIcon(fishName),
                onSelect = sell,
                price = type(fish.price) == 'number' and fish.price or fish.price.min,
                args = fishName,
                metadata = {
                    { label = 'Rarity', value = fish.rarity:upper() },
                    { label = 'Chance', value = fish.chance .. '%' }
                }
            }
            
            table.insert(fishByRarity[fish.rarity], option)
        end
    end

    -- Add fish to options in rarity order
    local rarityOrder = { 'mythical', 'legendary', 'epic', 'rare', 'uncommon', 'common' }
    for _, rarity in ipairs(rarityOrder) do
        for _, option in ipairs(fishByRarity[rarity]) do
            table.insert(options, option)
        end
    end

    if #options == 0 then
        ShowNotification(locale('nothing_to_sell'), 'error')
        return
    end

    lib.registerContext({
        id = 'sell_fish',
        title = '🐟 ' .. locale('sell_fish'),
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('sell_fish')
end

-- Enhanced buy function with better info display
---@param data { type: string, index: integer }
local function buy(data)
    local type, index = data.type, data.index
    local item = Config[type][index]
    local playerLevel = GetCurrentLevel()
    
    if item.minLevel > playerLevel then
        ShowNotification(locale('level_required', item.minLevel), 'error')
        return
    end
    
    local amount = lib.inputDialog(locale('buy_heading', Utils.getItemLabel(item.name), item.price), {
        {
            type = 'number',
            label = locale('amount'),
            description = ('Required Level: %d | Your Level: %d'):format(item.minLevel, playerLevel),
            min = 1,
            max = 50,
            required = true
        }
    })?[1] --[[@as number?]]

    if not amount then
        lib.showContext(type == 'fishingRods' and 'buy_rods' or 'buy_baits')
        return
    end

    local success = lib.callback.await('lunar_fishing:buy', false, data, amount)

    if success then
        ShowProgressBar(locale('buying'), 3000, false, {
            dict = 'misscarsteal4@actor',
            clip = 'actor_berating_loop'
        })
        ShowNotification(locale('bought_item_enhanced', amount, Utils.getItemLabel(item.name)), 'success')
    else
        ShowNotification(locale('not_enough_' .. Config.ped.buyAccount), 'error')
    end
end

-- Enhanced rod buying with detailed stats
local function buyRods()
    local options = {}

    for index, rod in ipairs(Config.fishingRods) do
        local playerLevel = GetCurrentLevel()
        local isLocked = rod.minLevel > playerLevel
        
        table.insert(options, {
            title = Utils.getItemLabel(rod.name),
            description = locale('rod_price', rod.price),
            image = GetInventoryIcon(rod.name),
            disabled = isLocked,
            onSelect = buy,
            args = { type = 'fishingRods', index = index },
            metadata = {
                { label = 'Required Level', value = rod.minLevel },
                { label = 'Break Chance', value = rod.breakChance .. '%' },
                { label = 'Catch Bonus', value = '+' .. math.floor((rod.catchBonus - 1) * 100) .. '%' },
                { label = 'Durability', value = rod.durability .. ' uses' },
                { label = 'Status', value = isLocked and '🔒 LOCKED' or '✅ AVAILABLE' }
            }
        })
    end

    lib.registerContext({
        id = 'buy_rods',
        title = '🎣 ' .. locale('buy_rods'),
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('buy_rods')
end

-- Enhanced bait buying with effect descriptions
local function buyBaits()
    local options = {}

    for index, bait in ipairs(Config.baits) do
        local playerLevel = GetCurrentLevel()
        local isLocked = bait.minLevel > playerLevel
        
        local effectDescription = 'Standard bait'
        if bait.waitDivisor > 1 then
            effectDescription = ('Reduces wait time by %d%%'):format(math.floor((1 - 1/bait.waitDivisor) * 100))
        end
        
        if bait.rarityBonus then
            local bonusText = {}
            for rarity, bonus in pairs(bait.rarityBonus) do
                table.insert(bonusText, ('%s: +%d%%'):format(rarity, math.floor((bonus - 1) * 100)))
            end
            if #bonusText > 0 then
                effectDescription = effectDescription .. ' | ' .. table.concat(bonusText, ', ')
            end
        end
        
        table.insert(options, {
            title = Utils.getItemLabel(bait.name),
            description = locale('bait_price', bait.price),
            image = GetInventoryIcon(bait.name),
            disabled = isLocked,
            onSelect = buy,
            args = { type = 'baits', index = index },
            metadata = {
                { label = 'Required Level', value = bait.minLevel },
                { label = 'Effect', value = effectDescription },
                { label = 'Status', value = isLocked and '🔒 LOCKED' or '✅ AVAILABLE' }
            }
        })
    end

    lib.registerContext({
        id = 'buy_baits',
        title = '🪱 ' .. locale('buy_baits'),
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('buy_baits')
end

-- New: Equipment shop
local function buyEquipment()
    local options = {}
    
    -- Add reels
    for index, reel in ipairs(Config.equipment.reels) do
        local playerLevel = GetCurrentLevel()
        local isLocked = reel.minLevel > playerLevel
        
        table.insert(options, {
            title = '🎯 ' .. Utils.getItemLabel(reel.name),
            description = locale('equipment_price', reel.price),
            image = GetInventoryIcon(reel.name),
            disabled = isLocked,
            onSelect = function()
                local success = lib.callback.await('lunar_fishing:buyEquipment', false, 'reels', index)
                if success then
                    ShowNotification(locale('bought_equipment'), 'success')
                else
                    ShowNotification(locale('not_enough_money'), 'error')
                end
            end,
            metadata = {
                { label = 'Type', value = 'Reel' },
                { label = 'Required Level', value = reel.minLevel },
                { label = 'Skillcheck Bonus', value = '+' .. reel.skillcheckBonus },
                { label = 'Status', value = isLocked and '🔒 LOCKED' or '✅ AVAILABLE' }
            }
        })
    end
    
    -- Add lines
    for index, line in ipairs(Config.equipment.lines) do
        local playerLevel = GetCurrentLevel()
        local isLocked = line.minLevel > playerLevel
        
        table.insert(options, {
            title = '🧵 ' .. Utils.getItemLabel(line.name),
            description = locale('equipment_price', line.price),
            image = GetInventoryIcon(line.name),
            disabled = isLocked,
            onSelect = function()
                local success = lib.callback.await('lunar_fishing:buyEquipment', false, 'lines', index)
                if success then
                    ShowNotification(locale('bought_equipment'), 'success')
                else
                    ShowNotification(locale('not_enough_money'), 'error')
                end
            end,
            metadata = {
                { label = 'Type', value = 'Line' },
                { label = 'Required Level', value = line.minLevel },
                { label = 'Break Resistance', value = '+' .. math.floor((line.breakResistance - 1) * 100) .. '%' },
                { label = 'Status', value = isLocked and '🔒 LOCKED' or '✅ AVAILABLE' }
            }
        })
    end
    
    -- Add hooks
    for index, hook in ipairs(Config.equipment.hooks) do
        local playerLevel = GetCurrentLevel()
        local isLocked = hook.minLevel > playerLevel
        
        table.insert(options, {
            title = '🪝 ' .. Utils.getItemLabel(hook.name),
            description = locale('equipment_price', hook.price),
            image = GetInventoryIcon(hook.name),
            disabled = isLocked,
            onSelect = function()
                local success = lib.callback.await('lunar_fishing:buyEquipment', false, 'hooks', index)
                if success then
                    ShowNotification(locale('bought_equipment'), 'success')
                else
                    ShowNotification(locale('not_enough_money'), 'error')
                end
            end,
            metadata = {
                { label = 'Type', value = 'Hook' },
                { label = 'Required Level', value = hook.minLevel },
                { label = 'Catch Bonus', value = '+' .. math.floor((hook.catchBonus - 1) * 100) .. '%' },
                { label = 'Status', value = isLocked and '🔒 LOCKED' or '✅ AVAILABLE' }
            }
        })
    end

    lib.registerContext({
        id = 'buy_equipment',
        title = '⚙️ Fishing Equipment',
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('buy_equipment')
end

-- New: Fish encyclopedia
local function showFishEncyclopedia()
    local options = {}
    local fishByRarity = {
        mythical = {},
        legendary = {},
        epic = {},
        rare = {},
        uncommon = {},
        common = {}
    }

    -- Organize fish by rarity for better display
    for fishName, fish in pairs(Config.fish) do
        local hasCaught = Framework.hasItem and Framework.hasItem(fishName) -- You might want to track this differently
        
        local option = {
            title = (hasCaught and '✅ ' or '❓ ') .. Utils.getItemLabel(fishName),
            description = hasCaught and 
                (type(fish.price) == 'number' and ('Value: $%d'):format(fish.price) or 
                ('Value: $%d - $%d'):format(fish.price.min, fish.price.max)) or
                'Not yet discovered',
            image = hasCaught and GetInventoryIcon(fishName) or nil,
            disabled = not hasCaught,
            metadata = hasCaught and {
                { label = 'Rarity', value = fish.rarity:upper() },
                { label = 'Catch Chance', value = fish.chance .. '%' },
                { label = 'Skillcheck', value = table.concat(fish.skillcheck, ', ') }
            } or nil
        }
        
        table.insert(fishByRarity[fish.rarity], option)
    end

    -- Add fish to options in rarity order
    local rarityOrder = { 'mythical', 'legendary', 'epic', 'rare', 'uncommon', 'common' }
    for _, rarity in ipairs(rarityOrder) do
        if #fishByRarity[rarity] > 0 then
            -- Add rarity header
            table.insert(options, {
                title = ('--- %s FISH ---'):format(rarity:upper()),
                description = ('Discovered: %d'):format(#fishByRarity[rarity]),
                disabled = true,
                icon = getRarityIcon(rarity)
            })
            
            for _, option in ipairs(fishByRarity[rarity]) do
                table.insert(options, option)
            end
        end
    end

    lib.registerContext({
        id = 'fish_encyclopedia',
        title = '📚 Fish Encyclopedia',
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('fish_encyclopedia')
end

-- New: Statistics menu
local function showStatistics()
    local playerStats = lib.callback.await('lunar_fishing:getPlayerStats', false)
    
    if not playerStats then
        ShowNotification('Unable to load statistics', 'error')
        return
    end
    
    local options = {
        {
            title = '📊 Total Fish Caught',
            description = playerStats.totalCaught .. ' fish',
            icon = 'chart-bar',
            disabled = true
        },
        {
            title = '💰 Total Value Earned',
            description = '$' .. (playerStats.totalValue or 0),
            icon = 'dollar-sign',
            disabled = true
        },
        {
            title = '🎣 Favorite Fishing Zone',
            description = playerStats.favoriteZone or 'Open Waters',
            icon = 'map-pin',
            disabled = true
        },
        {
            title = '🏆 Achievements',
            description = ('Unlocked: %d/%d'):format(
                Utils.getTableSize(playerStats.achievements or {}),
                #Config.achievements
            ),
            icon = 'trophy',
            disabled = true
        }
    }
    
    -- Add rarity breakdown
    if playerStats.rarityCounts then
        for rarity, count in pairs(playerStats.rarityCounts) do
            if count > 0 then
                table.insert(options, {
                    title = rarity:upper() .. ' Fish',
                    description = count .. ' caught',
                    icon = getRarityIcon(rarity),
                    disabled = true
                })
            end
        end
    end

    lib.registerContext({
        id = 'fishing_statistics',
        title = '📈 Fishing Statistics',
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('fishing_statistics')
end

-- New: Active contracts display
local function showActiveContracts()
    if Utils.getTableSize(playerContracts) == 0 then
        ShowNotification('📋 No active contracts', 'inform')
        return
    end
    
    local options = {}
    
    for contractId, contract in pairs(playerContracts) do
        local progress = contract.progress or 0
        local progressText = ''
        
        if contract.type == 'catch_specific' then
            progressText = ('%d/%d %s'):format(progress, contract.target.amount, contract.target.fish)
        elseif contract.type == 'catch_rarity' then
            progressText = ('%d/%d %s fish'):format(progress, contract.target.amount, contract.target.rarity)
        elseif contract.type == 'catch_value' then
            progressText = ('$%d/$%d value'):format(progress, contract.target.value)
        end
        
        local progressPercent = 0
        if contract.type == 'catch_value' then
            progressPercent = math.min((progress / contract.target.value) * 100, 100)
        else
            progressPercent = math.min((progress / (contract.target.amount or 1)) * 100, 100)
        end
        
        table.insert(options, {
            title = contract.title,
            description = contract.description,
            progress = progressPercent,
            colorScheme = progressPercent >= 100 and 'green' or 'blue',
            metadata = {
                { label = 'Progress', value = progressText },
                { label = 'Reward', value = '$' .. contract.reward.money .. ' + ' .. contract.reward.xp .. ' XP' }
            },
            disabled = true
        })
    end
    
    table.insert(options, {
        title = '📋 Browse New Contracts',
        description = 'View available contracts',
        icon = 'clipboard-list',
        onSelect = function()
            contractKeybind:getCurrentKey() and contractKeybind.onReleased()
        end
    })

    lib.registerContext({
        id = 'active_contracts',
        title = '📋 Active Contracts',
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('active_contracts')
end

-- Enhanced main fisherman menu
local function open()
    local level, progress = GetCurrentLevel(), GetCurrentLevelProgress() * 100
    local currentZoneName = currentZone and Config.fishingZones[currentZone.index].blip.name or 'Open Waters'
    local weather = GetCurrentWeatherType()
    local weatherEffect = Config.weatherEffects[weather]
    local weatherBonus = weatherEffect and weatherEffect.chanceBonus or 0

    lib.registerContext({
        id = 'fisherman',
        title = '🏢 SeaTrade Corporation',
        options = {
            {
                title = ('⭐ Level %d Fisher'):format(level),
                description = ('Progress: %.1f%% | Current Zone: %s'):format(progress, currentZoneName),
                icon = 'chart-simple',
                progress = math.max(progress, 0.01),
                colorScheme = 'lime',
                disabled = true
            },
            {
                title = '🌤️ Fishing Conditions',
                description = ('Weather: %s | Bonus: %s%d%%'):format(
                    weather, 
                    weatherBonus >= 0 and '+' or '', 
                    weatherBonus
                ),
                icon = 'cloud-sun',
                disabled = true
            },
            {
                title = '🎣 ' .. locale('buy_rods'),
                description = locale('buy_rods_desc'),
                icon = 'dollar-sign',
                arrow = true,
                onSelect = buyRods
            },
            {
                title = '🪱 ' .. locale('buy_baits'),
                description = locale('buy_baits_desc'),
                icon = 'worm',
                arrow = true,
                onSelect = buyBaits
            },
            {
                title = '⚙️ Buy Equipment',
                description = 'Purchase advanced fishing equipment',
                icon = 'gear',
                arrow = true,
                onSelect = buyEquipment
            },
            {
                title = '🐟 ' .. locale('sell_fish'),
                description = locale('sell_fish_desc'),
                icon = 'fish',
                arrow = true,
                onSelect = sellFish
            },
            {
                title = '📚 Fish Encyclopedia',
                description = 'View information about all fish species',
                icon = 'book',
                arrow = true,
                onSelect = showFishEncyclopedia
            },
            {
                title = '📈 Statistics',
                description = 'View your fishing statistics and achievements',
                icon = 'chart-bar',
                arrow = true,
                onSelect = showStatistics
            },
            {
                title = '📋 Active Contracts',
                description = ('Active: %d contracts'):format(Utils.getTableSize(playerContracts)),
                icon = 'clipboard-list',
                arrow = true,
                onSelect = showActiveContracts
            }
        }
    })

    lib.showContext('fisherman')
end

-- Create enhanced PEDs with updated interaction
for _, coords in ipairs(Config.ped.locations) do
    Utils.createPed(coords, Config.ped.model, {
        {
            label = locale('open_fisherman'),
            icon = 'comment',
            onSelect = open
        }
    })
    Utils.createBlip(coords, Config.ped.blip)
end

-- New: Tutorial system for new players
local function showTutorial()
    if GetCurrentLevel() > 1 then return end
    
    local tutorialSteps = {
        {
            title = '🎣 Welcome to Fishing!',
            description = 'Learn the basics of fishing in our world.',
            content = 'Fishing is a great way to earn money and relax. You\'ll need a fishing rod and bait to get started.'
        },
        {
            title = '🛒 Getting Equipment',
            description = 'Visit SeaTrade Corporation to buy equipment.',
            content = 'You can buy fishing rods, bait, and equipment from our vendors. Start with a basic rod and worms.'
        },
        {
            title = '🗺️ Finding Fishing Spots',
            description = 'Look for fishing zones on your map.',
            content = 'Different zones have different fish. Higher level zones have more valuable but harder to catch fish.'
        },
        {
            title = '🌤️ Weather Matters',
            description = 'Weather affects your fishing success.',
            content = 'Rain and thunderstorms make fish more active, while fog makes fishing harder.'
        },
        {
            title = '📋 Contracts & Tournaments',
            description = 'Participate in contracts and tournaments.',
            content = 'Complete contracts for extra rewards and compete in tournaments for prizes!'
        }
    ]
    
    for i, step in ipairs(tutorialSteps) do
        local alert = lib.alertDialog({
            header = step.title,
            content = step.content,
            centered = true,
            cancel = i > 1, -- Allow skipping after first step
            labels = {
                confirm = i < #tutorialSteps and 'Next' or 'Finish',
                cancel = 'Skip Tutorial'
            }
        })
        
        if alert == 'cancel' then break end
    end
end

-- Show tutorial for new players
AddEventHandler('lunar_fishing:playerLoaded', function()
    if GetCurrentLevel() == 1 then
        SetTimeout(3000, showTutorial)
    end
end)
