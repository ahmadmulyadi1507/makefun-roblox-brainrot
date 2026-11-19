-- Brainrot Bazaar, client HUD.
-- Everything on screen is a display: the server owns the money, the bases
-- and the brainrots, and this script only asks it to do things. Buying,
-- stealing, slapping, locking, upgrading and rebirthing all go through the
-- remotes, and the server answers with fresh numbers.
--
-- The HUD stays clear of the top-left corner, where Roblox puts its own
-- menu buttons. Slap is bound to F through ContextActionService (never a
-- raw InputBegan handler, so the camera's arrow keys keep working).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local buyEvent = remotes:WaitForChild("BuyBrainrot")
local stealEvent = remotes:WaitForChild("StealBrainrot")
local slapEvent = remotes:WaitForChild("Slap")
local lockEvent = remotes:WaitForChild("LockBase")
local upgradeEvent = remotes:WaitForChild("BuyUpgrade")
local rebirthEvent = remotes:WaitForChild("Rebirth")
local hudEvent = remotes:WaitForChild("HudUpdate")
local beltEvent = remotes:WaitForChild("BeltUpdate")
local notifyEvent = remotes:WaitForChild("Notify")
local waveEvent = remotes:WaitForChild("WaveUpdate")

-- ---------------------------------------------------------------------------
-- Frames
-- ---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(parent, name, size, position, text, textColor, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.3
	label.Parent = parent
	return label
end

local function makeButton(parent, name, size, position, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color or Color3.fromRGB(60, 140, 70)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	return button
end

-- Top bar: cash, income, rebirths and the wave timer, centred. Scale
-- width so it never swallows a phone screen.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 8)
topBar.Size = UDim2.new(0.46, 0, 0, 44)
topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
topBar.BackgroundTransparency = 0.15
topBar.Parent = gui
local topBarSize = Instance.new("UISizeConstraint")
topBarSize.MinSize = Vector2.new(300, 44)
topBarSize.MaxSize = Vector2.new(560, 44)
topBarSize.Parent = topBar
local cashLabel = makeLabel(topBar, "Cash", UDim2.new(0.30, 0, 1, 0), UDim2.new(0.01, 0, 0, 0), "$100", Color3.fromRGB(120, 255, 120))
local incomeLabel = makeLabel(topBar, "Income", UDim2.new(0.26, 0, 1, 0), UDim2.new(0.32, 0, 0, 0), "+$0/s", Color3.fromRGB(255, 220, 90))
local rebirthLabel = makeLabel(topBar, "Rebirths", UDim2.new(0.19, 0, 1, 0), UDim2.new(0.59, 0, 0, 0), "Rebirth x0", Color3.fromRGB(180, 140, 255))
local waveLabel = makeLabel(topBar, "Wave", UDim2.new(0.20, 0, 1, 0), UDim2.new(0.79, 0, 0, 0), "Wave: --", Color3.fromRGB(120, 180, 255))

-- Toast messages under the top bar.
local toast = makeLabel(gui, "Toast", UDim2.new(0.4, 0, 0, 36), UDim2.new(0.3, 0, 0, 58), "", Color3.fromRGB(255, 255, 255))
local toastStamp = 0
local function showToast(message, kind)
	toast.Text = message
	if kind == "good" then
		toast.TextColor3 = Color3.fromRGB(120, 255, 120)
	elseif kind == "bad" then
		toast.TextColor3 = Color3.fromRGB(255, 110, 110)
	else
		toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	local stamp = os.clock()
	toastStamp = stamp
	task.delay(3, function()
		if toastStamp == stamp then
			toast.Text = ""
		end
	end)
end

-- Wave banner: the big warning in the middle of the screen.
local waveBanner = makeLabel(gui, "WaveBanner", UDim2.new(0.7, 0, 0, 70), UDim2.new(0.15, 0, 0.45, 0), "", Color3.fromRGB(255, 90, 90), Enum.Font.GothamBlack)
waveBanner.Visible = false

-- Mission banner: what to actually do, in Indonesian, shown on join.
-- It hides itself after a while; the "?" button brings it back.
local mission = Instance.new("Frame")
mission.Name = "Mission"
mission.AnchorPoint = Vector2.new(0.5, 0)
mission.Position = UDim2.new(0.5, 0, 0, 100)
mission.Size = UDim2.new(0.46, 0, 0, 118)
mission.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mission.BackgroundTransparency = 0.1
mission.Parent = gui
local missionSize = Instance.new("UISizeConstraint")
missionSize.MinSize = Vector2.new(300, 118)
missionSize.MaxSize = Vector2.new(560, 118)
missionSize.Parent = mission
makeLabel(mission, "MissionTitle", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 4), "MISI — CARA MAIN", Color3.fromRGB(255, 210, 40))
local missionText = Instance.new("TextLabel")
missionText.Name = "MissionText"
missionText.Size = UDim2.new(1, -16, 0, 52)
missionText.Position = UDim2.new(0, 8, 0, 30)
missionText.BackgroundTransparency = 1
missionText.Text = "Beli brainrot di conveyor → brainrot menghasilkan uang tiap detik → kunci base-mu → rebut brainrot lawan!"
missionText.TextColor3 = Color3.fromRGB(255, 255, 255)
missionText.TextWrapped = true
missionText.TextScaled = true
missionText.Font = Enum.Font.Gotham
missionText.TextYAlignment = Enum.TextYAlignment.Top
missionText.TextXAlignment = Enum.TextXAlignment.Left
missionText.Parent = mission
local missionClose = makeButton(mission, "Close", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 82), "MENGERTI", Color3.fromRGB(60, 140, 70))
missionClose.MouseButton1Click:Connect(function()
	mission.Visible = false
end)
local helpButton = makeButton(gui, "Help", UDim2.new(0, 40, 0, 40), UDim2.new(1, -50, 0, 8), "?", Color3.fromRGB(70, 110, 200))
helpButton.MouseButton1Click:Connect(function()
	mission.Visible = true
end)
task.delay(25, function()
	mission.Visible = false
end)

