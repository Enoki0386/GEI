local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[MapValidator] Missing ReplicatedStorage.GameData. Map validation stopped.")
	return
end

local GameData = require(gameDataModule)
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local workspaceUtilModule = sharedFolder and sharedFolder:WaitForChild("WorkspaceUtil", 10)
local WorkspaceUtil = workspaceUtilModule and require(workspaceUtilModule)

local REQUIREMENTS = {
	{
		Path = "Workspace.LobbyFloor",
		Name = "LobbyFloor",
		ExpectedClass = "BasePart",
		Instruction = "Create a Part named LobbyFloor.",
		RecommendedSize = GameData.World.LobbyFloor.Size,
	},
	{
		Path = "Workspace.SpawnSurfaces.SpawnSurface1 or Workspace.SpawnSurface1",
		Name = GameData.Spawn.SurfaceName,
		FolderPaths = GameData.Spawn.SurfaceFolders,
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

local OPTIONAL_REQUIREMENTS = {
	{ Name = "EggPlaza" },
	{ Name = "EggHatcher", FolderPaths = { "EggPlaza" } },
	{ Name = "VIPZone", FolderPaths = { "Areas" } },
	{ Name = "Zone2Barrier", FolderPaths = { "Barriers" } },
	{ Name = "ZoneMachineBarrier", FolderPaths = { "Barriers" } },
	{ Name = "Zone3Barrier", FolderPaths = { "Barriers" } },
	{ Name = "Zone4Barrier", FolderPaths = { "Barriers" } },
	{ Name = "Zone5Barrier", FolderPaths = { "Barriers" } },
	{ Name = "SpawnSurface2", FolderPaths = { "SpawnSurfaces" } },
	{ Name = "SpawnSurface3", FolderPaths = { "SpawnSurfaces" } },
	{ Name = "SpawnSurface4", FolderPaths = { "SpawnSurfaces" } },
	{ Name = "MachineArea" },
	{ Name = "Recycler", FolderPaths = { "MachineArea" } },
	{ Name = "Crusher", FolderPaths = { "MachineArea" } },
	{ Name = "Compressor", FolderPaths = { "MachineArea" } },
	{ Name = "Sorter", FolderPaths = { "MachineArea" } },
	{ Name = "UpgradeShop2", FolderPaths = { "Areas" } },
	{ Name = "BossWasteArea", FolderPaths = { "Areas" } },
	{ Name = "PortalDimension2", FolderPaths = { "Areas" } },
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
	local instance, foundPath
	if WorkspaceUtil then
		instance, foundPath = WorkspaceUtil.Find(requirement.Name, requirement.FolderPaths, { SearchDescendants = false })
	else
		instance = Workspace:FindFirstChild(requirement.Name)
		foundPath = requirement.Path
	end
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
				.. ". Found: "
				.. tostring(foundPath or requirement.Path)
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

	local missingOptional = {}
	for _, optional in ipairs(OPTIONAL_REQUIREMENTS) do
		local instance = nil
		if WorkspaceUtil then
			instance = WorkspaceUtil.Find(optional.Name, optional.FolderPaths, { SearchDescendants = false })
		else
			instance = Workspace:FindFirstChild(optional.Name)
		end
		if not instance then
			table.insert(missingOptional, optional.Name)
		end
	end
	if #missingOptional > 0 then
		warnOnce("[MapValidator] Optional future map objects missing: " .. table.concat(missingOptional, ", ") .. ". This is OK until those features are enabled.")
	end

	if validCount == #REQUIREMENTS then
		print("[MapValidator] Manual map setup looks ready.")
	else
		warnOnce("[MapValidator] Manual map setup is incomplete. See README.md > Manual Roblox Studio Setup.")
	end
end

validateMap()

Workspace.DescendantAdded:Connect(function(child)
	for _, requirement in ipairs(REQUIREMENTS) do
		if child.Name == requirement.Name then
			task.defer(validateMap)
			return
		end
	end
end)
