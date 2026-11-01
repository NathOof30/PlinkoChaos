--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local configModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoardConfig")
local function getConfig()
	local ok, res = pcall(require, configModule)
	if ok and res and res.Crafting then
		return res
	end
	local fn = loadstring((configModule :: ModuleScript).Source)
	return fn()
end

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local CraftingService = {}
local isInitialized = false

function CraftingService.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	local buyStandardEvent = Network.GetRemoteEvent("RequestBuyStandard")
	local unlockBlueprintEvent = Network.GetRemoteEvent("RequestUnlockBlueprint")
	local craftBallEvent = Network.GetRemoteEvent("RequestCraftBall")
	local equipBallEvent = Network.GetRemoteEvent("RequestEquipBall")
	local unequipBallEvent = Network.GetRemoteEvent("RequestUnequipBall")
	local feedbackEvent = Network.GetRemoteEvent("InventoryFeedback")

	-- 1. Achat d'une bille Standard (10 Pièces)
	buyStandardEvent.OnServerEvent:Connect(function(player: Player)
		local BoardConfig = getConfig()
		local cost = (BoardConfig.Economy and BoardConfig.Economy.StandardBallCost) or 10

		if not PlayerDataService.HasEnoughCoins(player, cost) then
			local current = PlayerDataService.GetCoins(player)
			feedbackEvent:FireClient(player, false, string.format("Fonds insuffisants ! (%d/%d pièces)", current, cost))
			return
		end

		local removed = PlayerDataService.RemoveCoins(player, cost)
		if removed then
			PlayerDataService.AddInventory(player, "Standard", 1)
			feedbackEvent:FireClient(player, true, "Achat réussi : +1 Bille Standard en stock !")
			print(string.format("[PlinkoChaos] 🛒 %s a acheté 1 Bille Standard (-%d pièces)", player.Name, cost))
		end
	end)

	-- 2. Déblocage unique d'un plan de fabrication (Blueprint)
	unlockBlueprintEvent.OnServerEvent:Connect(function(player: Player, blueprintId: any)
		if typeof(blueprintId) ~= "string" then
			return
		end

		local success, msg = PlayerDataService.UnlockBlueprint(player, blueprintId)
		feedbackEvent:FireClient(player, success, msg)
		if success then
			print(string.format("[PlinkoChaos] 📜 %s a débloqué le plan : %s", player.Name, blueprintId))
		end
	end)

	-- 3. Fusion & Fabrication d'une bille spéciale (Sink d'inventaire)
	craftBallEvent.OnServerEvent:Connect(function(player: Player, targetBallType: any)
		if typeof(targetBallType) ~= "string" then
			return
		end

		local BoardConfig = getConfig()
		local craftingCfg = BoardConfig.Crafting or {}
		local recipes = craftingCfg.Recipes or {}
		local recipe = recipes[targetBallType]

		if not recipe then
			feedbackEvent:FireClient(player, false, "Aucune recette existante pour cette bille.")
			return
		end

		-- Sécurité 1 : Vérifier la possession du Blueprint
		local blueprints = PlayerDataService.GetBlueprints(player)
		if not blueprints or blueprints[targetBallType] ~= true then
			feedbackEvent:FireClient(player, false, "Tu dois d'abord débloquer le Plan de fabrication !")
			return
		end

		-- Sécurité 2 : Vérifier les ingrédients EXCLUSIVEMENT dans l'Inventaire (le Deck est sanctuarisé)
		local inventory = PlayerDataService.GetInventory(player)
		if not inventory then
			feedbackEvent:FireClient(player, false, "Erreur d'accès à ton inventaire.")
			return
		end

		for ingType, reqQty in pairs(recipe) do
			local currentQty = inventory[ingType] or 0
			if currentQty < reqQty then
				feedbackEvent:FireClient(
					player,
					false,
					string.format("Ingrédients manquants ! Il te faut %d %s (tu en as %d en stock).", reqQty, ingType, currentQty)
				)
				return
			end
		end

		-- Exécution de la fusion : consommation définitive des ingrédients en stock
		for ingType, reqQty in pairs(recipe) do
			PlayerDataService.RemoveInventory(player, ingType, reqQty)
		end

		-- Ajout de la nouvelle bille fabriquée dans l'inventaire
		PlayerDataService.AddInventory(player, targetBallType, 1)

		local targetName = (craftingCfg.Blueprints and craftingCfg.Blueprints[targetBallType] and craftingCfg.Blueprints[targetBallType].Name) or targetBallType
		feedbackEvent:FireClient(player, true, string.format("✨ Fabrication réussie : +1 %s !", targetName))
		print(string.format("[PlinkoChaos] 🔨 %s a fabriqué 1 %s avec succès !", player.Name, targetBallType))
	end)

	-- 4. Équipement d'une bille de l'Inventaire vers le Deck
	equipBallEvent.OnServerEvent:Connect(function(player: Player, ballType: any, targetSlot: any)
		if typeof(ballType) ~= "string" then
			return
		end

		local slotNum: number? = nil
		if typeof(targetSlot) == "number" then
			slotNum = targetSlot
		end

		local success, msg = PlayerDataService.EquipBall(player, ballType, slotNum)
		feedbackEvent:FireClient(player, success, msg)
	end)

	-- 5. Déséquipement d'une bille du Deck vers l'Inventaire
	unequipBallEvent.OnServerEvent:Connect(function(player: Player, slotIndex: any)
		if typeof(slotIndex) ~= "number" then
			return
		end

		local success, msg = PlayerDataService.UnequipBall(player, slotIndex)
		feedbackEvent:FireClient(player, success, msg)
	end)

	print("[PlinkoChaos] 🔨 CraftingService initialisé (Boutique, Blueprints, Craft sécurisé & Gestion Deck).")
end

return CraftingService

