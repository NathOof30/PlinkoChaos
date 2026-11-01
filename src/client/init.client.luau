--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- RemoteEvents
local requestDropEvent = Network.GetRemoteEvent("RequestDrop")
local dropFailedEvent = Network.GetRemoteEvent("DropFailed")
local requestReliefEvent = Network.GetRemoteEvent("RequestRelief")
local ballScoredEvent = Network.GetRemoteEvent("BallScored")
local deckSyncEvent = Network.GetRemoteEvent("DeckSync")
local slotStateChangedEvent = Network.GetRemoteEvent("SlotStateChanged")
local toggleBotSimulationEvent = Network.GetRemoteEvent("ToggleBotSimulation")
local inventorySyncEvent = Network.GetRemoteEvent("InventorySync")
local buyStandardEvent = Network.GetRemoteEvent("RequestBuyStandard")
local unlockBlueprintEvent = Network.GetRemoteEvent("RequestUnlockBlueprint")
local craftBallEvent = Network.GetRemoteEvent("RequestCraftBall")
local equipBallEvent = Network.GetRemoteEvent("RequestEquipBall")
local unequipBallEvent = Network.GetRemoteEvent("RequestUnequipBall")
local feedbackEvent = Network.GetRemoteEvent("InventoryFeedback")

-- Styles visuels et métadonnées des types de billes
type BallStyle = {
	readyColor: Color3,
	strokeColor: Color3,
	name: string,
	tier: number,
	desc: string,
}

local BALL_STYLES: { [string]: BallStyle } = {
	Standard = {
		readyColor = Color3.fromRGB(225, 228, 235),
		strokeColor = Color3.fromRGB(46, 204, 113),
		name = "Standard",
		tier = 1,
		desc = "Bille équilibrée en métal.",
	},
	Slime = {
		readyColor = Color3.fromRGB(80, 255, 60),
		strokeColor = Color3.fromRGB(60, 230, 40),
		name = "Slime",
		tier = 2,
		desc = "Rebond extrême & chaotique.",
	},
	Spring = {
		readyColor = Color3.fromRGB(80, 255, 60),
		strokeColor = Color3.fromRGB(60, 230, 40),
		name = "Slime",
		tier = 2,
		desc = "Rebond extrême & chaotique.",
	},
	Heavy = {
		readyColor = Color3.fromRGB(48, 52, 60),
		strokeColor = Color3.fromRGB(115, 125, 142),
		name = "Lourde",
		tier = 3,
		desc = "Masse en fonte, dégage la voie.",
	},
	Explosive = {
		readyColor = Color3.fromRGB(255, 80, 20),
		strokeColor = Color3.fromRGB(255, 140, 40),
		name = "Explosive",
		tier = 4,
		desc = "Déflagration au 5ème rebond.",
	},
}

-- États locaux répliqués depuis le serveur
local currentDeck: { [number]: { ballType: string, level: number }? } = {}
local currentSlotStates: { [number]: string } = {}
local currentInventory: { [string]: number } = {
	Standard = 1,
	Slime = 0,
	Heavy = 0,
	Explosive = 0,
}
local currentBlueprints: { [string]: boolean } = {
	Slime = false,
	Heavy = false,
	Explosive = false,
}
local currentCoins: number = 10

-- GUI Racine
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlinkoGameUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ==================== BARRE DE DECK INFÉRIEURE ====================

local deckContainer = Instance.new("Frame")
deckContainer.Name = "DeckContainer"
deckContainer.Size = UDim2.new(0, 490, 0, 128)
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

-- Barre des 10 Slots
local slotsBar = Instance.new("Frame")
slotsBar.Name = "SlotsBar"
slotsBar.Size = UDim2.new(1, -20, 0, 52)
slotsBar.Position = UDim2.new(0, 10, 0, 10)
slotsBar.BackgroundTransparency = 1
slotsBar.Parent = deckContainer

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = slotsBar

type SlotWidget = {
	button: TextButton,
	stroke: UIStroke,
	ballCircle: Frame,
	numberLabel: TextLabel,
	emptyLabel: TextLabel,
	state: string,
	ballType: string?,
	isEmpty: boolean,
}
local slotWidgets: { [number]: SlotWidget } = {}

-- Déclaration anticipée de la fonction d'ouverture du modal
local openModal: (tabIndex: number?) -> ()

-- Mise à jour visuelle d'un widget de slot de la barre inférieure
local function updateSlotWidget(slotIndex: number, animate: boolean?)
	local widget = slotWidgets[slotIndex]
	if not widget then
		return
	end

	local slotData = currentDeck[slotIndex]
	local slotState = currentSlotStates[slotIndex] or "Ready"
	widget.state = slotState

	if not slotData or not slotData.ballType then
		-- Slot vide
		widget.isEmpty = true
		widget.ballType = nil
		widget.button.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
		widget.stroke.Color = Color3.fromRGB(45, 52, 68)
		widget.stroke.Thickness = 1
		widget.ballCircle.Visible = false
		widget.emptyLabel.Visible = true
		widget.numberLabel.TextColor3 = Color3.fromRGB(90, 100, 120)
	else
		-- Slot équipé
		widget.isEmpty = false
		widget.ballType = slotData.ballType
		local style = BALL_STYLES[slotData.ballType] or BALL_STYLES.Standard
		widget.ballCircle.Visible = true
		widget.emptyLabel.Visible = false

		if slotState == "Ready" then
			widget.button.BackgroundColor3 = Color3.fromRGB(28, 33, 46)
			widget.stroke.Color = style.strokeColor
			widget.stroke.Thickness = 2
			widget.ballCircle.BackgroundColor3 = style.readyColor
			widget.numberLabel.TextColor3 = Color3.fromRGB(200, 215, 235)

			if animate then
				widget.button.Size = UDim2.new(0, 42, 0, 54)
				TweenService:Create(widget.button, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, 36, 0, 48),
				}):Play()
			end
		else
			-- Slot en cours de chute
			widget.button.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
			widget.stroke.Color = Color3.fromRGB(42, 46, 58)
			widget.stroke.Thickness = 1
			widget.ballCircle.BackgroundColor3 = Color3.fromRGB(40, 43, 50)
			widget.numberLabel.TextColor3 = Color3.fromRGB(75, 80, 95)
		end
	end
