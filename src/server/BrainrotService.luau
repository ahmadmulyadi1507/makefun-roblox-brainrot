-- BrainrotService: the whole game, server-side. It owns every number that
-- matters: who owns what, how much cash everyone has, what rides the
-- conveyor, who is locked, who is carrying a stolen brainrot, and when the
-- Noodle Tsunami comes. The client only asks; this module decides.
--
-- State lives in one place (playerData, belt, bases) and every change goes
-- through the functions below, so the economy can never drift out of sync
-- between the server, the leaderstats and the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local Config = require(Shared:WaitForChild("Config"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))

local BrainrotService = {}

-- Live state.
local world = nil
local remotes = nil
local belt = {} -- belt entries: {id, model, character, mutation, income, cost, x}
local nextBeltId = 1
local playerData = {} -- [userId] = {cash, lifetimeEarned, owned, rebirths, upgrades, lockedUntil, lockReadyAt, carrying, baseIndex}
local npcCarrying = {} -- [npcModel] = carried brainrot ref
local eventMultiplier = 1
local goldenHourUntil = 0
local wavePhase = "calm" -- calm | warning | sweeping
local waveSecondsLeft = 0

-- ---------------------------------------------------------------------------
-- Remotes
-- ---------------------------------------------------------------------------

local function createRemotes()
	local folder = Instance.new("Folder")
	folder.Name = "BrainrotRemotes"
	folder.Parent = ReplicatedStorage
	local names = {
		"BuyBrainrot", "StealBrainrot", "Slap", "LockBase", "BuyUpgrade", "Rebirth",
		"HudUpdate", "BeltUpdate", "Notify", "WaveUpdate",
	}
	local created = {}
	for _, name in ipairs(names) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		created[name] = event
	end
	return created
end

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function getData(player)
	return playerData[player.UserId]
end

local function getBaseOf(player)
	local data = getData(player)
	if not data or not data.baseIndex then
		return nil
	end
	return world.bases[data.baseIndex]
end

local function maxSlots(data)
	return math.min(Config.BASE_SLOTS + 2 * (data.upgrades.slots or 0), Config.BASE_MAX_SLOTS)
end

local function findFreeSlot(data)
	for slot = 1, maxSlots(data) do
		if data.owned[slot] == nil then
			return slot
		end
	end
	return nil
end

local function isBaseLocked(data)
	return data.lockedUntil ~= nil and os.time() < data.lockedUntil
end

local function incomePerSecond(data)
	local sum = 0
	for _, ref in pairs(data.owned) do
		if ref then
			sum = sum + ref.income
		end
	end
	local multiplier = (1 + 0.25 * (data.upgrades.income or 0))
		* (1 + Config.REBIRTH.MultiplierPerRebirth * data.rebirths)
		* eventMultiplier
	return math.floor(sum * multiplier + 0.5)
end

local function walkSpeedFor(data)
	local speed = 16 * (1 + 0.15 * (data.upgrades.speed or 0))
	if data.carrying then
		speed = speed * Config.STEAL.CarrySpeedMultiplier
	end
	return speed
end

local function applyWalkSpeed(player)
	local data = getData(player)
	local character = player.Character
	if not data or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = walkSpeedFor(data)
	end
end

local function notify(player, message, kind)
	remotes.Notify:FireClient(player, message, kind or "info")
end

local function notifyAll(message, kind)
	for _, player in ipairs(Players:GetPlayers()) do
		notify(player, message, kind)
	end
end

