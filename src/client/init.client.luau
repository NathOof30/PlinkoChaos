--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local requestDropEvent = Network.GetRemoteEvent("RequestDrop")
local dropFailedEvent = Network.GetRemoteEvent("DropFailed")
local requestReliefEvent = Network.GetRemoteEvent("RequestRelief")
local ballScoredEvent = Network.GetRemoteEvent("BallScored")
local deckSyncEvent = Network.GetRemoteEvent("DeckSync")
local slotStateChangedEvent = Network.GetRemoteEvent("SlotStateChanged")

-- 1. Interface Joueur : Barre de Deck & Commandes
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlinkoGameUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Conteneur principal du Deck en bas au centre
local deckContainer = Instance.new("Frame")
deckContainer.Name = "DeckContainer"
deckContainer.Size = UDim2.new(0, 440, 0, 126)
deckContainer.AnchorPoint = Vector2.new(0.5, 1)
deckContainer.Position = UDim2.new(0.5, 0, 1, -12)
deckContainer.BackgroundColor3 = Color3.fromRGB(16, 18, 25)
deckContainer.BackgroundTransparency = 0.25
deckContainer.Parent = screenGui

local deckCorner = Instance.new("UICorner")
deckCorner.CornerRadius = UDim.new(0, 16)
deckCorner.Parent = deckContainer

local deckStroke = Instance.new("UIStroke")
deckStroke.Color = Color3.fromRGB(48, 54, 72)
deckStroke.Thickness = 2
deckStroke.Parent = deckContainer

-- Barre des 10 Slots horizontaux
local slotsBar = Instance.new("Frame")
slotsBar.Name = "SlotsBar"
slotsBar.Size = UDim2.new(1, -20, 0, 52)
slotsBar.Position = UDim2.new(0, 10, 0, 12)
slotsBar.BackgroundTransparency = 1
slotsBar.Parent = deckContainer

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = slotsBar

-- Styles visuels par type de bille (Phase 5)
local BALL_STYLES: { [string]: { readyColor: Color3, strokeColor: Color3, name: string } } = {
	Standard = {
		readyColor = Color3.fromRGB(225, 228, 235), -- Métal argenté
		strokeColor = Color3.fromRGB(46, 204, 113), -- Vert prêt
		name = "Standard",
	},
	Heavy = {
		readyColor = Color3.fromRGB(48, 52, 60), -- Fonte sombre
		strokeColor = Color3.fromRGB(115, 125, 142), -- Acier trempé
		name = "Lourde",
	},
	Explosive = {
		readyColor = Color3.fromRGB(255, 80, 20), -- Orange incandescent / feu
		strokeColor = Color3.fromRGB(255, 140, 40), -- Flamme
		name = "Explosive",
	},
	Spring = {
		readyColor = Color3.fromRGB(46, 255, 120), -- Vert fluo bondissant
		strokeColor = Color3.fromRGB(50, 255, 180), -- Électrique
		name = "Ressort",
	},
}

-- Table pour stocker les références visuelles de chaque slot (1 à 10)
type SlotWidget = {
	button: TextButton,
	stroke: UIStroke,
	ballCircle: Frame,
	numberLabel: TextLabel,
	state: string,
	ballType: string,
}
local slotWidgets = {} :: { [number]: SlotWidget }

-- Fonction de mise à jour visuelle d'un slot selon son état (Ready vs Dropping) et son type de bille
local function setSlotWidgetState(slotIndex: number, newState: string, animate: boolean?)
	local widget = slotWidgets[slotIndex]
	if not widget then
		return
	end
	widget.state = newState
	local style = BALL_STYLES[widget.ballType] or BALL_STYLES.Standard

	if newState == "Ready" then
		-- Slot disponible : couleurs spécifiques au type de bille
		widget.button.BackgroundColor3 = Color3.fromRGB(28, 33, 46)
		widget.stroke.Color = style.strokeColor
		widget.stroke.Thickness = 2
		widget.ballCircle.BackgroundColor3 = style.readyColor
		widget.numberLabel.TextColor3 = Color3.fromRGB(200, 215, 235)

		if animate then
			-- Animation pop de rechargement lors du retour de la bille
			widget.button.Size = UDim2.new(0, 42, 0, 54)
			TweenService:Create(widget.button, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 36, 0, 48),
			}):Play()
		end
	else
		-- Slot en cours de chute (Dropping) : grisé et verrouillé
		widget.button.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
		widget.stroke.Color = Color3.fromRGB(42, 46, 58)
		widget.stroke.Thickness = 1
		widget.ballCircle.BackgroundColor3 = Color3.fromRGB(40, 43, 50)
		widget.numberLabel.TextColor3 = Color3.fromRGB(75, 80, 95)
	end
