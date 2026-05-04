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

local function waitForRequiredPart(name, recommendedSize)
	local warned = false

	while true do
		local part, path
		if WorkspaceUtil then
			part, path = WorkspaceUtil.Find(name, GameData.Spawn.SurfaceFolders, { SearchDescendants = false })
		else
			part = Workspace:FindFirstChild(name)
			path = "Workspace." .. name
		end
		if part and part:IsA("BasePart") then
			return part
		end

		if not warned then
			warn(
				"[SpawnManager] Missing "
					.. (path or ("Workspace." .. name))
					.. ". Create this Part manually in Roblox Studio. Recommended size: "
					.. tostring(recommendedSize.X)
					.. ", "
					.. tostring(recommendedSize.Y)
					.. ", "
					.. tostring(recommendedSize.Z)
					.. "."
			)
			warned = true
		end

		task.wait(5)
	end
end

task.spawn(function()
	waitForRequiredPart(GameData.Spawn.SurfaceName, GameData.World.SpawnSurface.Size)
end)