end

-- Création des 10 widgets de slots
for i = 1, 10 do
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
	stroke.Color = Color3.fromRGB(48, 54, 72)
	stroke.Thickness = 1.5
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
	ballCircle.BackgroundColor3 = Color3.fromRGB(225, 228, 235)
	ballCircle.BorderSizePixel = 0
	ballCircle.Parent = btn

	local ballCorner = Instance.new("UICorner")
	ballCorner.CornerRadius = UDim.new(1, 0)
	ballCorner.Parent = ballCircle

	local emptyLbl = Instance.new("TextLabel")
	emptyLbl.Name = "EmptyLabel"
	emptyLbl.Size = UDim2.new(1, 0, 0, 20)
	emptyLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	emptyLbl.Position = UDim2.new(0.5, 0, 0.65, 0)
	emptyLbl.BackgroundTransparency = 1
	emptyLbl.Text = "+"
	emptyLbl.Font = Enum.Font.GothamBold
	emptyLbl.TextSize = 18
	emptyLbl.TextColor3 = Color3.fromRGB(80, 92, 115)
	emptyLbl.Visible = false
	emptyLbl.Parent = btn

	slotWidgets[i] = {
		button = btn,
		stroke = stroke,
		ballCircle = ballCircle,
		numberLabel = numLbl,
		emptyLabel = emptyLbl,
		state = "Ready",
		ballType = nil,
		isEmpty = true,
	}

	-- Interaction au clic : lâcher si prêt, ou ouvrir l'atelier si vide
	btn.MouseButton1Click:Connect(function()
		local widget = slotWidgets[i]
		if not widget then
			return
		end

		if widget.isEmpty then
			if openModal then
				openModal(1) -- Ouvre directement sur l'onglet Deck & Inventaire
			end
		elseif widget.state == "Ready" then
			btn.Size = UDim2.new(0, 32, 0, 44)
			TweenService:Create(btn, TweenInfo.new(0.12), { Size = UDim2.new(0, 36, 0, 48) }):Play()
			requestDropEvent:FireServer(i)
		else
			-- Secousse si déjà en chute
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

-- ==================== BARRE DE CONTRÔLE INFÉRIEURE ====================

local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "ControlsFrame"
controlsFrame.Size = UDim2.new(1, -20, 0, 46)
controlsFrame.Position = UDim2.new(0, 10, 0, 68)
controlsFrame.BackgroundTransparency = 1
controlsFrame.Parent = deckContainer

-- 1. Bouton Atelier & Inventaire (Positionné à côté du bouton de drop)
local backpackButton = Instance.new("TextButton")
backpackButton.Name = "BackpackButton"
backpackButton.Size = UDim2.new(0, 155, 1, 0)
backpackButton.Position = UDim2.new(0, 0, 0, 0)
backpackButton.BackgroundColor3 = Color3.fromRGB(30, 38, 54)
backpackButton.Text = "🎒 Atelier & Craft"
backpackButton.Font = Enum.Font.FredokaOne
backpackButton.TextSize = 16
backpackButton.TextColor3 = Color3.fromRGB(225, 238, 255)
backpackButton.AutoButtonColor = true
backpackButton.Parent = controlsFrame

local bpCorner = Instance.new("UICorner")
bpCorner.CornerRadius = UDim.new(0, 12)
bpCorner.Parent = backpackButton

local bpStroke = Instance.new("UIStroke")
bpStroke.Color = Color3.fromRGB(58, 120, 220)
bpStroke.Thickness = 2
bpStroke.Parent = backpackButton

-- 2. Bouton principal Lâcher une Bille
local dropButton = Instance.new("TextButton")
dropButton.Name = "MainDropButton"
dropButton.Size = UDim2.new(1, -165, 1, 0)
dropButton.Position = UDim2.new(0, 165, 0, 0)
dropButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
dropButton.Text = "LÂCHER UNE BILLE (-10)"
dropButton.Font = Enum.Font.FredokaOne
dropButton.TextSize = 19
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

-- Bouton Développeur : Simulateur Multijoueur (3 joueurs IA)
local devSimButton = Instance.new("TextButton")
devSimButton.Name = "DevBotSimButton"
devSimButton.Size = UDim2.new(0, 195, 0, 36)
devSimButton.AnchorPoint = Vector2.new(1, 0)
devSimButton.Position = UDim2.new(1, -16, 0, 16)
devSimButton.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
devSimButton.Text = "🤖 Simuler 3 Joueurs [OFF]"
devSimButton.Font = Enum.Font.GothamBold
devSimButton.TextSize = 12
devSimButton.TextColor3 = Color3.fromRGB(195, 210, 235)
devSimButton.AutoButtonColor = true
devSimButton.Parent = screenGui

local devSimCorner = Instance.new("UICorner")
devSimCorner.CornerRadius = UDim.new(0, 8)
devSimCorner.Parent = devSimButton

local devSimStroke = Instance.new("UIStroke")
devSimStroke.Color = Color3.fromRGB(65, 75, 100)
devSimStroke.Thickness = 1.5
devSimStroke.Parent = devSimButton

local isSimActive = false
devSimButton.MouseButton1Click:Connect(function()
	toggleBotSimulationEvent:FireServer()
end)

toggleBotSimulationEvent.OnClientEvent:Connect(function(active: boolean)
	isSimActive = active
	if isSimActive then
		devSimButton.BackgroundColor3 = Color3.fromRGB(38, 125, 68)
		devSimButton.Text = "🤖 3 Joueurs Actifs [STOP]"
		devSimStroke.Color = Color3.fromRGB(46, 204, 113)
	else
		devSimButton.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
		devSimButton.Text = "🤖 Simuler 3 Joueurs [OFF]"
		devSimStroke.Color = Color3.fromRGB(65, 75, 100)
	end
end)

-- Lâcher global (prend le premier slot Ready disponible)
local lastDropTime = 0
local isButtonLocked = false

local function triggerMainDrop()
	if isButtonLocked then
		return
	end
	local now = os.clock()
	if now - lastDropTime < 0.18 then
		return
	end
	lastDropTime = now

	dropButton.Size = UDim2.new(1, -172, 1, -4)
	TweenService:Create(dropButton, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.new(1, -165, 1, 0) }):Play()

	requestDropEvent:FireServer(nil)
