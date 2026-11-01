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

-- 1. Interface Joueur : Bouton de Lâcher au Clic & Bouton de Secours
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlinkoGameUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Conteneur en bas au centre
local bottomFrame = Instance.new("Frame")
bottomFrame.Name = "BottomFrame"
bottomFrame.Size = UDim2.new(0, 320, 0, 110)
bottomFrame.AnchorPoint = Vector2.new(0.5, 1)
bottomFrame.Position = UDim2.new(0.5, 0, 1, -15)
bottomFrame.BackgroundTransparency = 1
bottomFrame.Parent = screenGui

-- Bouton de lâcher principal
local dropButton = Instance.new("TextButton")
dropButton.Name = "DropButton"
dropButton.Size = UDim2.new(0, 260, 0, 52)
dropButton.AnchorPoint = Vector2.new(0.5, 1)
dropButton.Position = UDim2.new(0.5, 0, 1, 0)
dropButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
dropButton.Text = "Lâcher (-10 Pièces)"
dropButton.Font = Enum.Font.FredokaOne
dropButton.TextSize = 21
dropButton.TextColor3 = Color3.fromRGB(255, 255, 255)
dropButton.AutoButtonColor = true

local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0, 14)
uicorner.Parent = dropButton

local uistroke = Instance.new("UIStroke")
uistroke.Color = Color3.fromRGB(39, 174, 96)
uistroke.Thickness = 2.5
uistroke.Parent = dropButton

dropButton.Parent = bottomFrame

-- Bouton de secours (apparaît uniquement si le joueur est à sec < 10 pièces)
local reliefButton = Instance.new("TextButton")
reliefButton.Name = "ReliefButton"
reliefButton.Size = UDim2.new(0, 240, 0, 36)
reliefButton.AnchorPoint = Vector2.new(0.5, 0)
reliefButton.Position = UDim2.new(0.5, 0, 0, 5)
reliefButton.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
reliefButton.Text = "🆘 Recharge de Secours (+50)"
reliefButton.Font = Enum.Font.FredokaOne
reliefButton.TextSize = 16
reliefButton.TextColor3 = Color3.fromRGB(255, 255, 255)
reliefButton.Visible = false

local reliefCorner = Instance.new("UICorner")
reliefCorner.CornerRadius = UDim.new(0, 10)
reliefCorner.Parent = reliefButton

reliefButton.Parent = bottomFrame

reliefButton.MouseButton1Click:Connect(function()
	requestReliefEvent:FireServer()
end)

-- Fonction de lâcher déclenchée uniquement par le clic
local lastDropTime = 0
local isButtonLocked = false

local function triggerDrop()
	if isButtonLocked then
		return
	end
	local now = os.clock()
	if now - lastDropTime < 0.25 then
		return
	end
	lastDropTime = now

	-- Petit effet tactile au clic
	dropButton.Size = UDim2.new(0, 245, 0, 46)
	TweenService:Create(dropButton, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.new(0, 260, 0, 52) }):Play()

	-- Envoi de la requête sécurisée au serveur
	requestDropEvent:FireServer()
end

dropButton.MouseButton1Click:Connect(triggerDrop)

-- Notification de refus si fonds insuffisants
dropFailedEvent.OnClientEvent:Connect(function(msg)
	isButtonLocked = true
	local originalColor = dropButton.BackgroundColor3
	local originalText = dropButton.Text

	dropButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	dropButton.Text = "Fonds insuffisants !"

	-- Secousse du bouton
	local origPos = dropButton.Position
	task.spawn(function()
		for i = 1, 3 do
			dropButton.Position = origPos + UDim2.new(0, 6, 0, 0)
			task.wait(0.04)
			dropButton.Position = origPos - UDim2.new(0, 6, 0, 0)
			task.wait(0.04)
		end
		dropButton.Position = origPos
	end)

	task.delay(1.2, function()
		dropButton.BackgroundColor3 = originalColor
		dropButton.Text = originalText
		isButtonLocked = false
	end)
end)

-- Surveillance du solde via leaderstats pour adapter l'interface
local function monitorLeaderstats(leaderstats: Folder)
	local coinsValue = leaderstats:WaitForChild("Pièces") :: IntValue
	local function updateUI(coins: number)
		if coins < 10 then
			reliefButton.Visible = true
			dropButton.BackgroundColor3 = Color3.fromRGB(108, 122, 137)
			dropButton.Text = "Lâcher (10 Pièces requises)"
			uistroke.Color = Color3.fromRGB(80, 90, 100)
		else
			reliefButton.Visible = false
			dropButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
			dropButton.Text = "Lâcher (-10 Pièces)"
			uistroke.Color = Color3.fromRGB(39, 174, 96)
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

-- 2. Effet d'évaporation 3D (Floating World Text & Particules)
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

-- 3. Réception du score et déclenchement de l'effet
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

print("[PlinkoChaos] 🎮 Contrôleur client Phase 3 prêt (Économie connectée, gestion du coût et sécurité faillite).")
