Config = {}

Config.progressPerCatch = 0.05 -- The progress per one fish caught

-- Enhanced: Weather effects on fishing
Config.weatherEffects = {
    ['CLEAR'] = { waitMultiplier = 1.0, chanceBonus = 0, message = 'Perfect fishing weather!' },
    ['CLOUDY'] = { waitMultiplier = 0.95, chanceBonus = 2, message = 'Cloudy skies help fishing.' },
    ['OVERCAST'] = { waitMultiplier = 0.9, chanceBonus = 5, message = 'Overcast conditions are great for fishing!' },
    ['RAIN'] = { waitMultiplier = 0.8, chanceBonus = 10, message = 'Rain makes fish more active!' },
    ['THUNDER'] = { waitMultiplier = 0.7, chanceBonus = 15, message = 'Thunder storms bring out the big fish!' },
    ['FOGGY'] = { waitMultiplier = 1.3, chanceBonus = -10, message = 'Fog makes fishing more difficult.' },
    ['SNOW'] = { waitMultiplier = 1.4, chanceBonus = -15, message = 'Cold weather slows down fish activity.' },
    ['BLIZZARD'] = { waitMultiplier = 1.6, chanceBonus = -20, message = 'Blizzard conditions are harsh for fishing.' },
}

-- Enhanced: Time of day effects (fixed time ranges)
Config.timeEffects = {
    night = { startHour = 21, endHour = 4, waitMultiplier = 1.3, chanceBonus = -8, message = 'Night fishing is challenging.' },
    dawn = { startHour = 5, endHour = 7, waitMultiplier = 0.85, chanceBonus = 8, message = 'Dawn - prime fishing time!' },
    morning = { startHour = 8, endHour = 11, waitMultiplier = 1.0, chanceBonus = 0, message = 'Morning fishing is steady.' },
    noon = { startHour = 12, endHour = 14, waitMultiplier = 1.2, chanceBonus = -5, message = 'Fish are less active in the heat.' },
    afternoon = { startHour = 15, endHour = 17, waitMultiplier = 1.1, chanceBonus = 0, message = 'Afternoon fishing is decent.' },
    dusk = { startHour = 18, endHour = 20, waitMultiplier = 0.85, chanceBonus = 8, message = 'Dusk - another prime time!' }
}

-- Enhanced: Seasonal effects with fish bonuses
Config.seasons = {
    spring = { 
        months = {3, 4, 5}, 
        message = 'Spring brings active fish!',
        fishBonus = { 'salmon', 'trout', 'bass' }
    },
    summer = { 
        months = {6, 7, 8}, 
        message = 'Summer heat affects some species.',
        fishBonus = { 'mahi_mahi', 'red_snapper', 'grouper', 'barracuda' }
    },
    autumn = { 
        months = {9, 10, 11}, 
        message = 'Autumn migration season!',
        fishBonus = { 'salmon', 'haddock', 'cod' }
    },
    winter = { 
        months = {12, 1, 2}, 
        message = 'Winter fishing requires patience.',
        fishBonus = { 'haddock', 'cod', 'sea_bass' }
    }
}

---@class Fish
---@field price integer | { min: integer, max: integer }
---@field chance integer Percentage chance
---@field skillcheck SkillCheckDifficulity
---@field rarity string -- Rarity classification

