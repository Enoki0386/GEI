local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. PlayerManager stopped.")
	return
end

local GameData = require(gameDataModule)

_G.GEI = _G.GEI or {}

local DATASTORE_NAME = "GEI_PlayerData_v1"
local DATASTORE_KEY_PREFIX = "Player_"

local dataStore = nil
local dataStoreDisabled = false
local dataStoreWarningShown = false
local debugPrintShown = false
local dataFoldersByPlayer = {}

local function getRemote(remoteName)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return nil
	end

	return remotes:FindFirstChild(remoteName)
end

local function fireClient(player, remoteName, ...)
	local remote = getRemote(remoteName)
	if remote then
		remote:FireClient(player, ...)
	end
end

local function warnDataStoreOnce(...)
	if dataStoreWarningShown then
		return
	end

	dataStoreWarningShown = true
	warn(...)
end

local function getDataStore()
	if dataStoreDisabled then
		return nil
	end

	if dataStore then
		return dataStore
	end

	local ok, storeOrError = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)

	if not ok then
		dataStoreDisabled = true
		warnDataStoreOnce("[GEI] DataStore unavailable. Studio-safe memory data will be used:", storeOrError)
		return nil
	end

	dataStore = storeOrError
	return dataStore
end

local function copySet(source)
	local result = {}
	for key, value in pairs(source) do
		if value == true then
			result[key] = true
		end
	end
	return result
end

local function getDebugConfig()
	local debugConfig = GameData.Debug
	if type(debugConfig) == "table" and debugConfig.Enabled == true then
		return debugConfig
	end

	return nil
end

local function applyDebugOverrides(saveData)
	local debugConfig = getDebugConfig()
	if not debugConfig then
		return saveData
	end

	if not debugPrintShown then
		debugPrintShown = true
		print("[Debug] Debug mode enabled: giving test values")
	end

	saveData.Cash = math.max(0, math.floor(debugConfig.StartingCash or saveData.Cash or 0))
	saveData.Diamonds = math.max(0, math.floor(debugConfig.StartingDiamonds or saveData.Diamonds or 0))
	saveData.WasteCount = math.max(0, math.floor(debugConfig.StartingWaste or saveData.WasteCount or 0))
	return saveData
end

local function getToolDamage(tool)
	local multiplier = 1
	local debugConfig = getDebugConfig()
	if debugConfig and type(debugConfig.ToolDamageMultiplier) == "number" then
		multiplier = math.max(0, debugConfig.ToolDamageMultiplier)
	end

	return math.max(0, math.floor((tool.Damage or 0) * multiplier))
end

local function createDefaultSaveData()
	return applyDebugOverrides({
		Cash = GameData.Economy.StartingCash,
		Diamonds = GameData.Economy.StartingDiamonds,
		WasteCount = 0,
		EquippedTool = "Brush",
		EquippedBackpack = "SmallBag",
		OwnedTools = {
			Brush = true,
		},
		OwnedBackpacks = {
			SmallBag = true,
		},
	})
end

local function mergeSaveData(savedData)
	local data = createDefaultSaveData()
	if type(savedData) ~= "table" then
		return data
	end

	if type(savedData.Cash) == "number" then
		data.Cash = math.max(0, math.floor(savedData.Cash))
	end
	if type(savedData.Diamonds) == "number" then
		data.Diamonds = math.max(0, math.floor(savedData.Diamonds))
	end
	if type(savedData.WasteCount) == "number" then
		data.WasteCount = math.max(0, math.floor(savedData.WasteCount))
	end
	if type(savedData.EquippedTool) == "string" and GameData.GetTool(savedData.EquippedTool) then
		data.EquippedTool = savedData.EquippedTool
	end
	if type(savedData.EquippedBackpack) == "string" and GameData.GetBackpack(savedData.EquippedBackpack) then
		data.EquippedBackpack = savedData.EquippedBackpack
	end
	if type(savedData.OwnedTools) == "table" then
		for toolId, owned in pairs(savedData.OwnedTools) do
			if owned == true and GameData.GetTool(toolId) then
				data.OwnedTools[toolId] = true
			end
		end
	end
	if type(savedData.OwnedBackpacks) == "table" then
		for backpackId, owned in pairs(savedData.OwnedBackpacks) do
			if owned == true and GameData.GetBackpack(backpackId) then
				data.OwnedBackpacks[backpackId] = true
			end
		end
	end

	if not data.OwnedTools[data.EquippedTool] then
		data.EquippedTool = "Brush"
	end
	if not data.OwnedBackpacks[data.EquippedBackpack] then
		data.EquippedBackpack = "SmallBag"
	end

	return applyDebugOverrides(data)
