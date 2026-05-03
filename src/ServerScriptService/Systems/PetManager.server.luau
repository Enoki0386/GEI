local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[PetManager] Missing ReplicatedStorage.GameData. Pets disabled.")
	return
end

local GameData = require(gameDataModule)
local random = Random.new()

_G.GEI = _G.GEI or {}

local function waitForPlayerManager()
	while not (_G.GEI and _G.GEI.PlayerManager) do
		task.wait(0.1)
	end

	return _G.GEI.PlayerManager
end

local function ensureRemotesFolder()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	return remotes
end

local function ensureRemoteFunction(remoteName)
	local remotes = ensureRemotesFolder()
	local remote = remotes:FindFirstChild(remoteName)
	if remote and not remote:IsA("RemoteFunction") then
		remote:Destroy()
		remote = nil
	end

	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = remoteName
		remote.Parent = remotes
	end

	return remote
end

local function ensureRemoteEvent(remoteName)
	local remotes = ensureRemotesFolder()
	local remote = remotes:FindFirstChild(remoteName)
	if remote and not remote:IsA("RemoteEvent") then
		remote:Destroy()
		remote = nil
	end

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = remotes
	end

	return remote
end

local hatchEggRemote = ensureRemoteFunction("HatchEgg")
local equipPetRemote = ensureRemoteFunction("EquipPet")
local unequipPetRemote = ensureRemoteFunction("UnequipPet")
local petInventoryUpdatedRemote = ensureRemoteEvent("PetInventoryUpdated")

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

local function getDataFolder(player)
	local PlayerManager = waitForPlayerManager()
	return PlayerManager.GetDataFolder(player)
end

local function getLeaderCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash
end

local function ensurePetsFolder(player)
	local dataFolder = getDataFolder(player)
	if not dataFolder then
		return nil
	end

	local petsFolder = dataFolder:FindFirstChild("Pets")
	if not petsFolder then
		petsFolder = Instance.new("Folder")
		petsFolder.Name = "Pets"
		petsFolder.Parent = dataFolder
	end

	if not petsFolder:FindFirstChild("MaxEquipped") then
		createValue("IntValue", "MaxEquipped", (GameData.Pets and GameData.Pets.MaxEquipped) or 3, petsFolder)
	end

	if not petsFolder:FindFirstChild("Inventory") then
		local inventory = Instance.new("Folder")
		inventory.Name = "Inventory"
		inventory.Parent = petsFolder
	end

	if not petsFolder:FindFirstChild("Equipped") then
		local equipped = Instance.new("Folder")
		equipped.Name = "Equipped"
		equipped.Parent = petsFolder
	end

	return petsFolder
end

local function getInventoryFolder(player)
	local petsFolder = ensurePetsFolder(player)
	return petsFolder and petsFolder:FindFirstChild("Inventory")
end

local function getEquippedFolder(player)
	local petsFolder = ensurePetsFolder(player)
	return petsFolder and petsFolder:FindFirstChild("Equipped")
end

local function getMaxEquipped(player)
	local petsFolder = ensurePetsFolder(player)
	local maxEquipped = petsFolder and petsFolder:FindFirstChild("MaxEquipped")
	return maxEquipped and math.max(1, maxEquipped.Value) or ((GameData.Pets and GameData.Pets.MaxEquipped) or 3)
end

local function getPetFolder(player, petUid)
	local inventory = getInventoryFolder(player)
	if not inventory then
		return nil
	end

	local petFolder = inventory:FindFirstChild(petUid)
	if petFolder and petFolder:IsA("Folder") then
		local petId = petFolder:FindFirstChild("PetId")
		if petId and GameData.GetPet(petId.Value) then
			return petFolder
		end
	end

	return nil
end

local function readPetFolder(petFolder)
	local uid = petFolder:FindFirstChild("Uid")
	local petId = petFolder:FindFirstChild("PetId")
	local level = petFolder:FindFirstChild("Level")
	local locked = petFolder:FindFirstChild("Locked")
	if not uid or not petId or not GameData.GetPet(petId.Value) then
		return nil
	end

	return {
		Uid = uid.Value,
		PetId = petId.Value,
		Level = level and level.Value or 1,
		Locked = locked and locked.Value == true or false,
	}
