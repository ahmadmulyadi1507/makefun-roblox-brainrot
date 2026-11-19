-- Brainrot Bazaar, server entrypoint.
-- Start the game service (world, economy, conveyor, wave) and then wake up
-- Sneaky Steve, the NPC rival. Nothing else runs on the server.
-- Each start is wrapped in pcall so one crashing service never silently
-- kills the other, and every failure is visible in the server log.

local BrainrotService = require(script:WaitForChild("BrainrotService"))
local NPCRival = require(script:WaitForChild("NPCRival"))

local ok, err = pcall(function()
	BrainrotService.start()
end)
if not ok then
	warn("[BrainrotBazaar] BrainrotService.start failed: " .. tostring(err))
end

local npcOk, npcErr = pcall(function()
	NPCRival.start()
end)
if not npcOk then
	warn("[BrainrotBazaar] NPCRival.start failed: " .. tostring(npcErr))
end

print("Brainrot Bazaar is open for business.")
