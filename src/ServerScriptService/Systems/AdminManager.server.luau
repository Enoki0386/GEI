local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local World1Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World1Data"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemoteFunction(name)
	local remote = remotes:FindFirstChild(name)
	if remote and not remote:IsA("RemoteFunction") then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local adminCommandRemote = ensureRemoteFunction("AdminCommand")
local adminCheckRemote = ensureRemoteFunction("AdminCheck")

local function getPlayerData(player)
	return player:FindFirstChild("PlayerData")
end

local function getLeaderValue(player, name)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	return value and value:IsA("IntValue") and value or nil
end

local function clampInt(value, minValue, maxValue)
	value = math.floor(tonumber(value) or 0)
	if maxValue then
		value = math.min(value, maxValue)
	end
	return math.max(minValue or 0, value)
end

local function addCurrency(player, name, amount)
	local value = getLeaderValue(player, name)
	if not value then
		return false, "Missing " .. name
	end
	value.Value = math.max(0, value.Value + clampInt(amount, -1000000000, 1000000000))
	return true, name .. " updated"
end

local function setWaste(player, mode)
	local data = getPlayerData(player)
	local waste = data and data:FindFirstChild("WasteCount")
	local maxWaste = data and data:FindFirstChild("MaxWaste")
	if not waste or not maxWaste then
		return false, "Missing backpack data"
	end
	if mode == "fill" then
		waste.Value = maxWaste.Value
	else
		waste.Value = 0
		local inventory = data:FindFirstChild("WasteInventory")
		if inventory then
			for _, child in ipairs(inventory:GetChildren()) do
				if child:IsA("IntValue") then
					child.Value = 0
				end
			end
		end
	end
	return true, "Waste updated"
end

local function giveTool(player, toolId)
	local tool = GameData.GetTool(toolId)
	local data = getPlayerData(player)
	local owned = data and data:FindFirstChild("OwnedTools")
	if not tool or not owned then
		return false, "Tool unavailable"
	end
	local value = owned:FindFirstChild(toolId) or Instance.new("BoolValue")
	value.Name = toolId
	value.Value = true
	value.Parent = owned
	if _G.GEI and _G.GEI.PlayerManager and _G.GEI.PlayerManager.EquipTool then
		_G.GEI.PlayerManager.EquipTool(player, toolId)
	end
	return true, "Tool given"
end

local function giveBackpack(player, backpackId)
	local backpack = GameData.GetBackpack(backpackId)
	local data = getPlayerData(player)
	local owned = data and data:FindFirstChild("OwnedBackpacks")
	if not backpack or not owned then
		return false, "Backpack unavailable"
	end
	local value = owned:FindFirstChild(backpackId) or Instance.new("BoolValue")
	value.Name = backpackId
	value.Value = true
	value.Parent = owned
	if _G.GEI and _G.GEI.PlayerManager and _G.GEI.PlayerManager.EquipBackpack then
		_G.GEI.PlayerManager.EquipBackpack(player, backpackId)
	end
	return true, "Backpack given"
end

local function givePet(player, petId, variant)
	if not (_G.GEI and _G.GEI.PetManager and _G.GEI.PetManager.AdminGivePet) then
		return false, "PetManager admin helper missing"
	end
	return _G.GEI.PetManager.AdminGivePet(player, petId, variant or "Normal")
end

local function unlockZone(player, zoneId)
	if not (_G.GEI and _G.GEI.WorldProgress and _G.GEI.WorldProgress.UnlockZone) then
		return false, "WorldProgress missing"
	end
	return _G.GEI.WorldProgress.UnlockZone(player, zoneId, true)
end

local function unlockAllZones(player)
	if not (_G.GEI and _G.GEI.WorldProgress and _G.GEI.WorldProgress.UnlockAllZones) then
		return false, "WorldProgress missing"
	end
	return _G.GEI.WorldProgress.UnlockAllZones(player)
end

local function resetZones(player)
	if not (_G.GEI and _G.GEI.WorldProgress and _G.GEI.WorldProgress.ResetZones) then
		return false, "WorldProgress missing"
	end
	return _G.GEI.WorldProgress.ResetZones(player)
end

local function teleportTo(player, targetName)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "Character missing"
	end
	local target = workspace:FindFirstChild(targetName, true)
	if target and target:IsA("Model") then
		target = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	if not target or not target:IsA("BasePart") then
		return false, "Target missing"
	end
	root.CFrame = CFrame.new(target.Position + Vector3.new(0, 5, 0))
	return true, "Teleported"
end

adminCheckRemote.OnServerInvoke = function(player)
	return { IsAdmin = World1Data.IsAdmin(player) }
end

adminCommandRemote.OnServerInvoke = function(player, command, payload)
	if not World1Data.IsAdmin(player) then
		warn("[AdminManager] Blocked non-admin command from", player.Name, command)
		return { Success = false, Error = "NotAdmin" }
	end

	payload = type(payload) == "table" and payload or {}
	local ok, message = false, "Unknown command"

	if command == "AddCash" then
		ok, message = addCurrency(player, "Cash", payload.Amount or 10000)
	elseif command == "AddDiamonds" then
		ok, message = addCurrency(player, "Diamonds", payload.Amount or 500)
	elseif command == "FillWaste" then
		ok, message = setWaste(player, "fill")
	elseif command == "ClearWaste" then
		ok, message = setWaste(player, "clear")
	elseif command == "GiveCrusher" then
		ok, message = giveTool(player, "Crusher")
	elseif command == "GiveLargeBag" then
		ok, message = giveBackpack(player, "LargeBag")
	elseif command == "GivePet" then
		ok, message = givePet(player, payload.PetId or "GoldenRaccoon", payload.Variant or "Normal")
	elseif command == "GiveGoldenPet" then
		ok, message = givePet(player, payload.PetId or "GoldenRaccoon", "Golden")
	elseif command == "UnlockZone2" then
		ok, message = unlockZone(player, "Zone2")
	elseif command == "UnlockZone3" then
		ok, message = unlockZone(player, "Zone3")
	elseif command == "UnlockZone4" then
		ok, message = unlockZone(player, "Zone4")
	elseif command == "UnlockAllZones" then
		ok, message = unlockAllZones(player)
	elseif command == "ResetZones" then
		ok, message = resetZones(player)
	elseif command == "Teleport" then
		ok, message = teleportTo(player, payload.Target or "SpawnLocation")
	end

	print(string.format("[AdminManager] %s ran %s -> %s", player.Name, tostring(command), tostring(message)))
	return { Success = ok, Message = message }
end

print("[AdminManager] Loaded. Admin UserId: 1990396002")
