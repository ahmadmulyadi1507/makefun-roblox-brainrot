-- CharacterFactory: turns a catalogue entry into a real 3D brainrot.
-- Every brainrot is a classic Roblox R6 avatar: a square torso, two
-- arms, two legs and a cube head with the classic Roblox face (two eyes
-- and a smile, built from parts). No Humanoid — the model stays anchored
-- and is moved with PivotTo, exactly like before. A floating tag above
-- it reads its name, its rarity and how much money it earns every second.
--
-- GEOMETRY RULES (read before touching the numbers):
-- * All sizes and offsets below are PRE-SCALE, relative to `origin` — the
--   point on the belt (or the base pad) the brainrot stands on.
-- * Classic R6 layout, pre-scale: legs 1x2x1 (feet at 0, tops at 2),
--   torso 2x2x1 with its centre at +3.0 (the pivot), arms 1x2x1 at the
--   torso's sides, head a 1.2 cube centred at +4.6 (top at 5.2).
-- * The pivot is the torso centre, exactly 3.0 above the feet pre-scale,
--   so after ScaleTo(2.0) the feet end exactly 6.0 below the pivot:
--   BELT_PIVOT_Y = 7.0 puts them on the belt top (Y=1) and a slot pivot
--   of pad-top + 6.0 puts them on the pad. Never move the torso centre
--   or the feet bottom, or the model sinks into (or floats over) the belt.
-- * Identity comes from the body colour + ONE oversized prop per
--   character (cape, tie, helmet, wizard hat...), never from the body
--   shape — every brainrot shares the same R6 skeleton, the way
--   characters in a normal Roblox game do. Every prop sits ON the belt
--   (bottom >= 0): nothing hangs below the belt top.
-- * Materials are PBR, not flat colour: SmoothPlastic bodies, Neon for
--   anything that must glow, Metal for the golden chair and the
--   briefcase handle. Saturated colours only, so the model pops against
--   the dark belt (60,60,70) and the green grass.

local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))

-- Belt brainrots are built 2.0x scale so they read clearly on a phone:
-- a classic R6 avatar is 5.2 studs tall, so at 2.0x it stands about
-- 10.4 studs tall on the belt, roughly 140 px on a phone screen, with
-- a big name tag and a glowing ring at the feet.
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

-- A darker shade of a colour, for the legs (classic avatars wear darker
-- pants than their shirt).
local function darken(color, factor)
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

-- Head colours that override the default skin tone.
local HEAD_COLORS = {
	toast = Color3.fromRGB(235, 195, 120),
	waffle = Color3.fromRGB(230, 180, 90),
}

-- One small extra per character id, on top of the R6 skeleton and the
-- accessory below. Everything sits above the belt (bottom >= 0).
local EXTRAS = {
	gran = function(model, origin)
		-- Grey hair bun on top of the head.
		makeBall(model, "HairBun", 1.2, origin + Vector3.new(0, 5.5, 0), Color3.fromRGB(190, 190, 190))
	end,
	gum = function(model, origin)
		-- A bubblegum bubble blown at the mouth.
		makeBall(model, "Bubble", 1.3, origin + Vector3.new(0.8, 4.5, 0.9), Color3.fromRGB(255, 150, 200), 0.25)
	end,
	moose = function(model, origin)
		-- Two antlers on top of the head.
		makePart(model, "AntlerLeft", Vector3.new(0.35, 1.6, 0.35), origin + Vector3.new(-0.9, 5.8, 0), Color3.fromRGB(90, 60, 30))
		makePart(model, "AntlerRight", Vector3.new(0.35, 1.6, 0.35), origin + Vector3.new(0.9, 5.8, 0), Color3.fromRGB(90, 60, 30))
	end,
}

