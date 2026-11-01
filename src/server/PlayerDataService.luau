--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local configModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoardConfig")
local function getConfig()
	local ok, res = pcall(require, configModule)
	if ok and res and res.Economy then
		return res
	end
	local fn = loadstring((configModule :: ModuleScript).Source)
	return fn()
end

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

export type BallSlot = {
	ballType: string,
	level: number,
}

export type PlayerData = {
	Coins: number,
	TotalDrops: number,
	Inventory: { [string]: number },
	Blueprints: { [string]: boolean },
	Deck: { [number]: BallSlot? },
}

local PlayerDataService = {}
local isInitialized = false

-- Cache en mémoire vive des profils joueurs (sauvegardés dans le DataStore)
local sessionCache = {} :: { [number]: PlayerData }

-- État volatile en session des 10 slots du Deck ("Ready" ou "Dropping")
-- Non persisté dans le DataStore : à chaque connexion, tous les slots démarrent "Ready"
local sessionSlotStates = {} :: { [number]: { [number]: string } }

-- Curseur séquentiel (round-robin) par joueur pour forcer l'alternance des slots équipés
local sessionSlotPointers = {} :: { [number]: number }

local dataStore: any = nil
local isDataStoreAvailable = true

local function getDataStoreInstance()
	if dataStore ~= nil then
		return dataStore
	end

	local BoardConfig = getConfig()
	local dsName = (BoardConfig.Economy and BoardConfig.Economy.DataStoreName) or "PlinkoChaos_UserData_v1"

	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(dsName)
	end)

	if ok and ds then
		dataStore = ds
	else
		isDataStoreAvailable = false
		warn("[PlinkoChaos] ⚠️ DataStore non accessible dans ce mode Studio. Mode mémoire locale activé.")
	end
	return dataStore
end

-- Création du profil initial (Phase 6 V2 GDD) :
-- Portefeuille: 10 Pièces | Inventaire: 1 Standard | Deck: 1 Standard (Slot 1, 9 slots vides)
local function createDefaultProfile(): PlayerData
	local BoardConfig = getConfig()
	local startingCoins = (BoardConfig.Economy and BoardConfig.Economy.StartingCoins) or 10

	local deck: { [number]: BallSlot? } = {}
	deck[1] = { ballType = "Standard", level = 1 }
	for i = 2, 10 do
		deck[i] = nil
	end

	return {
		Coins = startingCoins,
		TotalDrops = 0,
		Inventory = {
			Standard = 1,
			Slime = 0,
			Heavy = 0,
			Explosive = 0,
		},
		Blueprints = {
			Slime = false,
			Heavy = false,
			Explosive = false,
		},
		Deck = deck,
	}
end

