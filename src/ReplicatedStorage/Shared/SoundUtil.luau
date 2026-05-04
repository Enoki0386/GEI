local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundUtil = {}
local SOUND_ALIASES = {
	WasteHit = "Hit",
	WasteBreak = "Break",
}
local SOUND_COOLDOWNS = {
	Hit = 0.08,
	Break = 0.12,
	Sell = 0.35,
	Error = 0.4,
	Coin = 0.25,
}
local lastPlayedAt = {}

local function isUsableSoundId(soundId)
	return type(soundId) == "string"
		and soundId ~= ""
		and soundId ~= "0"
		and soundId ~= "rbxassetid://0"
end

local function getConfiguredSoundId(soundName, gameData)
	local soundsConfig = gameData and gameData.Sounds
	local soundId = type(soundsConfig) == "table" and soundsConfig[soundName] or nil
	if isUsableSoundId(soundId) then
		return soundId
	end

	local aliasName = SOUND_ALIASES[soundName]
	soundId = aliasName and type(soundsConfig) == "table" and soundsConfig[aliasName] or nil
	if isUsableSoundId(soundId) then
		return soundId
	end

	return nil
end

local function getSoundAsset(soundName)
	local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
	local source = soundsFolder and soundsFolder:FindFirstChild(soundName)
	if source and source:IsA("Sound") and isUsableSoundId(source.SoundId) then
		return source
	end

	local aliasName = SOUND_ALIASES[soundName]
	source = aliasName and soundsFolder and soundsFolder:FindFirstChild(aliasName) or nil
	if source and source:IsA("Sound") and isUsableSoundId(source.SoundId) then
		return source
	end

	return nil
end

local function getCanonicalSoundName(soundName)
	return SOUND_ALIASES[soundName] or soundName
end

local function canPlay(soundName)
	local canonicalName = getCanonicalSoundName(soundName)
	local cooldown = SOUND_COOLDOWNS[canonicalName] or 0
	if cooldown <= 0 then
		return true
	end

	local now = os.clock()
	local lastPlayed = lastPlayedAt[canonicalName] or 0
	if now - lastPlayed < cooldown then
		return false
	end

	lastPlayedAt[canonicalName] = now
	return true
end

function SoundUtil.Play(soundName, gameData, parent, volume)
	if type(soundName) ~= "string" or soundName == "" or not canPlay(soundName) then
		return nil
	end

	local source = getSoundAsset(soundName)
	local sound = nil

	if source then
		sound = source:Clone()
	else
		local soundId = getConfiguredSoundId(soundName, gameData)
		if not soundId then
			return nil
		end

		sound = Instance.new("Sound")
		sound.SoundId = soundId
	end

	if type(volume) == "number" then
		sound.Volume = volume
	end

	sound.Parent = parent or ReplicatedStorage
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength, 1) + 0.5)
	return sound
end

return SoundUtil
