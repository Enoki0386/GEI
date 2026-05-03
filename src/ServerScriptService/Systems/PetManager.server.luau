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
local hatchCooldowns = {}

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

local remotes = {
	HatchEgg = ensureRemoteFunction("HatchEgg"),
	EquipPet = ensureRemoteFunction("EquipPet"),
	UnequipPet = ensureRemoteFunction("UnequipPet"),
	DestroyPet = ensureRemoteFunction("DestroyPet"),
	FusePet = ensureRemoteFunction("FusePet"),
	PetInventoryUpdated = ensureRemoteEvent("PetInventoryUpdated"),
	PetError = ensureRemoteEvent("PetError"),
	PetHatchResult = ensureRemoteEvent("PetHatchResult"),
}

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

	createValue("IntValue", "MaxEquipped", (petsFolder:FindFirstChild("MaxEquipped") and petsFolder.MaxEquipped.Value) or ((GameData.Pets and GameData.Pets.MaxEquipped) or 3), petsFolder)
	createValue("IntValue", "MaxStorage", (petsFolder:FindFirstChild("MaxStorage") and petsFolder.MaxStorage.Value) or ((GameData.Pets and (GameData.Pets.MaxStorage or GameData.Pets.BasePetStorage)) or 30), petsFolder)

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

	if not petsFolder:FindFirstChild("Discovered") then
		local discovered = Instance.new("Folder")
		discovered.Name = "Discovered"
		discovered.Parent = petsFolder
	end

	local inventory = petsFolder:FindFirstChild("Inventory")
	local discovered = petsFolder:FindFirstChild("Discovered")
	for _, petFolder in ipairs(inventory:GetChildren()) do
		if petFolder:IsA("Folder") then
			local petId = petFolder:FindFirstChild("PetId")
			if petId and GameData.GetPet(petId.Value) then
				if not petFolder:FindFirstChild("Variant") then
					createValue("StringValue", "Variant", "Normal", petFolder)
				end
				if not petFolder:FindFirstChild("Uid") then
					createValue("StringValue", "Uid", petFolder.Name, petFolder)
				end
				createValue("BoolValue", petId.Value, true, discovered)
			end
		end
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

local function getDiscoveredFolder(player)
	local petsFolder = ensurePetsFolder(player)
	return petsFolder and petsFolder:FindFirstChild("Discovered")
end

local function getMaxEquipped(player)
	local petsFolder = ensurePetsFolder(player)
	local value = petsFolder and petsFolder:FindFirstChild("MaxEquipped")
	return value and math.max(1, value.Value) or ((GameData.Pets and GameData.Pets.MaxEquipped) or 3)
end

local function getMaxStorage(player)
	local petsFolder = ensurePetsFolder(player)
	local value = petsFolder and petsFolder:FindFirstChild("MaxStorage")
	return value and math.max(1, value.Value) or ((GameData.Pets and (GameData.Pets.MaxStorage or GameData.Pets.BasePetStorage)) or 30)
end

local function isEquipped(player, petUid)
	local equipped = getEquippedFolder(player)
	if not equipped then
		return false
	end

	for _, slotValue in ipairs(equipped:GetChildren()) do
		if slotValue:IsA("StringValue") and slotValue.Value == petUid then
			return true
		end
	end

	return false
end

local function readPetFolder(petFolder)
	local uid = petFolder:FindFirstChild("Uid")
	local petId = petFolder:FindFirstChild("PetId")
	local level = petFolder:FindFirstChild("Level")
	local locked = petFolder:FindFirstChild("Locked")
	local variant = petFolder:FindFirstChild("Variant")
	if not uid or not petId or not GameData.GetPet(petId.Value) then
		return nil
	end

	return {
		Uid = uid.Value,
		PetId = petId.Value,
		Level = level and level.Value or 1,
		Locked = locked and locked.Value == true or false,
		Variant = variant and variant.Value or "Normal",
	}
end

