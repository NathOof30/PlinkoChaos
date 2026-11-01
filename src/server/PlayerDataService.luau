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
	Deck: { [number]: BallSlot },
}

local PlayerDataService = {}
local isInitialized = false

-- Cache en mémoire vive des profils joueurs (sauvegardés dans le DataStore)
local sessionCache = {} :: { [number]: PlayerData }

-- État volatile en session des 10 slots du Deck ("Ready" ou "Dropping")
-- Non persisté dans le DataStore : à chaque connexion, tous les slots démarrent "Ready"
local sessionSlotStates = {} :: { [number]: { [number]: string } }

-- Curseur séquentiel (round-robin) par joueur pour forcer l'utilisation de tout le deck (1 à 10)
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

-- Création du Deck standard de 10 billes
local function createDefaultDeck(): { [number]: BallSlot }
	local deck = {}
	for i = 1, 10 do
		deck[i] = {
			ballType = "Standard",
			level = 1,
		}
	end
	return deck
end

-- Création et synchronisation du leaderboard natif Roblox
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

-- Chargement des données à la connexion du joueur
function PlayerDataService.LoadData(player: Player): PlayerData
	local BoardConfig = getConfig()
	local startingCoins = (BoardConfig.Economy and BoardConfig.Economy.StartingCoins) or 100
	local userId = player.UserId

	local defaultData: PlayerData = {
		Coins = startingCoins,
		TotalDrops = 0,
		Deck = createDefaultDeck(),
	}

	-- Initialisation de l'état de session : tous les 10 slots sont Ready
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
			-- Rétrocompatibilité : si le deck n'existait pas encore dans l'ancienne sauvegarde, on l'injecte
			local loadedDeck = savedData.Deck
			if not loadedDeck or typeof(loadedDeck) ~= "table" then
				loadedDeck = createDefaultDeck()
			else
				for i = 1, 10 do
					if not loadedDeck[i] then
						loadedDeck[i] = { ballType = "Standard", level = 1 }
					end
				end
			end

			finalData = {
				Coins = math.max(0, math.floor(savedData.Coins)),
				TotalDrops = savedData.TotalDrops or 0,
				Deck = loadedDeck,
			}
			print(string.format("[PlinkoChaos] 💾 Données chargées depuis DataStore pour %s : %d Pièces, Deck prêt (10 slots)", player.Name, finalData.Coins))
		else
			finalData = defaultData
			print(string.format("[PlinkoChaos] 🌟 Nouveau joueur %s ! Pécule de départ offert : %d Pièces, Deck 10 slots initialisé", player.Name, startingCoins))
		end

		sessionCache[userId] = finalData
		setupLeaderstats(player, finalData)
	end

	-- Envoi de la synchronisation complète du Deck au client
	task.defer(function()
		local deckSyncEvent = Network.GetRemoteEvent("DeckSync")
		deckSyncEvent:FireClient(player, finalData.Deck, sessionSlotStates[userId])
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
		return
	end

	local success, err = pcall(function()
		ds:SetAsync("Player_" .. userId, {
			Coins = data.Coins,
			TotalDrops = data.TotalDrops,
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

-- API de consultation du Deck et des États
function PlayerDataService.GetDeck(player: Player): { [number]: BallSlot }?
	local data = sessionCache[player.UserId]
	return data and data.Deck
end

function PlayerDataService.GetSlotStates(player: Player): { [number]: string }?
	return sessionSlotStates[player.UserId]
end

function PlayerDataService.IsSlotReady(player: Player, slotIndex: number): boolean
	local states = sessionSlotStates[player.UserId]
	return states ~= nil and states[slotIndex] == "Ready"
end

-- Sélection séquentielle circulaire (Round-Robin) des slots :
-- Permet de jouer l'ensemble des 10 billes (1 -> 10) sans qu'une bille déjà rentrée
-- au début du deck ne court-circuite les slots 8, 9 ou 10 lors d'un spam de lâchers.
function PlayerDataService.GetNextReadySlot(player: Player): number?
	local states = sessionSlotStates[player.UserId]
	if not states then
		return nil
	end

	local currentPointer = sessionSlotPointers[player.UserId] or 0

	for offset = 1, 10 do
		local candidate = ((currentPointer - 1 + offset) % 10) + 1
		if states[candidate] == "Ready" then
			sessionSlotPointers[player.UserId] = candidate
			return candidate
		end
	end

	return nil
end

-- Rétrocompatibilité
function PlayerDataService.GetFirstReadySlot(player: Player): number?
	return PlayerDataService.GetNextReadySlot(player)
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

	-- Notification temps-réel au client pour mettre à jour l'interface (grisé vs actif)
	local slotStateChangedEvent = Network.GetRemoteEvent("SlotStateChanged")
	slotStateChangedEvent:FireClient(player, slotIndex, newState)
end

-- API Monétaire
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

	return true
end

function PlayerDataService.RegisterDrop(player: Player)
	local data = sessionCache[player.UserId]
	if data then
		data.TotalDrops = (data.TotalDrops or 0) + 1
	end
end

-- Initialisation globale
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
		print("[PlinkoChaos] 🛑 Arrêt serveur : Sauvegarde de tous les joueurs en cours...")
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerDataService.SaveData(player)
		end
		print("[PlinkoChaos] ✅ Sauvegardes terminées.")
	end)

	print("[PlinkoChaos] 💰 PlayerDataService initialisé (Deck 10 slots & Cooldown physique intégrés).")
end

return PlayerDataService