-- Synchronisation du leaderboard natif Roblox
local function setupLeaderstats(player: Player, data: PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local coinsValue = leaderstats:FindFirstChild("Pièces") :: IntValue
	if not coinsValue then
		coinsValue = Instance.new("IntValue")
		coinsValue.Name = "Pièces"
		coinsValue.Value = data.Coins
		coinsValue.Parent = leaderstats
	else
		coinsValue.Value = data.Coins
	end
end

-- Synchronisation du Deck avec le client
function PlayerDataService.SyncDeck(player: Player)
	local userId = player.UserId
	local data = sessionCache[userId]
	local states = sessionSlotStates[userId]
	if not data or not states then
		return
	end

	local deckSyncEvent = Network.GetRemoteEvent("DeckSync")
	deckSyncEvent:FireClient(player, data.Deck, states)
end

-- Synchronisation de l'Inventaire, Blueprints et Pièces avec le client
function PlayerDataService.SyncInventory(player: Player)
	local userId = player.UserId
	local data = sessionCache[userId]
	if not data then
		return
	end

	local invSyncEvent = Network.GetRemoteEvent("InventorySync")
	invSyncEvent:FireClient(player, {
		Inventory = data.Inventory,
		Blueprints = data.Blueprints,
		Coins = data.Coins,
	})
end

-- Chargement des données à la connexion du joueur
function PlayerDataService.LoadData(player: Player): PlayerData
	local userId = player.UserId
	local defaultData = createDefaultProfile()

	-- Initialisation des états de session : tous les 10 slots démarrent Ready
	local slotStates = {}
	for i = 1, 10 do
		slotStates[i] = "Ready"
	end
	sessionSlotStates[userId] = slotStates
	sessionSlotPointers[userId] = 0

	local ds = getDataStoreInstance()
	local finalData: PlayerData

	if not isDataStoreAvailable or not ds then
		finalData = defaultData
		sessionCache[userId] = finalData
		setupLeaderstats(player, finalData)
		print(string.format("[PlinkoChaos] 💾 Données locales initialisées pour %s : %d Pièces (Mode Local)", player.Name, defaultData.Coins))
	else
		local success, savedData = pcall(function()
			return ds:GetAsync("Player_" .. userId)
		end)

		if success and savedData and typeof(savedData) == "table" and savedData.Coins ~= nil then
			-- Migration et rétrocompatibilité des données existantes
			local loadedInventory = savedData.Inventory
			if not loadedInventory or typeof(loadedInventory) ~= "table" then
				loadedInventory = {
					Standard = 1,
					Slime = 0,
					Heavy = 0,
					Explosive = 0,
				}
			else
				loadedInventory.Standard = loadedInventory.Standard or 0
				loadedInventory.Slime = loadedInventory.Slime or loadedInventory.Spring or 0
				loadedInventory.Heavy = loadedInventory.Heavy or 0
				loadedInventory.Explosive = loadedInventory.Explosive or 0
			end

			local loadedBlueprints = savedData.Blueprints
			if not loadedBlueprints or typeof(loadedBlueprints) ~= "table" then
				loadedBlueprints = {
					Slime = false,
					Heavy = false,
					Explosive = false,
				}
			else
				loadedBlueprints.Slime = loadedBlueprints.Slime or loadedBlueprints.Spring or false
				loadedBlueprints.Heavy = loadedBlueprints.Heavy or false
				loadedBlueprints.Explosive = loadedBlueprints.Explosive or false
			end

			local loadedDeck = savedData.Deck
			local cleanDeck: { [number]: BallSlot? } = {}
			if not loadedDeck or typeof(loadedDeck) ~= "table" then
				cleanDeck = defaultData.Deck
			else
				for i = 1, 10 do
					local item = loadedDeck[i]
					if item and typeof(item) == "table" and item.ballType then
						local bType = item.ballType == "Spring" and "Slime" or item.ballType
						cleanDeck[i] = {
							ballType = bType,
							level = item.level or 1,
						}
					else
						cleanDeck[i] = nil
					end
				end
			end

			finalData = {
				Coins = math.max(0, math.floor(savedData.Coins)),
				TotalDrops = savedData.TotalDrops or 0,
				Inventory = loadedInventory,
				Blueprints = loadedBlueprints,
				Deck = cleanDeck,
			}
			print(string.format("[PlinkoChaos] 💾 Données chargées depuis DataStore pour %s : %d Pièces", player.Name, finalData.Coins))
		else
			finalData = defaultData
			print(string.format("[PlinkoChaos] 🌟 Nouveau joueur %s ! Profil initial créé (10 Pièces, 1 Standard en stock, 1 Standard équipée)", player.Name))
		end

		sessionCache[userId] = finalData
		setupLeaderstats(player, finalData)
	end

	-- Envoi initial de la synchronisation Deck et Inventaire au client
	task.defer(function()
		PlayerDataService.SyncDeck(player)
		PlayerDataService.SyncInventory(player)
	end)

	return finalData
end

-- Sauvegarde des données à la déconnexion
function PlayerDataService.SaveData(player: Player)
	local userId = player.UserId
	local data = sessionCache[userId]
	if not data then
		return
	end

	local ds = getDataStoreInstance()
	if not isDataStoreAvailable or not ds then
		sessionCache[userId] = nil
		sessionSlotStates[userId] = nil
		sessionSlotPointers[userId] = nil
		return
	end

	local success, err = pcall(function()
		ds:SetAsync("Player_" .. userId, {
			Coins = data.Coins,
			TotalDrops = data.TotalDrops,
			Inventory = data.Inventory,
			Blueprints = data.Blueprints,
			Deck = data.Deck,
		})
	end)

	if success then
		print(string.format("[PlinkoChaos] 💾 Sauvegarde réussie pour %s : %d Pièces (Total drops: %d)", player.Name, data.Coins, data.TotalDrops or 0))
	else
		warn(string.format("[PlinkoChaos] ❌ Échec de sauvegarde pour %s : %s", player.Name, tostring(err)))
	end

	sessionCache[userId] = nil
	sessionSlotStates[userId] = nil
	sessionSlotPointers[userId] = nil
end

-- ==================== API DU DECK & DES SLOTS ====================

function PlayerDataService.GetDeck(player: Player): { [number]: BallSlot? }?
	local data = sessionCache[player.UserId]
	return data and data.Deck
end

function PlayerDataService.GetSlotStates(player: Player): { [number]: string }?
	return sessionSlotStates[player.UserId]
end

function PlayerDataService.IsSlotReady(player: Player, slotIndex: number): boolean
	local data = sessionCache[player.UserId]
	local states = sessionSlotStates[player.UserId]
	if not data or not data.Deck or not states then
		return false
	end
	-- Doit contenir une bille ET être à l'état Ready
	return data.Deck[slotIndex] ~= nil and states[slotIndex] == "Ready"
end

-- Sélection séquentielle circulaire (Round-Robin) des slots :
-- Ne parcourt QUE les slots équipés d'une bille et en état "Ready"
function PlayerDataService.GetNextReadySlot(player: Player): number?
	local states = sessionSlotStates[player.UserId]
	local data = sessionCache[player.UserId]
	if not states or not data or not data.Deck then
		return nil
	end

	local currentPointer = sessionSlotPointers[player.UserId] or 0

	for offset = 1, 10 do
		local candidate = ((currentPointer - 1 + offset) % 10) + 1
		if data.Deck[candidate] ~= nil and states[candidate] == "Ready" then
			sessionSlotPointers[player.UserId] = candidate
			return candidate
		end
	end

	return nil
end

function PlayerDataService.SetSlotPointer(player: Player, slotIndex: number)
	if slotIndex >= 1 and slotIndex <= 10 then
		sessionSlotPointers[player.UserId] = slotIndex
	end
end

function PlayerDataService.SetSlotState(player: Player, slotIndex: number, newState: string)
	local states = sessionSlotStates[player.UserId]
	if not states or slotIndex < 1 or slotIndex > 10 then
		return
	end

	if states[slotIndex] == newState then
		return
	end

	states[slotIndex] = newState

	local slotStateChangedEvent = Network.GetRemoteEvent("SlotStateChanged")
	slotStateChangedEvent:FireClient(player, slotIndex, newState)
end

-- Équiper une bille de l'inventaire vers un slot du Deck
function PlayerDataService.EquipBall(player: Player, ballType: string, targetSlotIndex: number?): (boolean, string)
	local userId = player.UserId
	local data = sessionCache[userId]
	if not data or not data.Inventory or not data.Deck then
		return false, "Profil joueur non chargé."
	end

	local inStock = data.Inventory[ballType] or 0
	if inStock <= 0 then
		return false, string.format("Tu ne possèdes aucune bille %s en stock !", ballType)
	end

	-- Déterminer le slot cible
	local destSlot: number?
	if targetSlotIndex and targetSlotIndex >= 1 and targetSlotIndex <= 10 then
		if data.Deck[targetSlotIndex] == nil then
			destSlot = targetSlotIndex
		else
			return false, string.format("L'emplacement #%d est déjà occupé !", targetSlotIndex)
		end
	else
		-- Premier slot vide disponible
		for i = 1, 10 do
			if data.Deck[i] == nil then
				destSlot = i
				break
			end
		end
	end

	if not destSlot then
		return false, "Ton Deck est plein (10/10) ! Retire une bille avant d'en équiper une nouvelle."
	end

	-- Transfert sécurisé : Inventaire -> Deck
	data.Inventory[ballType] -= 1
	data.Deck[destSlot] = {
		ballType = ballType,
		level = 1,
	}

	local states = sessionSlotStates[userId]
	if states then
		states[destSlot] = "Ready"
	end

	PlayerDataService.SyncDeck(player)
	PlayerDataService.SyncInventory(player)

	return true, string.format("Bille %s équipée sur l'emplacement #%d !", ballType, destSlot)
end

-- Déséquiper une bille du Deck vers l'inventaire
function PlayerDataService.UnequipBall(player: Player, slotIndex: number): (boolean, string)
	local userId = player.UserId
	local data = sessionCache[userId]
	local states = sessionSlotStates[userId]
	if not data or not data.Deck or not states then
		return false, "Profil joueur non chargé."
	end

	if slotIndex < 1 or slotIndex > 10 then
		return false, "Emplacement invalide."
	end

	local currentSlot = data.Deck[slotIndex]
	if not currentSlot then
		return false, "Cet emplacement est déjà vide !"
	end

	-- Sécurité anti-exploit : interdiction de retirer une bille qui est en train de tomber
	if states[slotIndex] ~= "Ready" then
		return false, "Cette bille est en jeu ! Attends qu'elle atterrisse pour la retirer."
	end

	local ballType = currentSlot.ballType

	-- Transfert sécurisé : Deck -> Inventaire
	data.Deck[slotIndex] = nil
	data.Inventory[ballType] = (data.Inventory[ballType] or 0) + 1

	PlayerDataService.SyncDeck(player)
	PlayerDataService.SyncInventory(player)

	return true, string.format("Bille %s renvoyée dans l'inventaire !", ballType)
end

-- ==================== API INVENTAIRE, BLUEPRINTS & CRAFT ====================

function PlayerDataService.GetInventory(player: Player): { [string]: number }?
	local data = sessionCache[player.UserId]
	return data and data.Inventory
end

function PlayerDataService.GetBlueprints(player: Player): { [string]: boolean }?
	local data = sessionCache[player.UserId]
	return data and data.Blueprints
end

function PlayerDataService.AddInventory(player: Player, ballType: string, count: number)
	local data = sessionCache[player.UserId]
	if not data or not data.Inventory or count <= 0 then
		return
	end
	data.Inventory[ballType] = (data.Inventory[ballType] or 0) + count
	PlayerDataService.SyncInventory(player)
end

function PlayerDataService.RemoveInventory(player: Player, ballType: string, count: number): boolean
	local data = sessionCache[player.UserId]
	if not data or not data.Inventory or count <= 0 then
		return false
	end
	local current = data.Inventory[ballType] or 0
	if current < count then
		return false
	end
	data.Inventory[ballType] = current - count
	PlayerDataService.SyncInventory(player)
	return true
end

function PlayerDataService.UnlockBlueprint(player: Player, blueprintId: string): (boolean, string)
	local data = sessionCache[player.UserId]
	if not data or not data.Blueprints then
		return false, "Profil joueur introuvable."
	end

	if data.Blueprints[blueprintId] == true then
		return false, "Tu possèdes déjà ce plan de fabrication !"
	end

	local BoardConfig = getConfig()
	local bpConfig = BoardConfig.Crafting and BoardConfig.Crafting.Blueprints and BoardConfig.Crafting.Blueprints[blueprintId]
	if not bpConfig then
		return false, "Ce plan de fabrication n'existe pas."
	end

	local cost = bpConfig.Cost or 500
	if data.Coins < cost then
		return false, string.format("Pièces insuffisantes (%d/%d) pour débloquer ce plan !", data.Coins, cost)
	end

	-- Déduction et activation
	data.Coins -= cost
	data.Blueprints[blueprintId] = true

	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsVal = leaderstats and leaderstats:FindFirstChild("Pièces") :: IntValue?
	if coinsVal then
		coinsVal.Value = data.Coins
	end

	PlayerDataService.SyncInventory(player)
	return true, string.format("Plan de fabrication '%s' débloqué avec succès !", bpConfig.Name)
end

-- ==================== API MONÉTAIRE & REVENU PASSIF ====================

function PlayerDataService.GetCoins(player: Player): number
	local data = sessionCache[player.UserId]
	return data and data.Coins or 0
end

function PlayerDataService.HasEnoughCoins(player: Player, cost: number): boolean
	local coins = PlayerDataService.GetCoins(player)
	return coins >= cost
end

function PlayerDataService.AddCoins(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local userId = player.UserId
	local data = sessionCache[userId]
	if not data then
		return
	end

	data.Coins += amount

	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsVal = leaderstats and leaderstats:FindFirstChild("Pièces") :: IntValue?
	if coinsVal then
		coinsVal.Value = data.Coins
	end

	PlayerDataService.SyncInventory(player)
end

function PlayerDataService.RemoveCoins(player: Player, amount: number): boolean
	if amount <= 0 then
		return true
	end
	local userId = player.UserId
	local data = sessionCache[userId]
	if not data or data.Coins < amount then
		return false
	end

	data.Coins = math.max(0, data.Coins - amount)

	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsVal = leaderstats and leaderstats:FindFirstChild("Pièces") :: IntValue?
	if coinsVal then
		coinsVal.Value = data.Coins
	end

	PlayerDataService.SyncInventory(player)
	return true
end

function PlayerDataService.RegisterDrop(player: Player)
	local data = sessionCache[player.UserId]
	if data then
		data.TotalDrops = (data.TotalDrops or 0) + 1
	end
end

-- ==================== INITIALISATION & REVENU PASSIF ====================

function PlayerDataService.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	Players.PlayerAdded:Connect(function(player)
		PlayerDataService.LoadData(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.SaveData(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if not sessionCache[player.UserId] then
			task.spawn(function()
				PlayerDataService.LoadData(player)
			end)
		end
	end

	-- Sauvegarde de sécurité à l'arrêt du serveur
	game:BindToClose(function()
		print("[PlinkoChaos] 🛑 Arrêt serveur : Sauvegarde de tous les profils joueurs en cours...")
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerDataService.SaveData(player)
		end
		print("[PlinkoChaos] ✅ Sauvegardes terminées.")
	end)

	-- Revenu passif serveur (+1 Pièce / seconde) anti-softlock, discret et silencieux
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = sessionCache[player.UserId]
				if data then
					data.Coins += 1
					local leaderstats = player:FindFirstChild("leaderstats")
					local coinsVal = leaderstats and leaderstats:FindFirstChild("Pièces") :: IntValue?
					if coinsVal then
						coinsVal.Value = data.Coins
					end
				end
			end
		end
	end)

	print("[PlinkoChaos] 💰 PlayerDataService initialisé (Phase 6 V2 : Deck 10 slots, Inventaire, Craft & Revenu passif +1/s).")
end

return PlayerDataService