-- Reopen buttons for the two side panels. They start hidden and only
-- appear while their panel is closed, so the screen is never stuck
-- behind a panel the player cannot dismiss.
local shopOpen = makeButton(gui, "ShopOpen", UDim2.new(0, 56, 0, 44), UDim2.new(1, -66, 0, 60), "BELT", Color3.fromRGB(60, 140, 70))
shopOpen.Visible = false
local baseOpen = makeButton(gui, "BaseOpen", UDim2.new(0, 56, 0, 44), UDim2.new(0, 10, 0, 60), "BASE", Color3.fromRGB(70, 90, 180))
baseOpen.Visible = false

-- Shop: what is on the conveyor right now, with a Buy button each.
-- Scale-sized and scrollable, so it fits a phone in landscape instead
-- of swallowing the middle of the screen.
local shop = Instance.new("Frame")
shop.Name = "Shop"
shop.AnchorPoint = Vector2.new(1, 0)
shop.Position = UDim2.new(1, -10, 0, 60)
shop.Size = UDim2.new(0.30, 0, 0.52, 0)
shop.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
shop.BackgroundTransparency = 0.15
shop.Parent = gui
local shopSize = Instance.new("UISizeConstraint")
shopSize.MinSize = Vector2.new(250, 240)
shopSize.MaxSize = Vector2.new(330, 430)
shopSize.Parent = shop
makeLabel(shop, "ShopTitle", UDim2.new(1, -48, 0, 34), UDim2.new(0, 0, 0, 0), "CONVEYOR — ON SALE", Color3.fromRGB(255, 210, 40))
local shopClose = makeButton(shop, "Close", UDim2.new(0, 40, 0, 30), UDim2.new(1, -44, 0, 2), "X", Color3.fromRGB(160, 50, 50))
shopClose.MouseButton1Click:Connect(function()
	shop.Visible = false
	shopOpen.Visible = true
end)
shopOpen.MouseButton1Click:Connect(function()
	shop.Visible = true
	shopOpen.Visible = false
end)
local shopList = Instance.new("ScrollingFrame")
shopList.Name = "ShopList"
shopList.Size = UDim2.new(1, -8, 1, -40)
shopList.Position = UDim2.new(0, 4, 0, 38)
shopList.BackgroundTransparency = 1
shopList.ScrollBarThickness = 6
shopList.ScrollingDirection = Enum.ScrollingDirection.Y
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.CanvasSize = UDim2.new(0, 0, 0, 0)
shopList.Parent = shop
local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 4)
shopLayout.Parent = shopList