local function updateHud(player)
	local data = getData(player)
	if not data then
		return
	end
	local lockLeft = 0
	if data.lockedUntil then
		lockLeft = math.max(0, data.lockedUntil - os.time())
	end
	remotes.HudUpdate:FireClient(player, {
		cash = data.cash,
		income = incomePerSecond(data),
		rebirths = data.rebirths,
		lifetimeEarned = data.lifetimeEarned,
		lockSecondsLeft = lockLeft,
		lockReadyIn = math.max(0, (data.lockReadyAt or 0) - os.time()),
		wavePhase = wavePhase,
		waveSecondsLeft = waveSecondsLeft,
		goldenHour = os.time() < goldenHourUntil,
		upgrades = data.upgrades,
		slotsUsed = (function()
			local count = 0
			for _ in pairs(data.owned) do
				count = count + 1
			end
			return count
		end)(),
		slotsMax = maxSlots(data),
	})
end

local function broadcastBelt()
	local list = {}
	for _, entry in ipairs(belt) do
		table.insert(list, {
			id = entry.id,
			name = entry.character.name,
			rarity = entry.character.rarity,
			mutation = entry.mutation.name,
			cost = entry.cost,
			income = entry.income,
			blurb = entry.character.blurb,
		})
	end
	for _, player in ipairs(Players:GetPlayers()) do
		remotes.BeltUpdate:FireClient(player, list)
	end
end

local function updateBaseBoard(base)
	if not base then
		return
	end
	if base.ownerUserId then
		local owner = Players:GetPlayerByUserId(base.ownerUserId)
		base.ownerLabel.Text = owner and ("@" .. owner.Name) or "Claimed"
	else
		base.ownerLabel.Text = "FREE — claim it!"
	end
end

local function setGate(base, locked)
	if base and base.gate then
		base.gate.Transparency = locked and 0.5 or 1
	end
end

-- ---------------------------------------------------------------------------
-- The conveyor
-- ---------------------------------------------------------------------------

local function spawnBeltBrainrot()
	if #belt >= Config.CONVEYOR.MaxOnBelt then
		return
	end
	local character = BrainrotData.rollCharacter()
	local mutation = BrainrotData.rollMutation()
	local position = Vector3.new(Config.CONVEYOR.StartX, 1, Config.CONVEYOR.Z)
	local model = CharacterFactory.buildBrainrot(character, mutation, position)
	model.Parent = world.folder
	local entry = {
		id = nextBeltId,
		model = model,
		character = character,
		mutation = mutation,
		income = character.income * mutation.multiplier,
		cost = character.cost,
		x = Config.CONVEYOR.StartX,
	}
	nextBeltId = nextBeltId + 1
	model:SetAttribute("BeltId", entry.id)
	table.insert(belt, entry)
	broadcastBelt()
end

-- Slide every belt brainrot along the belt. The ones nobody buys walk out
-- the far end and despawn.
local function moveBelt(dt, now)
	local i = 1
	while i <= #belt do
		local entry = belt[i]
		entry.x = entry.x + Config.CONVEYOR.Speed * dt
		if entry.x >= Config.CONVEYOR.EndX then
			entry.model:Destroy()
			table.remove(belt, i)
			broadcastBelt()
		else
			local bob = math.sin(now * 3 + entry.id) * 0.25
			entry.model:PivotTo(CFrame.new(entry.x, 1 + bob, Config.CONVEYOR.Z))
			i = i + 1
		end
	end
end

-- ---------------------------------------------------------------------------
-- Buying and owning
-- ---------------------------------------------------------------------------

local function placeOnSlot(player, data, ref, slot)
	local base = getBaseOf(player)
	local slotPosition = base.slots[slot]
	data.owned[slot] = ref
	ref.model:SetAttribute("BeltId", nil)
	ref.model:SetAttribute("OwnerUserId", player.UserId)
	ref.model:SetAttribute("SlotIndex", slot)
	-- Glide the brainrot from wherever it is onto its pad.
	local model = ref.model
	local from = model:GetPivot()
	local to = CFrame.new(slotPosition)
	local steps = 18
	task.spawn(function()
		for step = 1, steps do
			local t = step / steps
			model:PivotTo(from:Lerp(to, t))
			task.wait(0.03)
		end
		model:PivotTo(to)
	end)
end

