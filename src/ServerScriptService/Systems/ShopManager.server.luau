local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local playersInside = {}
local zoneWarningShown = false

local function normalizeCategory(category)
	if category == "Tool" or category == "Tools" then
		return "Tool"
	elseif category == "Backpack" or category == "Backpacks" then
		return "Backpack"
	end

	return nil
end

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

	if not zoneWarningShown then
		if zone then
			warn("[ShopManager] Workspace.BuyZone exists but must be a Part/BasePart. Shop zone entry is disabled until this is fixed.")
		else
			warn("[ShopManager] Missing Workspace.BuyZone. Create a Part named BuyZone. Recommended size: 20, 1, 16.")
		end
		zoneWarningShown = true
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
		warn("[ShopManager] Ignored invalid BuyItem request from", player.Name)
		return
	end

	category = normalizeCategory(category)
	if not category then
		warn("[ShopManager] Invalid shop category from", player.Name, itemId)
		ensureRemote("PurchaseResult"):FireClient(player, false, "UnknownCategory", "Unknown", itemId)
		return
	end

	local PlayerManager = waitForPlayerManager()
	local ok, reason = PlayerManager.BuyItem(player, category, itemId)
	ensureRemote("PurchaseResult"):FireClient(player, ok, reason, category, itemId)
end)

ensureRemote("EquipItem").OnServerEvent:Connect(function(player, category, itemId, mode)
	if type(category) ~= "string" or type(itemId) ~= "string" then
		warn("[ShopManager] Ignored invalid EquipItem request from", player.Name)
		return
	end

	category = normalizeCategory(category)
	if not category then
		warn("[ShopManager] Invalid equip category from", player.Name, itemId)
		ensureRemote("PurchaseResult"):FireClient(player, false, "UnknownCategory", "Unknown", itemId)
		return
	end

	local PlayerManager = waitForPlayerManager()
	local ok = false
	local reason = "CannotEquip"
	if category == "Tool" then
		if mode == "Toggle" then
			ok, reason = PlayerManager.ToggleTool(player, itemId)
		else
			ok = PlayerManager.EquipTool(player, itemId)
			reason = ok and "Equipped" or "CannotEquip"
		end
	elseif category == "Backpack" then
		ok = PlayerManager.EquipBackpack(player, itemId)
		reason = ok and "Equipped" or "CannotEquip"
	end

	ensureRemote("PurchaseResult"):FireClient(player, ok, reason, category, itemId)
end)

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
					ensureRemote("ShopState"):FireClient(player, true)
					ensureRemote("TutorialProgress"):FireClient(player, "OpenedShop")
				elseif not inside and playersInside[player] then
					playersInside[player] = nil
					ensureRemote("ShopState"):FireClient(player, false)
				end
			end
		else
			for player in pairs(playersInside) do
				playersInside[player] = nil
				ensureRemote("ShopState"):FireClient(player, false)
			end
		end

		task.wait(0.25)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playersInside[player] = nil
end)
