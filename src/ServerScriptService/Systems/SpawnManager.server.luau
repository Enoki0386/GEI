local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. SpawnManager stopped.")
	return
end

local GameData = require(gameDataModule)

local function ensureFolder(name)
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if existing then
		existing.Name = name .. "_Old"
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

ensureFolder(GameData.Spawn.WasteZoneName)

local startTime = os.clock()
local spawnSurface = Workspace:FindFirstChild(GameData.Spawn.SurfaceName)
while not spawnSurface and os.clock() - startTime < 5 do
	task.wait(0.1)
	spawnSurface = Workspace:FindFirstChild(GameData.Spawn.SurfaceName)
end

if not spawnSurface then
	warn("[GEI] SpawnSurface1 is missing. MapBuilder should create it before gameplay starts.")
end
