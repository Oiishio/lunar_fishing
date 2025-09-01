Config = {}

Config.progressPerCatch = 0.05 -- The progress per one fish caught

-- New: Weather effects on fishing
Config.weatherEffects = {
    ['RAIN'] = { waitMultiplier = 0.8, chanceBonus = 10 }, -- Rain makes fish more active
    ['THUNDER'] = { waitMultiplier = 0.7, chanceBonus = 15 }, -- Thunder storms are great for fishing
    ['FOGGY'] = { waitMultiplier = 1.2, chanceBonus = -5 }, -- Fog makes fishing harder
    ['CLEAR'] = { waitMultiplier = 1.0, chanceBonus = 0 }, -- Normal conditions
}

-- New: Time of day effects
Config.timeEffects = {
    dawn = { hour = 6, waitMultiplier = 0.9, chanceBonus = 5 }, -- Early morning
    dusk = { hour = 18, waitMultiplier = 0.9, chanceBonus = 5 }, -- Evening
}

---@class Fish
---@field price integer | { min: integer, max: integer }
---@field chance integer Percentage chance
---@field skillcheck SkillCheckDifficulity
---@field rarity string -- New: rarity classification
---@field season table<string, boolean>? -- New: seasonal availability
---@field timePreference table<string, boolean>? -- New: time preferences