-- One prop per character id. The prop is what makes a brainrot readable
-- from across the map: a cape for Sir Toastalot, a tie for the Banana.
-- Every prop sits on or above the belt (bottom >= 0): nothing hangs
-- below the belt top any more.
local function addAccessory(model, character, origin)
	if character.accessory == "Cape" then
		makePart(model, "Cape", Vector3.new(2.6, 3.4, 0.3), origin + Vector3.new(0, 2.2, -0.75), Color3.fromRGB(200, 30, 30))
	elseif character.accessory == "Tie" then
		makePart(model, "Tie", Vector3.new(0.8, 1.6, 0.25), origin + Vector3.new(0, 3, 0.6), Color3.fromRGB(30, 30, 120))
		makePart(model, "TieKnot", Vector3.new(0.7, 0.5, 0.3), origin + Vector3.new(0, 3.9, 0.6), Color3.fromRGB(30, 30, 120))
	elseif character.accessory == "RocketWalker" then
		makePart(model, "WalkerLeft", Vector3.new(1, 1, 2.6), origin + Vector3.new(-1.3, 0.5, 0), Color3.fromRGB(120, 120, 130))
		makePart(model, "WalkerRight", Vector3.new(1, 1, 2.6), origin + Vector3.new(1.3, 0.5, 0), Color3.fromRGB(120, 120, 130))
		makePart(model, "Flame", Vector3.new(1, 1.4, 1), origin + Vector3.new(0, 0.7, -1.4), Color3.fromRGB(255, 140, 0), 0, Enum.Material.Neon)
	elseif character.accessory == "Headphones" then
		makePart(model, "PhoneLeft", Vector3.new(0.6, 1.2, 1.2), origin + Vector3.new(-0.95, 4.6, 0), Color3.fromRGB(30, 30, 30))
		makePart(model, "PhoneRight", Vector3.new(0.6, 1.2, 1.2), origin + Vector3.new(0.95, 4.6, 0), Color3.fromRGB(30, 30, 30))
		makePart(model, "PhoneBand", Vector3.new(2.6, 0.4, 0.4), origin + Vector3.new(0, 5.4, 0), Color3.fromRGB(30, 30, 30))
	elseif character.accessory == "Briefcase" then
		makePart(model, "Briefcase", Vector3.new(2, 1.4, 0.5), origin + Vector3.new(2.3, 1, 0.3), Color3.fromRGB(110, 70, 30))
		makePart(model, "CaseHandle", Vector3.new(1, 0.25, 0.25), origin + Vector3.new(2.3, 1.8, 0.3), Color3.fromRGB(200, 170, 60), 0, Enum.Material.Metal)
	elseif character.accessory == "Helmet" then
		makeBall(model, "Helmet", 2.6, origin + Vector3.new(0, 4.6, 0), Color3.fromRGB(200, 230, 255), 0.4)
	elseif character.accessory == "WizardHat" then
		local hat = Instance.new("WedgePart")
		hat.Name = "WizardHat"
		hat.Size = Vector3.new(2.4, 2.2, 2.4)
		hat.Position = origin + Vector3.new(0, 6.3, 0)
		hat.Color = Color3.fromRGB(90, 40, 140)
		hat.Anchored = true
		hat.CanCollide = false
		hat.Parent = model
		makePart(model, "HatBrim", Vector3.new(3.6, 0.3, 3.6), origin + Vector3.new(0, 5.3, 0), Color3.fromRGB(90, 40, 140))
	elseif character.accessory == "Meatball" then
		makeBall(model, "Meatball", 1.6, origin + Vector3.new(0.9, 5.6, 0), Color3.fromRGB(140, 70, 30))
	elseif character.accessory == "GoldenChair" then
		makePart(model, "ChairSeat", Vector3.new(2.6, 0.4, 2), origin + Vector3.new(0, 0.2, -1.4), Color3.fromRGB(255, 215, 0), 0, Enum.Material.Metal)
		makePart(model, "ChairBack", Vector3.new(2.6, 2.6, 0.4), origin + Vector3.new(0, 1.5, -2.1), Color3.fromRGB(255, 215, 0), 0, Enum.Material.Metal)
	elseif character.accessory == "Hum" then
		makePart(model, "HumGlow", Vector3.new(3, 3, 2), origin + Vector3.new(0, 3, 0), Color3.fromRGB(140, 200, 255), 0.6, Enum.Material.Neon)
	elseif character.accessory == "Glasses" then
		makePart(model, "LensLeft", Vector3.new(0.8, 0.8, 0.2), origin + Vector3.new(-0.55, 4.7, 0.65), Color3.fromRGB(20, 20, 20))
		makePart(model, "LensRight", Vector3.new(0.8, 0.8, 0.2), origin + Vector3.new(0.55, 4.7, 0.65), Color3.fromRGB(20, 20, 20))
		makePart(model, "GlassesBridge", Vector3.new(0.6, 0.2, 0.2), origin + Vector3.new(0, 4.7, 0.65), Color3.fromRGB(20, 20, 20))
	elseif character.accessory == "MoonBoots" then
		makePart(model, "BootLeft", Vector3.new(1.2, 1, 2), origin + Vector3.new(-0.5, 0.5, 0.2), Color3.fromRGB(200, 200, 210))
		makePart(model, "BootRight", Vector3.new(1.2, 1, 2), origin + Vector3.new(0.5, 0.5, 0.2), Color3.fromRGB(200, 200, 210))
	end