end

-- Création des 10 boutons de slots
for i = 1, 10 do
	local defaultType = "Standard"
	if i == 1 then
		defaultType = "Heavy"
	elseif i == 2 then
		defaultType = "Explosive"
	elseif i == 3 then
		defaultType = "Spring"
	end

	local initialStyle = BALL_STYLES[defaultType] or BALL_STYLES.Standard

	local btn = Instance.new("TextButton")
	btn.Name = "Slot_" .. i
	btn.LayoutOrder = i
	btn.Size = UDim2.new(0, 36, 0, 48)
	btn.BackgroundColor3 = Color3.fromRGB(28, 33, 46)
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = slotsBar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = initialStyle.strokeColor
	stroke.Thickness = 2
	stroke.Parent = btn

	local numLbl = Instance.new("TextLabel")
	numLbl.Name = "SlotNumber"
	numLbl.Size = UDim2.new(1, 0, 0, 14)
	numLbl.Position = UDim2.new(0, 0, 0, 3)
	numLbl.BackgroundTransparency = 1
	numLbl.Text = tostring(i)
	numLbl.Font = Enum.Font.GothamBold
	numLbl.TextSize = 10
	numLbl.TextColor3 = Color3.fromRGB(200, 215, 235)
	numLbl.Parent = btn

	local ballCircle = Instance.new("Frame")
	ballCircle.Name = "BallIcon"
	ballCircle.Size = UDim2.new(0, 20, 0, 20)
	ballCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	ballCircle.Position = UDim2.new(0.5, 0, 0.65, 0)
	ballCircle.BackgroundColor3 = initialStyle.readyColor
	ballCircle.BorderSizePixel = 0
	ballCircle.Parent = btn

	local ballCorner = Instance.new("UICorner")
	ballCorner.CornerRadius = UDim.new(1, 0)
	ballCorner.Parent = ballCircle

	slotWidgets[i] = {
		button = btn,
		stroke = stroke,
		ballCircle = ballCircle,
		numberLabel = numLbl,
		state = "Ready",
		ballType = defaultType,
	}

	-- Clic direct sur un slot pour lâcher spécifiquement cette bille
	btn.MouseButton1Click:Connect(function()
		local widget = slotWidgets[i]
		if widget and widget.state == "Ready" then
			btn.Size = UDim2.new(0, 32, 0, 44)
			TweenService:Create(btn, TweenInfo.new(0.12), { Size = UDim2.new(0, 36, 0, 48) }):Play()
			requestDropEvent:FireServer(i)
		else
			-- Secousse si le slot est déjà en chute
			local origPos = btn.Position
			task.spawn(function()
				for _ = 1, 2 do
					btn.Position = origPos + UDim2.new(0, 3, 0, 0)
					task.wait(0.03)
					btn.Position = origPos - UDim2.new(0, 3, 0, 0)
					task.wait(0.03)
				end
				btn.Position = origPos
			end)
		end
	end)
end

-- Barre inférieure des contrôles (Bouton Drop global & Bouton Secours)
local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "ControlsFrame"
controlsFrame.Size = UDim2.new(1, -24, 0, 46)
controlsFrame.Position = UDim2.new(0, 12, 0, 70)
controlsFrame.BackgroundTransparency = 1
controlsFrame.Parent = deckContainer