---@type table<string, Fish>
Config.fish = {
    -- Common Fish (Level 1-2)
    ['anchovy'] = { 
        price = { min = 25, max = 50 }, 
        chance = 35, 
        skillcheck = { 'easy', 'medium' },
        rarity = 'common',
        season = { spring = true, summer = true, autumn = true, winter = true }
    },
    ['sardine'] = { 
        price = { min = 20, max = 40 }, 
        chance = 40, 
        skillcheck = { 'easy' },
        rarity = 'common',
        season = { spring = true, summer = true, autumn = true, winter = true }
    },
    ['mackerel'] = { 
        price = { min = 30, max = 60 }, 
        chance = 30, 
        skillcheck = { 'easy', 'medium' },
        rarity = 'common',
        timePreference = { dawn = true, dusk = true }
    },
    ['trout'] = { 
        price = { min = 50, max = 100 }, 
        chance = 35, 
        skillcheck = { 'easy', 'medium' },
        rarity = 'common',
        season = { spring = true, summer = true, autumn = true }
    },
    ['bass'] = { 
        price = { min = 60, max = 120 }, 
        chance = 25, 
        skillcheck = { 'easy', 'medium' },
        rarity = 'common',
        timePreference = { dawn = true, dusk = true }
    },
    
    -- Uncommon Fish (Level 2-3)
    ['haddock'] = { 
        price = { min = 150, max = 200 }, 
        chance = 20, 
        skillcheck = { 'easy', 'medium' },
        rarity = 'uncommon',
        season = { autumn = true, winter = true }
    },
    ['cod'] = { 
        price = { min = 120, max = 180 }, 
        chance = 22, 
        skillcheck = { 'easy', 'medium' },
        rarity = 'uncommon',
        season = { autumn = true, winter = true, spring = true }
    },
    ['salmon'] = { 
        price = { min = 200, max = 250 }, 
        chance = 15, 
        skillcheck = { 'easy', 'medium', 'medium' },
        rarity = 'uncommon',
        season = { spring = true, autumn = true }
    },
    ['sea_bass'] = { 
        price = { min = 180, max = 240 }, 
        chance = 18, 
        skillcheck = { 'easy', 'medium', 'medium' },
        rarity = 'uncommon'
    },
    
    -- Rare Fish (Level 3-4)
    ['grouper'] = { 
        price = { min = 300, max = 350 }, 
        chance = 12, 
        skillcheck = { 'easy', 'medium', 'medium', 'medium' },
        rarity = 'rare',
        season = { summer = true, autumn = true }
    },
    ['snook'] = { 
        price = { min = 280, max = 340 }, 
        chance = 14, 
        skillcheck = { 'easy', 'medium', 'medium' },
        rarity = 'rare',
        season = { summer = true }
    },
    ['piranha'] = { 
        price = { min = 350, max = 450 }, 
        chance = 10, 
        skillcheck = { 'easy', 'medium', 'hard' },
        rarity = 'rare'
    },
    ['red_snapper'] = { 
        price = { min = 400, max = 450 }, 
        chance = 8, 
        skillcheck = { 'easy', 'medium', 'medium', 'medium' },
        rarity = 'rare',
        season = { summer = true, autumn = true }
    },
    ['barracuda'] = { 
        price = { min = 420, max = 480 }, 
        chance = 7, 
        skillcheck = { 'easy', 'medium', 'hard' },
        rarity = 'rare'
    },
    
    -- Epic Fish (Level 4-5)
    ['mahi_mahi'] = { 
        price = { min = 450, max = 500 }, 
        chance = 6, 
        skillcheck = { 'easy', 'medium', 'medium', 'medium' },
        rarity = 'epic',
        season = { spring = true, summer = true }
    },
    ['yellowfin_tuna'] = { 
        price = { min = 800, max = 1000 }, 
        chance = 4, 
        skillcheck = { 'easy', 'medium', 'hard', 'hard' },
        rarity = 'epic',
        timePreference = { dawn = true }
    },
    ['swordfish'] = { 
        price = { min = 900, max = 1200 }, 
        chance = 3, 
        skillcheck = { 'medium', 'hard', 'hard' },
        rarity = 'epic'
    },
    ['tuna'] = { 
        price = { min = 1250, max = 1500 }, 
        chance = 3, 
        skillcheck = { 'easy', 'medium', 'hard' },
        rarity = 'epic'
    },
    
    -- Legendary Fish (Level 5+)
    ['blue_marlin'] = { 
        price = { min = 2000, max = 2500 }, 
        chance = 1, 
        skillcheck = { 'medium', 'hard', 'hard', 'hard' },
        rarity = 'legendary',
        timePreference = { dawn = true, dusk = true }
    },
    ['shark'] = { 
        price = { min = 2250, max = 2750 }, 
        chance = 1, 
        skillcheck = { 'easy', 'medium', 'hard' },
        rarity = 'legendary'
    },
    ['giant_squid'] = { 
        price = { min = 3000, max = 4000 }, 
        chance = 0.5, 
        skillcheck = { 'hard', 'hard', 'hard', 'hard' },
        rarity = 'legendary'
    },
    
    -- Mythical Fish (Level 6+) - Ultra rare
    ['kraken_tentacle'] = { 
        price = { min = 5000, max = 7500 }, 
        chance = 0.1, 
        skillcheck = { 'hard', 'hard', 'hard', 'hard', 'hard' },
        rarity = 'mythical'
    },
}

---@class FishingRod
---@field name string
---@field price integer
---@field minLevel integer The minimal level
---@field breakChance integer Percentage chance
---@field catchBonus number -- New: catch rate multiplier
---@field durability integer -- New: uses before breaking

---@type FishingRod[]
Config.fishingRods = {
    { name = 'basic_rod', price = 1000, minLevel = 1, breakChance = 20, catchBonus = 1.0, durability = 50 },
    { name = 'graphite_rod', price = 2500, minLevel = 2, breakChance = 10, catchBonus = 1.1, durability = 100 },
    { name = 'titanium_rod', price = 5000, minLevel = 3, breakChance = 1, catchBonus = 1.2, durability = 200 },
    { name = 'carbon_fiber_rod', price = 10000, minLevel = 4, breakChance = 0.5, catchBonus = 1.3, durability = 300 },
    { name = 'legendary_rod', price = 25000, minLevel = 5, breakChance = 0.1, catchBonus = 1.5, durability = 500 },
}

---@class FishingBait
---@field name string
---@field price integer
---@field minLevel integer The minimal level
---@field waitDivisor number The total wait time gets divided by this value
---@field rarityBonus table<string, number>? -- New: bonus chance for specific rarities

