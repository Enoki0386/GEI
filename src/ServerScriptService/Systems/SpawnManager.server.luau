local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. SpawnManager stopped.")
	return
end

local GameData = require(gameDataModule)
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local workspaceUtilModule = sharedFolder and sharedFolder:WaitForChild("WorkspaceUtil", 10)
local WorkspaceUtil = workspaceUtilModule and require(workspaceUtilModule)

local function getMainBasePart(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	local main = instance:FindFirstChild("Main", true)
	if main and main:IsA("BasePart") then
		return main
	end
	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function waitForRequiredPart(name, recommendedSize)
	local warned = false

	while true do
		local found, path
		if WorkspaceUtil then
			found, path = WorkspaceUtil.Find(name, GameData.Spawn.SurfaceFolders, { SearchDescendants = true })
		else
			found = Workspace:FindFirstChild(name, true)
			path = found and found:GetFullName() or ("Workspace." .. name)
		end

		local part = getMainBasePart(found)
		if part then
			return part
		end

		if not warned then
			warn("[SpawnManager] Missing or invalid " .. tostring(path or name) .. ". WasteNodeManager can create an emergency fallback, but you should keep a BasePart named " .. name .. ". Recommended size: " .. tostring(recommendedSize.X) .. ", " .. tostring(recommendedSize.Y) .. ", " .. tostring(recommendedSize.Z) .. ".")
			warned = true
		end

		task.wait(5)
	end
end

task.spawn(function()
	waitForRequiredPart(GameData.Spawn.SurfaceName, GameData.World.SpawnSurface.Size)
end)
