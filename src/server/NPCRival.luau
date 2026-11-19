-- NPCRival: Sneaky Steve, the rival who keeps the game tense even when
-- you play alone. He wanders near his hideout, picks an unlocked base that
-- holds brainrots, walks over, grabs one and runs for his hideout. Slap
-- him while he carries it and the brainrot goes home to its owner. If he
-- reaches his hideout, the brainrot is gone for good.
--
-- Steve is a simple blocky rig with a Humanoid, so he walks with
-- Humanoid:MoveTo like any Roblox character. His brain is a little state
-- machine that rethinks what to do every ThinkInterval seconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BrainrotService = require(script.Parent:WaitForChild("BrainrotService"))

local NPCRival = {}

local npcModel = nil
local npcHumanoid = nil
local npcRoot = nil
local carriedRef = nil
local state = "idle" -- idle | hunting | fleeing
local victim = nil
local victimSlot = nil
local lastStealAt = 0
local moveTarget = nil

local function makePart(parent, name, size, position, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = false
	part.CanCollide = true
	part.Parent = parent
	return part
end

-- Build Steve: a dark-hooded figure with a mask and a sack.
local function buildNPC(position)
	local model = Instance.new("Model")
	model.Name = Config.NPC.Name

	local root = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), position + Vector3.new(0, 3, 0), Color3.fromRGB(40, 40, 50))
	local torso = makePart(model, "Torso", Vector3.new(2, 2, 1), position + Vector3.new(0, 3, 0), Color3.fromRGB(40, 40, 50))
	local head = makePart(model, "Head", Vector3.new(1.6, 1.6, 1.6), position + Vector3.new(0, 4.8, 0), Color3.fromRGB(255, 220, 180))
	head.Shape = Enum.PartType.Ball
	-- Mask and hood.
	makePart(model, "Mask", Vector3.new(1.7, 0.7, 0.3), position + Vector3.new(0, 4.9, 0.75), Color3.fromRGB(20, 20, 20))
	makePart(model, "Hood", Vector3.new(2.2, 1.2, 2.2), position + Vector3.new(0, 5.6, 0), Color3.fromRGB(40, 40, 50))
	-- Arms, legs and the sack on his back.
	makePart(model, "LeftArm", Vector3.new(1, 2, 1), position + Vector3.new(-1.5, 3, 0), Color3.fromRGB(40, 40, 50))
	makePart(model, "RightArm", Vector3.new(1, 2, 1), position + Vector3.new(1.5, 3, 0), Color3.fromRGB(40, 40, 50))
	makePart(model, "LeftLeg", Vector3.new(1, 2, 1), position + Vector3.new(-0.5, 1, 0), Color3.fromRGB(25, 25, 35))
	makePart(model, "RightLeg", Vector3.new(1, 2, 1), position + Vector3.new(0.5, 1, 0), Color3.fromRGB(25, 25, 35))
	makePart(model, "Sack", Vector3.new(1.6, 1.6, 1), position + Vector3.new(0, 3.4, -0.9), Color3.fromRGB(150, 110, 60))

	-- Weld the limbs to the torso so the model walks as one body.
	local function weld(part0, part1, offset)
		local weld = Instance.new("Weld")
		weld.Part0 = part0
		weld.Part1 = part1
		weld.C0 = offset
		weld.Parent = part0
	end
	weld(torso, head, CFrame.new(0, 1.8, 0))
	weld(torso, model:FindFirstChild("LeftArm"), CFrame.new(-1.5, 0, 0))
	weld(torso, model:FindFirstChild("RightArm"), CFrame.new(1.5, 0, 0))
	weld(torso, model:FindFirstChild("LeftLeg"), CFrame.new(-0.5, -2, 0))
	weld(torso, model:FindFirstChild("RightLeg"), CFrame.new(0.5, -2, 0))
	weld(torso, model:FindFirstChild("Sack"), CFrame.new(0, 0.4, -0.9))
	weld(torso, model:FindFirstChild("Hood"), CFrame.new(0, 2.6, 0))
	weld(torso, model:FindFirstChild("Mask"), CFrame.new(0, 1.9, 0.75))
	-- The root part rides with the torso.
	local rootWeld = Instance.new("Weld")
	rootWeld.Part0 = root
	rootWeld.Part1 = torso
	rootWeld.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = Config.NPC.WalkSpeed
	humanoid.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("IsNPC", true)

	-- A name tag so players know exactly who is sneaking around.
	local tag = Instance.new("BillboardGui")
	tag.Name = "NPCTag"
	tag.Size = UDim2.new(0, 200, 0, 60)
	tag.StudsOffset = Vector3.new(0, 4.5, 0)
	tag.AlwaysOnTop = true
	tag.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "SNEAKY STEVE"
	label.TextColor3 = Color3.fromRGB(255, 90, 90)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.2
	label.Parent = tag

	model.Parent = game:GetService("Workspace")
	return model, humanoid, root
