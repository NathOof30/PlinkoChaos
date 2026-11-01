--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)
local BoardBuilder = require(ServerScriptService.Server.BoardBuilder)
local PlayerDataService = require(ServerScriptService.Server.PlayerDataService)
local DropService = require(ServerScriptService.Server.DropService)
local SlotService = require(ServerScriptService.Server.SlotService)
local BotSimulatorService = require(ServerScriptService.Server.BotSimulatorService)

-- 1. Initialise le réseau (création de tous les RemoteEvents pour éviter tout blocage client)
Network.InitServer()

-- 2. S'assure que le plateau physique et la plateforme de spawn existent
if not workspace:FindFirstChild("PlinkoBoard") then
	BoardBuilder.Build()
end

-- 3. Initialise l'économie, le système de Deck et les services de gameplay
PlayerDataService.Init()
DropService.Init()
SlotService.Init()
BotSimulatorService.Init()

print("[PlinkoChaos] 🚀 Phase 5 opérationnelle : Billes Spéciales (Lourde, Explosive, Ressort) & Deck 10 slots !")
