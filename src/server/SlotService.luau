--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local BoardConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoardConfig"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local SlotService = {}
local isInitialized = false

-- Événement réseau pour notifier les clients d'un score
local ballScoredEvent = Network.GetRemoteEvent("BallScored")

local function onSlotTouched(pad: Part, hit: BasePart)
	if not hit or not hit.Parent then
		return
	end

	-- Vérifie si l'objet qui touche est bien une bille Plinko
	if not CollectionService:HasTag(hit, "PlinkoBall") then
		return
	end

	-- Système de debounce strict par bille : 1 seul encaissement possible
	if hit:GetAttribute("Processed") == true then
		return
	end

	-- Verrouillage immédiat
	hit:SetAttribute("Processed", true)
	hit.CanTouch = false

	-- Capture de la position exacte de la bille pour l'effet de particule flottante
	local hitPosition = hit.Position

	local multiplier = pad:GetAttribute("Multiplier") or 1
	local slotLabel = pad:GetAttribute("SlotLabel") or "x?"
	local slotIndex = pad:GetAttribute("SlotIndex") or 0
	local baseValue = hit:GetAttribute("BaseValue") or 10
	local ownerUserId = hit:GetAttribute("OwnerUserId") or 0
	local ballId = hit:GetAttribute("BallId") or "unknown"
	local deckSlotIndex = hit:GetAttribute("DeckSlotIndex")

	local isPenalty = (multiplier < 1)
	local amount = 0
	local amountText = ""

	local player = Players:GetPlayerByUserId(ownerUserId)
	local playerName = player and player.Name or (ownerUserId == 0 and "Serveur/Test" or string.format("Joueur_%d", ownerUserId))

	if isPenalty then
		-- Bille x0.5 : restitution de 5 pièces sur les 10 dépensées au drop (perte nette de 5 pièces)
		local returnCoins = math.floor(baseValue * multiplier)
		if player then
			PlayerDataService.AddCoins(player, returnCoins)
		end
		amount = 5
		amountText = "-5"
		local currentBalance = player and PlayerDataService.GetCoins(player) or 0
		print(string.format("[PlinkoChaos] ⚠️ %s a touché le bac piège %s : -5 pièces (Solde: %d)",
			playerName, slotLabel, currentBalance))
	else
		-- Bacs x1, x2, x10 : versement du gain complet
		amount = math.floor(baseValue * multiplier)
		amountText = string.format("+%d", amount)
		if player then
			PlayerDataService.AddCoins(player, amount)
		end
		local currentBalance = player and PlayerDataService.GetCoins(player) or 0
		print(string.format("[PlinkoChaos] 🎯 %s a marqué dans le bac %s : +%d pièces (Solde: %d)",
			playerName, slotLabel, amount, currentBalance))
	end

	-- Libération immédiate du slot du Deck (cooldown physique terminé)
	if player and typeof(deckSlotIndex) == "number" then
		PlayerDataService.SetSlotState(player, deckSlotIndex, "Ready")
		print(string.format("[PlinkoChaos] 🔄 Bille revenue au Deck ! Slot #%d de %s est de nouveau Ready.", deckSlotIndex, player.Name))
	end

	-- Notification réseau à tous les clients avec position pour l'effet d'évaporation 3D
	ballScoredEvent:FireAllClients({
		ownerUserId = ownerUserId,
		playerName = playerName,
		ballId = ballId,
		deckSlotIndex = deckSlotIndex,
		multiplier = multiplier,
		slotLabel = slotLabel,
		slotIndex = slotIndex,
		baseValue = baseValue,
		amount = amount,
		amountText = amountText,
		isPenalty = isPenalty,
		hitPosition = hitPosition,
	})

	-- Feedback visuel : Flash lumineux temporaire sur le pad du bac
	task.spawn(function()
		local originalColor = pad.Color
		pad.Color = Color3.fromRGB(255, 255, 255)
		task.wait(0.18)
		if pad and pad.Parent then
			TweenService:Create(pad, TweenInfo.new(0.25), { Color = originalColor }):Play()
		end
	end)

	-- Destruction propre et sécurisée de la bille (anti-lag)
	task.delay(0.08, function()
		if hit and hit.Parent then
			hit:Destroy()
		end
	end)
end

function SlotService.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	-- Connexion de tous les pads tagués PlinkoSlot
	local function connectSlot(pad: Instance)
		if pad:IsA("Part") then
			pad.Touched:Connect(function(hit)
				onSlotTouched(pad, hit)
			end)
		end
	end

	for _, pad in ipairs(CollectionService:GetTagged("PlinkoSlot")) do
		connectSlot(pad)
	end
	CollectionService:GetInstanceAddedSignal("PlinkoSlot"):Connect(connectSlot)

	-- Watchdog de sécurité anti-blocage et détection de sortie de plateau
	task.spawn(function()
		local maxLifetime = (BoardConfig.Ball and BoardConfig.Ball.MaxLifetime) or 30
		local center = BoardConfig.CenterPosition or Vector3.new(0, 50, 0)
		local bottomLimit = center.Y - (BoardConfig.PlayableHeight or 66) / 2 - 5 -- Y < 12
		local topLimit = center.Y + (BoardConfig.PlayableHeight or 66) / 2 + 15 -- Y > 98
		local xLimit = (BoardConfig.PlayableWidth or 52) / 2 + 12 -- |X| > 38

		while true do
			task.wait(1.0)
			local activeFolder = workspace:FindFirstChild("ActiveBalls")
			if activeFolder then
				local now = os.clock()
				for _, ball in ipairs(activeFolder:GetChildren()) do
					if ball:IsA("BasePart") then
						local spawnTime = ball:GetAttribute("SpawnTime")
						local deckSlotIndex = ball:GetAttribute("DeckSlotIndex")
						local ownerUserId = ball:GetAttribute("OwnerUserId")
						local player = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
						local pos = ball.Position

						local isOutOfBounds = (pos.Y < bottomLimit) or (pos.Y > topLimit)
							or (math.abs(pos.X - center.X) > xLimit)
							or (math.abs(pos.Z - center.Z) > 8)

						local isTimedOut = spawnTime and (now - spawnTime > maxLifetime)

						if (isOutOfBounds or isTimedOut) and ball:GetAttribute("Processed") ~= true then
							ball:SetAttribute("Processed", true)
							if player and typeof(deckSlotIndex) == "number" then
								PlayerDataService.SetSlotState(player, deckSlotIndex, "Ready")
							end
							local reason = isOutOfBounds and "Sortie de limites" or string.format("Timeout (>%ds)", maxLifetime)
							print(string.format("[PlinkoChaos] 🛡️ Sécurité Watchdog : Bille %s récupérée (%s), Slot #%s réarmé dans le Deck.",
								ball.Name, reason, tostring(deckSlotIndex)))
							ball:Destroy()
						end
					end
				end
			end
		end
	end)

	print("[PlinkoChaos] SlotService initialisé avec succès.")
end

return SlotService