end

dropButton.MouseButton1Click:Connect(triggerMainDrop)

-- Notification en cas d'échec de drop
dropFailedEvent.OnClientEvent:Connect(function(msg: string)
	isButtonLocked = true
	local originalColor = dropButton.BackgroundColor3
	local originalText = dropButton.Text

	dropButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	dropButton.Text = msg

	local origPos = dropButton.Position
	task.spawn(function()
		for _ = 1, 3 do
			dropButton.Position = origPos + UDim2.new(0, 5, 0, 0)
			task.wait(0.04)
			dropButton.Position = origPos - UDim2.new(0, 5, 0, 0)
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

-- ==================== MODAL ATELIER & INVENTAIRE ====================

local modalBackdrop = Instance.new("Frame")
modalBackdrop.Name = "ModalBackdrop"
modalBackdrop.Size = UDim2.new(1, 0, 1, 0)
modalBackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
modalBackdrop.BackgroundTransparency = 0.55
modalBackdrop.Visible = false
modalBackdrop.Parent = screenGui

local modalFrame = Instance.new("Frame")
modalFrame.Name = "AtelierModal"
modalFrame.Size = UDim2.new(0, 710, 0, 500)
modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
modalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
modalFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
modalFrame.BackgroundTransparency = 0.05
modalFrame.Parent = modalBackdrop

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 16)
modalCorner.Parent = modalFrame

local modalStroke = Instance.new("UIStroke")
modalStroke.Color = Color3.fromRGB(56, 75, 110)
modalStroke.Thickness = 2
modalStroke.Parent = modalFrame

-- En-tête Modal
local modalHeader = Instance.new("Frame")
modalHeader.Name = "ModalHeader"
modalHeader.Size = UDim2.new(1, -28, 0, 48)
modalHeader.Position = UDim2.new(0, 14, 0, 10)
modalHeader.BackgroundTransparency = 1
modalHeader.Parent = modalFrame

local modalTitle = Instance.new("TextLabel")
modalTitle.Name = "Title"
modalTitle.Size = UDim2.new(0, 360, 1, 0)
modalTitle.BackgroundTransparency = 1
modalTitle.Text = "🎒 ATELIER DE FUSION & INVENTAIRE"
modalTitle.Font = Enum.Font.FredokaOne
modalTitle.TextSize = 20
modalTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
modalTitle.TextXAlignment = Enum.TextXAlignment.Left
modalTitle.Parent = modalHeader

local modalCoins = Instance.new("TextLabel")
modalCoins.Name = "CoinsIndicator"
modalCoins.Size = UDim2.new(0, 180, 1, 0)
modalCoins.Position = UDim2.new(1, -220, 0, 0)
modalCoins.BackgroundTransparency = 1
modalCoins.Text = "🪙 10 Pièces"
modalCoins.Font = Enum.Font.FredokaOne
modalCoins.TextSize = 18
modalCoins.TextColor3 = Color3.fromRGB(255, 215, 0)
modalCoins.TextXAlignment = Enum.TextXAlignment.Right
modalCoins.Parent = modalHeader

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, 0, 0.5, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeButton.Text = "✕"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.AutoButtonColor = true
closeButton.Parent = modalHeader

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- Toast de feedback
local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "ToastFeedback"
toastLabel.Size = UDim2.new(1, -28, 0, 24)
toastLabel.Position = UDim2.new(0, 14, 0, 58)
toastLabel.BackgroundColor3 = Color3.fromRGB(38, 140, 68)
toastLabel.BackgroundTransparency = 1
toastLabel.Text = ""
toastLabel.Font = Enum.Font.GothamBold
toastLabel.TextSize = 13
toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
toastLabel.Visible = false
toastLabel.Parent = modalFrame

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 6)
toastCorner.Parent = toastLabel

local function showToast(success: boolean, message: string)
	toastLabel.Visible = true
	toastLabel.Text = message
	toastLabel.BackgroundColor3 = success and Color3.fromRGB(38, 140, 68) or Color3.fromRGB(205, 55, 55)
	toastLabel.BackgroundTransparency = 0.2

	task.delay(2.6, function()
		if toastLabel and toastLabel.Parent then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.wait(0.4)
			toastLabel.Visible = false
		end
	end)
end

-- Barre d'onglets
local tabsBar = Instance.new("Frame")
tabsBar.Name = "TabsBar"
tabsBar.Size = UDim2.new(1, -28, 0, 38)
tabsBar.Position = UDim2.new(0, 14, 0, 84)
tabsBar.BackgroundTransparency = 1
tabsBar.Parent = modalFrame

local tabBtn1 = Instance.new("TextButton")
tabBtn1.Name = "TabDeckInv"
tabBtn1.Size = UDim2.new(0.5, -4, 1, 0)
tabBtn1.Position = UDim2.new(0, 0, 0, 0)
tabBtn1.BackgroundColor3 = Color3.fromRGB(45, 60, 90)
tabBtn1.Text = "🎴 Mon Deck & Inventaire"
tabBtn1.Font = Enum.Font.FredokaOne
tabBtn1.TextSize = 16
tabBtn1.TextColor3 = Color3.fromRGB(255, 255, 255)
tabBtn1.Parent = tabsBar

local tab1Corner = Instance.new("UICorner")
tab1Corner.CornerRadius = UDim.new(0, 8)
tab1Corner.Parent = tabBtn1

local tabBtn2 = Instance.new("TextButton")
tabBtn2.Name = "TabCraftShop"
tabBtn2.Size = UDim2.new(0.5, -4, 1, 0)
tabBtn2.Position = UDim2.new(0.5, 4, 0, 0)
tabBtn2.BackgroundColor3 = Color3.fromRGB(26, 32, 46)
tabBtn2.Text = "🔨 Atelier de Fusion & Boutique"
tabBtn2.Font = Enum.Font.FredokaOne
tabBtn2.TextSize = 16
tabBtn2.TextColor3 = Color3.fromRGB(160, 175, 205)
tabBtn2.Parent = tabsBar

local tab2Corner = Instance.new("UICorner")
tab2Corner.CornerRadius = UDim.new(0, 8)
tab2Corner.Parent = tabBtn2