end

local function getEquippedList(player)
	local equipped = getEquippedFolder(player)
	local result = {}
	local maxEquipped = getMaxEquipped(player)
	if not equipped then
		return result
	end

	for index = 1, maxEquipped do
		local slotValue = equipped:FindFirstChild("Slot" .. tostring(index))
		if slotValue and slotValue:IsA("StringValue") and slotValue.Value ~= "" then
			table.insert(result, slotValue.Value)
		end
	end

	return result
end

local function writeEquippedList(player, equippedList)
	local equipped = getEquippedFolder(player)
	if not equipped then
		return
	end

	for _, child in ipairs(equipped:GetChildren()) do
		child:Destroy()
	end

	for index, petUid in ipairs(equippedList) do
		createValue("StringValue", "Slot" .. tostring(index), petUid, equipped)
	end
end

local function addPetToInventory(player, petId)
	local inventory = getInventoryFolder(player)
	if not inventory then
		return nil
	end

	local uid = HttpService:GenerateGUID(false)
	while inventory:FindFirstChild(uid) do
		uid = HttpService:GenerateGUID(false)
	end

	local petFolder = Instance.new("Folder")
	petFolder.Name = uid
	petFolder.Parent = inventory
	createValue("StringValue", "Uid", uid, petFolder)
	createValue("StringValue", "PetId", petId, petFolder)
	createValue("IntValue", "Level", 1, petFolder)
	createValue("BoolValue", "Locked", false, petFolder)

	return readPetFolder(petFolder)
end

local function rollPet(eggConfig)
	local totalChance = 0
	for _, petConfig in ipairs(eggConfig.Pets) do
		totalChance += math.max(0, petConfig.Chance or 0)
	end

	if totalChance <= 0 then
		return nil
	end

	local roll = random:NextNumber(0, totalChance)
	local cursor = 0
	for _, petConfig in ipairs(eggConfig.Pets) do
		cursor += math.max(0, petConfig.Chance or 0)
		if roll <= cursor then
			return petConfig
		end
	end

	return eggConfig.Pets[1]
end

local PetManager = {}

function PetManager.GetEquippedPets(player)
	local inventory = getInventoryFolder(player)
	local result = {}
	if not inventory then
		return result
	end

	for _, petUid in ipairs(getEquippedList(player)) do
		local petFolder = inventory:FindFirstChild(petUid)
		local petData = petFolder and readPetFolder(petFolder)
		if petData then
			table.insert(result, petData)
		end
	end

	return result
end

function PetManager.GetPetBuffs(player)
	local defaults = GameData.Pets and GameData.Pets.DefaultBuffs or {}
	local buffs = {
		CashMultiplier = defaults.CashMultiplier or 1,
		DamageMultiplier = defaults.DamageMultiplier or 1,
		BackpackMultiplier = defaults.BackpackMultiplier or 1,
	}

	for _, petData in ipairs(PetManager.GetEquippedPets(player)) do
		local petConfig = GameData.GetPet(petData.PetId)
		local petBuffs = petConfig and petConfig.Buffs or nil
		if type(petBuffs) == "table" then
			for buffName, baseValue in pairs(buffs) do
				local petValue = petBuffs[buffName]
				if type(petValue) == "number" then
					buffs[buffName] = baseValue + (petValue - 1)
				end
			end
		end
	end

	return buffs
end

function PetManager.GetSnapshot(player)
	local inventory = getInventoryFolder(player)
	local pets = {
		Inventory = {},
		Equipped = getEquippedList(player),
		MaxEquipped = getMaxEquipped(player),
		Buffs = PetManager.GetPetBuffs(player),
	}

	if inventory then
		for _, petFolder in ipairs(inventory:GetChildren()) do
			if petFolder:IsA("Folder") then
				local petData = readPetFolder(petFolder)
				if petData then
					table.insert(pets.Inventory, petData)
				end
			end
		end
	end

	return pets
end

function PetManager.SendPetInventory(player)
	petInventoryUpdatedRemote:FireClient(player, PetManager.GetSnapshot(player))
end