local function buyBrainrot(player, beltId)
	local data = getData(player)
	if not data then
		return
	end
	local entryIndex = nil
	for i, entry in ipairs(belt) do
		if entry.id == beltId then
			entryIndex = i
			break
		end
	end
	if not entryIndex then
		notify(player, "That brainrot already left the belt!", "bad")
		return
	end
	local entry = belt[entryIndex]
	if data.cash < entry.cost then
		notify(player, "Not enough cash for " .. entry.character.name .. "!", "bad")
		return
	end
	local slot = findFreeSlot(data)
	if not slot then
		notify(player, "Your base is full! Buy more slots or rebirth.", "bad")
		return
	end
	if not getBaseOf(player) then
		notify(player, "You have no base yet — wait for a free one!", "bad")
		return
	end
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local distance = (character.HumanoidRootPart.Position - entry.model:GetPivot().Position).Magnitude
	if distance > Config.CONVEYOR.BuyRange then
		notify(player, "Get closer to the conveyor to buy!", "bad")
		return
	end
	data.cash = data.cash - entry.cost
	table.remove(belt, entryIndex)
	broadcastBelt()
	local ref = {
		model = entry.model,
		character = entry.character,
		mutation = entry.mutation,
		income = entry.income,
		cost = entry.cost,
	}
	placeOnSlot(player, data, ref, slot)
	notify(player, "Bought " .. entry.character.name .. " for " .. BrainrotData.formatMoney(entry.cost) .. "!", "good")
	updateHud(player)
end

-- ---------------------------------------------------------------------------
-- Stealing, carrying and slapping
-- ---------------------------------------------------------------------------

-- Put a carried brainrot back where it belongs: its owner's first free
-- slot, or back on the conveyor when the owner has no room.
local function returnCarried(ref, ownerUserId)
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if owner then
		local ownerData = getData(owner)
		if ownerData then
			local slot = findFreeSlot(ownerData)
			if slot then
				ownerData.owned[slot] = ref
				ref.model:SetAttribute("OwnerUserId", ownerUserId)
				ref.model:SetAttribute("SlotIndex", slot)
				local base = getBaseOf(owner)
				ref.model:PivotTo(CFrame.new(base.slots[slot]))
				updateHud(owner)
				return
			end
		end
	end
	-- No room at home: it goes back on the belt as a fresh listing.
	ref.model:SetAttribute("OwnerUserId", nil)
	ref.model:SetAttribute("SlotIndex", nil)
	ref.model:PivotTo(CFrame.new(Config.CONVEYOR.StartX, 1, Config.CONVEYOR.Z))
	local entry = {
		id = nextBeltId,
		model = ref.model,
		character = ref.character,
		mutation = ref.mutation,
		income = ref.income,
		cost = ref.cost,
		x = Config.CONVEYOR.StartX,
	}
	nextBeltId = nextBeltId + 1
	ref.model:SetAttribute("BeltId", entry.id)
	table.insert(belt, entry)
	broadcastBelt()
end

local function dropCarried(player)
	local data = getData(player)
	if not data or not data.carrying then
		return
	end
	local ref = data.carrying
	data.carrying = nil
	applyWalkSpeed(player)
	returnCarried(ref, ref.fromUserId)
end

-- A player grabs a brainrot off someone else's unlocked base.
local function stealBrainrot(player, targetUserId, slotIndex)
	local data = getData(player)
	if not data then
		return
	end
	if data.carrying then
		notify(player, "You are already carrying a brainrot!", "bad")
		return
	end
	if targetUserId == player.UserId then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		return
	end
	local targetData = getData(target)
	if not targetData then
		return
	end
	if isBaseLocked(targetData) then
		notify(player, "That base is locked!", "bad")
		return
	end
	local ref = targetData.owned[slotIndex]
	if not ref then
		notify(player, "Nothing in that slot!", "bad")
		return
	end
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local distance = (character.HumanoidRootPart.Position - ref.model:GetPivot().Position).Magnitude
	if distance > Config.CONVEYOR.BuyRange then
		notify(player, "Get closer to steal it!", "bad")
		return
	end
	targetData.owned[slotIndex] = nil
	ref.fromUserId = targetUserId
	ref.fromSlot = slotIndex
	data.carrying = ref
	applyWalkSpeed(player)
	notify(target, player.Name .. " is stealing your " .. ref.character.name .. "! Slap them!", "bad")
	notify(player, "You grabbed " .. ref.character.name .. "! Run home!", "good")
	updateHud(player)
	updateHud(target)