local dropButton = Instance.new("TextButton")
dropButton.Name = "MainDropButton"
dropButton.Size = UDim2.new(1, 0, 1, 0)
dropButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
dropButton.Text = "LÂCHER UNE BILLE (-10)"
dropButton.Font = Enum.Font.FredokaOne
dropButton.TextSize = 20
dropButton.TextColor3 = Color3.fromRGB(255, 255, 255)
dropButton.AutoButtonColor = true
dropButton.Parent = controlsFrame

local dropBtnCorner = Instance.new("UICorner")
dropBtnCorner.CornerRadius = UDim.new(0, 12)
dropBtnCorner.Parent = dropButton

local dropBtnStroke = Instance.new("UIStroke")
dropBtnStroke.Color = Color3.fromRGB(39, 174, 96)
dropBtnStroke.Thickness = 2
dropBtnStroke.Parent = dropButton

-- Bouton de secours (apparaît uniquement si le joueur a < 10 pièces)
local reliefButton = Instance.new("TextButton")
reliefButton.Name = "ReliefButton"
reliefButton.Size = UDim2.new(0, 200, 0, 32)
reliefButton.AnchorPoint = Vector2.new(0.5, 0)
reliefButton.Position = UDim2.new(0.5, 0, 0, -36)
reliefButton.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
reliefButton.Text = "🆘 Recharge de Secours (+50)"
reliefButton.Font = Enum.Font.FredokaOne
reliefButton.TextSize = 14
reliefButton.TextColor3 = Color3.fromRGB(255, 255, 255)
reliefButton.Visible = false
reliefButton.Parent = deckContainer

local reliefCorner = Instance.new("UICorner")
reliefCorner.CornerRadius = UDim.new(0, 8)
reliefCorner.Parent = reliefButton

reliefButton.MouseButton1Click:Connect(function()
	requestReliefEvent:FireServer()
end)

-- Déclenchement du lâcher global (prend le premier slot Ready disponible)
local lastDropTime = 0
local isButtonLocked = false

local function triggerMainDrop()
	if isButtonLocked then
		return
	end
	local now = os.clock()
	if now - lastDropTime < 0.20 then
		return
	end
	lastDropTime = now

	dropButton.Size = UDim2.new(1, -12, 1, -4)
	TweenService:Create(dropButton, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 1, 0) }):Play()

	-- nil en premier argument = le serveur choisit automatiquement le premier slot prêt
	requestDropEvent:FireServer(nil)
end

dropButton.MouseButton1Click:Connect(triggerMainDrop)

-- Notification en cas d'échec de drop (fonds insuffisants ou 10/10 en jeu)
dropFailedEvent.OnClientEvent:Connect(function(msg: string)
	isButtonLocked = true
	local originalColor = dropButton.BackgroundColor3
	local originalText = dropButton.Text

	dropButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	dropButton.Text = msg

	local origPos = dropButton.Position
	task.spawn(function()
		for _ = 1, 3 do
			dropButton.Position = origPos + UDim2.new(0, 6, 0, 0)
			task.wait(0.04)
			dropButton.Position = origPos - UDim2.new(0, 6, 0, 0)
			task.wait(0.04)
		end
		dropButton.Position = origPos
	end)

	task.delay(1.4, function()
		dropButton.BackgroundColor3 = originalColor
		dropButton.Text = originalText
		isButtonLocked = false
	end)
end)

-- Synchronisation initiale du Deck
deckSyncEvent.OnClientEvent:Connect(function(deckData, slotStates)
	if deckData and typeof(deckData) == "table" then
		for i = 1, 10 do
			if deckData[i] and deckData[i].ballType then
				local widget = slotWidgets[i]
				if widget then
					widget.ballType = deckData[i].ballType
				end
			end
		end
	end

	if slotStates and typeof(slotStates) == "table" then
		for i = 1, 10 do
			local st = slotStates[i] or "Ready"
			setSlotWidgetState(i, st, false)
		end
	end
end)