-- Conteneurs des Pages
local pageDeckInv = Instance.new("Frame")
pageDeckInv.Name = "PageDeckInv"
pageDeckInv.Size = UDim2.new(1, -28, 1, -134)
pageDeckInv.Position = UDim2.new(0, 14, 0, 126)
pageDeckInv.BackgroundTransparency = 1
pageDeckInv.Visible = true
pageDeckInv.Parent = modalFrame

local pageCraftShop = Instance.new("ScrollingFrame")
pageCraftShop.Name = "PageCraftShop"
pageCraftShop.Size = UDim2.new(1, -28, 1, -134)
pageCraftShop.Position = UDim2.new(0, 14, 0, 126)
pageCraftShop.BackgroundTransparency = 1
pageCraftShop.ScrollBarThickness = 6
pageCraftShop.CanvasSize = UDim2.new(0, 0, 0, 480)
pageCraftShop.Visible = false
pageCraftShop.Parent = modalFrame

local function switchTab(tabIndex: number)
	if tabIndex == 1 then
		pageDeckInv.Visible = true
		pageCraftShop.Visible = false
		tabBtn1.BackgroundColor3 = Color3.fromRGB(45, 60, 90)
		tabBtn1.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabBtn2.BackgroundColor3 = Color3.fromRGB(26, 32, 46)
		tabBtn2.TextColor3 = Color3.fromRGB(160, 175, 205)
	else
		pageDeckInv.Visible = false
		pageCraftShop.Visible = true
		tabBtn2.BackgroundColor3 = Color3.fromRGB(45, 60, 90)
		tabBtn2.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabBtn1.BackgroundColor3 = Color3.fromRGB(26, 32, 46)
		tabBtn1.TextColor3 = Color3.fromRGB(160, 175, 205)
	end
end

tabBtn1.MouseButton1Click:Connect(function() switchTab(1) end)
tabBtn2.MouseButton1Click:Connect(function() switchTab(2) end)

openModal = function(tabIndex: number?)
	switchTab(tabIndex or 1)
	modalBackdrop.Visible = true
end

backpackButton.MouseButton1Click:Connect(function()
	openModal(1)
end)

closeButton.MouseButton1Click:Connect(function()
	modalBackdrop.Visible = false
end)

-- ==================== CONTENU ONGLET 1 : DECK & INVENTAIRE ====================

-- Section Deck (Haut)
local deckSectionLbl = Instance.new("TextLabel")
deckSectionLbl.Size = UDim2.new(1, 0, 0, 20)
deckSectionLbl.Position = UDim2.new(0, 0, 0, 2)
deckSectionLbl.BackgroundTransparency = 1
deckSectionLbl.Text = "🎯 MON DECK ACTIF (10 SLOTS)"
deckSectionLbl.Font = Enum.Font.FredokaOne
deckSectionLbl.TextSize = 14
deckSectionLbl.TextColor3 = Color3.fromRGB(130, 185, 255)
deckSectionLbl.TextXAlignment = Enum.TextXAlignment.Left
deckSectionLbl.Parent = pageDeckInv

local modalDeckScroll = Instance.new("ScrollingFrame")
modalDeckScroll.Size = UDim2.new(1, 0, 0, 95)
modalDeckScroll.Position = UDim2.new(0, 0, 0, 24)
modalDeckScroll.BackgroundTransparency = 1
modalDeckScroll.ScrollBarThickness = 4
modalDeckScroll.CanvasSize = UDim2.new(0, 680, 0, 0)
modalDeckScroll.Parent = pageDeckInv

local deckListLayout = Instance.new("UIListLayout")
deckListLayout.FillDirection = Enum.FillDirection.Horizontal
deckListLayout.Padding = UDim.new(0, 8)
deckListLayout.SortOrder = Enum.SortOrder.LayoutOrder
deckListLayout.Parent = modalDeckScroll

type ModalDeckSlot = {
	frame: Frame,
	icon: Frame,
	title: TextLabel,
	stateLabel: TextLabel,
	unequipBtn: TextButton,
}
local modalDeckSlots: { [number]: ModalDeckSlot } = {}

for i = 1, 10 do
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = "DeckSlot_" .. i
	slotFrame.LayoutOrder = i
	slotFrame.Size = UDim2.new(0, 60, 0, 88)
	slotFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	slotFrame.Parent = modalDeckScroll

	local sfCorner = Instance.new("UICorner")
	sfCorner.CornerRadius = UDim.new(0, 8)
	sfCorner.Parent = slotFrame

	local sfStroke = Instance.new("UIStroke")
	sfStroke.Color = Color3.fromRGB(48, 56, 76)
	sfStroke.Thickness = 1
	sfStroke.Parent = slotFrame

	local slotNum = Instance.new("TextLabel")
	slotNum.Size = UDim2.new(1, 0, 0, 14)
	slotNum.Position = UDim2.new(0, 0, 0, 2)
	slotNum.BackgroundTransparency = 1
	slotNum.Text = "#" .. i
	slotNum.Font = Enum.Font.GothamBold
	slotNum.TextSize = 10
	slotNum.TextColor3 = Color3.fromRGB(180, 195, 215)
	slotNum.Parent = slotFrame

	local ballIcon = Instance.new("Frame")
	ballIcon.Name = "Icon"
	ballIcon.Size = UDim2.new(0, 20, 0, 20)
	ballIcon.AnchorPoint = Vector2.new(0.5, 0)
	ballIcon.Position = UDim2.new(0.5, 0, 0, 18)
	ballIcon.BackgroundColor3 = Color3.fromRGB(225, 228, 235)
	ballIcon.Parent = slotFrame

	local biCorner = Instance.new("UICorner")
	biCorner.CornerRadius = UDim.new(1, 0)
	biCorner.Parent = ballIcon

	local slotName = Instance.new("TextLabel")
	slotName.Name = "SlotName"
	slotName.Size = UDim2.new(1, 0, 0, 14)
	slotName.Position = UDim2.new(0, 0, 0, 42)
	slotName.BackgroundTransparency = 1
	slotName.Text = "Vide"
	slotName.Font = Enum.Font.GothamBold
	slotName.TextSize = 9
	slotName.TextColor3 = Color3.fromRGB(150, 160, 180)
	slotName.Parent = slotFrame

	local unequipBtn = Instance.new("TextButton")
	unequipBtn.Name = "UnequipBtn"
	unequipBtn.Size = UDim2.new(1, -8, 0, 20)
	unequipBtn.Position = UDim2.new(0, 4, 1, -24)
	unequipBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
	unequipBtn.Text = "Retirer"
	unequipBtn.Font = Enum.Font.GothamBold
	unequipBtn.TextSize = 9
	unequipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	unequipBtn.AutoButtonColor = true
	unequipBtn.Parent = slotFrame

	local ubCorner = Instance.new("UICorner")
	ubCorner.CornerRadius = UDim.new(0, 4)
	ubCorner.Parent = unequipBtn

	unequipBtn.MouseButton1Click:Connect(function()
		unequipBallEvent:FireServer(i)
	end)

	modalDeckSlots[i] = {
		frame = slotFrame,
		icon = ballIcon,
		title = slotName,
		stateLabel = slotNum,
		unequipBtn = unequipBtn,
	}