function PetManager.HatchEgg(player, eggId)
	if type(eggId) ~= "string" then
		return { Ok = false, Reason = "InvalidEgg" }
	end

	local eggConfig = GameData.GetEgg(eggId)
	if not eggConfig then
		return { Ok = false, Reason = "UnknownEgg" }
	end

	if eggConfig.Currency ~= "Cash" then
		return { Ok = false, Reason = "UnsupportedCurrency" }
	end

	local cash = getLeaderCash(player)
	if not cash then
		return { Ok = false, Reason = "DataMissing" }
	end

	if cash.Value < eggConfig.Price then
		return { Ok = false, Reason = "NotEnoughCash", Pets = PetManager.GetSnapshot(player) }
	end

	local petConfig = rollPet(eggConfig)
	if not petConfig then
		return { Ok = false, Reason = "EggEmpty" }
	end

	cash.Value -= eggConfig.Price
	local petData = addPetToInventory(player, petConfig.PetId)
	if not petData then
		cash.Value += eggConfig.Price
		return { Ok = false, Reason = "DataMissing" }
	end

	local PlayerManager = waitForPlayerManager()
	PlayerManager.Push(player)
	PetManager.SendPetInventory(player)

	return {
		Ok = true,
		Reason = "Hatched",
		Pet = petData,
		PetConfig = petConfig,
		Pets = PetManager.GetSnapshot(player),
	}
end

function PetManager.EquipPet(player, petUid)
	if type(petUid) ~= "string" or petUid == "" then
		return { Ok = false, Reason = "InvalidPet" }
	end

	if not getPetFolder(player, petUid) then
		return { Ok = false, Reason = "NotOwned", Pets = PetManager.GetSnapshot(player) }
	end

	local equippedList = getEquippedList(player)
	for _, equippedUid in ipairs(equippedList) do
		if equippedUid == petUid then
			return { Ok = true, Reason = "AlreadyEquipped", Pets = PetManager.GetSnapshot(player) }
		end
	end

	if #equippedList >= getMaxEquipped(player) then
		return { Ok = false, Reason = "MaxEquipped", Pets = PetManager.GetSnapshot(player) }
	end

	table.insert(equippedList, petUid)
	writeEquippedList(player, equippedList)

	local PlayerManager = waitForPlayerManager()
	PlayerManager.RecalculateDerivedStats(player)
	PetManager.SendPetInventory(player)

	return { Ok = true, Reason = "Equipped", Pets = PetManager.GetSnapshot(player) }
end

function PetManager.UnequipPet(player, petUid)
	if type(petUid) ~= "string" or petUid == "" then
		return { Ok = false, Reason = "InvalidPet" }
	end

	local equippedList = getEquippedList(player)
	local nextEquipped = {}
	local removed = false
	for _, equippedUid in ipairs(equippedList) do
		if equippedUid == petUid then
			removed = true
		else
			table.insert(nextEquipped, equippedUid)
		end
	end

	if not removed then
		return { Ok = false, Reason = "NotEquipped", Pets = PetManager.GetSnapshot(player) }
	end

	writeEquippedList(player, nextEquipped)

	local PlayerManager = waitForPlayerManager()
	PlayerManager.RecalculateDerivedStats(player)
	PetManager.SendPetInventory(player)

	return { Ok = true, Reason = "Unequipped", Pets = PetManager.GetSnapshot(player) }
end

hatchEggRemote.OnServerInvoke = function(player, eggId)
	return PetManager.HatchEgg(player, eggId)
end

equipPetRemote.OnServerInvoke = function(player, petUid)
	return PetManager.EquipPet(player, petUid)
end

unequipPetRemote.OnServerInvoke = function(player, petUid)
	return PetManager.UnequipPet(player, petUid)
end

_G.GEI.PetManager = PetManager

local function syncPlayer(player)
	local PlayerManager = waitForPlayerManager()
	local startTime = os.clock()
	while player.Parent and not PlayerManager.GetDataFolder(player) and os.clock() - startTime < 15 do
		task.wait(0.1)
	end

	if player.Parent and PlayerManager.GetDataFolder(player) then
		PlayerManager.RecalculateDerivedStats(player)
		PetManager.SendPetInventory(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.defer(syncPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(syncPlayer, player)
end