end

-- Carrying a stolen brainrot home completes the steal.
local function tryDeliverSteal(player)
	local data = getData(player)
	if not data or not data.carrying then
		return
	end
	local base = getBaseOf(player)
	if not base then
		return
	end
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local distance = (character.HumanoidRootPart.Position - base.position).Magnitude
	if distance > Config.STEAL.DeliverRadius then
		return
	end
	local slot = findFreeSlot(data)
	if not slot then
		notify(player, "Your base is full — the brainrot got away!", "bad")
		dropCarried(player)
		return
	end
	local ref = data.carrying
	data.carrying = nil
	applyWalkSpeed(player)
	placeOnSlot(player, data, ref, slot)
	notify(player, "Stole " .. ref.character.name .. "! It is yours now.", "good")
	updateHud(player)
end

-- A slap knocks a thief (or Sneaky Steve) down and makes them drop what
-- they carry. The brainrot goes home to its owner.
local function slap(player, target)
	local data = getData(player)
	if not data then
		return
	end
	if data.slapReadyAt and os.time() < data.slapReadyAt then
		return
	end
	data.slapReadyAt = os.time() + Config.STEAL.SlapCooldown
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local myRoot = character.HumanoidRootPart
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return
	end
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return
	end
	local distance = (myRoot.Position - targetRoot.Position).Magnitude
	if distance > Config.STEAL.SlapRange then
		return
	end
	-- Knockback away from the slapper, stronger with the slap upgrade.
	local direction = (targetRoot.Position - myRoot.Position).Unit
	local power = Config.STEAL.SlapKnockback * (1 + 0.5 * (data.upgrades.slap or 0))
	targetRoot.AssemblyLinearVelocity = direction * power + Vector3.new(0, 18, 0)
	if target:GetAttribute("IsNPC") then
		BrainrotService.onNPCSlapped(target)
		notify(player, "Slapped Sneaky Steve! He dropped it!", "good")
		return
	end
	local victim = Players:GetPlayerFromCharacter(target)
	if not victim then
		return
	end
	local victimData = getData(victim)
	if victimData and victimData.carrying then
		dropCarried(victim)
		notify(victim, player.Name .. " slapped you! Your stolen brainrot went home.", "bad")
		notify(player, "Slap! The brainrot is safe again.", "good")
	end
end

-- ---------------------------------------------------------------------------
-- Lock, upgrades, rebirth
-- ---------------------------------------------------------------------------

local function lockBase(player)
	local data = getData(player)
	if not data then
		return
	end
	if data.lockReadyAt and os.time() < data.lockReadyAt then
		notify(player, "Lock is recharging (" .. tostring(data.lockReadyAt - os.time()) .. "s left).", "bad")
		return
	end
	data.lockedUntil = os.time() + Config.LOCK.Duration
	data.lockReadyAt = os.time() + Config.LOCK.Duration + Config.LOCK.Cooldown
	local base = getBaseOf(player)
	setGate(base, true)
	notify(player, "Base locked for " .. tostring(Config.LOCK.Duration) .. " seconds!", "good")
	updateHud(player)
end

