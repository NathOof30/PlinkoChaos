--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local BallFactory = require(script.Parent:WaitForChild("BallFactory"))

local BotSimulatorService = {}
local isSimulating = false

-- 3 Profils de joueurs simulés avec pseudos distincts
local BOTS = {
	{ id = 9001, name = "Alex_Pro" },
	{ id = 9002, name = "PlinkoKing" },
	{ id = 9003, name = "ChaosMaster" },
}

local BALL_CHOICES = {
	"Standard",
	"Standard",
	"Heavy",
	"Explosive",
	"Spring",
}

function BotSimulatorService.Init()
	local toggleEvent = Network.GetRemoteEvent("ToggleBotSimulation")

	toggleEvent.OnServerEvent:Connect(function(player: Player)
		isSimulating = not isSimulating

		-- Notification au client du nouvel état
		toggleEvent:FireClient(player, isSimulating)

		if isSimulating then
			print("[PlinkoChaos] 🤖 Simulation multijoueur ACTIVÉE : 3 joueurs IA prêts à lâcher des billes.")
			task.spawn(function()
				while isSimulating do
					local bot = BOTS[math.random(1, #BOTS)]
					local ballType = BALL_CHOICES[math.random(1, #BALL_CHOICES)]
					local offset = (math.random() - 0.5) * 2.4

					local ball = BallFactory.CreateBall(ballType, nil, offset)
					ball:SetAttribute("OwnerUserId", bot.id)
					ball:SetAttribute("OwnerName", bot.name)
					ball:SetAttribute("BaseValue", 10)

					print(string.format("[PlinkoChaos] 🤖 Bot %s a lâché une bille %s (offset: %.2f)",
						bot.name, ballType, offset))

					-- Cadence rapide simulant le spam actif de 3 joueurs simultanés
					local waitDelay = 0.20 + math.random() * 0.22
					task.wait(waitDelay)
				end
				print("[PlinkoChaos] 🤖 Simulation multijoueur ARRÊTÉE.")
			end)
		else
			print("[PlinkoChaos] 🤖 Demande d'arrêt de la simulation reçue.")
		end
	end)

	print("[PlinkoChaos] 🤖 BotSimulatorService initialisé (Prêt pour la simulation multijoueur).")
end

return BotSimulatorService
