--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoardConfig")
local function getConfig(): any
	local ok, res = pcall(require, configModule)
	if ok and res and res.Pyramid then
		return res
	end
	local fn = loadstring((configModule :: ModuleScript).Source)
	if fn then
		return fn()
	end
	return require(configModule)
end

local BoardBuilder = {}

function BoardBuilder.Build(): Model
	local BoardConfig = getConfig()

	local existing = workspace:FindFirstChild("PlinkoBoard")
	if existing then
		existing:Destroy()
	end

	local boardModel = Instance.new("Model")
	boardModel.Name = "PlinkoBoard"

	local center = BoardConfig.CenterPosition
	local width = BoardConfig.PlayableWidth -- 52 studs
	local height = BoardConfig.PlayableHeight -- 66 studs
	local depth = BoardConfig.InternalDepth -- 1.8 studs
	local frame = BoardConfig.Frame
	local pyramid = BoardConfig.Pyramid
	local slotCfg = BoardConfig.Slots

	local slotH = slotCfg.Height
	local bottomY = center.Y - height / 2
	local totalBoardHeight = height + 10
	local frameCenterY = bottomY + totalBoardHeight / 2

	-- 1. Encadrement (Fond, Vitre, Mur du bas)
	local frameFolder = Instance.new("Folder")
	frameFolder.Name = "Frame"
	frameFolder.Parent = boardModel

	-- Fond (Backboard)
	local backboard = Instance.new("Part")
	backboard.Name = "Backboard"
	backboard.Anchored = true
	backboard.Material = Enum.Material.SmoothPlastic
	backboard.Color = frame.BackboardColor
	backboard.Size = Vector3.new(
		width + 2 * frame.WallThickness + 2,
		totalBoardHeight,
		frame.BackboardThickness
	)
	backboard.CFrame = CFrame.new(center.X, frameCenterY, center.Z - (depth / 2 + frame.BackboardThickness / 2))
	backboard.Parent = frameFolder

	-- Vitre avant transparente (CanCollide = true pour confiner les billes)
	local frontGlass = Instance.new("Part")
	frontGlass.Name = "FrontGlass"
	frontGlass.Anchored = true
	frontGlass.Material = Enum.Material.Glass
	frontGlass.Color = Color3.fromRGB(220, 240, 255)
	frontGlass.Transparency = frame.GlassTransparency
	frontGlass.CanCollide = true
	frontGlass.CastShadow = false
	frontGlass.Size = Vector3.new(
		width + 2 * frame.WallThickness + 2,
		totalBoardHeight,
		frame.GlassThickness
	)
	frontGlass.CFrame = CFrame.new(center.X, frameCenterY, center.Z + (depth / 2 + frame.GlassThickness / 2))
	frontGlass.Parent = frameFolder

	-- Mur du Bas (Sous les bacs)
	local bottomWall = Instance.new("Part")
	bottomWall.Name = "BottomWall"
	bottomWall.Anchored = true
	bottomWall.Material = Enum.Material.SmoothPlastic
	bottomWall.Color = frame.WallColor
	bottomWall.Size = Vector3.new(width + 2 * frame.WallThickness + 2, frame.WallThickness, depth)
	bottomWall.CFrame = CFrame.new(center.X, bottomY - frame.WallThickness / 2, center.Z)
	bottomWall.Parent = frameFolder

	-- 2. Paramètres analytiques de la pyramide et des parois inclinées
	local H_spacing = pyramid.HorizontalSpacing -- 3.6
	local V_spacing = pyramid.VerticalSpacing -- 3.8
	local pegRadius = BoardConfig.Pegs.Diameter / 2
	local clearance = 1.85 -- Distance constante garantie entre la paroi et le clou le plus extérieur (aucun piège)

	-- Angle exact de la pente de la pyramide
	local dX_per_row = H_spacing / 2 -- 1.8
	local dY_per_row = V_spacing -- 3.8
	local theta = math.atan2(dX_per_row, dY_per_row) -- ~25.35 degrés

	local slotTopY = bottomY + slotH
	local bottomPegY = slotTopY + 1.2
	local topPegY = bottomPegY + (pyramid.Rows - 1) * V_spacing

	-- Fonction de la ligne intérieure de la paroi droite à toute hauteur Y
	local function wallInnerX(y: number): number
		return (pyramid.StartPegCount - 1) * dX_per_row + pegRadius + clearance + (topPegY - y) * (dX_per_row / dY_per_row)
	end

	-- Sommet du couloir de lâcher
	local chuteTopY = topPegY + 7.0
	local xInnerTop = wallInnerX(chuteTopY)
	local xInnerBottom = wallInnerX(slotTopY)

	-- Construction des parois inclinées parfaites (du sommet au haut des bacs)
	local wallThickness = frame.WallThickness
	local L_vec_X = xInnerBottom - xInnerTop
	local L_vec_Y = slotTopY - chuteTopY -- négatif
	local slopedLength = math.sqrt(L_vec_X * L_vec_X + L_vec_Y * L_vec_Y)

	-- Vecteur normal unitaire pointant vers l'extérieur pour décaler le centre de la part
	local unitX = L_vec_X / slopedLength
	local unitY = L_vec_Y / slopedLength
	local normX = -unitY -- > 0 (vers la droite)
	local normY = unitX -- > 0 (vers le haut)

	local midInnerX = (xInnerTop + xInnerBottom) / 2
	local midInnerY = (chuteTopY + slotTopY) / 2

	-- Paroi inclinée droite (parfaitement parallèle à la pyramide, angle exact)
	local rightCenter = Vector3.new(
		center.X + midInnerX + normX * (wallThickness / 2),
		midInnerY + normY * (wallThickness / 2),
		center.Z
	)
	local rightSlopedWall = Instance.new("Part")
	rightSlopedWall.Name = "RightSlopedWall"
	rightSlopedWall.Anchored = true
	rightSlopedWall.Material = Enum.Material.SmoothPlastic
	rightSlopedWall.Color = frame.WallColor
	rightSlopedWall.Size = Vector3.new(wallThickness, slopedLength, depth)
	rightSlopedWall.CFrame = CFrame.new(rightCenter) * CFrame.Angles(0, 0, theta)
	rightSlopedWall.Parent = frameFolder

	-- Paroi inclinée gauche (symétrie exacte)
	local leftCenter = Vector3.new(
		center.X - (midInnerX + normX * (wallThickness / 2)),
		midInnerY + normY * (wallThickness / 2),
		center.Z
	)
	local leftSlopedWall = Instance.new("Part")
	leftSlopedWall.Name = "LeftSlopedWall"
	leftSlopedWall.Anchored = true
	leftSlopedWall.Material = Enum.Material.SmoothPlastic
	leftSlopedWall.Color = frame.WallColor
	leftSlopedWall.Size = Vector3.new(wallThickness, slopedLength, depth)
	leftSlopedWall.CFrame = CFrame.new(leftCenter) * CFrame.Angles(0, 0, -theta)
	leftSlopedWall.Parent = frameFolder

	-- Plafond supérieur de sécurité (bloque toute bille propulsée vers le haut lors d'une explosion)
	local ceiling = Instance.new("Part")
	ceiling.Name = "TopCeiling"
	ceiling.Anchored = true
	ceiling.Material = Enum.Material.SmoothPlastic
	ceiling.Color = frame.WallColor
	ceiling.Size = Vector3.new(2 * xInnerTop + 2 * wallThickness, wallThickness, depth)
	ceiling.CFrame = CFrame.new(center.X, chuteTopY + wallThickness / 2, center.Z)
	ceiling.Parent = frameFolder

	-- Parois verticales entourant les bacs (en dessous de slotTopY, s'alignent au pixel près)
	local slotWallHalfW = xInnerBottom
	local leftSlotWall = Instance.new("Part")
	leftSlotWall.Name = "LeftSlotWall"
	leftSlotWall.Anchored = true
	leftSlotWall.Material = Enum.Material.SmoothPlastic
	leftSlotWall.Color = frame.WallColor
	leftSlotWall.Size = Vector3.new(wallThickness, slotH, depth)
	leftSlotWall.CFrame = CFrame.new(center.X - (slotWallHalfW + wallThickness / 2), bottomY + slotH / 2, center.Z)
	leftSlotWall.Parent = frameFolder

	local rightSlotWall = Instance.new("Part")
	rightSlotWall.Name = "RightSlotWall"
	rightSlotWall.Anchored = true
	rightSlotWall.Material = Enum.Material.SmoothPlastic
	rightSlotWall.Color = frame.WallColor
	rightSlotWall.Size = Vector3.new(wallThickness, slotH, depth)
	rightSlotWall.CFrame = CFrame.new(center.X + (slotWallHalfW + wallThickness / 2), bottomY + slotH / 2, center.Z)
	rightSlotWall.Parent = frameFolder

	-- 3. Clous de la pyramide (Pegs)
	local pegsFolder = Instance.new("Folder")
	pegsFolder.Name = "Pegs"
	pegsFolder.Parent = boardModel

	local pegCfg = BoardConfig.Pegs
	local pegPhysProps = PhysicalProperties.new(
		pegCfg.PhysicalProperties.Density,
		pegCfg.PhysicalProperties.Friction,
		pegCfg.PhysicalProperties.Elasticity,
		pegCfg.PhysicalProperties.FrictionWeight,
		pegCfg.PhysicalProperties.ElasticityWeight
	)

	for row = 1, pyramid.Rows do
		local rowY = topPegY - (row - 1) * V_spacing
		local numPegs = pyramid.StartPegCount + (row - 1)
		local startX = -((numPegs - 1) / 2) * H_spacing

		for col = 1, numPegs do
			local pegX = startX + (col - 1) * H_spacing
			local peg = Instance.new("Part")
			peg.Name = string.format("Peg_R%02d_C%02d", row, col)
			peg.Shape = Enum.PartType.Cylinder
			peg.Size = Vector3.new(depth, pegCfg.Diameter, pegCfg.Diameter)
			peg.CFrame = CFrame.new(center.X + pegX, rowY, center.Z) * CFrame.Angles(0, math.rad(90), 0)
			peg.Anchored = true
			peg.Material = pegCfg.Material
			peg.Color = pegCfg.Color
			peg.CustomPhysicalProperties = pegPhysProps
			CollectionService:AddTag(peg, "PlinkoPeg")
			peg.Parent = pegsFolder
		end
	end

	-- 4. Bacs Récepteurs (Slots) & Multiplicateurs
	local slotsFolder = Instance.new("Folder")
	slotsFolder.Name = "Slots"
	slotsFolder.Parent = boardModel

	local slotList = slotCfg.List
	local totalWeight = 0
	for _, s in ipairs(slotList) do
		totalWeight += s.relativeWidth
	end

	local slotsTotalWidth = slotWallHalfW * 2
	local sepThick = slotCfg.SeparatorThickness
	local currentLeftX = center.X - slotWallHalfW

	-- Séparateur initial tout à gauche
	local firstSep = Instance.new("Part")
	firstSep.Name = "Separator_0"
	firstSep.Anchored = true
	firstSep.Material = Enum.Material.SmoothPlastic
	firstSep.Color = frame.WallColor
	firstSep.Size = Vector3.new(sepThick, slotH, depth)
	firstSep.CFrame = CFrame.new(currentLeftX + sepThick / 2, bottomY + slotH / 2, center.Z)
	firstSep.Parent = slotsFolder

	for index, slotDef in ipairs(slotList) do
		local slotWidth = (slotDef.relativeWidth / totalWeight) * slotsTotalWidth
		local slotCenterX = currentLeftX + (slotWidth / 2)

		-- Pad récepteur (détecteur / sensor au fond du bac)
		local pad = Instance.new("Part")
		pad.Name = string.format("SlotPad_%d_%s", index, slotDef.label)
		pad.Anchored = true
		pad.Material = Enum.Material.Neon
		pad.Color = slotDef.color
		pad.Size = Vector3.new(math.max(0.5, slotWidth - sepThick), 1.2, depth - 0.2)
		pad.CFrame = CFrame.new(slotCenterX, bottomY + 0.6, center.Z)

		-- Métadonnées de gameplay
		pad:SetAttribute("Multiplier", slotDef.multiplier)
		pad:SetAttribute("SlotIndex", index)
		pad:SetAttribute("SlotLabel", slotDef.label)
		CollectionService:AddTag(pad, "PlinkoSlot")
		pad.Parent = slotsFolder

		-- Plaque visuelle frontale montée devant la vitre
		local plaqueDepth = 0.4
		local plaqueWidth = math.max(0.5, slotWidth - 0.15)
		local plaqueHeight = 3.2

		local plaque = Instance.new("Part")
		plaque.Name = string.format("SlotPlaque_%d", index)
		plaque.Anchored = true
		plaque.Material = Enum.Material.SmoothPlastic
		plaque.Color = slotDef.color
		plaque.Size = Vector3.new(plaqueWidth, plaqueHeight, plaqueDepth)
		plaque.CFrame = CFrame.new(
			slotCenterX,
			bottomY + 1.6,
			center.Z + (depth / 2) + frame.GlassThickness + (plaqueDepth / 2) + 0.05
		)
		plaque.Parent = slotsFolder

		-- SurfaceGui avec CanvasSize proportionnel aux dimensions réelles (1 stud = 50 pixels)
		local pps = 50
		local canvasW = math.round(plaqueWidth * pps)
		local canvasH = math.round(plaqueHeight * pps)

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Face = Enum.NormalId.Back
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surfaceGui.CanvasSize = Vector2.new(canvasW, canvasH)
		surfaceGui.LightInfluence = 0
		surfaceGui.AlwaysOnTop = false
		surfaceGui.Parent = plaque

		local labelH = canvasH * 0.72
		local maxW = math.min(canvasW * 0.88, labelH * 1.9)

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(0, maxW, 0, labelH)
		textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = slotDef.label
		textLabel.Font = Enum.Font.FredokaOne
		textLabel.TextScaled = true

		if slotDef.multiplier == 10 or slotDef.multiplier == 2 then
			textLabel.TextColor3 = Color3.fromRGB(20, 20, 20)
		else
			textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			textLabel.TextStrokeTransparency = 0.2
			textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		end
		textLabel.Parent = surfaceGui

		-- Séparateur droit du bac
		local sep = Instance.new("Part")
		sep.Name = string.format("Separator_%d", index)
		sep.Anchored = true
		sep.Material = Enum.Material.SmoothPlastic
		sep.Color = frame.WallColor
		sep.Size = Vector3.new(sepThick, slotH, depth)
		sep.CFrame = CFrame.new(currentLeftX + slotWidth, bottomY + slotH / 2, center.Z)
		sep.Parent = slotsFolder

		currentLeftX += slotWidth
	end

	-- 5. Plateforme Joueur & SpawnLocation (face au plateau)
	local platformFolder = Instance.new("Folder")
	platformFolder.Name = "PlayerPlatform"
	platformFolder.Parent = boardModel

	local platZ = 55
	local platY = 16
	local platWidth = 30
	local platDepth = 16

	-- Sol de la plateforme
	local floor = Instance.new("Part")
	floor.Name = "PlatformFloor"
	floor.Anchored = true
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(35, 38, 48)
	floor.Size = Vector3.new(platWidth, 2, platDepth)
	floor.CFrame = CFrame.new(center.X, platY - 1, platZ)
	floor.Parent = platformFolder

	-- Point d'apparition (SpawnLocation)
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "PlayerSpawn"
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = true
	spawnLoc.Neutral = true
	spawnLoc.Duration = 0
	spawnLoc.Material = Enum.Material.SmoothPlastic
	spawnLoc.Color = Color3.fromRGB(48, 52, 68)
	spawnLoc.Size = Vector3.new(8, 0.4, 8)
	-- Oriente le joueur face au plateau (vers Z = 0)
	spawnLoc.CFrame = CFrame.lookAt(Vector3.new(center.X, platY + 0.2, platZ), Vector3.new(center.X, platY + 0.2, 0))
	spawnLoc.Parent = platformFolder

	-- Garde-corps / rambardes de sécurité
	local railingColor = Color3.fromRGB(60, 65, 82)
	local rMat = Enum.Material.Metal

	local backRailing = Instance.new("Part")
	backRailing.Name = "BackRailing"
	backRailing.Anchored = true
	backRailing.Material = rMat
	backRailing.Color = railingColor
	backRailing.Size = Vector3.new(platWidth, 3.5, 0.8)
	backRailing.CFrame = CFrame.new(center.X, platY + 1.75, platZ + platDepth / 2)
	backRailing.Parent = platformFolder

	local leftRailing = Instance.new("Part")
	leftRailing.Name = "LeftRailing"
	leftRailing.Anchored = true
	leftRailing.Material = rMat
	leftRailing.Color = railingColor
	leftRailing.Size = Vector3.new(0.8, 3.5, platDepth)
	leftRailing.CFrame = CFrame.new(center.X - platWidth / 2, platY + 1.75, platZ)
	leftRailing.Parent = platformFolder

	local rightRailing = Instance.new("Part")
	rightRailing.Name = "RightRailing"
	rightRailing.Anchored = true
	rightRailing.Material = rMat
	rightRailing.Color = railingColor
	rightRailing.Size = Vector3.new(0.8, 3.5, platDepth)
	rightRailing.CFrame = CFrame.new(center.X + platWidth / 2, platY + 1.75, platZ)
	rightRailing.Parent = platformFolder

	-- Rambarde frontale transparente (sécurité anti-chute tout en gardant une vue parfaite)
	local frontRailing = Instance.new("Part")
	frontRailing.Name = "FrontRailing"
	frontRailing.Anchored = true
	frontRailing.Material = Enum.Material.Glass
	frontRailing.Color = Color3.fromRGB(200, 225, 255)
	frontRailing.Transparency = 0.65
	frontRailing.Size = Vector3.new(platWidth, 3.2, 0.6)
	frontRailing.CFrame = CFrame.new(center.X, platY + 1.6, platZ - platDepth / 2)
	frontRailing.Parent = platformFolder

	local frontHandrail = Instance.new("Part")
	frontHandrail.Name = "FrontHandrail"
	frontHandrail.Anchored = true
	frontHandrail.Material = rMat
	frontHandrail.Color = railingColor
	frontHandrail.Size = Vector3.new(platWidth, 0.35, 0.9)
	frontHandrail.CFrame = CFrame.new(center.X, platY + 3.25, platZ - platDepth / 2)
	frontHandrail.Parent = platformFolder

	boardModel.Parent = workspace
	return boardModel
end

function BoardBuilder.SpawnTestBall(xOffset: number?): Part
	local BallFactory = require(script.Parent:WaitForChild("BallFactory"))
	return BallFactory.CreateStandardBall(nil, xOffset)
end

return BoardBuilder
