--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = {}

local function getEventsFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Events")
	if not folder then
		if RunService:IsServer() then
			local newFolder = Instance.new("Folder")
			newFolder.Name = "Events"
			newFolder.Parent = ReplicatedStorage
			return newFolder
		else
			return ReplicatedStorage:WaitForChild("Events") :: Folder
		end
	end
	return folder :: Folder
end

function Network.GetRemoteEvent(name: string): RemoteEvent
	local folder = getEventsFolder()
	local remote = folder:FindFirstChild(name)
	if not remote then
		if RunService:IsServer() then
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = name
			newRemote.Parent = folder
			return newRemote
		else
			return folder:WaitForChild(name) :: RemoteEvent
		end
	end
	return remote :: RemoteEvent
end

return Network

