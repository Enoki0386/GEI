local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. ToolVisualManager stopped.")
	return
end

local GameData = require(gameDataModule)

_G.GEI = _G.GEI or {}

local DEFAULT_GRIP = CFrame.new(0.55, -0.75, -0.35) * CFrame.Angles(math.rad(-70), math.rad(18), math.rad(12))

local function getToolsFolder()
	local folder = ReplicatedStorage:FindFirstChild("Tools")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Tools"
		folder.Parent = ReplicatedStorage
	end

	return folder
end

local function createPart(name, size, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = color
	part.Massless = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.Size = size
	part.Parent = parent
	return part
end

local function weldTo(part0, part1)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
	return weld
end

local function createFallbackTool(toolConfig)
	local visualConfig = toolConfig.Visual or {}
	local handleColor = visualConfig.HandleColor or toolConfig.Color
	local bristleColor = visualConfig.BristleColor or Color3.fromRGB(235, 238, 228)

	local tool = Instance.new("Tool")
	tool.Name = toolConfig.Id
	tool.ToolTip = toolConfig.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = visualConfig.GripOffset or DEFAULT_GRIP
	tool:SetAttribute("ToolId", toolConfig.Id)
	tool:SetAttribute("GEINativeTool", true)

	local handle = createPart("Handle", Vector3.new(0.22, 1.65, 0.22), handleColor, Enum.Material.Wood, tool)
	handle.Shape = Enum.PartType.Cylinder

	local head = createPart("BrushHead", Vector3.new(0.9, 0.26, 0.38), Color3.fromRGB(58, 65, 68), Enum.Material.SmoothPlastic, tool)
	head.CFrame = handle.CFrame * CFrame.new(0, -0.95, 0)
	weldTo(handle, head)

	for index = 1, 5 do
		local bristle = createPart("Bristle_" .. tostring(index), Vector3.new(0.12, 0.38, 0.08), bristleColor, Enum.Material.SmoothPlastic, tool)
		bristle.CFrame = head.CFrame * CFrame.new(-0.28 + (index - 1) * 0.14, -0.32, 0)
		weldTo(head, bristle)
	end

	local hitSound = Instance.new("Sound")
	hitSound.Name = "HitSound"
	hitSound.SoundId = "rbxassetid://0"
	hitSound.Volume = 0.25
	hitSound.Parent = handle

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "SwingParticles"
	particles.Enabled = false
	particles.LightEmission = 0.4
	particles.Lifetime = NumberRange.new(0.12, 0.22)
	particles.Rate = 0
	particles.Speed = NumberRange.new(3, 6)
	particles.SpreadAngle = Vector2.new(35, 35)
	particles.Parent = handle

	return tool
end

local function ensureToolTemplate(toolId)
	local toolConfig = GameData.GetTool(toolId)
	if not toolConfig then
		return nil
	end

	local toolsFolder = getToolsFolder()
	local existing = toolsFolder:FindFirstChild(toolId)
	if existing and existing:IsA("Tool") and existing:FindFirstChild("Handle") then
		existing.CanBeDropped = false
		existing:SetAttribute("ToolId", toolId)
		existing:SetAttribute("GEINativeTool", true)
		return existing
	end

	if existing then
		warn("[ToolVisualManager] ReplicatedStorage.Tools." .. toolId .. " exists but is not a Tool with a Handle. Using fallback Tool.")
		existing:Destroy()
	end

	local tool = createFallbackTool(toolConfig)
	tool.Parent = toolsFolder
	return tool
end

local function waitForDataFolder(player)
	local dataFolder = player:FindFirstChild("PlayerData")
	local startTime = os.clock()

	while not dataFolder and os.clock() - startTime < 10 do
		task.wait(0.1)
		dataFolder = player:FindFirstChild("PlayerData")
	end

	return dataFolder
end

local function playerOwnsTool(player, toolId)
	local dataFolder = player:FindFirstChild("PlayerData")
	local ownedTools = dataFolder and dataFolder:FindFirstChild("OwnedTools")
	local ownedValue = ownedTools and ownedTools:FindFirstChild(toolId)
	return ownedValue and ownedValue:IsA("BoolValue") and ownedValue.Value == true
end

local function removeOldCustomVisual(character)
	local oldVisual = character and character:FindFirstChild("GEIToolVisual")
	if oldVisual then
		oldVisual:Destroy()
	end
end

local function getToolInstance(player, toolId)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = character and character:FindFirstChild(toolId)
	if tool and tool:IsA("Tool") then
		return tool
	end

	tool = backpack and backpack:FindFirstChild(toolId)
	if tool and tool:IsA("Tool") then
		return tool
	end

	return nil
end

local function applyNativeToolState(player, toolId, equipped)
	local PlayerManager = _G.GEI and _G.GEI.PlayerManager
	if PlayerManager and PlayerManager.ApplyNativeToolState then
		PlayerManager.ApplyNativeToolState(player, toolId, equipped)
	end
end

local function hasAnyEquippedNativeTool(player)
	local character = player.Character
	if not character then
		return false
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("GEINativeTool") == true then
			return true
		end
	end

	return false
end

local function bindToolSignals(player, tool)
	if tool:GetAttribute("GEIToolSignalsBound") == true then
		return
	end

	tool:SetAttribute("GEIToolSignalsBound", true)

	tool.Equipped:Connect(function()
		local toolId = tool:GetAttribute("ToolId") or tool.Name
		applyNativeToolState(player, toolId, true)
	end)

	tool.Unequipped:Connect(function()
		local toolId = tool:GetAttribute("ToolId") or tool.Name
		task.defer(function()
			if not hasAnyEquippedNativeTool(player) then
				applyNativeToolState(player, toolId, false)
			end
		end)
	end)
end

local function syncInventory(player)
	local dataFolder = waitForDataFolder(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not dataFolder or not backpack then
		return
	end

	local character = player.Character
	removeOldCustomVisual(character)

	local ownedTools = dataFolder:FindFirstChild("OwnedTools")
	if not ownedTools then
		return
	end

	for _, toolId in ipairs(GameData.ToolOrder) do
		local ownedValue = ownedTools:FindFirstChild(toolId)
		local owns = ownedValue and ownedValue:IsA("BoolValue") and ownedValue.Value == true
		local existing = getToolInstance(player, toolId)

		if owns then
			if not existing then
				local template = ensureToolTemplate(toolId)
				if template then
					local clone = template:Clone()
					clone:SetAttribute("GEIToolSignalsBound", nil)
					clone.Parent = backpack
					bindToolSignals(player, clone)
				end
			else
				bindToolSignals(player, existing)
			end
		elseif existing then
			existing:Destroy()
		end
	end
end

local function equipTool(player, toolId)
	if not playerOwnsTool(player, toolId) then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not humanoid or not backpack then
		return false
	end

	syncInventory(player)
	local tool = getToolInstance(player, toolId)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	humanoid:UnequipTools()
	if tool.Parent ~= backpack and tool.Parent ~= character then
		tool.Parent = backpack
	end

	humanoid:EquipTool(tool)
	return tool.Parent == character
end

local function unequipTool(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end

	return true
end

local function watchPlayer(player)
	for _, toolId in ipairs(GameData.ToolOrder) do
		ensureToolTemplate(toolId)
	end

	player.CharacterAdded:Connect(function()
		task.wait(0.35)
		syncInventory(player)

		local dataFolder = player:FindFirstChild("PlayerData")
		local equippedTool = dataFolder and dataFolder:FindFirstChild("EquippedTool")
		local isToolEquipped = dataFolder and dataFolder:FindFirstChild("IsToolEquipped")
		if equippedTool and isToolEquipped and isToolEquipped.Value == true then
			equipTool(player, equippedTool.Value)
		end
	end)

	task.spawn(function()
		local dataFolder = waitForDataFolder(player)
		if not dataFolder then
			return
		end

		syncInventory(player)

		local ownedTools = dataFolder:FindFirstChild("OwnedTools")
		if ownedTools then
			ownedTools.ChildAdded:Connect(function()
				syncInventory(player)
			end)
			ownedTools.ChildRemoved:Connect(function()
				syncInventory(player)
			end)
		end
	end)
end

_G.GEI.ToolVisualManager = {
	SyncInventory = syncInventory,
	Equip = equipTool,
	Unequip = unequipTool,
}

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(watchPlayer, player)
end