---@type table<string, Fish>
Config.fish = {
    -- Common Fish
    ['anchovy'] = { price = { min = 25, max = 50 }, chance = 35, skillcheck = { 'easy', 'medium' }, rarity = 'common' },
    ['sardine'] = { price = { min = 20, max = 40 }, chance = 40, skillcheck = { 'easy' }, rarity = 'common' },
    ['mackerel'] = { price = { min = 30, max = 60 }, chance = 30, skillcheck = { 'easy', 'medium' }, rarity = 'common' },
    ['trout'] = { price = { min = 50, max = 100 }, chance = 35, skillcheck = { 'easy', 'medium' }, rarity = 'common' },
    ['bass'] = { price = { min = 60, max = 120 }, chance = 25, skillcheck = { 'easy', 'medium' }, rarity = 'common' },
    
    -- Uncommon Fish  
    ['haddock'] = { price = { min = 150, max = 200 }, chance = 20, skillcheck = { 'easy', 'medium' }, rarity = 'uncommon' },
    ['cod'] = { price = { min = 120, max = 180 }, chance = 22, skillcheck = { 'easy', 'medium' }, rarity = 'uncommon' },
    ['salmon'] = { price = { min = 200, max = 250 }, chance = 15, skillcheck = { 'easy', 'medium', 'medium' }, rarity = 'uncommon' },
    ['sea_bass'] = { price = { min = 180, max = 240 }, chance = 18, skillcheck = { 'easy', 'medium', 'medium' }, rarity = 'uncommon' },
    
    -- Rare Fish
    ['grouper'] = { price = { min = 300, max = 350 }, chance = 12, skillcheck = { 'easy', 'medium', 'medium', 'medium' }, rarity = 'rare' },
    ['snook'] = { price = { min = 280, max = 340 }, chance = 14, skillcheck = { 'easy', 'medium', 'medium' }, rarity = 'rare' },
    ['piranha'] = { price = { min = 350, max = 450 }, chance = 10, skillcheck = { 'easy', 'medium', 'hard' }, rarity = 'rare' },
    ['red_snapper'] = { price = { min = 400, max = 450 }, chance = 8, skillcheck = { 'easy', 'medium', 'medium', 'medium' }, rarity = 'rare' },
    ['barracuda'] = { price = { min = 420, max = 480 }, chance = 7, skillcheck = { 'easy', 'medium', 'hard' }, rarity = 'rare' },
    
    -- Epic Fish
    ['mahi_mahi'] = { price = { min = 450, max = 500 }, chance = 6, skillcheck = { 'easy', 'medium', 'medium', 'medium' }, rarity = 'epic' },
    ['yellowfin_tuna'] = { price = { min = 800, max = 1000 }, chance = 4, skillcheck = { 'easy', 'medium', 'hard', 'hard' }, rarity = 'epic' },
    ['swordfish'] = { price = { min = 900, max = 1200 }, chance = 3, skillcheck = { 'medium', 'hard', 'hard' }, rarity = 'epic' },
    ['tuna'] = { price = { min = 1250, max = 1500 }, chance = 3, skillcheck = { 'easy', 'medium', 'hard' }, rarity = 'epic' },
    
    -- Legendary Fish
    ['blue_marlin'] = { price = { min = 2000, max = 2500 }, chance = 1, skillcheck = { 'medium', 'hard', 'hard', 'hard' }, rarity = 'legendary' },
    ['shark'] = { price = { min = 2250, max = 2750 }, chance = 1, skillcheck = { 'easy', 'medium', 'hard' }, rarity = 'legendary' },
    ['giant_squid'] = { price = { min = 3000, max = 4000 }, chance = 0.5, skillcheck = { 'hard', 'hard', 'hard', 'hard' }, rarity = 'legendary' },
    
    -- Mythical Fish
    ['kraken_tentacle'] = { price = { min = 5000, max = 7500 }, chance = 0.1, skillcheck = { 'hard', 'hard', 'hard', 'hard', 'hard' }, rarity = 'mythical' },
}

---@class FishingRod
---@field name string
---@field price integer
---@field minLevel integer The minimal level
---@field breakChance integer Percentage chance

---@type FishingRod[]
Config.fishingRods = {
    { name = 'basic_rod', price = 1000, minLevel = 1, breakChance = 20 },
    { name = 'graphite_rod', price = 2500, minLevel = 2, breakChance = 10 },
    { name = 'titanium_rod', price = 5000, minLevel = 3, breakChance = 1 },
    { name = 'carbon_fiber_rod', price = 10000, minLevel = 4, breakChance = 0.5 },
    { name = 'legendary_rod', price = 25000, minLevel = 5, breakChance = 0.1 },
}

---@class FishingBait
---@field name string
---@field price integer
---@field minLevel integer The minimal level
---@field waitDivisor number The total wait time gets divided by this value

---@type FishingBait[]
Config.baits = {
    { name = 'worms', price = 5, minLevel = 1, waitDivisor = 1.0 },
    { name = 'artificial_bait', price = 50, minLevel = 2, waitDivisor = 3.0 },
    { name = 'premium_lure', price = 150, minLevel = 3, waitDivisor = 4.0 },
    { name = 'legendary_lure', price = 500, minLevel = 4, waitDivisor = 5.0 },
    { name = 'mythical_bait', price = 2000, minLevel = 5, waitDivisor = 6.0 },
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
---@field rarityMultiplier table<string, number>? -- Rarity chance multipliers

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
            vector3(-6000.0, -6000.0, 0.0),
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

Config.renting = {
    model = `s_m_m_dockwork_01`,
    account = 'money',
    boats = {
        { model = `seashark`, price = 300, image = 'https://i.postimg.cc/mDSqWj4P/164px-Speeder.webp' },
        { model = `speeder`, price = 500, image = 'https://i.postimg.cc/mDSqWj4P/164px-Speeder.webp' },
        { model = `dinghy`, price = 750, image = 'https://i.postimg.cc/ZKzjZgj0/164px-Dinghy2.webp'  },
        { model = `tug`, price = 1250, image = 'https://i.postimg.cc/jq7vpKHG/164px-Tug.webp' },
        { model = `marquis`, price = 2000, image = 'https://i.postimg.cc/mDSqWj4P/164px-Speeder.webp' },
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
        { coords = vector4(-1434.4818, -1512.2745, 2.1486, 25.8666), spawn = vector4(-1494.4496, -1537.6943, 2.3942, 115.6015) }
    }
}