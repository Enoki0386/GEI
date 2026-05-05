local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World1Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World1Data"))

_G.GEI = _G.GEI or {}

local STORE_NAME = "GEI_WorldProgress_v1"
local store = nil
local storeDisabled = false
local progressByPlayer = {}
local warningShown = false

local function warnOnce(...)
	if warningShown then
		return
	end
	warningShown = true
	warn(...)
end

local function getStore()
	if storeDisabled then
		return nil
	end
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		storeDisabled = true
		warnOnce("[WorldProgress] DataStore unavailable. Session progress will be used:", result)
		return nil
	end
	store = result
	return store
end

local function defaultProgress()
	return {
		UnlockedZones = {
			Zone1 = true,
			Zone2 = false,
			Zone3 = false,
			MachineZone = false,
			Zone4 = false,
			Portal = false,
		},
		Upgrades = {},
		BossDefeated = false,
		PortalUnlocked = false,
	}
end

local function sanitize(data)
	local result = defaultProgress()
	if type(data) ~= "table" then
		return result
	end
	if type(data.UnlockedZones) == "table" then
		for zoneId, unlocked in pairs(data.UnlockedZones) do
			if type(zoneId) == "string" and unlocked == true then
				result.UnlockedZones[zoneId] = true
			end
		end
	end
	if type(data.Upgrades) == "table" then
		for upgradeId, level in pairs(data.Upgrades) do
			if World1Data.DiamondUpgrades[upgradeId] then
				result.Upgrades[upgradeId] = math.max(0, math.floor(tonumber(level) or 0))
			end
		end
	end
	result.BossDefeated = data.BossDefeated == true
	result.PortalUnlocked = data.PortalUnlocked == true
	return result
end

local function getProgress(player)
	progressByPlayer[player] = progressByPlayer[player] or defaultProgress()
	return progressByPlayer[player]
end

local function createFolderSnapshot(player)
	local dataFolder = player:FindFirstChild("PlayerData")
	if not dataFolder then
		return
	end
	local progress = getProgress(player)
	local folder = dataFolder:FindFirstChild("WorldProgress")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "WorldProgress"
	folder.Parent = dataFolder

	local zones = Instance.new("Folder")
	zones.Name = "UnlockedZones"
	zones.Parent = folder
	for zoneId, unlocked in pairs(progress.UnlockedZones) do
		if unlocked then
			local v = Instance.new("BoolValue")
			v.Name = zoneId
			v.Value = true
			v.Parent = zones
		end
	end

	local upgrades = Instance.new("Folder")
	upgrades.Name = "Upgrades"
	upgrades.Parent = folder
	for upgradeId, level in pairs(progress.Upgrades) do
		local v = Instance.new("IntValue")
		v.Name = upgradeId
		v.Value = level
		v.Parent = upgrades
	end

	local boss = Instance.new("BoolValue")
	boss.Name = "BossDefeated"
	boss.Value = progress.BossDefeated == true
	boss.Parent = folder

	local portal = Instance.new("BoolValue")
	portal.Name = "PortalUnlocked"
	portal.Value = progress.PortalUnlocked == true
	portal.Parent = folder
end

local function load(player)
	local storeInstance = getStore()
	if not storeInstance then
		progressByPlayer[player] = defaultProgress()
		createFolderSnapshot(player)
		return
	end
	local ok, data = pcall(function()
		return storeInstance:GetAsync("Player_" .. player.UserId)
	end)
	if not ok then
		storeDisabled = true
		warnOnce("[WorldProgress] Load failed. Session progress will be used:", data)
		progressByPlayer[player] = defaultProgress()
	else
		progressByPlayer[player] = sanitize(data)
	end
	createFolderSnapshot(player)
end

local function save(player)
	local progress = progressByPlayer[player]
	if not progress then
		return
	end
	local storeInstance = getStore()
	if not storeInstance then
		return
	end
	pcall(function()
		storeInstance:SetAsync("Player_" .. player.UserId, progress)
	end)
end

local WorldProgress = {}

function WorldProgress.Get(player)
	return getProgress(player)
end

function WorldProgress.HasZone(player, zoneId)
	return getProgress(player).UnlockedZones[zoneId] == true
end

function WorldProgress.UnlockZone(player, zoneId, free)
	if zoneId == "Zone1" then
		return true, "Zone 1 already unlocked"
	end
	local zone = World1Data.Zones[zoneId]
	if not zone then
		return false, "Invalid zone"
	end
	local progress = getProgress(player)
	if progress.UnlockedZones[zoneId] then
		return true, zone.DisplayName .. " already unlocked"
	end
	if zone.Requires and not progress.UnlockedZones[zone.Requires] then
		return false, zone.LockedText or "Unlock previous zone first"
	end
	if zone.RequiresBossDefeated and progress.BossDefeated ~= true then
		return false, zone.LockedText or "Defeat the Boss first"
	end
	if not free then
		local leaderstats = player:FindFirstChild("leaderstats")
		local currency = leaderstats and leaderstats:FindFirstChild(zone.Currency or "Cash")
		if not currency or currency.Value < zone.Cost then
			local missing = math.max(0, (zone.Cost or 0) - (currency and currency.Value or 0))
			return false, "Not enough " .. (zone.Currency or "Cash") .. ". You need " .. tostring(missing) .. " more."
		end
		currency.Value -= zone.Cost
	end
	progress.UnlockedZones[zoneId] = true
	if zoneId == "Portal" then
		progress.PortalUnlocked = true
	end
	createFolderSnapshot(player)
	save(player)
	return true, zone.DisplayName .. " unlocked"
end

function WorldProgress.UnlockAllZones(player)
	local progress = getProgress(player)
	for zoneId in pairs(World1Data.Zones) do
		progress.UnlockedZones[zoneId] = true
	end
	progress.PortalUnlocked = true
	createFolderSnapshot(player)
	save(player)
	return true, "All zones unlocked"
end

function WorldProgress.ResetZones(player)
	local progress = getProgress(player)
	progress.UnlockedZones = defaultProgress().UnlockedZones
	progress.BossDefeated = false
	progress.PortalUnlocked = false
	createFolderSnapshot(player)
	save(player)
	return true, "Zones reset"
end

function WorldProgress.SetBossDefeated(player, defeated)
	local progress = getProgress(player)
	progress.BossDefeated = defeated == true
	progress.PortalUnlocked = progress.PortalUnlocked or progress.BossDefeated
	createFolderSnapshot(player)
	save(player)
end

function WorldProgress.SetUpgradeLevel(player, upgradeId, level)
	local progress = getProgress(player)
	progress.Upgrades[upgradeId] = math.max(0, math.floor(tonumber(level) or 0))
	createFolderSnapshot(player)
	save(player)
end

function WorldProgress.GetUpgradeLevel(player, upgradeId)
	return getProgress(player).Upgrades[upgradeId] or 0
end

_G.GEI.WorldProgress = WorldProgress

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		local start = os.clock()
		while player.Parent and not player:FindFirstChild("PlayerData") and os.clock() - start < 15 do
			task.wait(0.1)
		end
		load(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	progressByPlayer[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(load, player)
end
