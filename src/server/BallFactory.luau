--!strict
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoardConfig")
local function getConfig()
	local ok, res = pcall(require, configModule)
	if ok and res and res.Ball then
		return res
	end
	local fn = loadstring((configModule :: ModuleScript).Source)
	return fn()
end

local BallFactory = {}

-- Dossier dédié dans Workspace pour ranger proprement les billes en jeu
function BallFactory.GetActiveFolder(): Folder
	local folder = workspace:FindFirstChild("ActiveBalls")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ActiveBalls"
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- Création d'une bille standard (métallique blanc/gris)
function BallFactory.CreateStandardBall(owner: Player?, xOffset: number?): Part
	local BoardConfig = getConfig()
	local center = BoardConfig.CenterPosition
	local height = BoardConfig.PlayableHeight
	local ballCfg = BoardConfig.Ball
	local pyramid = BoardConfig.Pyramid
	local slotH = BoardConfig.Slots.Height

	local bottomY = center.Y - height / 2
	local slotTopY = bottomY + slotH
	local bottomPegY = slotTopY + 1.2
	local topPegY = bottomPegY + (pyramid.Rows - 1) * pyramid.VerticalSpacing

	local ball = Instance.new("Part")
	local ballId = HttpService:GenerateGUID(false)
	ball.Name = "PlinkoBall_" .. string.sub(ballId, 1, 8)
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(ballCfg.Diameter, ballCfg.Diameter, ballCfg.Diameter)
	ball.Material = ballCfg.Material or Enum.Material.Metal
	ball.Color = ballCfg.Color or Color3.fromRGB(225, 228, 235)
	ball.Anchored = false
	ball.CanCollide = true
	ball.CanTouch = true

	local physProps = PhysicalProperties.new(
		ballCfg.Density,
		ballCfg.Friction,
		ballCfg.Elasticity,
		1.0,
		1.0
	)
	ball.CustomPhysicalProperties = physProps

	-- Métadonnées de gameplay pour le cycle de vie
	local ownerUserId = owner and owner.UserId or 0
	ball:SetAttribute("BallId", ballId)
	ball:SetAttribute("OwnerUserId", ownerUserId)
	ball:SetAttribute("BaseValue", ballCfg.BaseValue or 10)
	ball:SetAttribute("SpawnTime", os.clock())
	ball:SetAttribute("Processed", false)

	CollectionService:AddTag(ball, "PlinkoBall")

	local offset = xOffset or ballCfg.DefaultSpawnOffset or 0.5
	local spawnY = topPegY + 4.5
	local spawnX = center.X + offset
	ball.CFrame = CFrame.new(spawnX, spawnY, center.Z)

	ball.Parent = BallFactory.GetActiveFolder()

	-- Le serveur garde impérativement le contrôle physique (NetworkOwner = nil)
	-- Essentiel pour la physique multijoueur universelle
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)

	return ball
end

return BallFactory

