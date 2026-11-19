-- CharacterFactory: turns a catalogue entry into a real 3D brainrot.
-- Every brainrot is a little blocky character built from parts: a body, a
-- head, eyes, and one prop that says who it is (a cape, a briefcase, a
-- wizard hat...). A floating tag above it reads its name, its rarity and
-- how much money it earns every second.
--
-- GEOMETRY RULES (read before touching the numbers):
-- * All sizes and offsets below are PRE-SCALE, relative to `origin` — the
--   point on the belt (or the base pad) the brainrot stands on.
-- * The body is always exactly 3 studs tall with its centre at +1.5, and
--   the feet always end at 0. That is the contract the rest of the game
--   relies on: after ScaleTo(2.0) the feet end exactly 3.0 below the
--   pivot, so BELT_PIVOT_Y = 4.0 puts them on the belt top (Y=1) and a
--   slot pivot of pad-top + 3.0 puts them on the pad. Never move the body
--   centre or the feet bottom, or the model sinks into (or floats over)
--   the belt.
-- * Silhouettes differ per character (ball / cylinder / box bodies, round
--   or square heads) so each one reads from 55 studs away; accessories
--   are oversized and sit ON the belt, never under it — the old
--   MoonBoots, RocketWalker flame and GoldenChair seat all hung below
--   the belt top and were invisible inside it.
-- * Materials are PBR, not flat colour: SmoothPlastic bodies, Neon for
--   anything that must glow, Metal for the golden chair and the
--   briefcase handle. Saturated colours only, so the model pops against
--   the dark belt (60,60,70) and the green grass.

local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))

-- Belt brainrots are built 2.0x scale so they read clearly on a phone:
-- at 55 studs a 2.0x body is about 10 studs tall, roughly 140 px on a
-- phone screen, with a big name tag and a glowing ring at the feet.
local MODEL_SCALE = 2.0

local CharacterFactory = {}