---@type FishingBait[]
Config.baits = {
    { name = 'worms', price = 5, minLevel = 1, waitDivisor = 1.0 },
    { name = 'artificial_bait', price = 50, minLevel = 2, waitDivisor = 3.0 },
    { name = 'premium_lure', price = 150, minLevel = 3, waitDivisor = 4.0, rarityBonus = { rare = 1.2, epic = 1.1 } },
    { name = 'legendary_lure', price = 500, minLevel = 4, waitDivisor = 5.0, rarityBonus = { epic = 1.3, legendary = 1.2 } },
    { name = 'mythical_bait', price = 2000, minLevel = 5, waitDivisor = 6.0, rarityBonus = { legendary = 1.5, mythical = 2.0 } },
}

-- New: Fishing tournaments
Config.tournaments = {
    enabled = true,
    duration = 3600000, -- 1 hour in milliseconds
    cooldown = 7200000, -- 2 hours between tournaments
    rewards = {
        [1] = { money = 10000, items = { ['legendary_rod'] = 1 } },
        [2] = { money = 7500, items = { ['carbon_fiber_rod'] = 1 } },
        [3] = { money = 5000, items = { ['premium_lure'] = 10 } },
    }
}

-- New: Fishing contracts/missions
Config.contracts = {
    enabled = true,
    refreshInterval = 3600000, -- 1 hour
    maxActive = 3,
    types = {
        {
            type = 'catch_specific',
            title = 'Catch %d %s',
            description = 'The local restaurant needs fresh %s for tonight\'s menu.',
            targetFish = { 'salmon', 'tuna', 'red_snapper' },
            targetAmount = { min = 3, max = 8 },
            reward = { money = { min = 500, max = 1500 }, xp = 0.1 }
        },
        {
            type = 'catch_rarity',
            title = 'Catch %d %s fish',
            description = 'A collector is looking for rare specimens.',
            targetRarity = { 'rare', 'epic', 'legendary' },
            targetAmount = { min = 1, max = 3 },
            reward = { money = { min = 1000, max = 3000 }, xp = 0.2 }
        },
        {
            type = 'catch_value',
            title = 'Catch fish worth $%d',
            description = 'Prove your fishing skills by catching valuable fish.',
            targetValue = { min = 2000, max = 5000 },
            reward = { money = { min = 800, max = 2000 }, xp = 0.15 }
        }
    }
}

---@class FishingZone
---@field locations vector3[] One of these gets picked at random
---@field radius number
---@field minLevel integer
---@field waitTime { min: integer, max: integer }
---@field includeOutside boolean Whether you can also catch fish from Config.outside
---@field blip BlipData?
---@field message { enter: string, exit: string }?
---@field fishList string[]
---@field rarityMultiplier table<string, number>? -- New: rarity chance multipliers

