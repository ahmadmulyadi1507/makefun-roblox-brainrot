-- WorldBuilder: builds the whole 3D world of Brainrot Bazaar at runtime.
-- A conveyor belt down the middle, four player bases around it, trees,
-- lamps, rocks, clouds, a spawn pad and the wave wall the Noodle Tsunami
-- sweeps across the map. Everything is anchored and placed from Config,
-- so the layout the code builds is the layout the screenshots show.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local WorldBuilder = {}

local function makePart(parent, name, className, size, position, color)
	local part = Instance.new(className or "Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color or Color3.fromRGB(180, 180, 180)
	part.Anchored = true
	part.CanCollide = true
	part.Parent = parent
	return part
end

local function makeBall(parent, name, radius, position, color, transparency)
	local ball = makePart(parent, name, "Part", Vector3.new(radius * 2, radius * 2, radius * 2), position, color)
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = transparency or 0
	return ball
end

local function makeCylinder(parent, name, radius, height, position, color)
	local part = makePart(parent, name, "Part", Vector3.new(height, radius * 2, radius * 2), position, color)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- A floating name board above a base: shows the base name and its owner.
-- Kept small (150x56): BillboardGui pixels are screen-space, so the old
-- 260x100 board read as a giant "Base 1" from across the map.
local function makeBaseBoard(parent, baseDef)
	local pole = makePart(parent, "BoardPole", "Part", Vector3.new(0.6, 8, 0.6),
		baseDef.position + Vector3.new(0, 4, -Config.BASE_SIZE.Z / 2 - 1), Color3.fromRGB(90, 60, 30))
	local board = makePart(parent, "Board", "Part", Vector3.new(10, 4, 0.5),
		baseDef.position + Vector3.new(0, 9, -Config.BASE_SIZE.Z / 2 - 1), baseDef.color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BaseBoard"
	gui.Size = UDim2.new(0, 150, 0, 56)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = false
	gui.Adornee = board
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.45, 0)
	title.BackgroundTransparency = 1
	title.Text = baseDef.name
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui
	local owner = Instance.new("TextLabel")
	owner.Name = "Owner"
	owner.Size = UDim2.new(1, 0, 0.45, 0)
	owner.Position = UDim2.new(0, 0, 0.5, 0)
	owner.BackgroundTransparency = 1
	owner.Text = "FREE — claim it!"
	owner.TextColor3 = Color3.fromRGB(255, 255, 200)
	owner.TextScaled = true
	owner.Font = Enum.Font.Gotham
	owner.Parent = gui
	return owner
end

-- One player base: platform, six slot pads, a lock gate, a glowing
-- border and a beacon pillar so the base reads from across the map.
local function buildBase(parent, baseDef, index)
	local folder = Instance.new("Folder")
	folder.Name = baseDef.name:gsub(" ", "")
	folder.Parent = parent

	-- Platform 2 studs thick with its top at Y=1: a 1-stud step up from
	-- the grass, so players walk straight on, but from the low spawn
	-- camera it reads as a solid coloured slab instead of the old
	-- half-buried 0.5-stud lip that looked like a thin line.
	local platform = makePart(folder, "Platform", "Part",
		Vector3.new(Config.BASE_SIZE.X, 2, Config.BASE_SIZE.Z),
		baseDef.position + Vector3.new(0, 0, 0), baseDef.color)
	platform.Material = Enum.Material.SmoothPlastic

	-- Thick glowing border so a base reads as a safe zone at a glance,
	-- even from across the map.
	for _, border in ipairs({
		{ "BorderNorth", Vector3.new(Config.BASE_SIZE.X, 0.4, 0.4), Vector3.new(0, 1.2, -Config.BASE_SIZE.Z / 2) },
		{ "BorderSouth", Vector3.new(Config.BASE_SIZE.X, 0.4, 0.4), Vector3.new(0, 1.2, Config.BASE_SIZE.Z / 2) },
		{ "BorderWest", Vector3.new(0.4, 0.4, Config.BASE_SIZE.Z), Vector3.new(-Config.BASE_SIZE.X / 2, 1.2, 0) },
		{ "BorderEast", Vector3.new(0.4, 0.4, Config.BASE_SIZE.Z), Vector3.new(Config.BASE_SIZE.X / 2, 1.2, 0) },
	}) do
		local part = makePart(folder, border[1], "Part", border[2], baseDef.position + border[3], Color3.fromRGB(255, 255, 255))
		part.Material = Enum.Material.Neon
	end

	-- Six slot pads in a 3 by 2 grid.
	local slots = {}
	local slotIndex = 1
	for _, dz in ipairs({ -3.5, 3.5 }) do
		for _, dx in ipairs({ -7, 0, 7 }) do
			local pad = makePart(folder, "Slot" .. slotIndex, "Part", Vector3.new(6, 0.3, 6),
				baseDef.position + Vector3.new(dx, 1.15, dz), Color3.fromRGB(240, 240, 240))
			pad.Material = Enum.Material.Neon
			pad.Transparency = 0.6
			-- Slot pivot: pad top (1.3) + 3.0, because a 2.0x brainrot's
			-- feet end exactly 3.0 below its pivot.
			slots[slotIndex] = pad.Position + Vector3.new(0, 3.15, 0)
			slotIndex = slotIndex + 1
		end
	end

	-- The lock gate stands across the side that faces the conveyor. It is
	-- invisible while unlocked and glows red while the base is locked.
	-- It spans the platform top (Y=1) up to Y=7.
	local facing = 1
	if baseDef.position.Z > 0 then
		facing = -1
	end
	local gate = makePart(folder, "Gate", "Part",
		Vector3.new(Config.BASE_SIZE.X, 6, 0.5),
		baseDef.position + Vector3.new(0, 4, facing * (Config.BASE_SIZE.Z / 2)),
		Color3.fromRGB(255, 40, 40))
	gate.Material = Enum.Material.ForceField
	gate.Transparency = 1
	gate.CanCollide = false

	local ownerLabel = makeBaseBoard(folder, baseDef)

	-- A tall glowing beacon just behind the base (on the grass, clear of
	-- the slot pads and the gate) so the base reads from across the map,
	-- even from the low spawn camera.
	local beaconX = baseDef.position.X + (baseDef.position.X > 0 and 9 or -9)
	local beaconZ = baseDef.position.Z + (baseDef.position.Z > 0 and 8.5 or -8.5)
	local beacon = makePart(folder, "Beacon", "Part", Vector3.new(1.2, 12, 1.2),
		Vector3.new(beaconX, 6, beaconZ), baseDef.color)
	beacon.Material = Enum.Material.Neon
	local beaconLight = makeBall(folder, "BeaconLight", 1.5, Vector3.new(beaconX, 12.8, beaconZ), baseDef.color)
	beaconLight.Material = Enum.Material.Neon

	return {
		index = index,
		name = baseDef.name,
		position = baseDef.position,
		color = baseDef.color,
		platform = platform,
		gate = gate,
		ownerLabel = ownerLabel,
		slots = slots,
		ownerUserId = nil,
	}
end

local function buildConveyor(parent)
	local belt = makePart(parent, "Belt", "Part",
		Vector3.new(Config.CONVEYOR.EndX - Config.CONVEYOR.StartX + 4, 1, Config.CONVEYOR.Width),
		Vector3.new(0, 0.5, Config.CONVEYOR.Z), Color3.fromRGB(60, 60, 70))
	belt.Material = Enum.Material.SmoothPlastic
	-- Yellow glowing side rails, and a white glowing edge strip on the
	-- belt top, so the dark belt cuts a bright line across the grass.
	local railNorth = makePart(parent, "RailNorth", "Part", Vector3.new(128, 0.8, 0.8),
		Vector3.new(0, 1.4, Config.CONVEYOR.Z - Config.CONVEYOR.Width / 2 - 0.3), Color3.fromRGB(255, 210, 40))
	railNorth.Material = Enum.Material.Neon
	local railSouth = makePart(parent, "RailSouth", "Part", Vector3.new(128, 0.8, 0.8),
		Vector3.new(0, 1.4, Config.CONVEYOR.Z + Config.CONVEYOR.Width / 2 + 0.3), Color3.fromRGB(255, 210, 40))
	railSouth.Material = Enum.Material.Neon
	for _, z in ipairs({ Config.CONVEYOR.Z - Config.CONVEYOR.Width / 2 + 0.25, Config.CONVEYOR.Z + Config.CONVEYOR.Width / 2 - 0.25 }) do
		local strip = makePart(parent, "BeltEdge", "Part", Vector3.new(128, 0.15, 0.5),
			Vector3.new(0, 1.06, z), Color3.fromRGB(255, 255, 255))
		strip.Material = Enum.Material.Neon
	end
	-- Chevron stripes along the belt so its direction reads at a glance.
	for x = -55, 55, 10 do
		local chevron = makePart(parent, "Chevron", "Part", Vector3.new(3, 0.15, 7),
			Vector3.new(x, 1.06, Config.CONVEYOR.Z), Color3.fromRGB(255, 210, 40))
		chevron.Material = Enum.Material.Neon
	end
	-- Spawn portal (green) where brainrots walk in, exit arch (red) where
	-- the ones nobody bought walk out.
	for _, portal in ipairs({
		{ x = Config.CONVEYOR.StartX - 2, color = Color3.fromRGB(60, 220, 90) },
		{ x = Config.CONVEYOR.EndX + 2, color = Color3.fromRGB(220, 60, 60) },
	}) do
		makePart(parent, "PortalPillarA", "Part", Vector3.new(2, 8, 2),
			Vector3.new(portal.x, 4, -5), portal.color)
		makePart(parent, "PortalPillarB", "Part", Vector3.new(2, 8, 2),
			Vector3.new(portal.x, 4, 5), portal.color)
		makePart(parent, "PortalBeam", "Part", Vector3.new(2, 2, 12),
			Vector3.new(portal.x, 8.5, 0), portal.color)
	end
	return belt
end

local function buildDecorations(parent)
	-- Trees: trunk and two puffs of leaves.
	local treeSpots = {
		Vector3.new(-75, 0, -55), Vector3.new(-70, 0, 55), Vector3.new(75, 0, -55),
		Vector3.new(70, 0, 55), Vector3.new(-20, 0, -60), Vector3.new(25, 0, 60),
		Vector3.new(-95, 0, 10), Vector3.new(95, 0, -10), Vector3.new(0, 0, -70),
		Vector3.new(-55, 0, 70),
	}
	for i, spot in ipairs(treeSpots) do
		makeCylinder(parent, "TreeTrunk" .. i, 0.8, 6, spot + Vector3.new(0, 3, 0), Color3.fromRGB(120, 80, 40))
		makeBall(parent, "TreeTop" .. i, 3, spot + Vector3.new(0, 8, 0), Color3.fromRGB(50, 160, 60))
		makeBall(parent, "TreeTopB" .. i, 2, spot + Vector3.new(1.5, 10, 0.5), Color3.fromRGB(70, 180, 70))
	end
	-- Lamps along the conveyor.
	for _, x in ipairs({ -40, -15, 15, 40 }) do
		for _, z in ipairs({ -12, 12 }) do
			makeCylinder(parent, "LampPole", 0.3, 7, Vector3.new(x, 3.5, z), Color3.fromRGB(60, 60, 60))
			makeBall(parent, "LampHead", 1, Vector3.new(x, 7.2, z), Color3.fromRGB(255, 240, 150))
		end
	end
	-- Rocks scattered outside the play lanes.
	for i, spot in ipairs({
		Vector3.new(-80, 0, 30), Vector3.new(80, 0, 40), Vector3.new(60, 0, -65),
		Vector3.new(-60, 0, -45), Vector3.new(85, 0, 5), Vector3.new(-85, 0, -30),
	}) do
		makeBall(parent, "Rock" .. i, 2 + (i % 2), spot + Vector3.new(0, 1, 0), Color3.fromRGB(130, 130, 135))
	end
	-- Puffy clouds drifting high above the map.
	for i, spot in ipairs({
		Vector3.new(-60, 45, -40), Vector3.new(30, 50, 30), Vector3.new(70, 42, -60),
		Vector3.new(-30, 48, 60), Vector3.new(0, 55, -10),
	}) do
		makeBall(parent, "Cloud" .. i, 6, spot, Color3.fromRGB(255, 255, 255), 0.25)
		makeBall(parent, "CloudB" .. i, 4, spot + Vector3.new(5, 1, 0), Color3.fromRGB(255, 255, 255), 0.25)
	end
end

-- The title sign stands on the FAR side of the conveyor (Z=-32), well
-- clear of the sightline from the spawn pad (Z=55) to the belt (Z=0).
-- It used to stand at Z=46, directly in that sightline: its 34-stud
-- opaque board hid every brainrot body from the spawn camera while the
-- AlwaysOnTop name tags still showed through, so players saw only
-- floating text. The billboard is also far smaller now (400x100 instead
-- of 900x240): BillboardGui pixels are screen-space, so the old one
-- filled the whole phone screen.
local function buildSign(parent)
	local board = makePart(parent, "TitleBoard", "Part", Vector3.new(20, 5, 1),
		Vector3.new(0, 13, -32), Color3.fromRGB(40, 40, 60))
	-- Two slim posts hold the sign up; they never collide, so players
	-- can walk straight through them.
	for _, dx in ipairs({ -9, 9 }) do
		local pole = makePart(parent, "SignPole", "Part", Vector3.new(0.5, 10.5, 0.5),
			Vector3.new(dx, 5.25, -32), Color3.fromRGB(60, 60, 70))
		pole.CanCollide = false
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TitleSign"
	gui.Size = UDim2.new(0, 400, 0, 100)
	gui.AlwaysOnTop = false
	gui.Adornee = board
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.6, 0)
	title.BackgroundTransparency = 1
	title.Text = "BRAINROT BAZAAR"
	title.TextColor3 = Color3.fromRGB(255, 210, 40)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Name = "Subtitle"
	sub.Size = UDim2.new(1, 0, 0.35, 0)
	sub.Position = UDim2.new(0, 0, 0.6, 0)
	sub.BackgroundTransparency = 1
	sub.Text = "Snatch them. Stack them. Survive the wave."
	sub.TextColor3 = Color3.fromRGB(255, 255, 255)
	sub.TextScaled = true
	sub.Font = Enum.Font.GothamBold
	sub.Parent = gui
	return board
end

-- Build everything and hand back the parts the game logic needs.
function WorldBuilder.buildWorld()
	local world = Instance.new("Folder")
	world.Name = "BrainrotWorld"
	world.Parent = game:GetService("Workspace")

	buildConveyor(world)
	buildDecorations(world)
	buildSign(world)

	local bases = {}
	for i, baseDef in ipairs(Config.BASES) do
		bases[i] = buildBase(world, baseDef, i)
	end

	-- Spawn pad: players appear here when they join or get washed home.
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = Vector3.new(0, 0.5, 55)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Color = Color3.fromRGB(240, 240, 240)
	spawnLocation.Transparency = 0.4
	spawnLocation.Parent = world

	-- The wave wall waits far off the map until the tsunami comes.
	local wave = makePart(world, "WaveWall", "Part", Vector3.new(4, 70, 260),
		Vector3.new(-220, 35, 0), Color3.fromRGB(60, 140, 255))
	wave.Material = Enum.Material.Glass
	wave.Transparency = 0.45
	wave.CanCollide = false

	return {
		folder = world,
		bases = bases,
		wavePart = wave,
		spawnLocation = spawnLocation,
	}
end

return WorldBuilder