end

-- Section Inventaire / Stock (Bas)
local invSectionLbl = Instance.new("TextLabel")
invSectionLbl.Size = UDim2.new(1, 0, 0, 20)
invSectionLbl.Position = UDim2.new(0, 0, 0, 126)
invSectionLbl.BackgroundTransparency = 1
invSectionLbl.Text = "📦 BILLES EN RÉSERVE (STOCK D'INVENTAIRE)"
invSectionLbl.Font = Enum.Font.FredokaOne
invSectionLbl.TextSize = 14
invSectionLbl.TextColor3 = Color3.fromRGB(80, 235, 160)
invSectionLbl.TextXAlignment = Enum.TextXAlignment.Left
invSectionLbl.Parent = pageDeckInv

local invCardsContainer = Instance.new("Frame")
invCardsContainer.Size = UDim2.new(1, 0, 1, -150)
invCardsContainer.Position = UDim2.new(0, 0, 0, 150)
invCardsContainer.BackgroundTransparency = 1
invCardsContainer.Parent = pageDeckInv

local invGrid = Instance.new("UIGridLayout")
invGrid.CellSize = UDim2.new(0.25, -6, 1, 0)
invGrid.CellPadding = UDim2.new(0, 8, 0, 0)
invGrid.Parent = invCardsContainer

type InvCard = {
	stockLabel: TextLabel,
	equipBtn: TextButton,
}
local invCards: { [string]: InvCard } = {}

local BALL_TYPES_ORDER = { "Standard", "Slime", "Heavy", "Explosive" }

for _, bType in ipairs(BALL_TYPES_ORDER) do
	local style = BALL_STYLES[bType] or BALL_STYLES.Standard

	local card = Instance.new("Frame")
	card.Name = "InvCard_" .. bType
	card.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	card.Parent = invCardsContainer

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(45, 54, 75)
	cardStroke.Thickness = 1.5
	cardStroke.Parent = card

	local cIcon = Instance.new("Frame")
	cIcon.Size = UDim2.new(0, 36, 0, 36)
	cIcon.AnchorPoint = Vector2.new(0.5, 0)
	cIcon.Position = UDim2.new(0.5, 0, 0, 12)
	cIcon.BackgroundColor3 = style.readyColor
	cIcon.Parent = card

	local ciCorner = Instance.new("UICorner")
	ciCorner.CornerRadius = UDim.new(1, 0)
	ciCorner.Parent = cIcon

	local cTitle = Instance.new("TextLabel")
	cTitle.Size = UDim2.new(1, -8, 0, 18)
	cTitle.Position = UDim2.new(0, 4, 0, 52)
	cTitle.BackgroundTransparency = 1
	cTitle.Text = style.name .. " (T" .. style.tier .. ")"
	cTitle.Font = Enum.Font.FredokaOne
	cTitle.TextSize = 14
	cTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
	cTitle.Parent = card

	local cDesc = Instance.new("TextLabel")
	cDesc.Size = UDim2.new(1, -12, 0, 32)
	cDesc.Position = UDim2.new(0, 6, 0, 72)
	cDesc.BackgroundTransparency = 1
	cDesc.Text = style.desc
	cDesc.Font = Enum.Font.Gotham
	cDesc.TextSize = 10
	cDesc.TextColor3 = Color3.fromRGB(150, 160, 180)
	cDesc.TextWrapped = true
	cDesc.Parent = card

	local cStock = Instance.new("TextLabel")
	cStock.Name = "StockLabel"
	cStock.Size = UDim2.new(1, 0, 0, 22)
	cStock.Position = UDim2.new(0, 0, 0, 108)
	cStock.BackgroundTransparency = 1
	cStock.Text = "Stock: 0"
	cStock.Font = Enum.Font.FredokaOne
	cStock.TextSize = 15
	cStock.TextColor3 = Color3.fromRGB(80, 220, 255)
	cStock.Parent = card

	local equipBtn = Instance.new("TextButton")
	equipBtn.Name = "EquipButton"
	equipBtn.Size = UDim2.new(1, -16, 0, 32)
	equipBtn.AnchorPoint = Vector2.new(0.5, 1)
	equipBtn.Position = UDim2.new(0.5, 0, 1, -10)
	equipBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	equipBtn.Text = "Équiper"
	equipBtn.Font = Enum.Font.FredokaOne
	equipBtn.TextSize = 13
	equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	equipBtn.AutoButtonColor = true
	equipBtn.Parent = card

	local ebCorner = Instance.new("UICorner")
	ebCorner.CornerRadius = UDim.new(0, 6)
	ebCorner.Parent = equipBtn

	equipBtn.MouseButton1Click:Connect(function()
		equipBallEvent:FireServer(bType, nil)
	end)

	invCards[bType] = {
		stockLabel = cStock,
		equipBtn = equipBtn,
	}
end

-- ==================== CONTENU ONGLET 2 : ATELIER DE CRAFT & BOUTIQUE ====================

local shopListLayout = Instance.new("UIListLayout")
shopListLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopListLayout.Padding = UDim.new(0, 12)
shopListLayout.Parent = pageCraftShop

