local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. SellZoneManager stopped.")
	return
end

local GameData = require(gameDataModule)
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local workspaceUtilModule = sharedFolder and sharedFolder:WaitForChild("WorkspaceUtil", 10)
local WorkspaceUtil = workspaceUtilModule and require(workspaceUtilModule)
local playersInside = {}
local lastSellTimes = {}
local zoneWarningShown = false

local function waitForPlayerManager()
	while not (_G.GEI and _G.GEI.PlayerManager) do
		task.wait(0.1)
	end

	return _G.GEI.PlayerManager
end

local function ensureRemote(remoteName)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild(remoteName)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = remotes
	end

	return remote
end

local function getZone()
	local zone, path
	if WorkspaceUtil then
		zone, path = WorkspaceUtil.Find("SellZone", { "Areas" }, { SearchDescendants = true })
	else
		zone = Workspace:FindFirstChild("SellZone")
		path = "Workspace.SellZone"
	end
	if zone and zone:IsA("BasePart") then
		return zone
	end

	if not zoneWarningShown then
		if zone then
			warn("[SellZoneManager] " .. (path or "Workspace.SellZone") .. " exists but must be a Part/BasePart. Selling is disabled until this is fixed.")
		else
			warn("[SellZoneManager] Missing Workspace.SellZone. Create a Part named SellZone. Recommended size: 20, 1, 16.")
		end
		zoneWarningShown = true
	end

	return nil
end

local function isPointInsideZone(zone, point)
	local localPoint = zone.CFrame:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= zone.Size.X / 2
		and math.abs(localPoint.Z) <= zone.Size.Z / 2
		and math.abs(localPoint.Y) <= 8
end

local function getRootPart(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getSellTeleportCFrame()
	local target
	if WorkspaceUtil then
		target = WorkspaceUtil.Find("SellTeleportPoint", { "Areas" }, { SearchDescendants = true })
	else
		target = Workspace:FindFirstChild("SellTeleportPoint", true)
	end
	if target and target:IsA("BasePart") then
		return CFrame.new(target.Position + Vector3.new(0, 3, 0))
	end

	local zone = getZone()
	if zone then
		return CFrame.new(zone.Position + Vector3.new(0, 4, 0))
	end

	return nil
end

ensureRemote("TeleportToSell").OnServerEvent:Connect(function(player)
	local root = getRootPart(player)
	local targetCFrame = getSellTeleportCFrame()
	if root and targetCFrame then
		root.CFrame = targetCFrame
	end
end)

local function sellForPlayer(player)
	local now = os.clock()
	if (lastSellTimes[player] or 0) + GameData.Economy.SellCooldown > now then
		return
	end

	lastSellTimes[player] = now

	local PlayerManager = waitForPlayerManager()
	local cashEarned = PlayerManager.SellWaste(player)
	if cashEarned > 0 then
		ensureRemote("SellFeedback"):FireClient(player, cashEarned)
		ensureRemote("TutorialProgress"):FireClient(player, "SoldWaste")
	end
end

task.spawn(function()
	while true do
		local zone = getZone()
		if zone then
			zoneWarningShown = false
			for _, player in ipairs(Players:GetPlayers()) do
				local root = getRootPart(player)
				local inside = root ~= nil and isPointInsideZone(zone, root.Position)

				if inside and not playersInside[player] then
					playersInside[player] = true
					sellForPlayer(player)
				elseif not inside and playersInside[player] then
					playersInside[player] = nil
				elseif inside then
					sellForPlayer(player)
				end
			end
		else
			for player in pairs(playersInside) do
				playersInside[player] = nil
			end
		end

		task.wait(0.35)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playersInside[player] = nil
	lastSellTimes[player] = nil
end)