---@type FishingZone[]
Config.fishingZones = {
    {
        blip = {
            name = 'Shallow Waters',
            sprite = 317,
            color = 42,
            scale = 0.6
        },
        locations = {
            vector3(-1200.0, -1500.0, 0.0),
            vector3(1200.0, -2800.0, 0.0)
        },
        radius = 150.0,
        minLevel = 1,
        waitTime = { min = 3, max = 8 },
        includeOutside = true,
        message = { enter = 'You have entered shallow waters - perfect for beginners.', exit = 'You have left the shallow waters.' },
        fishList = { 'anchovy', 'sardine', 'mackerel', 'trout', 'bass' },
        rarityMultiplier = { common = 1.2, uncommon = 0.8 }
    },
    {
        blip = {
            name = 'Coral Reef',
            sprite = 317,
            color = 24,
            scale = 0.6
        },
        locations = {
            vector3(-1774.0654, -1796.2740, 0.0),
            vector3(2482.8589, -2575.6780, 0.0)
        },
        radius = 250.0,
        minLevel = 2,
        waitTime = { min = 5, max = 10 },
        includeOutside = true,
        message = { enter = 'You have entered a vibrant coral reef.', exit = 'You have left the coral reef.' },
        fishList = { 'mahi_mahi', 'red_snapper', 'grouper', 'barracuda', 'snook' },
        rarityMultiplier = { uncommon = 1.2, rare = 1.1 }
    },
    {
        blip = {
            name = 'Deep Waters',
            sprite = 317,
            color = 29,
            scale = 0.6
        },
        locations = {
            vector3(-4941.7964, -2411.9146, 0.0),
            vector3(-3500.0, -4000.0, 0.0)
        },
        radius = 1000.0,
        minLevel = 4,
        waitTime = { min = 20, max = 40 },
        includeOutside = false,
        message = { enter = 'You have entered the deep waters - danger and treasure await.', exit = 'You have left the deep waters.' },
        fishList = { 'tuna', 'yellowfin_tuna', 'swordfish', 'shark', 'blue_marlin' },
        rarityMultiplier = { epic = 1.3, legendary = 1.2 }
    },
    {
        blip = {
            name = 'Mysterious Swamp',
            sprite = 317,
            color = 56,
            scale = 0.6
        },
        locations = {
            vector3(-2188.1182, 2596.9348, 0.0),
        },
        radius = 200.0,
        minLevel = 2,
        waitTime = { min = 10, max = 20 },
        includeOutside = true,
        message = { enter = 'You have entered a mysterious swamp - something lurks beneath.', exit = 'You have left the swamp.' },
        fishList = { 'piranha', 'bass', 'cod' },
        rarityMultiplier = { rare = 1.1 }
    },
    {
        blip = {
            name = 'Abyssal Depths',
            sprite = 317,
            color = 1,
            scale = 0.7
        },
        locations = {
            vector3(-6000.0, -6000.0, 0.0), -- Far out in the ocean
        },
        radius = 500.0,
        minLevel = 6,
        waitTime = { min = 45, max = 90 },
        includeOutside = false,
        message = { enter = 'You have entered the abyssal depths - ancient creatures dwell here.', exit = 'You have left the abyssal depths.' },
        fishList = { 'giant_squid', 'kraken_tentacle' },
        rarityMultiplier = { legendary = 1.5, mythical = 2.0 }
    },
}

-- Outside of all zones
Config.outside = {
    waitTime = { min = 10, max = 25 },
    fishList = {
        'trout', 'anchovy', 'haddock', 'salmon', 'sardine', 'mackerel', 'bass', 'cod', 'sea_bass'
    }
}

-- New: Fishing achievements
Config.achievements = {
    {
        id = 'first_catch',
        title = 'First Catch',
        description = 'Catch your first fish',
        requirement = { type = 'total_caught', amount = 1 },
        reward = { xp = 0.1, money = 100 }
    },
    {
        id = 'rare_hunter',
        title = 'Rare Hunter',
        description = 'Catch 10 rare fish',
        requirement = { type = 'rarity_caught', rarity = 'rare', amount = 10 },
        reward = { xp = 0.5, money = 1000 }
    },
    {
        id = 'legend_fisher',
        title = 'Legend Fisher',
        description = 'Catch a legendary fish',
        requirement = { type = 'rarity_caught', rarity = 'legendary', amount = 1 },
        reward = { xp = 1.0, money = 5000, items = { ['legendary_lure'] = 5 } }
    },
    {
        id = 'zone_master',
        title = 'Zone Master',
        description = 'Catch fish in all zones',
        requirement = { type = 'zones_visited', amount = 5 },
        reward = { xp = 0.8, money = 2500 }
    }
}

Config.ped = {
    model = `s_m_m_cntrybar_01`,
    buyAccount = 'money',
    sellAccount = 'money',
    blip = {
        name = 'SeaTrade Corporation',
        sprite = 356,
        color = 74,
        scale = 0.75
    },
    locations = {
        vector4(-2081.3831, 2614.3223, 3.0840, 112.7910),
        vector4(-1492.3639, -939.2579, 10.2140, 144.0305)
    }
}

