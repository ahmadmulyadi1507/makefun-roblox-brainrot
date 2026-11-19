-- Brainrot Bazaar, server entrypoint.
-- Start the game service (world, economy, conveyor, wave) and then wake up
-- Sneaky Steve, the NPC rival. Nothing else runs on the server.

local BrainrotService = require(script:WaitForChild("BrainrotService"))
local NPCRival = require(script:WaitForChild("NPCRival"))

BrainrotService.start()
NPCRival.start()

print("Brainrot Bazaar is open for business.")