end

-- Walk to a point and wait until Steve gets there (or gives up). While he
-- walks, a brainrot he carries floats above his head, the way a player's
-- stolen brainrot does.
local function walkTo(target, carry)
	if not npcHumanoid or not npcRoot then
		return false
	end
	moveTarget = target
	npcHumanoid:MoveTo(target)
	local finished = false
	local connection
	connection = npcHumanoid.MoveToFinished:Connect(function(reached)
		finished = reached
		if connection then
			connection:Disconnect()
		end
	end)
	local waited = 0
	while not finished and waited < 20 do
		task.wait(0.5)
		waited = waited + 0.5
		if carry and carry.model and carry.model.Parent then
			carry.model:PivotTo(npcRoot.CFrame * CFrame.new(0, 5.0, 0))
		end
		-- Re-aim if the target moved (a victim's base never moves, but a
		-- fleeing Steve should keep pushing towards his hideout).
		if moveTarget and (npcRoot.Position - moveTarget).Magnitude > 4 then
			npcHumanoid:MoveTo(moveTarget)
		end
	end
	if connection then
		connection:Disconnect()
	end
	return finished
end

-- Steve was slapped: drop the brainrot, forget the plan, run home.
local function onSlapped(_npcModel)
	if carriedRef then
		BrainrotService.npcDrop(npcModel)
		carriedRef = nil
	end
	victim = nil
	victimSlot = nil
	state = "idle"
	if npcHumanoid then
		npcHumanoid.WalkSpeed = Config.NPC.WalkSpeed + 4
		npcHumanoid:MoveTo(Config.NPC.Hideout)
		task.delay(3, function()
			if npcHumanoid then
				npcHumanoid.WalkSpeed = Config.NPC.WalkSpeed
			end
		end)
	end
end

-- One think step of the state machine.
local function think()
	if not npcModel or not npcHumanoid or not npcRoot then
		return
	end
	if state == "idle" then
		-- Wander near the hideout until the cooldown is up.
		if os.time() - lastStealAt < Config.NPC.StealCooldown then
			local wander = Config.NPC.Hideout + Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
			walkTo(wander)
			return
		end
		local targetPlayer, slot = BrainrotService.pickStealTarget()
		if not targetPlayer then
			local wander = Config.NPC.Hideout + Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
			walkTo(wander)
			return
		end
		victim = targetPlayer
		victimSlot = slot
		state = "hunting"
	elseif state == "hunting" then
		if not victim or not victim.Parent then
			state = "idle"
			return
		end
		-- Walk to the victim's base, then grab the brainrot from its pad.
		local basePosition = BrainrotService.getBasePosition(victim)
		if not basePosition then
			state = "idle"
			return
		end
		walkTo(basePosition)
		local ref = BrainrotService.npcSteal(npcModel, victim, victimSlot)
		if ref then
			carriedRef = ref
			state = "fleeing"
			lastStealAt = os.time()
		else
			-- Someone else got it first, or the base locked. Rethink.
			state = "idle"
			victim = nil
			victimSlot = nil
		end
	elseif state == "fleeing" then
		if not carriedRef then
			state = "idle"
			return
		end
		-- Carry the brainrot above his head, the way players carry theirs.
		if carriedRef.model and carriedRef.model.Parent then
			carriedRef.model:PivotTo(npcRoot.CFrame * CFrame.new(0, 5.0, 0))
		end
		local reached = walkTo(Config.NPC.Hideout, carriedRef)
		if reached or (npcRoot.Position - Config.NPC.Hideout).Magnitude < 8 then
			BrainrotService.npcEscape(npcModel)
			carriedRef = nil
			victim = nil
			victimSlot = nil
			state = "idle"
		end
	end
end

function NPCRival.start()
	npcModel, npcHumanoid, npcRoot = buildNPC(Config.NPC.Hideout + Vector3.new(0, 3, 0))
	BrainrotService.registerNPCSlapHandler(onSlapped)
	task.spawn(function()
		while true do
			task.wait(Config.NPC.ThinkInterval)
			-- Never think while a wave is sweeping; Steve hides too.
			local ok, err = pcall(think)
			if not ok then
				warn("Sneaky Steve stumbled: " .. tostring(err))
				state = "idle"
				victim = nil
				victimSlot = nil
			end
		end
	end)
end

return NPCRival
