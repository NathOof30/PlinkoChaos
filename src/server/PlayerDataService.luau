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

export type PlayerData = {
	Coins: number,
	TotalDrops: number,
}

local PlayerDataService = {}
local isInitialized = false

-- Cache en mémoire vive par UserId (0 latence pendant la partie, pas de spam DataStore)
local sessionCache = {} :: { [number]: PlayerData }

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

-- Création et synchronisation du leaderboard natif Roblox (en haut à droite)
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

-- Chargement des données à la connexion
function PlayerDataService.LoadData(player: Player): PlayerData
	local BoardConfig = getConfig()
	local startingCoins = (BoardConfig.Economy and BoardConfig.Economy.StartingCoins) or 100
	local userId = player.UserId

	local defaultData: PlayerData = {
		Coins = startingCoins,
		TotalDrops = 0,
	}

	local ds = getDataStoreInstance()
	if not isDataStoreAvailable or not ds then
		sessionCache[userId] = defaultData
		setupLeaderstats(player, defaultData)
		print(string.format("[PlinkoChaos] 💾 Données locales initialisées pour %s : %d Pièces (Mode Local)", player.Name, defaultData.Coins))
		return defaultData
	end

	local success, savedData = pcall(function()
		return ds:GetAsync("Player_" .. userId)
	end)

	local finalData: PlayerData
	if success and savedData and typeof(savedData) == "table" and savedData.Coins ~= nil then
		finalData = {
			Coins = math.max(0, math.floor(savedData.Coins)),
			TotalDrops = savedData.TotalDrops or 0,
		}
		print(string.format("[PlinkoChaos] 💾 Données chargées depuis le DataStore pour %s : %d Pièces", player.Name, finalData.Coins))
	else
		finalData = defaultData
		print(string.format("[PlinkoChaos] 🌟 Nouveau joueur %s ! Pécule de départ offert : %d Pièces", player.Name, startingCoins))
	end

	sessionCache[userId] = finalData
	setupLeaderstats(player, finalData)
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
		return
	end

	local success, err = pcall(function()
		ds:SetAsync("Player_" .. userId, {
			Coins = data.Coins,
			TotalDrops = data.TotalDrops,
		})
	end)

	if success then
		print(string.format("[PlinkoChaos] 💾 Sauvegarde réussie pour %s : %d Pièces (Total drops: %d)", player.Name, data.Coins, data.TotalDrops or 0))
	else
		warn(string.format("[PlinkoChaos] ❌ Échec de sauvegarde pour %s : %s", player.Name, tostring(err)))
	end

	sessionCache[userId] = nil
end

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

	print("[PlinkoChaos] 💰 PlayerDataService initialisé.")
end

return PlayerDataService