end

-- The floating tag: name on top, rarity and money per second below.
-- Small on purpose (150x60): BillboardGui pixels are screen-space and
-- do not shrink with distance, so the old 260x100 tags merged into one
-- unreadable band — belt brainrots ride 24 studs apart, about 280 px
-- apart on a phone screen, so 150 px leaves a clear gap between them.
-- A dark semi-transparent backing keeps the text readable against the
-- bright sky. StudsOffset 10 clears the tallest hat (the WizardHat top
-- sits 8.8 above the pivot at scale 2.0).
local function addNameTag(model, character, mutation, incomePerSecond)
	local tag = Instance.new("BillboardGui")
	tag.Name = "BrainrotTag"
	tag.Size = UDim2.new(0, 150, 0, 60)
	tag.StudsOffset = Vector3.new(0, 10, 0)
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
-- Classic R6: legs, square torso, arms, cube head with the classic face.
function CharacterFactory.buildBrainrot(character, mutation, position)
	local incomePerSecond = character.income * mutation.multiplier
	local model = Instance.new("Model")
	model.Name = character.name

	local bodyColor = character.color
	if mutation.tint then
		bodyColor = mutation.tint
	end
	local legColor = darken(bodyColor, 0.65)

	-- Legs: 1x2x1, feet at 0, tops at 2.
	makePart(model, "LeftLeg", Vector3.new(1, 2, 1), position + Vector3.new(-0.5, 1, 0), legColor)
	makePart(model, "RightLeg", Vector3.new(1, 2, 1), position + Vector3.new(0.5, 1, 0), legColor)

	-- Torso: 2x2x1, centre at +3.0 — the pivot. Feet end exactly 3.0
	-- below it pre-scale (6.0 at scale 2.0).
	local body = makePart(model, "Body", Vector3.new(2, 2, 1), position + Vector3.new(0, 3, 0), bodyColor)

	-- Arms: 1x2x1 at the torso's sides.
	makePart(model, "LeftArm", Vector3.new(1, 2, 1), position + Vector3.new(-1.5, 3, 0), bodyColor)
	makePart(model, "RightArm", Vector3.new(1, 2, 1), position + Vector3.new(1.5, 3, 0), bodyColor)

	-- Head: a 1.2 cube centred at +4.6 (top at 5.2), classic skin tone
	-- unless the character overrides it.
	local headColor = HEAD_COLORS[character.id] or Color3.fromRGB(255, 220, 180)
	makePart(model, "Head", Vector3.new(1.2, 1.2, 1.2), position + Vector3.new(0, 4.6, 0), headColor)

	-- The classic Roblox face on the front of the head (+Z side, the
	-- side the spawn sees): two eyes and a smile, built from parts.
	makePart(model, "EyeLeft", Vector3.new(0.35, 0.45, 0.15), position + Vector3.new(-0.28, 4.75, 0.65), Color3.fromRGB(20, 20, 20))
	makePart(model, "EyeRight", Vector3.new(0.35, 0.45, 0.15), position + Vector3.new(0.28, 4.75, 0.65), Color3.fromRGB(20, 20, 20))
	makePart(model, "Smile", Vector3.new(0.7, 0.18, 0.15), position + Vector3.new(0, 4.35, 0.65), Color3.fromRGB(20, 20, 20))

	local extra = EXTRAS[character.id]
	if extra then
		extra(model, position)
	end
	addAccessory(model, character, position)
	addNameTag(model, character, mutation, incomePerSecond)

	model.PrimaryPart = body
	-- Scale the whole model up around its pivot (the body) so it reads
	-- clearly on a phone. All sizes and offsets above are pre-scale.
	model:ScaleTo(MODEL_SCALE)

	-- A glowing ring in the brainrot's rarity colour, flat on the ground
	-- under its feet, so it pops against the dark belt. The ring sits
	-- 5.85 studs below the pivot: the scaled feet end 6.0 below it, so
	-- the ring rides just above the belt top.
	local rarityInfo = BrainrotData.RARITIES[character.rarity]
	local ring = Instance.new("Part")
	ring.Name = "BaseRing"
	ring.Size = Vector3.new(0.3, 8, 8)
	ring.CFrame = CFrame.new(body.Position + Vector3.new(0, -5.85, 0)) * CFrame.Angles(0, 0, math.rad(90))
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
