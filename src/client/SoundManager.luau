--!strict
local SoundService = game:GetService("SoundService")

local SoundManager = {}

local soundsFolder: Folder? = nil

local ASSETS = {
	PegHit = "rbxassetid://138567614125924",
	CoinCollect = "rbxassetid://135483737426662",
	CoinClinking = "rbxassetid://133570405319995",
	JackpotCash = "rbxassetid://101396758527961",
	ChimeReward = "rbxassetid://9116394545",
	ButtonClick = "rbxassetid://88442833509532",
	Explosion = "rbxassetid://138090596",
}

-- Pool de voix audio pour les percussions sur clous (anti-latence et anti-fuite mémoire)
local PEG_POOL_SIZE = 8
local pegPool: { Sound } = {}
local pegPoolIndex = 1
local lastPegHitTime = 0
local PEG_THROTTLE_INTERVAL = 0.032 -- ~30 sons/sec max pour éviter toute saturation sonore

function SoundManager.Init()
	if soundsFolder then
		return
	end

	local folder = SoundService:FindFirstChild("PlinkoSounds") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlinkoSounds"
		folder.Parent = SoundService
	end
	soundsFolder = folder

	-- Initialisation du pool de sons pour les clous
	for i = 1, PEG_POOL_SIZE do
		local s = Instance.new("Sound")
		s.Name = "PegSound_" .. i
		s.SoundId = ASSETS.PegHit
		s.Volume = 0.28
		s.RollOffMaxDistance = 120
		s.Parent = folder
		table.insert(pegPool, s)
	end
end

-- Percussion sur un clou avec Pitch Shifting dynamique (Casino Moderne)
function SoundManager.PlayPegHit(position: Vector3?)
	SoundManager.Init()
	local now = os.clock()
	if now - lastPegHitTime < PEG_THROTTLE_INTERVAL then
		return
	end
	lastPegHitTime = now

	local sound = pegPool[pegPoolIndex]
	if sound then
		pegPoolIndex = (pegPoolIndex % PEG_POOL_SIZE) + 1

		-- Variation dynamique de pitch entre 0.92 et 1.28
		local pitch = math.random(92, 128) / 100
		sound.PlaybackSpeed = pitch
		sound.Volume = 0.26 + math.random() * 0.08
		sound:Play()
	end
end

-- Son gratifiant à l'arrivée dans un bac
function SoundManager.PlaySlotOutcome(multiplier: number, isPenalty: boolean, position: Vector3?)
	SoundManager.Init()
	if not soundsFolder then
		return
	end

	if isPenalty then
		-- Bac piège x0.5 : tap mat / discret
		local s = Instance.new("Sound")
		s.SoundId = ASSETS.ButtonClick
		s.Volume = 0.45
		s.PlaybackSpeed = 0.65 -- Son plus grave et mat
		s.Parent = soundsFolder
		s:Play()
		game:GetService("Debris"):AddItem(s, 1.5)
	elseif multiplier >= 10 then
		-- JACKPOT x10 : Caisse enregistreuse + Carillon triomphal
		local cash = Instance.new("Sound")
		cash.SoundId = ASSETS.JackpotCash
		cash.Volume = 0.85
		cash.PlaybackSpeed = 1.0
		cash.Parent = soundsFolder
		cash:Play()
		game:GetService("Debris"):AddItem(cash, 3.5)

		task.delay(0.12, function()
			if soundsFolder then
				local fanfare = Instance.new("Sound")
				fanfare.SoundId = ASSETS.ChimeReward
				fanfare.Volume = 0.70
				fanfare.PlaybackSpeed = 1.05
				fanfare.Parent = soundsFolder
				fanfare:Play()
				game:GetService("Debris"):AddItem(fanfare, 3.5)
			end
		end)
	elseif multiplier >= 2 then
		-- Bac x2 : Carillon joyeux de pièces qui s'entrechoquent
		local s = Instance.new("Sound")
		s.SoundId = ASSETS.CoinClinking
		s.Volume = 0.55
		s.PlaybackSpeed = 1.08
		s.Parent = soundsFolder
		s:Play()
		game:GetService("Debris"):AddItem(s, 2.0)
	else
		-- Bac x1 : Tintement simple et net de pièce
		local s = Instance.new("Sound")
		s.SoundId = ASSETS.CoinCollect
		s.Volume = 0.45
		s.PlaybackSpeed = 1.0 + (math.random() - 0.5) * 0.1
		s.Parent = soundsFolder
		s:Play()
		game:GetService("Debris"):AddItem(s, 2.0)
	end
end

-- Bruitages Interface Utilisateur
function SoundManager.PlayButtonClick()
	SoundManager.Init()
	if not soundsFolder then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = ASSETS.ButtonClick
	s.Volume = 0.35
	s.PlaybackSpeed = 1.05 + (math.random() - 0.5) * 0.08
	s.Parent = soundsFolder
	s:Play()
	game:GetService("Debris"):AddItem(s, 1.0)
end

function SoundManager.PlayCraftSuccess()
	SoundManager.Init()
	if not soundsFolder then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = ASSETS.ChimeReward
	s.Volume = 0.65
	s.PlaybackSpeed = 1.15
	s.Parent = soundsFolder
	s:Play()
	game:GetService("Debris"):AddItem(s, 2.5)
end

function SoundManager.PlayDeckSlotPop()
	SoundManager.Init()
	if not soundsFolder then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = ASSETS.ButtonClick
	s.Volume = 0.28
	s.PlaybackSpeed = 1.55 + (math.random() - 0.5) * 0.1
	s.Parent = soundsFolder
	s:Play()
	game:GetService("Debris"):AddItem(s, 0.8)
end

return SoundManager