-- Changement d'état d'un slot individuel (Ready <-> Dropping)
slotStateChangedEvent.OnClientEvent:Connect(function(slotIndex: number, newState: string)
	if slotIndex and slotIndex >= 1 and slotIndex <= 10 then
		setSlotWidgetState(slotIndex, newState, newState == "Ready")
	end
end)

-- Surveillance du solde via leaderstats
local function monitorLeaderstats(leaderstats: Folder)
	local coinsValue = leaderstats:WaitForChild("Pièces") :: IntValue
	local function updateUI(coins: number)
		if coins < 10 then
			reliefButton.Visible = true
			dropButton.BackgroundColor3 = Color3.fromRGB(108, 122, 137)
			dropButton.Text = "Fonds insuffisants (10 Pièces)"
			dropBtnStroke.Color = Color3.fromRGB(80, 90, 100)
		else
			reliefButton.Visible = false
			dropButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
			dropButton.Text = "LÂCHER UNE BILLE (-10)"
			dropBtnStroke.Color = Color3.fromRGB(39, 174, 96)
		end
	end

	coinsValue.Changed:Connect(updateUI)
	updateUI(coinsValue.Value)
end

local existingLeaderstats = localPlayer:FindFirstChild("leaderstats")
if existingLeaderstats then
	task.spawn(monitorLeaderstats, existingLeaderstats :: Folder)
else
	localPlayer.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" and child:IsA("Folder") then
			monitorLeaderstats(child)
		end
	end)
end

-- 2. Effet d'évaporation 3D à l'impact (Floating World Text & Particules)
local fxFolder = workspace:FindFirstChild("PlinkoFX")
if not fxFolder then
	local f = Instance.new("Folder")
	f.Name = "PlinkoFX"
	f.Parent = workspace
	fxFolder = f
end