local function rebuildShop(entries)
	for _, child in ipairs(shopList:GetChildren()) do
		if child:IsA("Frame") or child.Name == "Empty" then
			child:Destroy()
		end
	end
	if #entries == 0 then
		makeLabel(shopList, "Empty", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), "The belt is empty... for now.", Color3.fromRGB(200, 200, 200))
		return
	end
	for _, entry in ipairs(entries) do
		local row = Instance.new("Frame")
		row.Name = "Row" .. tostring(entry.id)
		row.Size = UDim2.new(1, 0, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
		row.Parent = shopList
		local rarityColor = Color3.fromRGB(200, 200, 200)
		local rarityInfo = BrainrotData.RARITIES[entry.rarity]
		if rarityInfo then
			rarityColor = rarityInfo.color
		end
		local title = entry.name
		if entry.mutation ~= "Normal" then
			title = entry.mutation .. " " .. title
		end
		makeLabel(row, "Name", UDim2.new(0.62, 0, 0, 26), UDim2.new(0.03, 0, 0, 4), title, rarityColor)
		makeLabel(row, "Stats", UDim2.new(0.62, 0, 0, 20), UDim2.new(0.03, 0, 0, 30),
			entry.rarity .. "  •  " .. BrainrotData.formatMoney(entry.income) .. "/s", Color3.fromRGB(200, 200, 200), Enum.Font.Gotham)
		local buyButton = makeButton(row, "Buy", UDim2.new(0.32, 0, 0, 44), UDim2.new(0.66, 0, 0, 6),
			"BUY " .. BrainrotData.formatMoney(entry.cost), Color3.fromRGB(60, 140, 70))
		buyButton.MouseButton1Click:Connect(function()
			buyEvent:FireServer(entry.id)
		end)
	end
end

-- Base panel: lock, upgrades and rebirth. Top-left now (below the
-- Roblox menu) instead of bottom-left, so the mobile joystick never
-- sits on top of it. Scale-sized and scrollable like the shop.
local basePanel = Instance.new("Frame")
basePanel.Name = "BasePanel"
basePanel.AnchorPoint = Vector2.new(0, 0)
basePanel.Position = UDim2.new(0, 10, 0, 60)
basePanel.Size = UDim2.new(0.30, 0, 0.52, 0)
basePanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
basePanel.BackgroundTransparency = 0.15
basePanel.Parent = gui
local baseSize = Instance.new("UISizeConstraint")
baseSize.MinSize = Vector2.new(250, 240)
baseSize.MaxSize = Vector2.new(330, 430)
baseSize.Parent = basePanel
makeLabel(basePanel, "BaseTitle", UDim2.new(1, -48, 0, 30), UDim2.new(0, 0, 0, 0), "YOUR BASE", Color3.fromRGB(255, 210, 40))
local baseClose = makeButton(basePanel, "Close", UDim2.new(0, 40, 0, 30), UDim2.new(1, -44, 0, 2), "X", Color3.fromRGB(160, 50, 50))
baseClose.MouseButton1Click:Connect(function()
	basePanel.Visible = false
	baseOpen.Visible = true
end)
baseOpen.MouseButton1Click:Connect(function()
	basePanel.Visible = true
	baseOpen.Visible = false
end)
local baseList = Instance.new("ScrollingFrame")
baseList.Name = "BaseList"
baseList.Size = UDim2.new(1, -8, 1, -36)
baseList.Position = UDim2.new(0, 4, 0, 34)
baseList.BackgroundTransparency = 1
baseList.ScrollBarThickness = 6
baseList.ScrollingDirection = Enum.ScrollingDirection.Y
baseList.AutomaticCanvasSize = Enum.AutomaticSize.Y
baseList.CanvasSize = UDim2.new(0, 0, 0, 0)
baseList.Parent = basePanel
local baseLayout = Instance.new("UIListLayout")
baseLayout.Padding = UDim.new(0, 4)
baseLayout.Parent = baseList
local slotsLabel = makeLabel(baseList, "Slots", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), "Slots: 0/6", Color3.fromRGB(200, 200, 200), Enum.Font.Gotham)
local lockButton = makeButton(baseList, "Lock", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), "LOCK BASE (30s)", Color3.fromRGB(200, 60, 60))
lockButton.MouseButton1Click:Connect(function()
	lockEvent:FireServer()
end)
local upgradeButtons = {}
local upgradeOrder = { "speed", "slap", "slots", "income" }
for _, upgradeId in ipairs(upgradeOrder) do
	local def = Config.UPGRADES[upgradeId]
	local button = makeButton(baseList, "Upgrade" .. upgradeId, UDim2.new(1, 0, 0, 38),
		UDim2.new(0, 0, 0, 0), def.name .. " — " .. BrainrotData.formatMoney(def.baseCost), Color3.fromRGB(70, 90, 180))
	button.MouseButton1Click:Connect(function()
		upgradeEvent:FireServer(upgradeId)
	end)
	upgradeButtons[upgradeId] = button