local function getPetFolder(player, petUid)
	local inventory = getInventoryFolder(player)
	if not inventory then
		return nil
	end

	local petFolder = inventory:FindFirstChild(petUid)
	if petFolder and petFolder:IsA("Folder") and readPetFolder(petFolder) then
		return petFolder
	end

	return nil
end

local function getInventoryCount(player)
	local inventory = getInventoryFolder(player)
	local count = 0
	if not inventory then
		return 0
	end

	for _, child in ipairs(inventory:GetChildren()) do
		if child:IsA("Folder") and readPetFolder(child) then
			count += 1
		end
	end

	return count
end

local function getEquippedList(player)
	local equipped = getEquippedFolder(player)
	local result = {}
	if not equipped then
		return result
	end

	for index = 1, getMaxEquipped(player) do
		local slotValue = equipped:FindFirstChild("Slot" .. tostring(index))
		if slotValue and slotValue:IsA("StringValue") and slotValue.Value ~= "" then
			if getPetFolder(player, slotValue.Value) then
				table.insert(result, slotValue.Value)
			end
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

local function markDiscovered(player, petId)
	local discovered = getDiscoveredFolder(player)
	if discovered and GameData.GetPet(petId) then
		createValue("BoolValue", petId, true, discovered)
	end
end

local function addPetToInventory(player, petId, variant)
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
	createValue("StringValue", "Variant", variant or "Normal", petFolder)
	markDiscovered(player, petId)

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

local function makeResponse(success, reason, extra)
	local response = extra or {}
	response.Success = success
	response.Ok = success
	response.Error = success and nil or reason
	response.Reason = reason
	return response
end

local function getVariantBuffValue(petData, buffName)
	local petConfig = GameData.GetPet(petData.PetId)
	local baseValue = petConfig and petConfig.Buffs and petConfig.Buffs[buffName]
	if type(baseValue) ~= "number" then
		return nil
	end

	if petData.Variant == "Golden" then
		local goldenMultiplier = (GameData.Pets and GameData.Pets.GoldenBuffMultiplier) or 1.5
		return 1 + ((baseValue - 1) * goldenMultiplier)
	end

	return baseValue
end

local PetManager = {}

function PetManager.GetEquippedPets(player)
	local result = {}
	for _, petUid in ipairs(getEquippedList(player)) do
		local petFolder = getPetFolder(player, petUid)
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
		for buffName, currentValue in pairs(buffs) do
			local petValue = getVariantBuffValue(petData, buffName)
			if type(petValue) == "number" then
				buffs[buffName] = currentValue + (petValue - 1)
			end
		end
	end

	return buffs
end

function PetManager.GetSnapshot(player)
	local inventory = getInventoryFolder(player)
	local discoveredFolder = getDiscoveredFolder(player)
	local pets = {
		Inventory = {},
		Equipped = getEquippedList(player),
		MaxEquipped = getMaxEquipped(player),
		MaxStorage = getMaxStorage(player),
		Discovered = {},
		Buffs = PetManager.GetPetBuffs(player),
	}

	if inventory then
		for _, petFolder in ipairs(inventory:GetChildren()) do
			if petFolder:IsA("Folder") then
				local petData = readPetFolder(petFolder)
				if petData then
					table.insert(pets.Inventory, petData)
					pets.Discovered[petData.PetId] = true
				end
			end
		end
	end

	if discoveredFolder then
		for _, child in ipairs(discoveredFolder:GetChildren()) do
			if child:IsA("BoolValue") and child.Value == true and GameData.GetPet(child.Name) then
				pets.Discovered[child.Name] = true
			end
		end
	end

	return pets
end

function PetManager.SendPetInventory(player)
	remotes.PetInventoryUpdated:FireClient(player, PetManager.GetSnapshot(player))
end

local function refreshPlayer(player)
	local PlayerManager = waitForPlayerManager()
	PlayerManager.RecalculateDerivedStats(player)
	PetManager.SendPetInventory(player)
end