local function spawnEvaporationEffect(hitPosition: Vector3, amountText: string, isPenalty: boolean, multiplier: number)
	local fxPart = Instance.new("Part")
	fxPart.Name = "FX_Score"
	fxPart.Size = Vector3.new(0.2, 0.2, 0.2)
	fxPart.Transparency = 1
	fxPart.CanCollide = false
	fxPart.Anchored = true
	fxPart.CFrame = CFrame.new(hitPosition + Vector3.new(0, 0.5, 1.2))
	fxPart.Parent = fxFolder

	local textColor: Color3
	if isPenalty then
		textColor = Color3.fromRGB(255, 60, 60)
	elseif multiplier >= 10 then
		textColor = Color3.fromRGB(255, 215, 0)
	elseif multiplier >= 2 then
		textColor = Color3.fromRGB(46, 204, 113)
	else
		textColor = Color3.fromRGB(80, 210, 255)
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ScoreBillboard"
	billboard.Adornee = fxPart
	billboard.Size = UDim2.new(0, 140, 0, 50)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Parent = fxPart

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = amountText
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = textColor
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.TextStrokeTransparency = 0.2
	textLabel.Parent = billboard

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://6071575925"
	emitter.Color = ColorSequence.new(textColor)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.0)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.Rate = 0
	emitter.Parent = fxPart

	emitter:Emit(isPenalty and 8 or 14)

	local DURATION = 1.3
	local floatTween = TweenService:Create(billboard, TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 5.5, 0),
	})
	floatTween:Play()

	billboard.Size = UDim2.new(0, 90, 0, 32)
	TweenService:Create(billboard, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 140, 0, 50),
	}):Play()

	task.delay(DURATION * 0.5, function()
		if textLabel and textLabel.Parent then
			TweenService:Create(textLabel, TweenInfo.new(DURATION * 0.5), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)

	Debris:AddItem(fxPart, DURATION + 0.2)
end

ballScoredEvent.OnClientEvent:Connect(function(data)
	if not data or not data.hitPosition then
		return
	end

	spawnEvaporationEffect(
		data.hitPosition,
		data.amountText or "+0",
		data.isPenalty == true,
		data.multiplier or 1
	)
end)

-- 3. Système d'Outlines & Reconnaissance Multijoueur
-- Vert pour nos billes (reconnaissable même pour la bille sombre)
-- Rouge pour les adversaires avec affichage discret du pseudo
local activeBallsFolder = workspace:FindFirstChild("ActiveBalls") :: Folder?

local function decorateBall(ball: Instance)
	if not ball:IsA("BasePart") then
		return
	end

	task.spawn(function()
		local ownerUserId = ball:GetAttribute("OwnerUserId")
		if ownerUserId == nil then
			local waited = 0
			while waited < 1.0 and ball:GetAttribute("OwnerUserId") == nil do
				task.wait(0.05)
				waited += 0.05
			end
			ownerUserId = ball:GetAttribute("OwnerUserId")
		end

		if not ball or not ball.Parent then
			return
		end

		local isMyBall = (ownerUserId == localPlayer.UserId)

		-- Highlight Roblox pour l'outline
		local highlight = Instance.new("Highlight")
		highlight.Name = "PlinkoBallHighlight"
		highlight.Adornee = ball
		highlight.FillTransparency = 1 -- Intérieur transparent pour voir la couleur originale de la bille
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

		if isMyBall then
			-- Vert franc (bien vert mais pas fluo)
			highlight.OutlineColor = Color3.fromRGB(38, 168, 65)
		else
			-- Rouge pour les billes adverses
			highlight.OutlineColor = Color3.fromRGB(225, 45, 45)

			-- Affichage discret du pseudo adverse
			local ownerName = ball:GetAttribute("OwnerName")
			if not ownerName or ownerName == "" then
				local opponentPlayer = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
				ownerName = opponentPlayer and opponentPlayer.DisplayName or (opponentPlayer and opponentPlayer.Name or "Adversaire")
			end

			local tagGui = Instance.new("BillboardGui")
			tagGui.Name = "OpponentTag"
			tagGui.Adornee = ball
			tagGui.Size = UDim2.new(0, 68, 0, 16)
			tagGui.StudsOffset = Vector3.new(0, 1.15, 0)
			tagGui.AlwaysOnTop = true
			tagGui.LightInfluence = 0
			tagGui.MaxDistance = 120
			tagGui.Parent = ball

			local tagFrame = Instance.new("Frame")
			tagFrame.Size = UDim2.new(1, 0, 1, 0)
			tagFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
			tagFrame.BackgroundTransparency = 0.30
			tagFrame.Parent = tagGui

			local tagCorner = Instance.new("UICorner")
			tagCorner.CornerRadius = UDim.new(0, 4)
			tagCorner.Parent = tagFrame

			local tagStroke = Instance.new("UIStroke")
			tagStroke.Color = Color3.fromRGB(225, 55, 55)
			tagStroke.Thickness = 1
			tagStroke.Parent = tagFrame

			local tagLabel = Instance.new("TextLabel")
			tagLabel.Size = UDim2.new(1, 0, 1, 0)
			tagLabel.BackgroundTransparency = 1
			tagLabel.Text = tostring(ownerName)
			tagLabel.Font = Enum.Font.GothamBold
			tagLabel.TextSize = 9
			tagLabel.TextColor3 = Color3.fromRGB(255, 235, 235)
			tagLabel.TextTruncate = Enum.TextTruncate.AtEnd
			tagLabel.Parent = tagFrame
		end

		highlight.Parent = ball
	end)
end

if activeBallsFolder then
	activeBallsFolder.ChildAdded:Connect(decorateBall)
	for _, child in ipairs(activeBallsFolder:GetChildren()) do
		decorateBall(child)
	end
end

workspace.ChildAdded:Connect(function(child)
	if child.Name == "ActiveBalls" and child:IsA("Folder") then
		activeBallsFolder = child
		child.ChildAdded:Connect(decorateBall)
		for _, b in ipairs(child:GetChildren()) do
			decorateBall(b)
		end
	end
end)

print("[PlinkoChaos] 🎴 Barre de Deck UI Phase 5 initialisée (Outlines multijoueur & Billes spéciales actives).")