-- 1. Section Boutique Standard
local shopSectionLbl = Instance.new("TextLabel")
shopSectionLbl.Size = UDim2.new(1, 0, 0, 22)
shopSectionLbl.LayoutOrder = 1
shopSectionLbl.BackgroundTransparency = 1
shopSectionLbl.Text = "🛒 BOUTIQUE DE BASE (ACHAT DE BILLES STANDARDS)"
shopSectionLbl.Font = Enum.Font.FredokaOne
shopSectionLbl.TextSize = 14
shopSectionLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
shopSectionLbl.TextXAlignment = Enum.TextXAlignment.Left
shopSectionLbl.Parent = pageCraftShop

local shopCard = Instance.new("Frame")
shopCard.Size = UDim2.new(1, 0, 0, 64)
shopCard.LayoutOrder = 2
shopCard.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
shopCard.Parent = pageCraftShop

local scCorner = Instance.new("UICorner")
scCorner.CornerRadius = UDim.new(0, 10)
scCorner.Parent = shopCard

local scStroke = Instance.new("UIStroke")
scStroke.Color = Color3.fromRGB(50, 60, 85)
scStroke.Thickness = 1.5
scStroke.Parent = shopCard

local scIcon = Instance.new("Frame")
scIcon.Size = UDim2.new(0, 32, 0, 32)
scIcon.AnchorPoint = Vector2.new(0, 0.5)
scIcon.Position = UDim2.new(0, 16, 0.5, 0)
scIcon.BackgroundColor3 = Color3.fromRGB(225, 228, 235)
scIcon.Parent = shopCard

local sciCorner = Instance.new("UICorner")
sciCorner.CornerRadius = UDim.new(1, 0)
sciCorner.Parent = scIcon

local scTitle = Instance.new("TextLabel")
scTitle.Size = UDim2.new(0, 300, 0, 20)
scTitle.Position = UDim2.new(0, 60, 0, 12)
scTitle.BackgroundTransparency = 1
scTitle.Text = "Bille Standard (Tier 1)"
scTitle.Font = Enum.Font.FredokaOne
scTitle.TextSize = 15
scTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
scTitle.TextXAlignment = Enum.TextXAlignment.Left
scTitle.Parent = shopCard

local scDesc = Instance.new("TextLabel")
scDesc.Size = UDim2.new(0, 300, 0, 16)
scDesc.Position = UDim2.new(0, 60, 0, 34)
scDesc.BackgroundTransparency = 1
scDesc.Text = "Composant de base indispensable pour toutes les fusions."
scDesc.Font = Enum.Font.Gotham
scDesc.TextSize = 11
scDesc.TextColor3 = Color3.fromRGB(160, 175, 195)
scDesc.TextXAlignment = Enum.TextXAlignment.Left
scDesc.Parent = shopCard

local buyStdBtn = Instance.new("TextButton")
buyStdBtn.Size = UDim2.new(0, 160, 0, 38)
buyStdBtn.AnchorPoint = Vector2.new(1, 0.5)
buyStdBtn.Position = UDim2.new(1, -16, 0.5, 0)
buyStdBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
buyStdBtn.Text = "Acheter (10 🪙)"
buyStdBtn.Font = Enum.Font.FredokaOne
buyStdBtn.TextSize = 14
buyStdBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buyStdBtn.AutoButtonColor = true
buyStdBtn.Parent = shopCard

local bsbCorner = Instance.new("UICorner")
bsbCorner.CornerRadius = UDim.new(0, 8)
bsbCorner.Parent = buyStdBtn

buyStdBtn.MouseButton1Click:Connect(function()
	buyStandardEvent:FireServer()
end)

-- 2. Section Plans & Fusion
local craftSectionLbl = Instance.new("TextLabel")
craftSectionLbl.Size = UDim2.new(1, 0, 0, 22)
craftSectionLbl.LayoutOrder = 3
craftSectionLbl.BackgroundTransparency = 1
craftSectionLbl.Text = "🔨 ATELIER DE CRAFT & BLUEPRINTS (PLANS DE FABRICATION)"
craftSectionLbl.Font = Enum.Font.FredokaOne
craftSectionLbl.TextSize = 14
craftSectionLbl.TextColor3 = Color3.fromRGB(255, 140, 50)
craftSectionLbl.TextXAlignment = Enum.TextXAlignment.Left
craftSectionLbl.Parent = pageCraftShop

type CraftRowWidget = {
	blueprintBtn: TextButton,
	craftBtn: TextButton,
	recipeLabel: TextLabel,
	statusLabel: TextLabel,
}
local craftRows: { [string]: CraftRowWidget } = {}

local CRAFTABLE_BALLS = {
	{ type = "Slime", name = "Bille Slime (Tier 2)", cost = 500, recipeText = "5 Billes Standards" },
	{ type = "Heavy", name = "Bille Lourde (Tier 3)", cost = 2000, recipeText = "3 Slimes + 10 Standards" },
	{ type = "Explosive", name = "Bille Explosive (Tier 4)", cost = 8000, recipeText = "2 Lourdes + 5 Slimes + 20 Standards" },
}

