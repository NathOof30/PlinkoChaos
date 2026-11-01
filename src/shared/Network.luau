--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = {}

local ALL_REMOTE_EVENTS = {
	"RequestDrop",
	"DropFailed",
	"RequestRelief",
	"BallScored",
	"DeckSync",
	"SlotStateChanged",
	"ToggleBotSimulation",
}

local function getEventsFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Events")
	if not folder then
		if RunService:IsServer() then
			local newFolder = Instance.new("Folder")
			newFolder.Name = "Events"
			newFolder.Parent = ReplicatedStorage
			return newFolder
		else
			return ReplicatedStorage:WaitForChild("Events", 10) :: Folder
		end
	end
	return folder :: Folder
end

function Network.InitServer()
	if not RunService:IsServer() then
		return
	end
	local folder = getEventsFolder()
	for _, eventName in ipairs(ALL_REMOTE_EVENTS) do
		if not folder:FindFirstChild(eventName) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = eventName
			remote.Parent = folder
		end
	end
	print("[PlinkoChaos] 📡 Network RemoteEvents initialisés avec succès côté serveur.")
end

-- Pré-initialisation automatique côté serveur dès le chargement du module
if RunService:IsServer() then
	Network.InitServer()
end

function Network.GetRemoteEvent(name: string): RemoteEvent
	local folder = getEventsFolder()
	if not folder then
		error("[Network] Dossier 'Events' introuvable dans ReplicatedStorage !")
	end

	local remote = folder:FindFirstChild(name)
	if not remote then
		if RunService:IsServer() then
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = name
			newRemote.Parent = folder
			return newRemote
		else
			local waited = folder:WaitForChild(name, 5)
			if not waited then
				warn(string.format("[Network] RemoteEvent '%s' non reçu après 5s, attente infinie...", name))
				return folder:WaitForChild(name) :: RemoteEvent
			end
			return waited :: RemoteEvent
		end
	end
	return remote :: RemoteEvent
end

return Network

