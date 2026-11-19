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

-- Top bar: cash, income, rebirths and the wave timer, centred.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.Size = UDim2.new(0.62, 0, 0, 46)
topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
topBar.BackgroundTransparency = 0.15
topBar.Parent = gui
local cashLabel = makeLabel(topBar, "Cash", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), "$100", Color3.fromRGB(120, 255, 120))
local incomeLabel = makeLabel(topBar, "Income", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.33, 0, 0, 0), "+$0/s", Color3.fromRGB(255, 220, 90))
local rebirthLabel = makeLabel(topBar, "Rebirths", UDim2.new(0.18, 0, 1, 0), UDim2.new(0.59, 0, 0, 0), "Rebirth x0", Color3.fromRGB(180, 140, 255))
local waveLabel = makeLabel(topBar, "Wave", UDim2.new(0.2, 0, 1, 0), UDim2.new(0.78, 0, 0, 0), "Wave: --", Color3.fromRGB(120, 180, 255))

-- Toast messages under the top bar.
local toast = makeLabel(gui, "Toast", UDim2.new(0.6, 0, 0, 36), UDim2.new(0.2, 0, 0, 66), "", Color3.fromRGB(255, 255, 255))
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
local waveBanner = makeLabel(gui, "WaveBanner", UDim2.new(0.7, 0, 0, 70), UDim2.new(0.15, 0, 0.32, 0), "", Color3.fromRGB(255, 90, 90), Enum.Font.GothamBlack)
waveBanner.Visible = false

-- Shop: what is on the conveyor right now, with a Buy button each.
local shop = Instance.new("Frame")
shop.Name = "Shop"
shop.AnchorPoint = Vector2.new(1, 0)
shop.Position = UDim2.new(1, -12, 0, 70)
shop.Size = UDim2.new(0, 310, 0, 400)
shop.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
shop.BackgroundTransparency = 0.15
shop.Parent = gui
makeLabel(shop, "ShopTitle", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 0), "CONVEYOR — ON SALE", Color3.fromRGB(255, 210, 40))
local shopList = Instance.new("Frame")
shopList.Name = "ShopList"
shopList.Size = UDim2.new(1, -8, 1, -40)
shopList.Position = UDim2.new(0, 4, 0, 38)
shopList.BackgroundTransparency = 1
shopList.Parent = shop
local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 4)
shopLayout.Parent = shopList

local function rebuildShop(entries)
	for _, child in ipairs(shopList:GetChildren()) do
		if child:IsA("Frame") then
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
		row.Size = UDim2.new(1, 0, 0, 58)
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
		makeLabel(row, "Name", UDim2.new(0.62, 0, 0, 24), UDim2.new(0.03, 0, 0, 2), title, rarityColor)
		makeLabel(row, "Stats", UDim2.new(0.62, 0, 0, 20), UDim2.new(0.03, 0, 0, 26),
			entry.rarity .. "  •  " .. BrainrotData.formatMoney(entry.income) .. "/s", Color3.fromRGB(200, 200, 200), Enum.Font.Gotham)
		makeLabel(row, "Blurb", UDim2.new(0.62, 0, 0, 14), UDim2.new(0.03, 0, 0, 44), entry.blurb, Color3.fromRGB(170, 170, 170), Enum.Font.Gotham)
		local buyButton = makeButton(row, "Buy", UDim2.new(0.32, 0, 0, 44), UDim2.new(0.66, 0, 0, 7),
			"BUY " .. BrainrotData.formatMoney(entry.cost), Color3.fromRGB(60, 140, 70))
		buyButton.MouseButton1Click:Connect(function()
			buyEvent:FireServer(entry.id)
		end)
	end
end

-- Base panel: lock, upgrades and rebirth.
local basePanel = Instance.new("Frame")
basePanel.Name = "BasePanel"
basePanel.AnchorPoint = Vector2.new(0, 1)
basePanel.Position = UDim2.new(0, 12, 1, -12)
basePanel.Size = UDim2.new(0, 310, 0, 270)
basePanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
basePanel.BackgroundTransparency = 0.15
basePanel.Parent = gui
makeLabel(basePanel, "BaseTitle", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), "YOUR BASE", Color3.fromRGB(255, 210, 40))
local slotsLabel = makeLabel(basePanel, "Slots", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 32), "Slots: 0/6", Color3.fromRGB(200, 200, 200), Enum.Font.Gotham)
local lockButton = makeButton(basePanel, "Lock", UDim2.new(0.94, 0, 0, 34), UDim2.new(0.03, 0, 0, 58), "LOCK BASE (30s)", Color3.fromRGB(200, 60, 60))
lockButton.MouseButton1Click:Connect(function()
	lockEvent:FireServer()
end)
local upgradeButtons = {}
local upgradeOrder = { "speed", "slap", "slots", "income" }
for i, upgradeId in ipairs(upgradeOrder) do
	local def = Config.UPGRADES[upgradeId]
	local button = makeButton(basePanel, "Upgrade" .. upgradeId, UDim2.new(0.94, 0, 0, 30),
		UDim2.new(0.03, 0, 0, 96 + (i - 1) * 34), def.name .. " — " .. BrainrotData.formatMoney(def.baseCost), Color3.fromRGB(70, 90, 180))
	button.MouseButton1Click:Connect(function()
		upgradeEvent:FireServer(upgradeId)
	end)
	upgradeButtons[upgradeId] = button
end
local rebirthButton = makeButton(basePanel, "Rebirth", UDim2.new(0.94, 0, 0, 34), UDim2.new(0.03, 0, 0, 232), "REBIRTH", Color3.fromRGB(140, 60, 180))
rebirthButton.MouseButton1Click:Connect(function()
	rebirthEvent:FireServer()
end)

-- Slap button, bottom right, for touch players and mouse players alike.
local slapButton = makeButton(gui, "Slap", UDim2.new(0, 96, 0, 96), UDim2.new(1, -116, 1, -116), "SLAP!\n(F)", Color3.fromRGB(220, 80, 40))
slapButton.AnchorPoint = Vector2.new(0, 0)

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