function PetManager.AdminGivePet(player, petId, variant)
	if type(petId) ~= "string" or not GameData.GetPet(petId) then
		return false, "Invalid pet"
	end
	if getInventoryCount(player) >= getMaxStorage(player) then
		return false, "Inventory full"
	end
	local petData = addPetToInventory(player, petId, variant or "Normal")
	if not petData then
		return false, "Could not add pet"
	end
	refreshPlayer(player)
	return true, "Pet given"
end

function PetManager.HatchEgg(player, eggId)
	local now = os.clock()
	if hatchCooldowns[player] and now - hatchCooldowns[player] < 3.2 then
		return makeResponse(false, "HatchCooldown", { Pets = PetManager.GetSnapshot(player) })
	end
	hatchCooldowns[player] = now
	if type(eggId) ~= "string" then
		return makeResponse(false, "InvalidEgg")
	end

	local eggConfig = GameData.GetEgg(eggId)
	if not eggConfig then
		return makeResponse(false, "InvalidEgg")
	end

	if eggConfig.Currency ~= "Cash" then
		return makeResponse(false, "InvalidEgg")
	end

	if getInventoryCount(player) >= getMaxStorage(player) then
		local snapshot = PetManager.GetSnapshot(player)
		remotes.PetError:FireClient(player, "InventoryFull", snapshot)
		return makeResponse(false, "InventoryFull", { Pets = snapshot })
	end

	local cash = getLeaderCash(player)
	if not cash then
		return makeResponse(false, "DataMissing")
	end

	if cash.Value < eggConfig.Price then
		local snapshot = PetManager.GetSnapshot(player)
		remotes.PetError:FireClient(player, "NotEnoughCash", snapshot)
		return makeResponse(false, "NotEnoughCash", { Pets = snapshot })
	end

	local petConfig = rollPet(eggConfig)
	if not petConfig then
		return makeResponse(false, "InvalidEgg")
	end

	cash.Value -= eggConfig.Price
	local petData = addPetToInventory(player, petConfig.PetId, "Normal")
	if not petData then
		cash.Value += eggConfig.Price
		return makeResponse(false, "DataMissing")
	end

	local PlayerManager = waitForPlayerManager()
	PlayerManager.Push(player)
	PetManager.SendPetInventory(player)

	local response = makeResponse(true, "Hatched", {
		Pet = petData,
		PetConfig = petConfig,
		TotalBuffs = PetManager.GetPetBuffs(player),
		Pets = PetManager.GetSnapshot(player),
	})
	remotes.PetHatchResult:FireClient(player, response)
	return response
end

function PetManager.EquipPet(player, petUid)
	if type(petUid) ~= "string" or petUid == "" then
		return makeResponse(false, "InvalidPet")
	end

	if not getPetFolder(player, petUid) then
		return makeResponse(false, "NotOwned", { Pets = PetManager.GetSnapshot(player) })
	end

	local equippedList = getEquippedList(player)
	for _, equippedUid in ipairs(equippedList) do
		if equippedUid == petUid then
			return makeResponse(true, "AlreadyEquipped", { Pets = PetManager.GetSnapshot(player) })
		end
	end

	if #equippedList >= getMaxEquipped(player) then
		local snapshot = PetManager.GetSnapshot(player)
		remotes.PetError:FireClient(player, "MaxEquipped", snapshot)
		return makeResponse(false, "MaxEquipped", { Pets = snapshot })
	end

	table.insert(equippedList, petUid)
	writeEquippedList(player, equippedList)
	refreshPlayer(player)

	return makeResponse(true, "Equipped", { Pets = PetManager.GetSnapshot(player) })
end

function PetManager.UnequipPet(player, petUid)
	if type(petUid) ~= "string" or petUid == "" then
		return makeResponse(false, "InvalidPet")
	end

	local nextEquipped = {}
	local removed = false
	for _, equippedUid in ipairs(getEquippedList(player)) do
		if equippedUid == petUid then
			removed = true
		else
			table.insert(nextEquipped, equippedUid)
		end
	end

	if not removed then
		return makeResponse(false, "NotEquipped", { Pets = PetManager.GetSnapshot(player) })
	end

	writeEquippedList(player, nextEquipped)
	refreshPlayer(player)

	return makeResponse(true, "Unequipped", { Pets = PetManager.GetSnapshot(player) })