local function buyUpgrade(player, upgradeId)
	local data = getData(player)
	local def = Config.UPGRADES[upgradeId]
	if not data or not def then
		return
	end
	local level = data.upgrades[upgradeId] or 0
	if level >= def.maxLevel then
		notify(player, def.name .. " is already maxed!", "bad")
		return
	end
	local cost = def.baseCost * (2 ^ level)
	if data.cash < cost then
		notify(player, "Not enough cash for " .. def.name .. "!", "bad")
		return
	end
	data.cash = data.cash - cost
	data.upgrades[upgradeId] = level + 1
	if upgradeId == "slots" then
		notify(player, def.name .. " level " .. tostring(level + 1) .. " — +2 slots!", "good")
	else
		notify(player, def.name .. " level " .. tostring(level + 1) .. "!", "good")
	end
	applyWalkSpeed(player)
	updateHud(player)
end

local function rebirth(player)
	local data = getData(player)
	if not data then
		return
	end
	if data.lifetimeEarned < Config.REBIRTH.RequiredLifetimeEarned then
		notify(player, "Rebirth needs " .. BrainrotData.formatMoney(Config.REBIRTH.RequiredLifetimeEarned)
			.. " lifetime earned. You have " .. BrainrotData.formatMoney(data.lifetimeEarned) .. ".", "bad")
		return
	end
	for _, ref in pairs(data.owned) do
		if ref and ref.model then
			ref.model:Destroy()
		end
	end
	if data.carrying and data.carrying.model then
		returnCarried(data.carrying, data.carrying.fromUserId)
	end
	data.owned = {}
	data.carrying = nil
	data.cash = Config.START_CASH
	data.rebirths = data.rebirths + 1
	applyWalkSpeed(player)
	notifyAll(player.Name .. " rebirthed! Income x" .. tostring(1 + Config.REBIRTH.MultiplierPerRebirth * data.rebirths) .. " forever.", "good")
	updateHud(player)
end

-- ---------------------------------------------------------------------------
-- The Noodle Tsunami
-- ---------------------------------------------------------------------------

local function washPlayerHome(player)
	local data = getData(player)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	if data and data.carrying then
		dropCarried(player)
	end
	character.HumanoidRootPart.CFrame = CFrame.new(Config.SPAWN_POSITION)
	notify(player, "The wave washed you home!", "bad")
end

local function runWaveCycle()
	while true do
		-- Quiet time between waves.
		for _ = 1, Config.WAVE.Interval do
			wavePhase = "calm"
			waveSecondsLeft = Config.WAVE.Interval
			task.wait(1)
		end
		-- Warning: get home, the wave is coming.
		wavePhase = "warning"
		notifyAll("NOODLE TSUNAMI INCOMING! Get back to your base!", "bad")
		for remaining = Config.WAVE.WarningSeconds, 1, -1 do
			waveSecondsLeft = remaining
			for _, player in ipairs(Players:GetPlayers()) do
				remotes.WaveUpdate:FireClient(player, "warning", remaining)
			end
			task.wait(1)
		end
		-- The sweep: a wall of noodles crosses the whole map.
		wavePhase = "sweeping"
		local steps = Config.WAVE.SweepSeconds * 10
		for step = 0, steps do
			local t = step / steps
			local x = -130 + 260 * t
			world.wavePart.CFrame = CFrame.new(x, 35, 0)
			waveSecondsLeft = math.ceil(Config.WAVE.SweepSeconds * (1 - t))
			if step % 10 == 0 then
				for _, player in ipairs(Players:GetPlayers()) do
					remotes.WaveUpdate:FireClient(player, "sweeping", waveSecondsLeft)
				end
			end
			if step % 5 == 0 then
				for _, player in ipairs(Players:GetPlayers()) do
					local data = getData(player)
					local base = data and getBaseOf(player)
					local character = player.Character
					if base and character and character:FindFirstChild("HumanoidRootPart") then
						local distance = (character.HumanoidRootPart.Position - base.position).Magnitude
						if distance > Config.BASE_SAFE_RADIUS then
							washPlayerHome(player)
						end
					end
				end
			end
			task.wait(0.1)
		end
		world.wavePart.CFrame = CFrame.new(-220, 35, 0)
		wavePhase = "calm"
		waveSecondsLeft = Config.WAVE.Interval
		-- Sometimes the wave leaves a Golden Hour behind: double income.
		if math.random() <= Config.WAVE.GoldenHourChance then
			eventMultiplier = Config.WAVE.GoldenHourMultiplier
			goldenHourUntil = os.time() + Config.WAVE.GoldenHourSeconds
			notifyAll("GOLDEN HOUR! Double income for " .. tostring(Config.WAVE.GoldenHourSeconds) .. " seconds!", "good")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Income tick and locks
