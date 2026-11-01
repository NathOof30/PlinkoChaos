--!strict
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

-- Effet visuel et physique de détonation pour la Bille Explosive
local function triggerBallExplosion(ball: Part, profile: any)
	if ball:GetAttribute("HasExploded") == true then
		return
	end
	ball:SetAttribute("HasExploded", true)

	local position = ball.Position
	local radius = profile.ExplosionRadius or 7.5
	local baseForce = profile.ExplosionForce or 26.0

	-- 1. Son et Flash visuel d'explosion Roblox
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 0 -- 0 pour ne pas détruire les parts du plateau
	explosion.BlastPressure = 0 -- On gère l'impulsion physique manuellement
	explosion.Parent = workspace

	-- Son d'impact explosif
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://138090596"
	sound.Volume = 0.85
	sound.RollOffMaxDistance = 150
	sound.Parent = ball
	sound:Play()
	Debris:AddItem(sound, 3)

	-- Onde de choc visuelle (Anneau lumineux expansif)
	task.spawn(function()
		local shockwave = Instance.new("Part")
		shockwave.Name = "ExplosionShockwave"
		shockwave.Shape = Enum.PartType.Ball
		shockwave.Size = Vector3.new(0.5, 0.5, 0.5)
		shockwave.CFrame = CFrame.new(position)
		shockwave.Material = Enum.Material.Neon
		shockwave.Color = Color3.fromRGB(255, 120, 30)
		shockwave.Transparency = 0.2
		shockwave.CanCollide = false
		shockwave.Anchored = true
		shockwave.Parent = workspace

		local tween = TweenService:Create(
			shockwave,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = Vector3.new(radius * 1.8, radius * 1.8, radius * 1.8),
				Transparency = 1,
			}
		)
		tween:Play()
		tween.Completed:Connect(function()
			shockwave:Destroy()
		end)
	end)

	-- 2. Souffle physique centrifuge sur toutes les billes voisines
	local activeFolder = BallFactory.GetActiveFolder()
	local pushedCount = 0

	for _, other in ipairs(activeFolder:GetChildren()) do
		if other:IsA("BasePart") and other ~= ball and other:GetAttribute("Processed") ~= true then
			local delta = other.Position - position
			local dist = delta.Magnitude
			if dist <= radius and dist > 0.1 then
				-- Vecteur de propulsion principalement latéral et modéré en hauteur pour éviter les sorties par le haut
				local dirX = delta.X
				local dirY = delta.Y
				local len2D = math.sqrt(dirX * dirX + dirY * dirY)
				local unit2D = len2D > 0.05 and Vector2.new(dirX / len2D, dirY / len2D) or Vector2.new(math.random() > 0.5 and 1 or -1, 0)

				local pushDir = Vector3.new(unit2D.X * 0.95, math.clamp(unit2D.Y * 0.5, -0.2, 0.4), 0).Unit
				local falloff = math.clamp(1 - (dist / radius), 0.25, 1.0)
				-- Vitesse d'impulsion augmentée pour une dispersion violente et spectaculaire
				local targetVel = math.clamp(baseForce * falloff * 4.2, 50, 160)
				local impulse = pushDir * (targetVel * other.AssemblyMass)
				other:ApplyImpulse(impulse)
				pushedCount += 1
			end
		end
	end

	-- Impulsion de recul sur la bille explosive elle-même
	ball:ApplyImpulse(Vector3.new((math.random() - 0.5) * 35, -12, 0) * ball.AssemblyMass)

	-- 3. Mise à jour de l'apparence de la bille explosive (calcinée après explosion)
	ball.Material = Enum.Material.Slate
	ball.Color = Color3.fromRGB(55, 55, 60)
	local fuse = ball:FindFirstChild("FuseSparks")
	if fuse and fuse:IsA("ParticleEmitter") then
		fuse.Enabled = false
	end

	print(string.format("[PlinkoChaos] 💥 Bille Explosive a détoné ! (%d billes propulsées dans un rayon de %.1f studs)", pushedCount, radius))
end

