local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[MapValidator] Missing ReplicatedStorage.GameData. Map validation stopped.")
	return
end

local GameData = require(gameDataModule)

local REQUIREMENTS = {
	{
		Path = "Workspace.LobbyFloor",
		Name = "LobbyFloor",
		ExpectedClass = "BasePart",
		Instruction = "Create a Part named LobbyFloor.",
		RecommendedSize = GameData.World.LobbyFloor.Size,
	},
	{
		Path = "Workspace.SpawnSurface1",
		Name = GameData.Spawn.SurfaceName,
		ExpectedClass = "BasePart",
		Instruction = "Create a Part named SpawnSurface1.",
		RecommendedSize = GameData.World.SpawnSurface.Size,
	},
	{
		Path = "Workspace.SellZone",
		Name = "SellZone",
		ExpectedClass = "BasePart",
		Instruction = "Create a Part named SellZone.",
		RecommendedSize = GameData.World.SellZone.Size,
	},
	{
		Path = "Workspace.BuyZone",
		Name = "BuyZone",
		ExpectedClass = "BasePart",
		Instruction = "Create a Part named BuyZone.",
		RecommendedSize = GameData.World.BuyZone.Size,
	},
	{
		Path = "Workspace.SpawnLocation",
		Name = "SpawnLocation",
		ExpectedClass = "SpawnLocation",
		Instruction = "Insert a SpawnLocation and name it SpawnLocation.",
		RecommendedSize = Vector3.new(8, 1, 8),
	},
	{
		Path = "Workspace.WasteZone",
		Name = GameData.Spawn.WasteZoneName,
		ExpectedClass = "Folder",
		Instruction = "Create a Folder named WasteZone in Workspace.",
	},
}

local warnedMessages = {}

local function vectorToText(vector)
	if not vector then
		return nil
	end

	return string.format("%d, %d, %d", vector.X, vector.Y, vector.Z)
end

local function warnOnce(message)
	if warnedMessages[message] then
		return
	end

	warnedMessages[message] = true
	warn(message)
end

local function getTypeText(requirement)
	if requirement.ExpectedClass == "BasePart" then
		return "a BasePart"
	end

	return "a " .. requirement.ExpectedClass
end

local function validateRequirement(requirement)
	local instance = Workspace:FindFirstChild(requirement.Name)
	if not instance then
		local sizeText = vectorToText(requirement.RecommendedSize)
		local message = "[MapValidator] Missing " .. requirement.Path .. ". " .. requirement.Instruction
		if sizeText then
			message ..= " Recommended size: " .. sizeText .. "."
		end
		warnOnce(message)
		return false
	end

	local isValid = false
	if requirement.ExpectedClass == "BasePart" then
		isValid = instance:IsA("BasePart")
	else
		isValid = instance.ClassName == requirement.ExpectedClass
	end

	if not isValid then
		warnOnce(
			"[MapValidator] "
				.. requirement.Path
				.. " exists but must be "
				.. getTypeText(requirement)
				.. ". Rename or replace it in Roblox Studio."
		)
		return false
	end

	return true
end

local function validateMap()
	local validCount = 0
	for _, requirement in ipairs(REQUIREMENTS) do
		if validateRequirement(requirement) then
			validCount += 1
		end
	end

	if validCount == #REQUIREMENTS then
		print("[MapValidator] Manual map setup looks ready.")
	else
		warnOnce("[MapValidator] Manual map setup is incomplete. See README.md > Manual Roblox Studio Setup.")
	end
end

validateMap()

Workspace.ChildAdded:Connect(function(child)
	for _, requirement in ipairs(REQUIREMENTS) do
		if child.Name == requirement.Name then
			task.defer(validateMap)
			return
		end
	end
end)