-- ---------------------------------------------------------------------------

local function runIncomeLoop()
	while true do
		task.wait(1)
		if os.time() >= goldenHourUntil and eventMultiplier ~= 1 then
			eventMultiplier = 1
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local data = getData(player)
			if data then
				if not data.baseIndex then
					assignBase(player)
				end
				local income = incomePerSecond(data)
				data.cash = data.cash + income
				data.lifetimeEarned = data.lifetimeEarned + income
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local cashValue = leaderstats:FindFirstChild("Cash")
					if cashValue then
						cashValue.Value = data.cash
					end
					local incomeValue = leaderstats:FindFirstChild("Income")
					if incomeValue then
						incomeValue.Value = income
					end
				end
				-- A lock that ran out opens its gate again.
				if data.lockedUntil and os.time() >= data.lockedUntil then
					data.lockedUntil = nil
					setGate(getBaseOf(player), false)
				end
				updateHud(player)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- NPC rival hooks (Sneaky Steve lives in NPCRival.luau)
-- ---------------------------------------------------------------------------

local npcSlapHandler = nil

function BrainrotService.registerNPCSlapHandler(handler)
	npcSlapHandler = handler
end

function BrainrotService.onNPCSlapped(npcModel)
	if npcSlapHandler then
		npcSlapHandler(npcModel)
	end
end

-- The NPC rival asks where a victim's base is so it can walk there.
function BrainrotService.getBasePosition(player)
	local base = getBaseOf(player)
	if base then
		return base.position
	end
	return nil
end