end
local rebirthButton = makeButton(baseList, "Rebirth", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), "REBIRTH", Color3.fromRGB(140, 60, 180))
rebirthButton.MouseButton1Click:Connect(function()
	rebirthEvent:FireServer()
end)

-- Slap button, bottom right, for touch players and mouse players alike.
-- Anchored to the bottom edge and shifted left of the mobile jump
-- button, clear of the shop panel above it.
local slapButton = makeButton(gui, "Slap", UDim2.new(0, 96, 0, 96), UDim2.new(1, -260, 1, -16), "SLAP!\n(F)", Color3.fromRGB(220, 80, 40))
slapButton.AnchorPoint = Vector2.new(1, 1)

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

local function findSlapTarget()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best = nil
	local bestDistance = Config.STEAL.SlapRange
	for _, descendant in ipairs(game:GetService("Workspace"):GetDescendants()) do
		if descendant:IsA("Model") and descendant ~= character then
			local targetRoot = descendant:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local isNPC = descendant:GetAttribute("IsNPC") == true
				local isPlayer = Players:GetPlayerFromCharacter(descendant) ~= nil
				if isNPC or isPlayer then
					local distance = (targetRoot.Position - root.Position).Magnitude
					if distance <= bestDistance then
						best = descendant
						bestDistance = distance
					end
				end
			end
		end
	end
	return best
end

local function doSlap()
	local target = findSlapTarget()
	if target then
		slapEvent:FireServer(target)
	end
end

slapButton.MouseButton1Click:Connect(doSlap)
ContextActionService:BindAction("SlapBrainrot", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		doSlap()
	end
end, false, Enum.KeyCode.F)

