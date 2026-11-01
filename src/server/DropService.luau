--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local BoardConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoardConfig"))
local BallFactory = require(script.Parent:WaitForChild("BallFactory"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local DropService = {}
local isInitialized = false

-- Debounce par joueur pour éviter le spam réseau
local playerLastDrop = {} :: { [number]: number }
local DROP_COOLDOWN = 0.25 -- Cooldown minimal en secondes entre chaque lâcher

function DropService.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	local requestDropEvent = Network.GetRemoteEvent("RequestDrop")
	local dropFailedEvent = Network.GetRemoteEvent("DropFailed")
	local requestReliefEvent = Network.GetRemoteEvent("RequestRelief")

	local dropCost = (BoardConfig.Economy and BoardConfig.Economy.DropCost) or 10

	requestDropEvent.OnServerEvent:Connect(function(player: Player, requestedOffset: any)
		local now = os.clock()
		local lastDrop = playerLastDrop[player.UserId] or 0
		if now - lastDrop < DROP_COOLDOWN then
			return -- Cooldown anti-spam
		end

		-- Vérification économique : le joueur a-t-il les 10 pièces requises ?
		if not PlayerDataService.HasEnoughCoins(player, dropCost) then
			local currentCoins = PlayerDataService.GetCoins(player)
			dropFailedEvent:FireClient(player, string.format("Fonds insuffisants ! (Tu as %d/10 pièces)", currentCoins))
			print(string.format("[PlinkoChaos] ⛔ %s n'a pas assez de pièces pour jouer (%d/10)", player.Name, currentCoins))
			return
		end

		playerLastDrop[player.UserId] = now

		-- Déduction du coût de la bille
		PlayerDataService.RemoveCoins(player, dropCost)
		PlayerDataService.RegisterDrop(player)

		-- Validation de sécurité de l'offset demandé par le client
		local offset: number
		if typeof(requestedOffset) == "number" then
			offset = math.clamp(requestedOffset, -1.5, 1.5)
		else
			local defaultOffset = (BoardConfig.Ball and BoardConfig.Ball.DefaultSpawnOffset) or 0.5
			offset = defaultOffset + (math.random() - 0.5) * 0.4
		end

		-- Instanciation de la bille métallique via BallFactory
		local ball = BallFactory.CreateStandardBall(player, offset)
		local remaining = PlayerDataService.GetCoins(player)
		print(string.format("[PlinkoChaos] 🟢 Bille lâchée par %s (-%d pièces, reste: %d)", player.Name, dropCost, remaining))
	end)

	-- Recharge de secours si le joueur est à sec (pour continuer à tester sans redémarrer)
	requestReliefEvent.OnServerEvent:Connect(function(player: Player)
		local currentCoins = PlayerDataService.GetCoins(player)
		if currentCoins < dropCost then
			PlayerDataService.AddCoins(player, 50)
			print(string.format("[PlinkoChaos] 🎁 Secours accordé à %s : +50 Pièces", player.Name))
		end
	end)

	-- Nettoyage mémoire quand un joueur quitte la partie
	Players.PlayerRemoving:Connect(function(player)
		playerLastDrop[player.UserId] = nil
	end)

	print("[PlinkoChaos] DropService initialisé avec validation économique (10 pièces/drop).")
end

return DropService