-- Pick a victim for the NPC: a player with an unlocked base holding at
-- least one brainrot. Returns the player and a slot, or nil.
function BrainrotService.pickStealTarget()
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = getData(player)
		if data and not isBaseLocked(data) then
			local hasAny = false
			for _ in pairs(data.owned) do
				hasAny = true
				break
			end
			if hasAny then
				table.insert(candidates, player)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	local victim = candidates[math.random(1, #candidates)]
	local victimData = getData(victim)
	local slots = {}
	for slot in pairs(victimData.owned) do
		table.insert(slots, slot)
	end
	local slot = slots[math.random(1, #slots)]
	return victim, slot
end

-- The NPC grabs a brainrot off a victim's base and carries it.
function BrainrotService.npcSteal(npcModel, victim, slotIndex)
	local victimData = getData(victim)
	if not victimData then
		return nil
	end
	local ref = victimData.owned[slotIndex]
	if not ref then
		return nil
	end
	victimData.owned[slotIndex] = nil
	ref.fromUserId = victim.UserId
	ref.fromSlot = slotIndex
	npcCarrying[npcModel] = ref
	notify(victim, "Sneaky Steve is stealing your " .. ref.character.name .. "! Slap him!", "bad")
	updateHud(victim)
	return ref
end

-- The NPC was slapped: the brainrot goes home.
function BrainrotService.npcDrop(npcModel)
	local ref = npcCarrying[npcModel]
	if not ref then
		return
	end
	npcCarrying[npcModel] = nil
	returnCarried(ref, ref.fromUserId)
end

-- The NPC got away with it: the brainrot is gone for good.
function BrainrotService.npcEscape(npcModel)
	local ref = npcCarrying[npcModel]
	if not ref then
		return
	end
	npcCarrying[npcModel] = nil
	if ref.model then
		ref.model:Destroy()
	end
	local victim = Players:GetPlayerByUserId(ref.fromUserId)
	if victim then
		notify(victim, "Sneaky Steve escaped with your " .. ref.character.name .. "!", "bad")
	end
end

-- ---------------------------------------------------------------------------
-- Players
-- ---------------------------------------------------------------------------

function assignBase(player)
	local data = getData(player)
	if not data or data.baseIndex then
		return
	end
	for i, base in ipairs(world.bases) do
		if not base.ownerUserId then
			base.ownerUserId = player.UserId
			data.baseIndex = i
			updateBaseBoard(base)
			setGate(base, false)
			notify(player, "Welcome to " .. base.name .. "! Buy brainrots from the conveyor.", "good")
			return
		end
	end
	notify(player, "All bases are taken right now — hang on for a free one!", "bad")
end

local function setupPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = Config.START_CASH
	cashValue.Parent = leaderstats
	local incomeValue = Instance.new("IntValue")
	incomeValue.Name = "Income"
	incomeValue.Value = 0
	incomeValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = 0
	rebirthValue.Parent = leaderstats

	playerData[player.UserId] = {
		cash = Config.START_CASH,
		lifetimeEarned = 0,
		owned = {},
		rebirths = 0,
		upgrades = { speed = 0, slap = 0, slots = 0, income = 0 },
		lockedUntil = nil,
		lockReadyAt = 0,
		slapReadyAt = 0,
		carrying = nil,
		baseIndex = nil,
	}
	assignBase(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyWalkSpeed(player)
	end)
	if player.Character then
		applyWalkSpeed(player)
	end
	updateHud(player)
	broadcastBelt()
end

local function cleanupPlayer(player)
	local data = playerData[player.UserId]
	if not data then
		return
	end
	if data.carrying then
		returnCarried(data.carrying, data.carrying.fromUserId)
	end
	for _, ref in pairs(data.owned) do
		if ref and ref.model then
			ref.model:Destroy()
		end
	end
	if data.baseIndex then
		local base = world.bases[data.baseIndex]
		if base then
			base.ownerUserId = nil
			updateBaseBoard(base)
			setGate(base, false)
		end
	end
	playerData[player.UserId] = nil
end

-- ---------------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------------

function BrainrotService.start()
	world = WorldBuilder.buildWorld()
	remotes = createRemotes()

	remotes.BuyBrainrot.OnServerEvent:Connect(function(player, beltId)
		buyBrainrot(player, beltId)
	end)
	remotes.StealBrainrot.OnServerEvent:Connect(function(player, targetUserId, slotIndex)
		stealBrainrot(player, targetUserId, slotIndex)
	end)
	remotes.Slap.OnServerEvent:Connect(function(player, target)
		slap(player, target)
	end)
	remotes.LockBase.OnServerEvent:Connect(function(player)
		lockBase(player)
	end)
	remotes.BuyUpgrade.OnServerEvent:Connect(function(player, upgradeId)
		buyUpgrade(player, upgradeId)
	end)
	remotes.Rebirth.OnServerEvent:Connect(function(player)
		rebirth(player)
	end)

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	-- The belt starts with three brainrots already on it.
	for _ = 1, 3 do
		spawnBeltBrainrot()
	end
	task.spawn(function()
		while true do
			task.wait(Config.CONVEYOR.SpawnInterval)
			spawnBeltBrainrot()
		end
	end)
	task.spawn(runIncomeLoop)
	task.spawn(runWaveCycle)

	-- Every frame: slide the belt, float carried brainrots over their
	-- carrier's head, and hand a steal to anyone who made it home.
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		moveBelt(dt, now)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = getData(player)
			if data and data.carrying then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and data.carrying.model and data.carrying.model.Parent then
					data.carrying.model:PivotTo(root.CFrame * CFrame.new(0, 4.5, 0))
				end
				tryDeliverSteal(player)
			end
		end
	end)
end

return BrainrotService
