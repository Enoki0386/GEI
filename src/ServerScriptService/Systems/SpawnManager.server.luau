local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. SpawnManager stopped.")
	return
end

local GameData = require(gameDataModule)

local function waitForRequiredPart(name, recommendedSize)
	local warned = false

	while true do
		local part = Workspace:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end

		if not warned then
			warn(
				"[SpawnManager] Missing Workspace."
					.. name
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
