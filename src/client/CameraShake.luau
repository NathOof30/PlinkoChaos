--!strict
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraShake = {}

local currentCamera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

type ShakeState = {
	intensity: number,
	duration: number,
	startTime: number,
	frequency: number,
}

local activeShakes: { ShakeState } = {}
local renderConnection: RBXScriptConnection? = nil
local lastOffset = CFrame.new()

local function update(dt: number)
	currentCamera = Workspace.CurrentCamera or currentCamera
	if not currentCamera then
		return
	end

	-- Nettoyer le décalage de la frame précédente
	currentCamera.CFrame = currentCamera.CFrame * lastOffset:Inverse()

	local now = os.clock()
	local totalOffsetX = 0
	local totalOffsetY = 0
	local totalRotZ = 0

	for i = #activeShakes, 1, -1 do
		local shake = activeShakes[i]
		local elapsed = now - shake.startTime
		local progress = elapsed / shake.duration

		if progress >= 1 then
			table.remove(activeShakes, i)
		else
			-- Amortissement doux non-linéaire (decay exponentiel)
			local damp = (1 - progress) * (1 - progress)
			local phase = elapsed * shake.frequency
			local amp = shake.intensity * damp

			local ox = math.sin(phase * 1.3) * amp
			local oy = math.cos(phase * 1.7) * amp
			local rz = math.sin(phase * 0.9) * (amp * 0.015)

			totalOffsetX += ox
			totalOffsetY += oy
			totalRotZ += rz
		end
	end

	if #activeShakes == 0 then
		lastOffset = CFrame.new()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		return
	end

	lastOffset = CFrame.new(totalOffsetX, totalOffsetY, 0) * CFrame.Angles(0, 0, totalRotZ)
	currentCamera.CFrame = currentCamera.CFrame * lastOffset
end

function CameraShake.Shake(intensity: number, duration: number, frequency: number?)
	local shake: ShakeState = {
		intensity = math.clamp(intensity, 0.05, 0.35),
		duration = math.clamp(duration, 0.08, 0.40),
		startTime = os.clock(),
		frequency = frequency or 24,
	}
	table.insert(activeShakes, shake)

	if not renderConnection then
		renderConnection = RunService.RenderStepped:Connect(update)
	end
end

-- Secousse brève et viscérale pour l'explosion de bille
function CameraShake.Explosion()
	CameraShake.Shake(0.24, 0.18, 28)
end

-- Secousse subtile et rythmée lors du Jackpot x10
function CameraShake.Jackpot()
	CameraShake.Shake(0.18, 0.25, 20)
end

return CameraShake