end

local function loadSaveData(player)
	local store = getDataStore()
	if not store then
		return createDefaultSaveData()
	end

	local ok, savedDataOrError = pcall(function()
		return store:GetAsync(DATASTORE_KEY_PREFIX .. player.UserId)
	end)

	if not ok then
		dataStoreDisabled = true
		warnDataStoreOnce("[GEI] Could not load DataStore data. Using Studio-safe defaults for this session:", savedDataOrError)
		return createDefaultSaveData()
	end

	return mergeSaveData(savedDataOrError)
end

local function createValue(className, name, value, parent)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		existing.Value = value
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Value = value
	instance.Parent = parent
	return instance
end

local function createOwnedFolder(folderName, ownedSet, parent)
	local folder = parent:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BoolValue") and not ownedSet[child.Name] then
			child:Destroy()
		end
	end

	for itemId, owned in pairs(ownedSet) do
		if owned == true then
			createValue("BoolValue", itemId, true, folder)
		end
	end

	return folder
end

local function applyWalkSpeed(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if humanoid and GameData.Player and type(GameData.Player.WalkSpeed) == "number" then
		humanoid.WalkSpeed = GameData.Player.WalkSpeed
	end
end

local function getPlayerDataFolder(player)
	return dataFoldersByPlayer[player] or player:FindFirstChild("PlayerData")
end

local function getLeaderstats(player)
	return player:FindFirstChild("leaderstats")
end

local function updateDerivedStats(player)
	local dataFolder = getPlayerDataFolder(player)
	if not dataFolder then
		return
	end

	local equippedTool = dataFolder:FindFirstChild("EquippedTool")
	local equippedBackpack = dataFolder:FindFirstChild("EquippedBackpack")
	local tool = equippedTool and GameData.GetTool(equippedTool.Value) or GameData.GetTool("Brush")
	local backpack = equippedBackpack and GameData.GetBackpack(equippedBackpack.Value) or GameData.GetBackpack("SmallBag")

	createValue("NumberValue", "ToolDamage", getToolDamage(tool), dataFolder)
	createValue("IntValue", "MaxWaste", backpack.Capacity, dataFolder)

	local wasteCount = dataFolder:FindFirstChild("WasteCount")
	if wasteCount and wasteCount.Value > backpack.Capacity then
		wasteCount.Value = backpack.Capacity
	end
end

local function snapshotPlayerData(player)
	local dataFolder = getPlayerDataFolder(player)
	local leaderstats = getLeaderstats(player)
	if not dataFolder or not leaderstats then
		return nil
	end

	local ownedTools = {}
	local ownedBackpacks = {}
	local ownedToolsFolder = dataFolder:FindFirstChild("OwnedTools")
	local ownedBackpacksFolder = dataFolder:FindFirstChild("OwnedBackpacks")

	if ownedToolsFolder then
		for _, child in ipairs(ownedToolsFolder:GetChildren()) do
			if child:IsA("BoolValue") and child.Value == true then
				ownedTools[child.Name] = true
			end
		end
	end

	if ownedBackpacksFolder then
		for _, child in ipairs(ownedBackpacksFolder:GetChildren()) do
			if child:IsA("BoolValue") and child.Value == true then
				ownedBackpacks[child.Name] = true
			end
		end
	end

	return {
		Cash = leaderstats.Cash.Value,
		Diamonds = leaderstats.Diamonds.Value,
		WasteCount = dataFolder.WasteCount.Value,
		MaxWaste = dataFolder.MaxWaste.Value,
		EquippedTool = dataFolder.EquippedTool.Value,
		IsToolEquipped = dataFolder.IsToolEquipped.Value,
		EquippedBackpack = dataFolder.EquippedBackpack.Value,
		ToolDamage = dataFolder.ToolDamage.Value,
		OwnedTools = ownedTools,
		OwnedBackpacks = ownedBackpacks,
	}
end

local function pushPlayerData(player)
	local snapshot = snapshotPlayerData(player)
	if snapshot then
		fireClient(player, "PlayerDataUpdate", snapshot)
	end
end

local function serializePlayer(player)
	local snapshot = snapshotPlayerData(player)
	if not snapshot then
		return nil
	end

	return {
		Cash = snapshot.Cash,
		Diamonds = snapshot.Diamonds,
		WasteCount = snapshot.WasteCount,
		EquippedTool = snapshot.EquippedTool,
		EquippedBackpack = snapshot.EquippedBackpack,
		OwnedTools = copySet(snapshot.OwnedTools),
		OwnedBackpacks = copySet(snapshot.OwnedBackpacks),
	}
end

local function savePlayer(player)
	local saveData = serializePlayer(player)
	if not saveData then
		return
	end

	local store = getDataStore()
	if not store then
		return
	end

	local ok, errorMessage = pcall(function()
		store:SetAsync(DATASTORE_KEY_PREFIX .. player.UserId, saveData)
	end)

	if not ok then
		dataStoreDisabled = true
		warnDataStoreOnce("[GEI] Could not save player data. The game keeps running:", errorMessage)
	end
end

local function setupPlayer(player)
	local saveData = loadSaveData(player)
	local backpack = GameData.GetBackpack(saveData.EquippedBackpack) or GameData.GetBackpack("SmallBag")
	local tool = GameData.GetTool(saveData.EquippedTool) or GameData.GetTool("Brush")

	player.CharacterAdded:Connect(applyWalkSpeed)
	if player.Character then
		task.defer(applyWalkSpeed, player.Character)
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	createValue("IntValue", "Cash", saveData.Cash, leaderstats)
	createValue("IntValue", "Diamonds", saveData.Diamonds, leaderstats)

	local dataFolder = Instance.new("Folder")
	dataFolder.Name = "PlayerData"
	dataFolder.Parent = player
	dataFoldersByPlayer[player] = dataFolder

	createValue("IntValue", "WasteCount", math.min(saveData.WasteCount, backpack.Capacity), dataFolder)
	createValue("IntValue", "MaxWaste", backpack.Capacity, dataFolder)
	createValue("StringValue", "EquippedTool", tool.Id, dataFolder)
	createValue("BoolValue", "IsToolEquipped", false, dataFolder)
	createValue("StringValue", "EquippedBackpack", backpack.Id, dataFolder)
	createValue("NumberValue", "ToolDamage", getToolDamage(tool), dataFolder)

	createOwnedFolder("OwnedTools", saveData.OwnedTools, dataFolder)
	createOwnedFolder("OwnedBackpacks", saveData.OwnedBackpacks, dataFolder)

	for _, child in ipairs(dataFolder:GetChildren()) do
		if child:IsA("ValueBase") then
			child.Changed:Connect(function()
				pushPlayerData(player)
			end)
		end
	end

	pushPlayerData(player)
	if _G.GEI.ToolVisualManager and _G.GEI.ToolVisualManager.SyncInventory then
		task.defer(_G.GEI.ToolVisualManager.SyncInventory, player)
	end
end

local PlayerManager = {}

local function normalizeCategory(category)
	if category == "Tool" or category == "Tools" then
		return "Tool"
	elseif category == "Backpack" or category == "Backpacks" then
		return "Backpack"
	end

	return nil
end

local function getOwnedFolder(dataFolder, category)
	if category == "Tool" then
		return dataFolder:FindFirstChild("OwnedTools")
	elseif category == "Backpack" then
		return dataFolder:FindFirstChild("OwnedBackpacks")
	end

	return nil
end

function PlayerManager.GetDataFolder(player)
	return getPlayerDataFolder(player)
end

function PlayerManager.GetSnapshot(player)
	return snapshotPlayerData(player)
end

function PlayerManager.HasTool(player, toolId)
	local dataFolder = getPlayerDataFolder(player)
	local ownedTools = dataFolder and dataFolder:FindFirstChild("OwnedTools")
	local ownedValue = ownedTools and ownedTools:FindFirstChild(toolId)
	return ownedValue ~= nil and ownedValue:IsA("BoolValue") and ownedValue.Value == true
end

function PlayerManager.HasBackpack(player, backpackId)
	local dataFolder = getPlayerDataFolder(player)
	local ownedBackpacks = dataFolder and dataFolder:FindFirstChild("OwnedBackpacks")
	local ownedValue = ownedBackpacks and ownedBackpacks:FindFirstChild(backpackId)
	return ownedValue ~= nil and ownedValue:IsA("BoolValue") and ownedValue.Value == true
end

function PlayerManager.EquipTool(player, toolId)
	local tool = GameData.GetTool(toolId)
	local dataFolder = getPlayerDataFolder(player)
	if not tool or not dataFolder or not PlayerManager.HasTool(player, toolId) then
		return false
	end

	dataFolder.EquippedTool.Value = tool.Id
	updateDerivedStats(player)

	if _G.GEI.ToolVisualManager and _G.GEI.ToolVisualManager.SyncInventory then
		_G.GEI.ToolVisualManager.SyncInventory(player)
	end

	local nativeEquipped = false
	if _G.GEI.ToolVisualManager and _G.GEI.ToolVisualManager.Equip then
		nativeEquipped = _G.GEI.ToolVisualManager.Equip(player, tool.Id) == true
	end

	local isToolEquipped = dataFolder:FindFirstChild("IsToolEquipped")
	if isToolEquipped and isToolEquipped:IsA("BoolValue") then
		isToolEquipped.Value = nativeEquipped
	end

	pushPlayerData(player)

	return nativeEquipped
end

function PlayerManager.UnequipTool(player)
	local dataFolder = getPlayerDataFolder(player)
	if not dataFolder then
		return false
	end

	if _G.GEI.ToolVisualManager and _G.GEI.ToolVisualManager.Unequip then
		_G.GEI.ToolVisualManager.Unequip(player)
	end

	local isToolEquipped = dataFolder:FindFirstChild("IsToolEquipped")
	if isToolEquipped and isToolEquipped:IsA("BoolValue") then
		isToolEquipped.Value = false
	end

	pushPlayerData(player)
	return true
end

function PlayerManager.ToggleTool(player, toolId)
	local dataFolder = getPlayerDataFolder(player)
	if not dataFolder then
		return false, "DataMissing"
	end

	local equippedTool = dataFolder:FindFirstChild("EquippedTool")
	local isToolEquipped = dataFolder:FindFirstChild("IsToolEquipped")
	if equippedTool and isToolEquipped and equippedTool.Value == toolId and isToolEquipped.Value == true then
		PlayerManager.UnequipTool(player)
		return true, "Unequipped"
	end

	local equipped = PlayerManager.EquipTool(player, toolId)
	return equipped, equipped and "Equipped" or "CannotEquip"
end

function PlayerManager.ApplyNativeToolState(player, toolId, equipped)
	local tool = GameData.GetTool(toolId)
	local dataFolder = getPlayerDataFolder(player)
	if not tool or not dataFolder or not PlayerManager.HasTool(player, toolId) then
		return false
	end

	if equipped then
		dataFolder.EquippedTool.Value = tool.Id
		updateDerivedStats(player)
	end

	local equippedTool = dataFolder:FindFirstChild("EquippedTool")
	local isToolEquipped = dataFolder:FindFirstChild("IsToolEquipped")
	if equippedTool and equippedTool.Value == tool.Id and isToolEquipped and isToolEquipped:IsA("BoolValue") then
		isToolEquipped.Value = equipped == true
		pushPlayerData(player)
		return true
	end

	return false
end

function PlayerManager.EquipBackpack(player, backpackId)
	local backpack = GameData.GetBackpack(backpackId)
	local dataFolder = getPlayerDataFolder(player)
	if not backpack or not dataFolder or not PlayerManager.HasBackpack(player, backpackId) then
		return false
	end

	dataFolder.EquippedBackpack.Value = backpack.Id
	updateDerivedStats(player)
	pushPlayerData(player)

	if _G.GEI.BackpackManager and _G.GEI.BackpackManager.Attach then
		task.defer(_G.GEI.BackpackManager.Attach, player)
	end

	return true
end

function PlayerManager.BuyItem(player, category, itemId)
	category = normalizeCategory(category)
	local leaderstats = getLeaderstats(player)
	local dataFolder = getPlayerDataFolder(player)
	if not leaderstats or not dataFolder then
		warn("[ShopManager] Purchase failed for", player.Name, itemId, "reason: DataMissing")
		return false, "DataMissing"
	end

	if not category then
		warn("[ShopManager] Purchase failed for", player.Name, itemId, "reason: UnknownCategory")
		return false, "UnknownCategory"
	end

	if category == "Tool" then
		local tool = GameData.GetTool(itemId)
		if not tool then
			warn("[ShopManager] Purchase failed for", player.Name, itemId, "reason: UnknownTool")
			return false, "UnknownTool"
		end
		if PlayerManager.HasTool(player, itemId) then
			local equipped = PlayerManager.EquipTool(player, itemId)
			return equipped, equipped and "Equipped" or "CannotEquip"
		end
		if leaderstats.Cash.Value < tool.Price then
			warn("[ShopManager] Purchase failed for", player.Name, itemId, "reason: NotEnoughCash")
			return false, "NotEnoughCash"
		end

		local ownedFolder = getOwnedFolder(dataFolder, category)
		if not ownedFolder then
			warn("[ShopManager] Purchase failed for", player.Name, itemId, "reason: OwnedFolderMissing")
			return false, "DataMissing"
		end

		leaderstats.Cash.Value -= tool.Price
		createValue("BoolValue", itemId, true, ownedFolder)
		PlayerManager.EquipTool(player, itemId)
		pushPlayerData(player)
		return true, "Bought"
	elseif category == "Backpack" then
		local backpack = GameData.GetBackpack(itemId)
		if not backpack then
			warn("[ShopManager] Purchase failed for", player.Name, itemId, "reason: UnknownBackpack")
			return false, "UnknownBackpack"
		end
		if PlayerManager.HasBackpack(player, itemId) then
			local equipped = PlayerManager.EquipBackpack(player, itemId)
			return equipped, equipped and "Equipped" or "CannotEquip"
		end
		if leaderstats.Cash.Value < backpack.Price then
			warn("[ShopManager] Purchase failed for", player.Name, itemId, "reason: NotEnoughCash")
			return false, "NotEnoughCash"
		end

		local ownedFolder = getOwnedFolder(dataFolder, category)
		if not ownedFolder then
			warn("[ShopManager] Purchase failed for", player.Name, itemId, "reason: OwnedFolderMissing")
			return false, "DataMissing"
		end

		leaderstats.Cash.Value -= backpack.Price
		createValue("BoolValue", itemId, true, ownedFolder)
		PlayerManager.EquipBackpack(player, itemId)
		pushPlayerData(player)
		return true, "Bought"
	end

	return false, "UnknownCategory"
end

function PlayerManager.AddWaste(player, amount)
	local dataFolder = getPlayerDataFolder(player)
	if not dataFolder then
		return 0
	end

	local wasteValue = dataFolder:FindFirstChild("WasteCount")
	local maxWasteValue = dataFolder:FindFirstChild("MaxWaste")
	if not wasteValue or not maxWasteValue then
		return 0
	end

	local freeSpace = math.max(0, maxWasteValue.Value - wasteValue.Value)
	local accepted = math.min(math.max(0, math.floor(amount)), freeSpace)
	if accepted <= 0 then
		return 0
	end

	wasteValue.Value += accepted
	pushPlayerData(player)
	return accepted
end

function PlayerManager.AddDiamonds(player, amount)
	local leaderstats = getLeaderstats(player)
	if not leaderstats then
		return 0
	end

	local diamonds = math.max(0, math.floor(amount))
	if diamonds <= 0 then
		return 0
	end

	leaderstats.Diamonds.Value += diamonds
	pushPlayerData(player)
	return diamonds
end

function PlayerManager.SellWaste(player)
	local dataFolder = getPlayerDataFolder(player)
	local leaderstats = getLeaderstats(player)
	if not dataFolder or not leaderstats then
		return 0
	end

	local wasteValue = dataFolder:FindFirstChild("WasteCount")
	if not wasteValue or wasteValue.Value <= 0 then
		return 0
	end

	local cashEarned = GameData.GetCashForWaste(wasteValue.Value)
	wasteValue.Value = 0
	leaderstats.Cash.Value += cashEarned
	pushPlayerData(player)
	return cashEarned
end

function PlayerManager.Push(player)
	pushPlayerData(player)
end

_G.GEI.PlayerManager = PlayerManager

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	dataFoldersByPlayer[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(setupPlayer, player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)