for idx, item in ipairs(CRAFTABLE_BALLS) do
	local bType = item.type
	local style = BALL_STYLES[bType] or BALL_STYLES.Standard

	local row = Instance.new("Frame")
	row.Name = "CraftRow_" .. bType
	row.Size = UDim2.new(1, 0, 0, 82)
	row.LayoutOrder = 3 + idx
	row.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	row.Parent = pageCraftShop

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 10)
	rCorner.Parent = row

	local rStroke = Instance.new("UIStroke")
	rStroke.Color = Color3.fromRGB(50, 60, 85)
	rStroke.Thickness = 1.5
	rStroke.Parent = row

	local rIcon = Instance.new("Frame")
	rIcon.Size = UDim2.new(0, 36, 0, 36)
	rIcon.AnchorPoint = Vector2.new(0, 0.5)
	rIcon.Position = UDim2.new(0, 16, 0.5, 0)
	rIcon.BackgroundColor3 = style.readyColor
	rIcon.Parent = row

	local riCorner = Instance.new("UICorner")
	riCorner.CornerRadius = UDim.new(1, 0)
	riCorner.Parent = rIcon

	local rTitle = Instance.new("TextLabel")
	rTitle.Size = UDim2.new(0, 240, 0, 18)
	rTitle.Position = UDim2.new(0, 64, 0, 12)
	rTitle.BackgroundTransparency = 1
	rTitle.Text = item.name
	rTitle.Font = Enum.Font.FredokaOne
	rTitle.TextSize = 15
	rTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	rTitle.TextXAlignment = Enum.TextXAlignment.Left
	rTitle.Parent = row

	local rStatus = Instance.new("TextLabel")
	rStatus.Size = UDim2.new(0, 240, 0, 14)
	rStatus.Position = UDim2.new(0, 64, 0, 32)
	rStatus.BackgroundTransparency = 1
	rStatus.Text = "🔒 Plan non débloqué"
	rStatus.Font = Enum.Font.GothamBold
	rStatus.TextSize = 11
	rStatus.TextColor3 = Color3.fromRGB(240, 140, 60)
	rStatus.TextXAlignment = Enum.TextXAlignment.Left
	rStatus.Parent = row

	local rRecipe = Instance.new("TextLabel")
	rRecipe.Size = UDim2.new(0, 280, 0, 16)
	rRecipe.Position = UDim2.new(0, 64, 0, 50)
	rRecipe.BackgroundTransparency = 1
	rRecipe.Text = "Recette : " .. item.recipeText
	rRecipe.Font = Enum.Font.Gotham
	rRecipe.TextSize = 11
	rRecipe.TextColor3 = Color3.fromRGB(170, 185, 210)
	rRecipe.TextXAlignment = Enum.TextXAlignment.Left
	rRecipe.Parent = row

	-- Bouton Déblocage Plan
	local bpBtn = Instance.new("TextButton")
	bpBtn.Name = "UnlockBPBtn"
	bpBtn.Size = UDim2.new(0, 180, 0, 38)
	bpBtn.AnchorPoint = Vector2.new(1, 0.5)
	bpBtn.Position = UDim2.new(1, -16, 0.5, 0)
	bpBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
	bpBtn.Text = string.format("🔒 Plan (%d 🪙)", item.cost)
	bpBtn.Font = Enum.Font.FredokaOne
	bpBtn.TextSize = 13
	bpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	bpBtn.AutoButtonColor = true
	bpBtn.Parent = row

	local bpCorner2 = Instance.new("UICorner")
	bpCorner2.CornerRadius = UDim.new(0, 8)
	bpCorner2.Parent = bpBtn

	bpBtn.MouseButton1Click:Connect(function()
		unlockBlueprintEvent:FireServer(bType)
	end)

	-- Bouton Fabrication / Fusion
	local craftBtn = Instance.new("TextButton")
	craftBtn.Name = "CraftBallBtn"
	craftBtn.Size = UDim2.new(0, 180, 0, 38)
	craftBtn.AnchorPoint = Vector2.new(1, 0.5)
	craftBtn.Position = UDim2.new(1, -16, 0.5, 0)
	craftBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	craftBtn.Text = "✨ Fabriquer (+1)"
	craftBtn.Font = Enum.Font.FredokaOne
	craftBtn.TextSize = 14
	craftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	craftBtn.AutoButtonColor = true
	craftBtn.Visible = false
	craftBtn.Parent = row

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 8)
	cbCorner.Parent = craftBtn

	craftBtn.MouseButton1Click:Connect(function()
		craftBallEvent:FireServer(bType)
	end)

	craftRows[bType] = {
		blueprintBtn = bpBtn,
		craftBtn = craftBtn,
		recipeLabel = rRecipe,
		statusLabel = rStatus,
	}
end

-- ==================== LOGIQUE DE RAFRAÎCHISSEMENT GLOBAL UI ====================

