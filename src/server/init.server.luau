--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local BoardBuilder = require(ServerScriptService.Server.BoardBuilder)
local PlayerDataService = require(ServerScriptService.Server.PlayerDataService)
local DropService = require(ServerScriptService.Server.DropService)
local SlotService = require(ServerScriptService.Server.SlotService)

-- 1. S'assure que le plateau physique et la plateforme de spawn existent
if not workspace:FindFirstChild("PlinkoBoard") then
	BoardBuilder.Build()
end

-- 2. Initialise l'économie et les services de gameplay
PlayerDataService.Init()
DropService.Init()
SlotService.Init()

print("[PlinkoChaos] 🚀 Phase 3 opérationnelle : DataStore, Économie (10 pièces/drop), DropService et SlotService actifs !")