end

function PetManager.DestroyPet(player, petUid)
	if type(petUid) ~= "string" or petUid == "" then
		return makeResponse(false, "InvalidPet")
	end

	if isEquipped(player, petUid) then
		local snapshot = PetManager.GetSnapshot(player)
		remotes.PetError:FireClient(player, "DestroyEquipped", snapshot)
		return makeResponse(false, "DestroyEquipped", { Pets = snapshot })
	end

	local petFolder = getPetFolder(player, petUid)
	if not petFolder then
		return makeResponse(false, "NotOwned", { Pets = PetManager.GetSnapshot(player) })
	end

	petFolder:Destroy()
	refreshPlayer(player)
	return makeResponse(true, "Destroyed", { Pets = PetManager.GetSnapshot(player) })
end

function PetManager.FusePet(player, petUidOrPetId)
	if type(petUidOrPetId) ~= "string" or petUidOrPetId == "" then
		return makeResponse(false, "InvalidPet")
	end

	local inventory = getInventoryFolder(player)
	if not inventory then
		return makeResponse(false, "DataMissing")
	end

	local targetPetId = petUidOrPetId
	local selectedFolder = getPetFolder(player, petUidOrPetId)
	if selectedFolder then
		local selectedData = readPetFolder(selectedFolder)
		targetPetId = selectedData and selectedData.PetId or petUidOrPetId
	end

	if not GameData.GetPet(targetPetId) then
		return makeResponse(false, "InvalidPet")
	end

	local candidates = {}
	local equippedNormalCount = 0
	for _, petFolder in ipairs(inventory:GetChildren()) do
		if petFolder:IsA("Folder") then
			local petData = readPetFolder(petFolder)
			if petData and petData.PetId == targetPetId and petData.Variant == "Normal" then
				if isEquipped(player, petData.Uid) then
					equippedNormalCount += 1
				else
					table.insert(candidates, petFolder)
				end
			end
		end
	end

	if #candidates < 3 then
		local snapshot = PetManager.GetSnapshot(player)
		local reason = equippedNormalCount > 0 and "FuseEquipped" or "NotEnoughDuplicates"
		remotes.PetError:FireClient(player, reason, snapshot)
		return makeResponse(false, reason, { Pets = snapshot })
	end

	for index = 1, 3 do
		candidates[index]:Destroy()
	end

	local goldenPet = addPetToInventory(player, targetPetId, "Golden")
	refreshPlayer(player)

	return makeResponse(true, "Fused", {
		Pet = goldenPet,
		Pets = PetManager.GetSnapshot(player),
		TotalBuffs = PetManager.GetPetBuffs(player),
	})
end

remotes.HatchEgg.OnServerInvoke = function(player, eggId)
	return PetManager.HatchEgg(player, eggId)
end

remotes.EquipPet.OnServerInvoke = function(player, petUid)
	return PetManager.EquipPet(player, petUid)
end

remotes.UnequipPet.OnServerInvoke = function(player, petUid)
	return PetManager.UnequipPet(player, petUid)
end

remotes.DestroyPet.OnServerInvoke = function(player, petUid)
	return PetManager.DestroyPet(player, petUid)
end

remotes.FusePet.OnServerInvoke = function(player, petUidOrPetId)
	return PetManager.FusePet(player, petUidOrPetId)
end

_G.GEI.PetManager = PetManager

local function syncPlayer(player)
	local PlayerManager = waitForPlayerManager()
	local startTime = os.clock()
	while player.Parent and not PlayerManager.GetDataFolder(player) and os.clock() - startTime < 15 do
		task.wait(0.1)
	end

	if player.Parent and PlayerManager.GetDataFolder(player) then
		refreshPlayer(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.defer(syncPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(syncPlayer, player)
end