-- Clicking a brainrot on the conveyor buys it; clicking one on someone
-- else's base tries to steal it. The server checks every part of it.
local function hookClickDetector(detector)
	detector.MouseClick:Connect(function()
		local part = detector.Parent
		local model = part and part.Parent
		if not model or not model:GetAttribute("IsBrainrot") then
			return
		end
		local beltId = model:GetAttribute("BeltId")
		if beltId then
			buyEvent:FireServer(beltId)
			return
		end
		local ownerId = model:GetAttribute("OwnerUserId")
		local slot = model:GetAttribute("SlotIndex")
		if ownerId and ownerId ~= player.UserId and slot then
			stealEvent:FireServer(ownerId, slot)
		end
	end)
end

for _, descendant in ipairs(game:GetService("Workspace"):GetDescendants()) do
	if descendant:IsA("ClickDetector") and descendant.Name == "BrainrotClick" then
		hookClickDetector(descendant)
	end
end
game:GetService("Workspace").DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ClickDetector") and descendant.Name == "BrainrotClick" then
		hookClickDetector(descendant)
	end
end)

-- ---------------------------------------------------------------------------
-- Server updates
-- ---------------------------------------------------------------------------

hudEvent.OnClientEvent:Connect(function(state)
	cashLabel.Text = BrainrotData.formatMoney(state.cash)
	incomeLabel.Text = "+" .. BrainrotData.formatMoney(state.income) .. "/s"
	rebirthLabel.Text = "Rebirth x" .. tostring(state.rebirths)
	if state.goldenHour then
		waveLabel.Text = "GOLDEN HOUR 2x!"
		waveLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	elseif state.wavePhase == "warning" then
		waveLabel.Text = "WAVE IN " .. tostring(state.waveSecondsLeft) .. "s!"
		waveLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	elseif state.wavePhase == "sweeping" then
		waveLabel.Text = "WAVE!"
		waveLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	else
		waveLabel.Text = "Wave: " .. tostring(state.waveSecondsLeft) .. "s"
		waveLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	end
	slotsLabel.Text = "Slots: " .. tostring(state.slotsUsed) .. "/" .. tostring(state.slotsMax)
	if state.lockSecondsLeft > 0 then
		lockButton.Text = "LOCKED (" .. tostring(state.lockSecondsLeft) .. "s)"
	elseif state.lockReadyIn > 0 then
		lockButton.Text = "LOCK READY IN " .. tostring(state.lockReadyIn) .. "s"
	else
		lockButton.Text = "LOCK BASE (30s)"
	end
	for upgradeId, button in pairs(upgradeButtons) do
		local def = Config.UPGRADES[upgradeId]
		local level = state.upgrades[upgradeId] or 0
		if level >= def.maxLevel then
			button.Text = def.name .. " — MAX"
		else
			button.Text = def.name .. " Lv" .. tostring(level) .. " — " .. BrainrotData.formatMoney(def.baseCost * (2 ^ level))
		end
	end
	if state.lifetimeEarned >= Config.REBIRTH.RequiredLifetimeEarned then
		rebirthButton.Text = "REBIRTH NOW! (+" .. tostring(Config.REBIRTH.MultiplierPerRebirth * 100) .. "% income)"
	else
		rebirthButton.Text = "REBIRTH — " .. BrainrotData.formatMoney(state.lifetimeEarned) .. " / "
			.. BrainrotData.formatMoney(Config.REBIRTH.RequiredLifetimeEarned) .. " earned"
	end
end)

beltEvent.OnClientEvent:Connect(function(entries)
	rebuildShop(entries)
end)

notifyEvent.OnClientEvent:Connect(function(message, kind)
	showToast(message, kind)
end)

waveEvent.OnClientEvent:Connect(function(phase, secondsLeft)
	if phase == "warning" then
		waveBanner.Visible = true
		waveBanner.Text = "NOODLE TSUNAMI IN " .. tostring(secondsLeft) .. "s — GET TO YOUR BASE!"
	elseif phase == "sweeping" then
		waveBanner.Visible = true
		waveBanner.Text = "THE WAVE IS HERE — HOLD ON!"
	else
		waveBanner.Visible = false
	end
end)
