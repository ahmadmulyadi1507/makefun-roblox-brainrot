-- BrainrotData: the cast of Brainrot Bazaar.
-- Every character here is an original invention for this game: absurd,
-- meme-born, named, and priced on a ladder of rarities. Nothing is copied
-- from any existing brainrot game.

local BrainrotData = {}

-- Rarity ladder, cheapest first. The colour is the colour of the name tag
-- and of the rarity label the player reads on the conveyor.
BrainrotData.RARITIES = {
	Common = { order = 1, color = Color3.fromRGB(200, 200, 200) },
	Rare = { order = 2, color = Color3.fromRGB(90, 160, 255) },
	Epic = { order = 3, color = Color3.fromRGB(180, 90, 255) },
	Legendary = { order = 4, color = Color3.fromRGB(255, 200, 40) },
	Mythic = { order = 5, color = Color3.fromRGB(255, 80, 120) },
	Secret = { order = 6, color = Color3.fromRGB(80, 230, 220) },
}

-- Spawn weights: rarer characters show up on the conveyor less often.
BrainrotData.RARITY_WEIGHTS = {
	Common = 42,
	Rare = 28,
	Epic = 16,
	Legendary = 8,
	Mythic = 4,
	Secret = 2,
}

-- Mutations roll when a brainrot spawns on the conveyor. A mutation
-- multiplies what the brainrot earns every second.
BrainrotData.MUTATIONS = {
	{ name = "Normal", multiplier = 1, weight = 86, tint = nil },
	{ name = "Golden", multiplier = 2, weight = 10, tint = Color3.fromRGB(255, 215, 0) },
	{ name = "Diamond", multiplier = 5, weight = 3, tint = Color3.fromRGB(170, 225, 255) },
	{ name = "Rainbow", multiplier = 10, weight = 1, tint = Color3.fromRGB(255, 120, 200) },
}

-- The cast. Fields: id, name, rarity, cost (cash to buy), income ($ per
-- second on a base), color (body colour), accessory (which prop the
-- factory builds for it), blurb (the joke the shop shows).
BrainrotData.CHARACTERS = {
	{
		id = "toast",
		name = "Sir Toastalot",
		rarity = "Common",
		cost = 50,
		income = 5,
		color = Color3.fromRGB(210, 140, 60),
		accessory = "Cape",
		blurb = "A toaster that screams when your bread is done. It is always done.",
	},
	{
		id = "banana",
		name = "Banana in a Suit",
		rarity = "Common",
		cost = 120,
		income = 9,
		color = Color3.fromRGB(250, 220, 60),
		accessory = "Tie",
		blurb = "Middle management. Potassium division.",
	},
	{
		id = "gran",
		name = "Turbo Gran",
		rarity = "Rare",
		cost = 450,
		income = 22,
		color = Color3.fromRGB(200, 120, 180),
		accessory = "RocketWalker",
		blurb = "She finished the marathon before it started.",
	},
	{
		id = "pickle",
		name = "DJ Gherkin",
		rarity = "Rare",
		cost = 800,
		income = 35,
		color = Color3.fromRGB(90, 180, 80),
		accessory = "Headphones",
		blurb = "Drops beats. Drops pickles. Never drops the bass.",
	},
	{
		id = "capy",
		name = "Capybara CEO",
		rarity = "Epic",
		cost = 2200,
		income = 70,
		color = Color3.fromRGB(150, 110, 70),
		accessory = "Briefcase",
		blurb = "Signed the merger with a nap.",
	},
	{
		id = "potato",
		name = "Potato Astronaut",
		rarity = "Epic",
		cost = 3800,
		income = 110,
		color = Color3.fromRGB(220, 200, 160),
		accessory = "Helmet",
		blurb = "One small step for spud.",
	},
	{
		id = "waffle",
		name = "Waffle Wizard",
		rarity = "Legendary",
		cost = 9000,
		income = 200,
		color = Color3.fromRGB(230, 180, 90),
		accessory = "WizardHat",
		blurb = "Casts syrup. Resistance is futile and sticky.",
	},
	{
		id = "yeti",
		name = "Spaghetti Yeti",
		rarity = "Legendary",
		cost = 16000,
		income = 350,
		color = Color3.fromRGB(240, 230, 210),
		accessory = "Meatball",
		blurb = "Elusive. Al dente. Afraid of colanders.",
	},
	{
		id = "meow",
		name = "Chairman Meow",
		rarity = "Mythic",
		cost = 45000,
		income = 700,
		color = Color3.fromRGB(255, 200, 60),
		accessory = "GoldenChair",
		blurb = "The board meeting is now in session. Bring tuna.",
	},
	{
		id = "fridge",
		name = "The Forbidden Fridge",
		rarity = "Mythic",
		cost = 80000,
		income = 1200,
		color = Color3.fromRGB(180, 200, 220),
		accessory = "Hum",
		blurb = "It hums a tune nobody taught it. Do not open it at 3 AM.",
	},
	{
		id = "gum",
		name = "Professor Bubblegum",
		rarity = "Secret",
		cost = 220000,
		income = 2500,
		color = Color3.fromRGB(255, 120, 200),
		accessory = "Glasses",
		blurb = "Published 40 papers. Chewed every one.",
	},
	{
		id = "moose",
		name = "Moonwalking Moose",
		rarity = "Secret",
		cost = 550000,
		income = 5000,
		color = Color3.fromRGB(120, 90, 60),
		accessory = "MoonBoots",
		blurb = "Walks backwards through time. Antlers first.",
	},
}

-- Look a character up by its id. Returns nil when there is no such id.
function BrainrotData.getCharacter(id)
	for _, character in ipairs(BrainrotData.CHARACTERS) do
		if character.id == id then
			return character
		end
	end
	return nil
end

-- Pick a random character, weighted so rarer ones appear less often.
function BrainrotData.rollCharacter()
	local pool = {}
	local total = 0
	for _, character in ipairs(BrainrotData.CHARACTERS) do
		local weight = BrainrotData.RARITY_WEIGHTS[character.rarity] or 1
		total = total + weight
		table.insert(pool, { character = character, weight = weight })
	end
	local roll = math.random(1, total)
	for _, entry in ipairs(pool) do
		roll = roll - entry.weight
		if roll <= 0 then
			return entry.character
		end
	end
	return BrainrotData.CHARACTERS[1]
end

-- Roll a mutation the same weighted way. Most spawns are Normal.
function BrainrotData.rollMutation()
	local total = 0
	for _, mutation in ipairs(BrainrotData.MUTATIONS) do
		total = total + mutation.weight
	end
	local roll = math.random(1, total)
	for _, mutation in ipairs(BrainrotData.MUTATIONS) do
		roll = roll - mutation.weight
		if roll <= 0 then
			return mutation
		end
	end
	return BrainrotData.MUTATIONS[1]
end

-- Short money text: 1500 becomes $1.5K, 2500000 becomes $2.5M.
function BrainrotData.formatMoney(amount)
	amount = math.floor(amount + 0.5)
	if amount >= 1000000 then
		return string.format("$%.1fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("$%.1fK", amount / 1000)
	else
		return "$" .. tostring(amount)
	end
end

return BrainrotData
