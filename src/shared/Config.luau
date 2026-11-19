-- Config: every number that tunes Brainrot Bazaar lives here, so a balance
-- change is one edit and the server, the client and the world builder all
-- read the same values.

local Config = {}

-- What a new player starts with.
Config.START_CASH = 100

-- The conveyor belt down the middle of the map. Brainrots spawn at StartX,
-- walk towards EndX at Speed studs a second, and despawn at the far end.
Config.CONVEYOR = {
	StartX = -60,
	EndX = 60,
	Z = 0,
	Width = 8,
	Speed = 4,
	SpawnInterval = 6,
	MaxOnBelt = 8,
	BuyRange = 40,
}

-- Player bases: four plots around the conveyor. Each base has Slots pads
-- where owned brainrots stand, upgradeable to MaxSlots.
Config.BASES = {
	{ name = "Base 1", position = Vector3.new(-42, 0, -30), color = Color3.fromRGB(220, 70, 70) },
	{ name = "Base 2", position = Vector3.new(42, 0, -30), color = Color3.fromRGB(70, 120, 220) },
	{ name = "Base 3", position = Vector3.new(-42, 0, 30), color = Color3.fromRGB(70, 200, 90) },
	{ name = "Base 4", position = Vector3.new(42, 0, 30), color = Color3.fromRGB(230, 180, 40) },
}
Config.BASE_SIZE = Vector3.new(22, 1, 14)
Config.BASE_SLOTS = 6
Config.BASE_MAX_SLOTS = 10
-- A player standing this close to their own base centre counts as home.
Config.BASE_SAFE_RADIUS = 13

-- The Noodle Tsunami: every Interval seconds a wave is warned, then sweeps
-- the map. Anyone caught outside their base is washed back to spawn and
-- drops whatever they were carrying.
Config.WAVE = {
	Interval = 120,
	WarningSeconds = 30,
	SweepSeconds = 12,
	GoldenHourChance = 0.25,
	GoldenHourSeconds = 60,
	GoldenHourMultiplier = 2,
}

-- Stealing: pick a brainrot off an unlocked base, carry it home. Carrying
-- slows you down; a slap makes you drop it.
Config.STEAL = {
	CarrySpeedMultiplier = 0.7,
	SlapRange = 10,
	SlapCooldown = 3,
	SlapKnockback = 28,
	DeliverRadius = 12,
}

-- Locking your base: no one can steal from it while the lock holds.
Config.LOCK = {
	Duration = 30,
	Cooldown = 60,
}

-- Upgrades. Each has 3 levels; the cost doubles per level.
Config.UPGRADES = {
	speed = { name = "Speed Boots", desc = "+15% walk speed", baseCost = 500, maxLevel = 3 },
	slap = { name = "Slap Power", desc = "+50% slap knockback", baseCost = 750, maxLevel = 3 },
	slots = { name = "Base Slots", desc = "+2 brainrot slots", baseCost = 1500, maxLevel = 2 },
	income = { name = "Income Boost", desc = "+25% income", baseCost = 1000, maxLevel = 3 },
}

-- Rebirth: trade everything you own for a permanent income multiplier.
Config.REBIRTH = {
	RequiredLifetimeEarned = 100000,
	MultiplierPerRebirth = 0.5,
}

-- Sneaky Steve, the NPC rival who tries to steal from players.
Config.NPC = {
	Name = "Sneaky Steve",
	Hideout = Vector3.new(-95, 0, -95),
	ThinkInterval = 2,
	StealCooldown = 45,
	WalkSpeed = 11,
}

-- Where players appear when they join or get washed home.
Config.SPAWN_POSITION = Vector3.new(0, 3, 55)

return Config
