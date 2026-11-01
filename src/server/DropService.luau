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
local DROP_COOLDOWN = 0.15 -- Cooldown minimal technique anti-spam

function DropService.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	local requestDropEvent = Network.GetRemoteEvent("RequestDrop")
	local dropFailedEvent = Network.GetRemoteEvent("DropFailed")
	local requestReliefEvent = Network.GetRemoteEvent("RequestRelief")

	local dropCost = (BoardConfig.Economy and BoardConfig.Economy.DropCost) or 10

	requestDropEvent.OnServerEvent:Connect(function(player: Player, requestedSlot: any, requestedOffset: any)
		local now = os.clock()
		local lastDrop = playerLastDrop[player.UserId] or 0
		if now - lastDrop < DROP_COOLDOWN then
			return -- Cooldown technique anti-spam
		end

		-- 1. Résolution du Slot de bille : slot spécifique ou prochain slot séquentiel (Round-Robin)
		local targetSlotIndex: number?
		if typeof(requestedSlot) == "number" and requestedSlot >= 1 and requestedSlot <= 10 then
			if PlayerDataService.IsSlotReady(player, requestedSlot) then
				targetSlotIndex = requestedSlot
				PlayerDataService.SetSlotPointer(player, requestedSlot)
			else
				dropFailedEvent:FireClient(player, string.format("La bille #%d est déjà en train de tomber !", requestedSlot))
				return
			end
		else
			targetSlotIndex = PlayerDataService.GetNextReadySlot(player)
			if not targetSlotIndex then
				dropFailedEvent:FireClient(player, "Toutes tes 10 billes sont en jeu ! Attends un atterrissage.")
				print(string.format("[PlinkoChaos] ⏳ %s a tous ses 10 slots occupés sur le plateau", player.Name))
				return
			end
		end

		-- 2. Vérification économique (10 pièces par drop)
		if not PlayerDataService.HasEnoughCoins(player, dropCost) then
			local currentCoins = PlayerDataService.GetCoins(player)
			dropFailedEvent:FireClient(player, string.format("Fonds insuffisants ! (Tu as %d/10 pièces)", currentCoins))
			print(string.format("[PlinkoChaos] ⛔ %s n'a pas assez de pièces pour jouer (%d/10)", player.Name, currentCoins))
			return
		end

		playerLastDrop[player.UserId] = now

		-- 3. Déduction monétaire et verrouillage du Slot en état "Dropping"
		PlayerDataService.RemoveCoins(player, dropCost)
		PlayerDataService.SetSlotState(player, targetSlotIndex, "Dropping")
		PlayerDataService.RegisterDrop(player)

		-- 4. Validation de la position de lâcher
		local offset: number
		if typeof(requestedOffset) == "number" then
			offset = math.clamp(requestedOffset, -1.5, 1.5)
		else
			local defaultOffset = (BoardConfig.Ball and BoardConfig.Ball.DefaultSpawnOffset) or 0.5
			offset = defaultOffset + (math.random() - 0.5) * 0.4
		end

		-- 5. Récupération du type de bille du Deck et instanciation
		local deck = PlayerDataService.GetDeck(player)
		local slotInfo = deck and deck[targetSlotIndex]
		local ballType = (slotInfo and slotInfo.ballType) or "Standard"

		local ball = BallFactory.CreateBall(ballType, player, offset)
		ball:SetAttribute("DeckSlotIndex", targetSlotIndex)

		local remaining = PlayerDataService.GetCoins(player)
		print(string.format("[PlinkoChaos] 🟢 Bille #%d (%s) lâchée par %s (-%d pièces, reste: %d)", targetSlotIndex, ballType, player.Name, dropCost, remaining))
	end)

	-- Recharge de secours si le joueur est à sec
	requestReliefEvent.OnServerEvent:Connect(function(player: Player)
		local currentCoins = PlayerDataService.GetCoins(player)
		if currentCoins < dropCost then
			PlayerDataService.AddCoins(player, 50)
			print(string.format("[PlinkoChaos] 🎁 Secours accordé à %s : +50 Pièces", player.Name))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerLastDrop[player.UserId] = nil
	end)

	print("[PlinkoChaos] DropService initialisé (Contrôle des 10 Slots du Deck actif).")
end

return DropService
