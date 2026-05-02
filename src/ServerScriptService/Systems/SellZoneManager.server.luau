local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. SellZoneManager stopped.")
	return
end

local GameData = require(gameDataModule)
local playersInside = {}
local lastSellTimes = {}

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
	local zone = Workspace:FindFirstChild("SellZone")
	if zone and zone:IsA("BasePart") then
		return zone
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
		end

		task.wait(0.35)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playersInside[player] = nil
	lastSellTimes[player] = nil
end)