local function makePart(parent, name, size, position, color, transparency, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Transparency = transparency or 0
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = parent
	return part
end

local function makeBall(parent, name, diameter, position, color, transparency, material)
	local part = makePart(parent, name, Vector3.new(diameter, diameter, diameter), position, color, transparency, material)
	part.Shape = Enum.PartType.Ball
	return part
end

-- A vertical cylinder (a Roblox cylinder's long axis is X, so it is
-- rotated 90 degrees around Z to stand up).
local function makeCylinderVertical(parent, name, radius, height, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = parent
	return part
end

-- One silhouette per character id. bodySize is always (height 3, width,
-- depth): for a ball the X is the diameter, for a cylinder X is the height
-- and Y the diameter. headSize is a diameter for a ball head, a Vector3
-- for a box head. headColor overrides the default skin tone.
local SHAPES = {
	toast = {
		body = "box", bodySize = Vector3.new(3, 3, 2),
		head = "box", headSize = Vector3.new(2.4, 2.4, 2.4), headColor = Color3.fromRGB(235, 195, 120),
	},
	banana = {
		body = "cylinder", bodySize = Vector3.new(3, 3, 3),
		head = "ball", headSize = Vector3.new(2.6, 2.6, 2.6),
	},
	gran = {
		body = "box", bodySize = Vector3.new(3, 3, 2),
		head = "ball", headSize = Vector3.new(2.6, 2.6, 2.6),
		extra = function(model, origin)
			-- Grey hair bun on top of the head.
			makeBall(model, "HairBun", 1.3, origin + Vector3.new(0, 5.5, 0), Color3.fromRGB(190, 190, 190))
		end,
	},
	pickle = {
		body = "cylinder", bodySize = Vector3.new(3, 3, 3),
		head = "ball", headSize = Vector3.new(2.6, 2.6, 2.6),
	},
	capy = {
		body = "ball", bodySize = Vector3.new(3, 3, 3),
		head = "ball", headSize = Vector3.new(2.6, 2.6, 2.6),
	},
	potato = {
		body = "ball", bodySize = Vector3.new(3, 3, 3),
		head = "ball", headSize = Vector3.new(2, 2, 2),
	},
	waffle = {
		body = "box", bodySize = Vector3.new(3.2, 3, 2.2),
		head = "box", headSize = Vector3.new(2.6, 2.6, 2.6), headColor = Color3.fromRGB(230, 180, 90),
	},
	yeti = {
		body = "ball", bodySize = Vector3.new(3, 3, 3),
		head = "ball", headSize = Vector3.new(2.6, 2.6, 2.6),
	},
	meow = {
		body = "box", bodySize = Vector3.new(3, 3, 2),
		head = "ball", headSize = Vector3.new(2.6, 2.6, 2.6),
	},
	fridge = {
		body = "box", bodySize = Vector3.new(3.4, 3, 2.6),
		head = "ball", headSize = Vector3.new(2.2, 2.2, 2.2),
	},
	gum = {
		body = "box", bodySize = Vector3.new(3, 3, 2),
		head = "ball", headSize = Vector3.new(2.6, 2.6, 2.6),
		extra = function(model, origin)
			-- A bubblegum bubble blown at the mouth.
			makeBall(model, "Bubble", 1.4, origin + Vector3.new(0.9, 3.6, 1.2), Color3.fromRGB(255, 150, 200), 0.25)
		end,
	},
	moose = {
		body = "box", bodySize = Vector3.new(3, 3, 2),
		head = "ball", headSize = Vector3.new(2.6, 2.6, 2.6),
		extra = function(model, origin)
			-- Two antlers on top of the head.
			makePart(model, "AntlerLeft", Vector3.new(0.4, 1.8, 0.4), origin + Vector3.new(-1, 5.6, 0), Color3.fromRGB(90, 60, 30))
			makePart(model, "AntlerRight", Vector3.new(0.4, 1.8, 0.4), origin + Vector3.new(1, 5.6, 0), Color3.fromRGB(90, 60, 30))
		end,
	},
}

-- One prop per character id. The prop is what makes a brainrot readable
-- from across the map: a cape for Sir Toastalot, a tie for the Banana.
-- Every prop sits on or above the belt (bottom >= 0): nothing hangs
-- below the belt top any more.
local function addAccessory(model, character, origin)
	if character.accessory == "Cape" then
		makePart(model, "Cape", Vector3.new(4, 3.6, 0.3), origin + Vector3.new(0, 1.8, -1.4), Color3.fromRGB(200, 30, 30))
	elseif character.accessory == "Tie" then
		makePart(model, "Tie", Vector3.new(1, 2.2, 0.3), origin + Vector3.new(0, 1.5, 1.15), Color3.fromRGB(30, 30, 120))
		makePart(model, "TieKnot", Vector3.new(0.9, 0.6, 0.35), origin + Vector3.new(0, 2.8, 1.15), Color3.fromRGB(30, 30, 120))
	elseif character.accessory == "RocketWalker" then
		makePart(model, "WalkerLeft", Vector3.new(1.1, 1.1, 3), origin + Vector3.new(-1.4, 0.55, 0), Color3.fromRGB(120, 120, 130))
		makePart(model, "WalkerRight", Vector3.new(1.1, 1.1, 3), origin + Vector3.new(1.4, 0.55, 0), Color3.fromRGB(120, 120, 130))
		makePart(model, "Flame", Vector3.new(1.2, 1.6, 1.2), origin + Vector3.new(0, 0.8, -1.6), Color3.fromRGB(255, 140, 0), 0, Enum.Material.Neon)
	elseif character.accessory == "Headphones" then
		makePart(model, "PhoneLeft", Vector3.new(0.7, 1.6, 1.6), origin + Vector3.new(-1.6, 3.6, 0), Color3.fromRGB(30, 30, 30))
		makePart(model, "PhoneRight", Vector3.new(0.7, 1.6, 1.6), origin + Vector3.new(1.6, 3.6, 0), Color3.fromRGB(30, 30, 30))
		makePart(model, "PhoneBand", Vector3.new(3.4, 0.5, 0.5), origin + Vector3.new(0, 4.6, 0), Color3.fromRGB(30, 30, 30))
	elseif character.accessory == "Briefcase" then
		makePart(model, "Briefcase", Vector3.new(2.2, 1.5, 0.6), origin + Vector3.new(2.4, 0.9, 0.7), Color3.fromRGB(110, 70, 30))
		makePart(model, "CaseHandle", Vector3.new(1.2, 0.3, 0.3), origin + Vector3.new(2.4, 1.75, 0.7), Color3.fromRGB(200, 170, 60), 0, Enum.Material.Metal)
	elseif character.accessory == "Helmet" then
		makeBall(model, "Helmet", 3.8, origin + Vector3.new(0, 4.2, 0), Color3.fromRGB(200, 230, 255), 0.4)
	elseif character.accessory == "WizardHat" then
		local hat = Instance.new("WedgePart")
		hat.Name = "WizardHat"
		hat.Size = Vector3.new(3, 2.4, 3)
		hat.Position = origin + Vector3.new(0, 5.3, 0)
		hat.Color = Color3.fromRGB(90, 40, 140)
		hat.Anchored = true
		hat.CanCollide = false
		hat.Parent = model
		makePart(model, "HatBrim", Vector3.new(4.4, 0.4, 4.4), origin + Vector3.new(0, 4.4, 0), Color3.fromRGB(90, 40, 140))
	elseif character.accessory == "Meatball" then
		makeBall(model, "Meatball", 1.8, origin + Vector3.new(1, 5.2, 0), Color3.fromRGB(140, 70, 30))
	elseif character.accessory == "GoldenChair" then
		makePart(model, "ChairSeat", Vector3.new(4.2, 0.6, 4.2), origin + Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 215, 0), 0, Enum.Material.Metal)
		makePart(model, "ChairBack", Vector3.new(4.2, 3.6, 0.6), origin + Vector3.new(0, 2.1, -1.9), Color3.fromRGB(255, 215, 0), 0, Enum.Material.Metal)
	elseif character.accessory == "Hum" then
		makePart(model, "HumGlow", Vector3.new(4, 4, 3), origin + Vector3.new(0, 1.6, 0), Color3.fromRGB(140, 200, 255), 0.6, Enum.Material.Neon)
	elseif character.accessory == "Glasses" then
		makePart(model, "LensLeft", Vector3.new(1.1, 1.1, 0.25), origin + Vector3.new(-0.7, 4.3, 1.3), Color3.fromRGB(20, 20, 20))
		makePart(model, "LensRight", Vector3.new(1.1, 1.1, 0.25), origin + Vector3.new(0.7, 4.3, 1.3), Color3.fromRGB(20, 20, 20))
		makePart(model, "GlassesBridge", Vector3.new(0.8, 0.25, 0.25), origin + Vector3.new(0, 4.3, 1.3), Color3.fromRGB(20, 20, 20))
	elseif character.accessory == "MoonBoots" then
		makePart(model, "BootLeft", Vector3.new(1.2, 0.9, 2), origin + Vector3.new(-0.85, 0.45, 0.3), Color3.fromRGB(200, 200, 210))
		makePart(model, "BootRight", Vector3.new(1.2, 0.9, 2), origin + Vector3.new(0.85, 0.45, 0.3), Color3.fromRGB(200, 200, 210))
	end
end

-- The floating tag: name on top, rarity and money per second below.
-- Small on purpose (150x60): BillboardGui pixels are screen-space and
-- do not shrink with distance, so the old 260x100 tags merged into one
-- unreadable band — belt brainrots ride 24 studs apart, about 280 px
-- apart on a phone screen, so 150 px leaves a clear gap between them.
-- A dark semi-transparent backing keeps the text readable against the
-- bright sky. StudsOffset 11 clears the tallest hat (the WizardHat top
-- sits 10.0 above the pivot at scale 2.0).
local function addNameTag(model, character, mutation, incomePerSecond)
	local tag = Instance.new("BillboardGui")
	tag.Name = "BrainrotTag"
	tag.Size = UDim2.new(0, 150, 0, 60)
	tag.StudsOffset = Vector3.new(0, 11, 0)
	tag.AlwaysOnTop = true
	tag.Parent = model
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.45
	bg.BorderSizePixel = 0
	bg.Parent = tag
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = bg
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

	local shape = SHAPES[character.id] or SHAPES.toast

	-- Body: exactly 3 studs tall, centre at +1.5. The pivot is the body,
	-- so the feet always end 1.5 below it pre-scale (3.0 at scale 2.0).
	local body
	if shape.body == "ball" then
		body = makeBall(model, "Body", shape.bodySize.X, position + Vector3.new(0, 1.5, 0), bodyColor)
	elseif shape.body == "cylinder" then
		body = makeCylinderVertical(model, "Body", shape.bodySize.Y / 2, shape.bodySize.X, position + Vector3.new(0, 1.5, 0), bodyColor)
	else
		body = makePart(model, "Body", shape.bodySize, position + Vector3.new(0, 1.5, 0), bodyColor)
	end

	-- Head: round for most, a square slice for the toast and the waffle.
	local headColor = shape.headColor or Color3.fromRGB(255, 220, 180)
	local headDepth
	if shape.head == "box" then
		makePart(model, "Head", shape.headSize, position + Vector3.new(0, 4.2, 0), headColor)
		headDepth = shape.headSize.Z / 2
	else
		makeBall(model, "Head", shape.headSize.X, position + Vector3.new(0, 4.2, 0), headColor)
		headDepth = shape.headSize.X / 2
	end

	-- Face on the front of the head (+Z side, the side the spawn sees).
	local faceZ = headDepth + 0.05
	makePart(model, "EyeLeft", Vector3.new(0.5, 0.7, 0.3), position + Vector3.new(-0.55, 4.4, faceZ), Color3.fromRGB(20, 20, 20))
	makePart(model, "EyeRight", Vector3.new(0.5, 0.7, 0.3), position + Vector3.new(0.55, 4.4, faceZ), Color3.fromRGB(20, 20, 20))
	makePart(model, "Smile", Vector3.new(1.1, 0.3, 0.3), position + Vector3.new(0, 3.75, faceZ), Color3.fromRGB(20, 20, 20))

	-- Arms and feet so it reads as a walking character, not a sliding box.
	makePart(model, "ArmLeft", Vector3.new(0.8, 2.2, 0.8), position + Vector3.new(-1.9, 1.6, 0), bodyColor)
	makePart(model, "ArmRight", Vector3.new(0.8, 2.2, 0.8), position + Vector3.new(1.9, 1.6, 0), bodyColor)
	makePart(model, "FootLeft", Vector3.new(1.1, 0.6, 1.5), position + Vector3.new(-0.85, 0.3, 0.25), Color3.fromRGB(40, 40, 40))
	makePart(model, "FootRight", Vector3.new(1.1, 0.6, 1.5), position + Vector3.new(0.85, 0.3, 0.25), Color3.fromRGB(40, 40, 40))

	if shape.extra then
		shape.extra(model, position)
	end
	addAccessory(model, character, position)
	addNameTag(model, character, mutation, incomePerSecond)

	model.PrimaryPart = body
	-- Scale the whole model up around its pivot (the body) so it reads
	-- clearly on a phone. All sizes and offsets above are pre-scale.
	model:ScaleTo(MODEL_SCALE)

	-- A glowing ring in the brainrot's rarity colour, flat on the ground
	-- under its feet, so it pops against the dark belt. The ring sits
	-- 2.85 studs below the pivot: the scaled feet end 3.0 below it, so
	-- the ring rides just above the belt top.
	local rarityInfo = BrainrotData.RARITIES[character.rarity]
	local ring = Instance.new("Part")
	ring.Name = "BaseRing"
	ring.Size = Vector3.new(0.3, 7, 7)
	ring.CFrame = CFrame.new(body.Position + Vector3.new(0, -2.85, 0)) * CFrame.Angles(0, 0, math.rad(90))
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
