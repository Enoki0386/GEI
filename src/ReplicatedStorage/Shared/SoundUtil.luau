local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundUtil = {}

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

	return nil
end

local function getSoundAsset(soundName)
	local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
	local source = soundsFolder and soundsFolder:FindFirstChild(soundName)
	if source and source:IsA("Sound") and isUsableSoundId(source.SoundId) then
		return source
	end

	return nil
end

function SoundUtil.Play(soundName, gameData, parent, volume)
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
