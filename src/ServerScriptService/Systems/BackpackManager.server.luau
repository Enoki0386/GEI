local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. BackpackManager stopped.")
	return
end

local GameData = require(gameDataModule)

_G.GEI = _G.GEI or {}

local function waitForDataFolder(player)
	local dataFolder = player:FindFirstChild("PlayerData")
	local startTime = os.clock()

	while not dataFolder and os.clock() - startTime < 10 do
		task.wait(0.1)
		dataFolder = player:FindFirstChild("PlayerData")
	end

	return dataFolder
end

local function getBackTorso(character)
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function attachBackpack(player)
	local character = player.Character
	if not character then
		return
	end

	local torso = getBackTorso(character)
	if not torso then
		return
	end

	local dataFolder = waitForDataFolder(player)
	local equippedBackpack = dataFolder and dataFolder:FindFirstChild("EquippedBackpack")
	local backpackConfig = equippedBackpack and GameData.GetBackpack(equippedBackpack.Value) or GameData.GetBackpack("SmallBag")
	if not backpackConfig then
		return
	end

	local oldBackpack = character:FindFirstChild("GEIBackpack")
	if oldBackpack then
		oldBackpack:Destroy()
	end

	-- Replace this simple part later with a Toolbox model by welding the model to the same torso.
	local backpackPart = Instance.new("Part")
	backpackPart.Name = "GEIBackpack"
	backpackPart.CanCollide = false
	backpackPart.CanTouch = false
	backpackPart.Color = backpackConfig.Color
	backpackPart.Massless = true
	backpackPart.Material = Enum.Material.SmoothPlastic
	backpackPart.Size = backpackConfig.Size
	backpackPart.CFrame = torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2 + backpackConfig.Size.Z / 2)
	backpackPart.Parent = character

	local weld = Instance.new("Weld")
	weld.Name = "GEIBackpackWeld"
	weld.Part0 = torso
	weld.Part1 = backpackPart
	weld.C0 = CFrame.new(0, 0, torso.Size.Z / 2 + backpackConfig.Size.Z / 2)
	weld.Parent = backpackPart
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		attachBackpack(player)
	end)

	if player.Character then
		task.defer(attachBackpack, player)
	end

	task.spawn(function()
		local dataFolder = waitForDataFolder(player)
		local equippedBackpack = dataFolder and dataFolder:FindFirstChild("EquippedBackpack")
		if equippedBackpack then
			equippedBackpack.Changed:Connect(function()
				attachBackpack(player)
			end)
		end
	end)
end

_G.GEI.BackpackManager = {
	Attach = attachBackpack,
}

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(watchPlayer, player)
end
