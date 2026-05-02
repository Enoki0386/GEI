local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local playersInside = {}

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
	local zone = Workspace:FindFirstChild("BuyZone")
	if zone and zone:IsA("BasePart") then
		return zone
	end

	return nil
end

local function getRootPart(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function isPointInsideZone(zone, point)
	local localPoint = zone.CFrame:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= zone.Size.X / 2
		and math.abs(localPoint.Z) <= zone.Size.Z / 2
		and math.abs(localPoint.Y) <= 8
end

ensureRemote("BuyItem").OnServerEvent:Connect(function(player, category, itemId)
	if type(category) ~= "string" or type(itemId) ~= "string" then
		return
	end

	local PlayerManager = waitForPlayerManager()
	local ok, reason = PlayerManager.BuyItem(player, category, itemId)
	ensureRemote("PurchaseResult"):FireClient(player, ok, reason, category, itemId)
end)

ensureRemote("EquipItem").OnServerEvent:Connect(function(player, category, itemId)
	if type(category) ~= "string" or type(itemId) ~= "string" then
		return
	end

	local PlayerManager = waitForPlayerManager()
	local ok = false
	if category == "Tool" then
		ok = PlayerManager.EquipTool(player, itemId)
	elseif category == "Backpack" then
		ok = PlayerManager.EquipBackpack(player, itemId)
	end

	ensureRemote("PurchaseResult"):FireClient(player, ok, ok and "Equipped" or "CannotEquip", category, itemId)
end)

task.spawn(function()
	while true do
		local zone = getZone()
		if zone then
			for _, player in ipairs(Players:GetPlayers()) do
				local root = getRootPart(player)
				local inside = root ~= nil and isPointInsideZone(zone, root.Position)

				if inside and not playersInside[player] then
					playersInside[player] = true
					ensureRemote("ShopState"):FireClient(player, true)
					ensureRemote("TutorialProgress"):FireClient(player, "OpenedShop")
				elseif not inside and playersInside[player] then
					playersInside[player] = nil
					ensureRemote("ShopState"):FireClient(player, false)
				end
			end
		end

		task.wait(0.25)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playersInside[player] = nil
end)