-- Création d'une bille selon son type (Standard, Heavy, Explosive, Spring)
function BallFactory.CreateBall(ballType: string?, owner: Player?, xOffset: number?): Part
	local BoardConfig = getConfig()
	local center = BoardConfig.CenterPosition
	local height = BoardConfig.PlayableHeight
	local ballCfg = BoardConfig.Ball
	local pyramid = BoardConfig.Pyramid
	local slotH = BoardConfig.Slots.Height

	local selectedType = ballType or "Standard"
	local ballTypes = BoardConfig.BallTypes or {}
	local typeProfile = ballTypes[selectedType] or ballTypes.Standard or ballCfg

	local bottomY = center.Y - height / 2
	local slotTopY = bottomY + slotH
	local bottomPegY = slotTopY + 1.2
	local topPegY = bottomPegY + (pyramid.Rows - 1) * pyramid.VerticalSpacing

	local ball = Instance.new("Part")
	local ballId = HttpService:GenerateGUID(false)
	ball.Name = string.format("Ball_%s_%s", selectedType, string.sub(ballId, 1, 6))
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(ballCfg.Diameter, ballCfg.Diameter, ballCfg.Diameter)
	ball.Material = typeProfile.Material or Enum.Material.Metal
	ball.Color = typeProfile.Color or Color3.fromRGB(225, 228, 235)
	ball.Anchored = false
	ball.CanCollide = true
	ball.CanTouch = true

	-- Propriétés physiques spécifiques au type de bille
	local physProps = PhysicalProperties.new(
		typeProfile.Density or ballCfg.Density or 1.0,
		typeProfile.Friction or ballCfg.Friction or 0.2,
		typeProfile.Elasticity or ballCfg.Elasticity or 0.45,
		typeProfile.FrictionWeight or 1.0,
		typeProfile.ElasticityWeight or 1.0
	)
	ball.CustomPhysicalProperties = physProps

	-- Métadonnées de gameplay pour le cycle de vie et le multijoueur
	local ownerUserId = owner and owner.UserId or 0
	local ownerName = owner and (owner.DisplayName or owner.Name) or (ownerUserId == 0 and "Serveur" or string.format("Joueur_%d", ownerUserId))

	ball:SetAttribute("BallId", ballId)
	ball:SetAttribute("BallType", selectedType)
	ball:SetAttribute("OwnerUserId", ownerUserId)
	ball:SetAttribute("OwnerName", ownerName)
	ball:SetAttribute("BaseValue", ballCfg.BaseValue or 10)
	ball:SetAttribute("SpawnTime", os.clock())
	ball:SetAttribute("Processed", false)

	CollectionService:AddTag(ball, "PlinkoBall")

	-- 1. Spécificités visuelles et comportementales par type
	if selectedType == "Explosive" then
		-- Mèche crépitante (étincelles)
		local fuse = Instance.new("ParticleEmitter")
		fuse.Name = "FuseSparks"
		fuse.Texture = "rbxassetid://6071575925"
		fuse.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 100)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 20)),
		})
		fuse.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 0.05),
		})
		fuse.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 0.8),
		})
		fuse.Lifetime = NumberRange.new(0.2, 0.35)
		fuse.Rate = 20
		fuse.Speed = NumberRange.new(1.5, 3.5)
		fuse.SpreadAngle = Vector2.new(180, 180)
		fuse.Parent = ball

		-- Gestionnaire des 5 rebonds et clignotement progressif
		local bounceCount = 0
		local maxBounces = typeProfile.MaxBounces or 5
		local lastBounceTime = 0
		local blinkFrequency = 0 -- Hz (0 = pas de clignotement, augmente avec les rebonds)
		local isStrobeOn = false

		-- Boucle de clignotement dynamique qui s'accélère au fil des rebonds
		task.spawn(function()
			while ball and ball.Parent and ball:GetAttribute("HasExploded") ~= true do
				if blinkFrequency > 0 then
					isStrobeOn = not isStrobeOn
					if isStrobeOn then
						-- Flash jaune / blanc incandescent d'alerte
						ball.Color = Color3.fromRGB(255, 245, 80)
					else
						-- Retour couleur orange flamme
						ball.Color = typeProfile.Color
					end
					task.wait(0.5 / blinkFrequency)
				else
					task.wait(0.1)
				end
			end
		end)

		local touchConn: RBXScriptConnection? = nil
		touchConn = ball.Touched:Connect(function(hit)
			if ball:GetAttribute("HasExploded") == true then
				if touchConn then
					touchConn:Disconnect()
				end
				return
			end

			-- On ignore le contact avec la vitre avant de protection et le fond
			if hit.Name == "FrontGlass" or hit.Name == "Backboard" then
				return
			end

			local now = os.clock()
			if now - lastBounceTime < 0.08 then
				return -- Debounce pour compter les rebonds distincts
			end
			lastBounceTime = now

			bounceCount += 1
			ball:SetAttribute("BounceCount", bounceCount)

			-- Clignotement de plus en plus rapide et intensité de la mèche accrue
			if bounceCount < maxBounces then
				if bounceCount == 1 then
					blinkFrequency = 1.8 -- Pulsation d'alerte initiale
				elseif bounceCount == 2 then
					blinkFrequency = 3.5
				elseif bounceCount == 3 then
					blinkFrequency = 6.0
				elseif bounceCount >= 4 then
					blinkFrequency = 12.0 -- Stroboscope d'urgence imminente !
				end

				if fuse and fuse.Parent then
					fuse.Rate = 20 + bounceCount * 18
					fuse.Speed = NumberRange.new(2 + bounceCount * 0.8, 4 + bounceCount * 1.2)
				end
			else
				-- Détonation au 5ème rebond !
				if touchConn then
					touchConn:Disconnect()
				end
				triggerBallExplosion(ball, typeProfile)
			end
		end)

	elseif selectedType == "Slime" or selectedType == "Spring" then
		-- Bille Slime : aura visqueuse et bulles bondissantes
		local trailPart = Instance.new("ParticleEmitter")
		trailPart.Name = "SlimeBubbles"
		trailPart.Texture = "rbxassetid://6071575925"
		trailPart.Color = ColorSequence.new(Color3.fromRGB(80, 255, 60))
		trailPart.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0.05),
		})
		trailPart.Lifetime = NumberRange.new(0.25, 0.5)
		trailPart.Rate = 16
		trailPart.Speed = NumberRange.new(0.5, 2.0)
		trailPart.SpreadAngle = Vector2.new(180, 180)
		trailPart.Parent = ball

	elseif selectedType == "Heavy" then
		-- Bille lourde : teinte sombre et imposante
		ball.Color = typeProfile.Color or Color3.fromRGB(48, 52, 60)
	end

	-- Positionnement d'apparition
	local offset = xOffset or ballCfg.DefaultSpawnOffset or 0.5
	local spawnY = topPegY + 4.5
	local spawnX = center.X + offset
	ball.CFrame = CFrame.new(spawnX, spawnY, center.Z)

	ball.Parent = BallFactory.GetActiveFolder()

	-- Le serveur garde impérativement le contrôle physique universel
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)

	return ball
end

-- Wrapper de rétrocompatibilité
function BallFactory.CreateStandardBall(owner: Player?, xOffset: number?): Part
	return BallFactory.CreateBall("Standard", owner, xOffset)
end

return BallFactory