-- Enhanced boat rental system
Config.renting = {
    model = `s_m_m_dockwork_01`,
    account = 'money',
    boats = {
        { model = `seashark`, price = 300, image = 'https://i.imgur.com/placeholder1.png', fuel = 80, description = 'Fast and agile' },
        { model = `speeder`, price = 500, image = 'https://i.imgur.com/placeholder2.png', fuel = 100, description = 'Balanced performance' },
        { model = `dinghy`, price = 750, image = 'https://i.imgur.com/placeholder3.png', fuel = 120, description = 'Stable and reliable' },
        { model = `tug`, price = 1250, image = 'https://i.imgur.com/placeholder4.png', fuel = 150, description = 'Heavy duty vessel' },
        { model = `marquis`, price = 2000, image = 'https://i.imgur.com/placeholder5.png', fuel = 200, description = 'Luxury fishing yacht' },
    },
    blip = {
        name = 'Boat Rental',
        sprite = 410,
        color = 74,
        scale = 0.75
    },
    returnDivider = 5,
    returnRadius = 30.0,
    locations = {
        { coords = vector4(-1434.4818, -1512.2745, 2.1486, 25.8666), spawn = vector4(-1494.4496, -1537.6943, 2.3942, 115.6015) },
        { coords = vector4(-1603.4, -1115.2, 13.0, 45.0), spawn = vector4(-1620.5, -1095.8, 0.5, 135.0) }, -- New location
    }
}

-- New: Fishing equipment upgrades
Config.equipment = {
    reels = {
        { name = 'basic_reel', price = 200, minLevel = 1, skillcheckBonus = 0 },
        { name = 'precision_reel', price = 800, minLevel = 3, skillcheckBonus = 1 },
        { name = 'master_reel', price = 2000, minLevel = 5, skillcheckBonus = 2 },
    },
    lines = {
        { name = 'nylon_line', price = 50, minLevel = 1, breakResistance = 1.0 },
        { name = 'fluorocarbon_line', price = 150, minLevel = 2, breakResistance = 1.2 },
        { name = 'braided_line', price = 300, minLevel = 3, breakResistance = 1.5 },
    },
    hooks = {
        { name = 'basic_hook', price = 10, minLevel = 1, catchBonus = 1.0 },
        { name = 'sharp_hook', price = 50, minLevel = 2, catchBonus = 1.1 },
        { name = 'barbed_hook', price = 150, minLevel = 3, catchBonus = 1.2 },
    }
}

-- New: Weather-based fishing bonuses
Config.seasons = {
    spring = { months = {3, 4, 5}, fishBonus = { 'salmon', 'trout', 'mahi_mahi' } },
    summer = { months = {6, 7, 8}, fishBonus = { 'mahi_mahi', 'red_snapper', 'grouper', 'snook' } },
    autumn = { months = {9, 10, 11}, fishBonus = { 'salmon', 'haddock', 'cod', 'grouper' } },
    winter = { months = {12, 1, 2}, fishBonus = { 'haddock', 'cod' } }
}

-- New: Fishing skills/perks system
Config.skills = {
    {
        name = 'patience',
        maxLevel = 10,
        description = 'Reduces waiting time between catches',
        effect = function(level) return 1 - (level * 0.05) end -- 5% reduction per level
    },
    {
        name = 'precision',
        maxLevel = 10,
        description = 'Increases success rate of skill checks',
        effect = function(level) return level * 0.1 end -- 10% bonus per level
    },
    {
        name = 'luck',
        maxLevel = 10,
        description = 'Increases rare fish catch chance',
        effect = function(level) return 1 + (level * 0.05) end -- 5% increase per level
    },
    {
        name = 'strength',
        maxLevel = 10,
        description = 'Reduces rod break chance',
        effect = function(level) return 1 - (level * 0.1) end -- 10% reduction per level
    }
}
