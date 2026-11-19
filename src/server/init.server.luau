-- Brainrot Bazaar, server entrypoint.
-- Start the game service (world, economy, conveyor, wave) and then wake up
-- Sneaky Steve, the NPC rival. Nothing else runs on the server.

local BrainrotService = require(script.Parent:WaitForChild("BrainrotService"))
local NPCRival = require(script.Parent:WaitForChild("NPCRival"))

BrainrotService.start()
NPCRival.start()

print("Brainrot Bazaar is open for business.")
