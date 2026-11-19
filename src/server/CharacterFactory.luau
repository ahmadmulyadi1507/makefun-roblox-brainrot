-- CharacterFactory: turns a catalogue entry into a real 3D brainrot.
-- Every brainrot is a little blocky character built from parts: a body, a
-- head, eyes, and one prop that says who it is (a cape, a briefcase, a
-- wizard hat...). A floating tag above it reads its name, its rarity and
-- how much money it earns every second.

local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))

-- Belt brainrots are built 1.3x scale so they read clearly on a phone:
-- a bigger body, a bigger name tag and a glowing ring at the feet.
local MODEL_SCALE = 1.3

local CharacterFactory = {}

local function makePart(parent, name, size, position, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.Parent = parent
	return part
end

-- One prop per character id. The prop is what makes a brainrot readable
-- from across the map: a cape for Sir Toastalot, a tie for the Banana.
local function addAccessory(model, character, origin)
	local c = character.color
	if character.accessory == "Cape" then
		makePart(model, "Cape", Vector3.new(3.2, 3.4, 0.3), origin + Vector3.new(0, 1.4, -1.2), Color3.fromRGB(200, 30, 30))
	elseif character.accessory == "Tie" then
		makePart(model, "Tie", Vector3.new(0.7, 1.6, 0.3), origin + Vector3.new(0, 1.6, 1.15), Color3.fromRGB(30, 30, 120))
	elseif character.accessory == "RocketWalker" then
		makePart(model, "WalkerLeft", Vector3.new(0.8, 0.8, 2.4), origin + Vector3.new(-1.2, -0.6, 0), Color3.fromRGB(120, 120, 130))
		makePart(model, "WalkerRight", Vector3.new(0.8, 0.8, 2.4), origin + Vector3.new(1.2, -0.6, 0), Color3.fromRGB(120, 120, 130))
		makePart(model, "Flame", Vector3.new(0.9, 1.2, 0.9), origin + Vector3.new(0, -0.8, -1.4), Color3.fromRGB(255, 140, 0))
	elseif character.accessory == "Headphones" then
		makePart(model, "PhoneLeft", Vector3.new(0.5, 1.2, 1.2), origin + Vector3.new(-1.35, 3.4, 0), Color3.fromRGB(30, 30, 30))
		makePart(model, "PhoneRight", Vector3.new(0.5, 1.2, 1.2), origin + Vector3.new(1.35, 3.4, 0), Color3.fromRGB(30, 30, 30))
		makePart(model, "PhoneBand", Vector3.new(2.8, 0.4, 0.4), origin + Vector3.new(0, 4.3, 0), Color3.fromRGB(30, 30, 30))
	elseif character.accessory == "Briefcase" then
		makePart(model, "Briefcase", Vector3.new(1.8, 1.3, 0.5), origin + Vector3.new(2.2, 0.4, 0.6), Color3.fromRGB(110, 70, 30))
	elseif character.accessory == "Helmet" then
		local dome = makePart(model, "Helmet", Vector3.new(3, 3, 3), origin + Vector3.new(0, 3.5, 0), Color3.fromRGB(200, 230, 255), 0.45)
		dome.Shape = Enum.PartType.Ball
	elseif character.accessory == "WizardHat" then
		local hat = Instance.new("WedgePart")
		hat.Name = "WizardHat"
		hat.Size = Vector3.new(2.6, 2.2, 2.6)
		hat.Position = origin + Vector3.new(0, 5.2, 0)
		hat.Color = Color3.fromRGB(90, 40, 140)
		hat.Anchored = true
		hat.CanCollide = false
		hat.Parent = model
		makePart(model, "HatBrim", Vector3.new(3.6, 0.3, 3.6), origin + Vector3.new(0, 4.3, 0), Color3.fromRGB(90, 40, 140))
	elseif character.accessory == "Meatball" then
		local ball = makePart(model, "Meatball", Vector3.new(1.4, 1.4, 1.4), origin + Vector3.new(0.8, 4.8, 0), Color3.fromRGB(140, 70, 30))
		ball.Shape = Enum.PartType.Ball
	elseif character.accessory == "GoldenChair" then
		makePart(model, "ChairSeat", Vector3.new(3.4, 0.5, 3.4), origin + Vector3.new(0, -0.4, 0), Color3.fromRGB(255, 215, 0))
		makePart(model, "ChairBack", Vector3.new(3.4, 3, 0.5), origin + Vector3.new(0, 1.2, -1.6), Color3.fromRGB(255, 215, 0))
	elseif character.accessory == "Hum" then
		makePart(model, "HumGlow", Vector3.new(3.4, 3.4, 2.4), origin + Vector3.new(0, 1.6, 0), Color3.fromRGB(140, 200, 255), 0.6)
	elseif character.accessory == "Glasses" then
		makePart(model, "LensLeft", Vector3.new(0.9, 0.9, 0.2), origin + Vector3.new(-0.6, 3.5, 1.15), Color3.fromRGB(20, 20, 20))
		makePart(model, "LensRight", Vector3.new(0.9, 0.9, 0.2), origin + Vector3.new(0.6, 3.5, 1.15), Color3.fromRGB(20, 20, 20))
	elseif character.accessory == "MoonBoots" then
		makePart(model, "BootLeft", Vector3.new(1, 0.8, 1.8), origin + Vector3.new(-0.8, -0.9, 0.3), Color3.fromRGB(200, 200, 210))
		makePart(model, "BootRight", Vector3.new(1, 0.8, 1.8), origin + Vector3.new(0.8, -0.9, 0.3), Color3.fromRGB(200, 200, 210))
	end
end

-- The floating tag: name on top, rarity and money per second below.
-- Small on purpose (150x60): BillboardGui pixels are screen-space and
-- do not shrink with distance, so the old 260x100 tags merged into one
-- unreadable band — belt brainrots ride 24 studs apart, about 280 px
-- apart on a phone screen, so 150 px leaves a clear gap between them.
local function addNameTag(model, character, mutation, incomePerSecond)
	local tag = Instance.new("BillboardGui")
	tag.Name = "BrainrotTag"
	tag.Size = UDim2.new(0, 150, 0, 60)
	tag.StudsOffset = Vector3.new(0, 7, 0)
	tag.AlwaysOnTop = true
	tag.Parent = model
	local rarityInfo = BrainrotData.RARITIES[character.rarity]
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = character.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Parent = tag
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0.4, 0)
	rarityLabel.BackgroundTransparency = 1
	local rarityText = character.rarity
	if mutation.name ~= "Normal" then
		rarityText = mutation.name .. " " .. character.rarity
	end
	rarityLabel.Text = rarityText
	rarityLabel.TextColor3 = rarityInfo and rarityInfo.color or Color3.fromRGB(255, 255, 255)
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextStrokeTransparency = 0
	rarityLabel.Parent = tag
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "Income"
	incomeLabel.Size = UDim2.new(1, 0, 0.3, 0)
	incomeLabel.Position = UDim2.new(0, 0, 0.7, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = BrainrotData.formatMoney(incomePerSecond) .. "/s"
	incomeLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	incomeLabel.TextScaled = true
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextStrokeTransparency = 0
	incomeLabel.Parent = tag
	return tag
end

-- Build one brainrot model at a position, facing the way the conveyor runs.
function CharacterFactory.buildBrainrot(character, mutation, position)
	local incomePerSecond = character.income * mutation.multiplier
	local model = Instance.new("Model")
	model.Name = character.name

	local bodyColor = character.color
	if mutation.tint then
		bodyColor = mutation.tint
	end

	local body = makePart(model, "Body", Vector3.new(3, 3, 2), position + Vector3.new(0, 1.5, 0), bodyColor)
	local head = makePart(model, "Head", Vector3.new(2.2, 2.2, 2.2), position + Vector3.new(0, 4, 0),
		Color3.fromRGB(255, 220, 180))
	-- Eyes and a smile on the front of the head.
	makePart(model, "EyeLeft", Vector3.new(0.4, 0.6, 0.2), position + Vector3.new(-0.5, 4.2, 1.15), Color3.fromRGB(20, 20, 20))
	makePart(model, "EyeRight", Vector3.new(0.4, 0.6, 0.2), position + Vector3.new(0.5, 4.2, 1.15), Color3.fromRGB(20, 20, 20))
	makePart(model, "Smile", Vector3.new(1, 0.25, 0.2), position + Vector3.new(0, 3.4, 1.15), Color3.fromRGB(20, 20, 20))
	-- Little feet so it reads as walking, not sliding.
	makePart(model, "FootLeft", Vector3.new(1, 0.6, 1.4), position + Vector3.new(-0.8, 0.3, 0.2), Color3.fromRGB(40, 40, 40))
	makePart(model, "FootRight", Vector3.new(1, 0.6, 1.4), position + Vector3.new(0.8, 0.3, 0.2), Color3.fromRGB(40, 40, 40))

	addAccessory(model, character, position)
	addNameTag(model, character, mutation, incomePerSecond)

	model.PrimaryPart = body
	-- Scale the whole model up around its pivot (the body) so it reads
	-- clearly on a phone. All sizes and offsets above are pre-scale.
	model:ScaleTo(MODEL_SCALE)

	-- A glowing ring in the brainrot's rarity colour, flat on the ground
	-- under its feet, so it pops against the dark belt. The ring sits
	-- 1.85 studs below the pivot: the scaled feet end 1.95 below it.
	local rarityInfo = BrainrotData.RARITIES[character.rarity]
	local ring = Instance.new("Part")
	ring.Name = "BaseRing"
	ring.Size = Vector3.new(0.3, 6, 6)
	ring.CFrame = CFrame.new(position + Vector3.new(0, -0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = rarityInfo and rarityInfo.color or Color3.fromRGB(255, 255, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = model

	model:SetAttribute("CharacterId", character.id)
	model:SetAttribute("Mutation", mutation.name)
	model:SetAttribute("Income", incomePerSecond)
	model:SetAttribute("Cost", character.cost)
	model:SetAttribute("IsBrainrot", true)

	-- A click target so a player can buy (or steal) it by clicking it.
	local clicker = Instance.new("ClickDetector")
	clicker.Name = "BrainrotClick"
	clicker.MaxActivationDistance = 40
	clicker.Parent = body

	return model
end

return CharacterFactory