local function refreshAllUI()
	modalCoins.Text = string.format("🪙 %d Pièces", currentCoins)

	-- 1. Rafraîchissement de la barre inférieure de Deck
	local equippedCount = 0
	for i = 1, 10 do
		updateSlotWidget(i, false)
		if currentDeck[i] ~= nil then
			equippedCount += 1
		end
	end

	-- 2. Rafraîchissement de la vue Deck dans le Modal
	for i = 1, 10 do
		local mSlot = modalDeckSlots[i]
		if mSlot then
			local dItem = currentDeck[i]
			local dState = currentSlotStates[i] or "Ready"
			if dItem and dItem.ballType then
				local style = BALL_STYLES[dItem.ballType] or BALL_STYLES.Standard
				mSlot.icon.Visible = true
				mSlot.icon.BackgroundColor3 = style.readyColor
				mSlot.title.Text = style.name
				mSlot.title.TextColor3 = Color3.fromRGB(240, 245, 255)

				if dState == "Ready" then
					mSlot.stateLabel.Text = "#" .. i .. " (Prêt)"
					mSlot.stateLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
					mSlot.unequipBtn.Visible = true
					mSlot.unequipBtn.Text = "Retirer"
					mSlot.unequipBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
				else
					mSlot.stateLabel.Text = "#" .. i .. " (En jeu)"
					mSlot.stateLabel.TextColor3 = Color3.fromRGB(240, 160, 40)
					mSlot.unequipBtn.Visible = false
				end
			else
				mSlot.icon.Visible = false
				mSlot.title.Text = "Vide"
				mSlot.title.TextColor3 = Color3.fromRGB(100, 115, 140)
				mSlot.stateLabel.Text = "#" .. i
				mSlot.stateLabel.TextColor3 = Color3.fromRGB(140, 150, 170)
				mSlot.unequipBtn.Visible = false
			end
		end
	end

	-- 3. Rafraîchissement des Cartes d'Inventaire (Stock & Bouton Équiper)
	local isDeckFull = (equippedCount >= 10)
	for _, bType in ipairs(BALL_TYPES_ORDER) do
		local card = invCards[bType]
		if card then
			local count = currentInventory[bType] or 0
			card.stockLabel.Text = string.format("Stock: %d", count)
			if count > 0 and not isDeckFull then
				card.equipBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
				card.equipBtn.Text = "Équiper"
				card.equipBtn.AutoButtonColor = true
			elseif count <= 0 then
				card.equipBtn.BackgroundColor3 = Color3.fromRGB(55, 60, 75)
				card.equipBtn.Text = "Épuisé (0)"
				card.equipBtn.AutoButtonColor = false
			else
				card.equipBtn.BackgroundColor3 = Color3.fromRGB(55, 60, 75)
				card.equipBtn.Text = "Deck Plein"
				card.equipBtn.AutoButtonColor = false
			end
		end
	end

	-- 4. Rafraîchissement des Lignes de Craft & Blueprints
	for _, item in ipairs(CRAFTABLE_BALLS) do
		local bType = item.type
		local row = craftRows[bType]
		if row then
			local hasBlueprint = currentBlueprints[bType] == true
			if hasBlueprint then
				row.statusLabel.Text = "✅ Plan débloqué"
				row.statusLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
				row.blueprintBtn.Visible = false
				row.craftBtn.Visible = true

				-- Vérification détaillée des ingrédients requis dans l'inventaire
				local canCraft = false
				if bType == "Slime" then
					local std = currentInventory.Standard or 0
					canCraft = (std >= 5)
					row.recipeLabel.Text = string.format("Ingrédients : %d/5 Standards", std)
					row.recipeLabel.TextColor3 = canCraft and Color3.fromRGB(80, 235, 120) or Color3.fromRGB(240, 85, 85)
				elseif bType == "Heavy" then
					local slm = currentInventory.Slime or 0
					local std = currentInventory.Standard or 0
					canCraft = (slm >= 3 and std >= 10)
					row.recipeLabel.Text = string.format("Ingrédients : %d/3 Slimes, %d/10 Standards", slm, std)
					row.recipeLabel.TextColor3 = canCraft and Color3.fromRGB(80, 235, 120) or Color3.fromRGB(240, 85, 85)
				elseif bType == "Explosive" then
					local hvy = currentInventory.Heavy or 0
					local slm = currentInventory.Slime or 0
					local std = currentInventory.Standard or 0
					canCraft = (hvy >= 2 and slm >= 5 and std >= 20)
					row.recipeLabel.Text = string.format("Ingrédients : %d/2 Lourdes, %d/5 Slimes, %d/20 Standards", hvy, slm, std)
					row.recipeLabel.TextColor3 = canCraft and Color3.fromRGB(80, 235, 120) or Color3.fromRGB(240, 85, 85)
				end

				if canCraft then
					row.craftBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
					row.craftBtn.Text = "✨ Fabriquer (+1)"
					row.craftBtn.AutoButtonColor = true
				else
					row.craftBtn.BackgroundColor3 = Color3.fromRGB(60, 68, 85)
					row.craftBtn.Text = "Manque Ingrédients"
					row.craftBtn.AutoButtonColor = false
				end
			else
				row.statusLabel.Text = "🔒 Plan non débloqué"
				row.statusLabel.TextColor3 = Color3.fromRGB(240, 140, 60)
				row.blueprintBtn.Visible = true
				row.craftBtn.Visible = false
				row.recipeLabel.Text = "Recette : " .. item.recipeText
				row.recipeLabel.TextColor3 = Color3.fromRGB(160, 175, 200)

				if currentCoins >= item.cost then
					row.blueprintBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
					row.blueprintBtn.AutoButtonColor = true
				else
					row.blueprintBtn.BackgroundColor3 = Color3.fromRGB(70, 75, 90)
					row.blueprintBtn.AutoButtonColor = false
				end
			end
		end
	end
end

-- Écoute des synchronisations réseau
inventorySyncEvent.OnClientEvent:Connect(function(data)
	if data and typeof(data) == "table" then
		if data.Inventory then
			currentInventory = data.Inventory
		end
		if data.Blueprints then
			currentBlueprints = data.Blueprints
		end
		if data.Coins ~= nil then
			currentCoins = data.Coins
		end
		refreshAllUI()
	end
end)

deckSyncEvent.OnClientEvent:Connect(function(deckData, slotStates)
	if deckData and typeof(deckData) == "table" then
		currentDeck = deckData
	end
	if slotStates and typeof(slotStates) == "table" then
		currentSlotStates = slotStates
	end
	refreshAllUI()
end)

slotStateChangedEvent.OnClientEvent:Connect(function(slotIndex: number, newState: string)
	if slotIndex and slotIndex >= 1 and slotIndex <= 10 then
		currentSlotStates[slotIndex] = newState
		updateSlotWidget(slotIndex, newState == "Ready")
		refreshAllUI()
	end
end)

feedbackEvent.OnClientEvent:Connect(function(success: boolean, message: string)
	showToast(success, message)
end)

-- Surveillance du solde via leaderstats
local function monitorLeaderstats(leaderstats: Folder)
	local coinsValue = leaderstats:WaitForChild("Pièces") :: IntValue
	local function updateUI(coins: number)
		currentCoins = coins
		modalCoins.Text = string.format("🪙 %d Pièces", coins)

		if coins < 10 then
			reliefButton.Visible = true
			dropButton.BackgroundColor3 = Color3.fromRGB(108, 122, 137)
			dropButton.Text = "Fonds insuffisants (10 🪙)"
			dropBtnStroke.Color = Color3.fromRGB(80, 90, 100)
		else
			reliefButton.Visible = false
			dropButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
			dropButton.Text = "LÂCHER UNE BILLE (-10)"
			dropBtnStroke.Color = Color3.fromRGB(39, 174, 96)
		end
		refreshAllUI()
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

-- ==================== EFFETS PARTICULAIRES & OUTLINES MULTIJOUEUR ====================

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

	-- Filtrage multijoueur : seuls nos propres gains apparaissent
	if data.ownerUserId ~= localPlayer.UserId then
		return
	end

	spawnEvaporationEffect(
		data.hitPosition,
		data.amountText or "+0",
		data.isPenalty == true,
		data.multiplier or 1
	)
end)

-- Décoration Multijoueur des Billes (Highlight Vert pour joueur, Rouge + Pseudo pour adversaires)
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

		local highlight = Instance.new("Highlight")
		highlight.Name = "PlinkoBallHighlight"
		highlight.Adornee = ball
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

		if isMyBall then
			highlight.OutlineColor = Color3.fromRGB(38, 168, 65)
		else
			highlight.OutlineColor = Color3.fromRGB(225, 45, 45)

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

print("[PlinkoChaos] 🎒 Client UI Phase 6 V2 initialisée (Deck 10 slots, Inventaire & Atelier de Crafting opérationnels).")
