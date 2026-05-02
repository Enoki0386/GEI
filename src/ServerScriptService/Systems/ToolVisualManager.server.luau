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

local function waitForDataFolder(player)
	local dataFolder = player:FindFirstChild("PlayerData")
	local startTime = os.clock()

	while not dataFolder and os.clock() - startTime < 10 do
		task.wait(0.1)
		dataFolder = player:FindFirstChild("PlayerData")
	end

	return dataFolder
end

local function getHand(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
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

local function attachTool(player)
	local character = player.Character
	if not character then
		return
	end

	local hand = getHand(character)
	if not hand then
		return
	end

	local dataFolder = waitForDataFolder(player)
	local equippedTool = dataFolder and dataFolder:FindFirstChild("EquippedTool")
	local toolConfig = equippedTool and GameData.GetTool(equippedTool.Value) or GameData.GetTool("Brush")
	if not toolConfig then
		return
	end

	local oldVisual = character:FindFirstChild("GEIToolVisual")
	if oldVisual then
		oldVisual:Destroy()
	end

	local visualConfig = toolConfig.Visual or {}
	local gripOffset = visualConfig.GripOffset or DEFAULT_GRIP
	local handleColor = visualConfig.HandleColor or toolConfig.Color
	local bristleColor = visualConfig.BristleColor or Color3.fromRGB(235, 238, 228)

	local model = Instance.new("Model")
	model.Name = "GEIToolVisual"
	model:SetAttribute("ToolId", toolConfig.Id)
	model.Parent = character

	local handle = createPart("Handle", Vector3.new(0.22, 1.65, 0.22), handleColor, Enum.Material.Wood, model)
	handle.Shape = Enum.PartType.Cylinder
	handle.CFrame = hand.CFrame * gripOffset

	local head = createPart("BrushHead", Vector3.new(0.9, 0.26, 0.38), Color3.fromRGB(58, 65, 68), Enum.Material.SmoothPlastic, model)
	head.CFrame = handle.CFrame * CFrame.new(0, -0.95, 0)
	weldTo(handle, head)

	for index = 1, 5 do
		local bristle = createPart("Bristle_" .. tostring(index), Vector3.new(0.12, 0.38, 0.08), bristleColor, Enum.Material.SmoothPlastic, model)
		bristle.CFrame = head.CFrame * CFrame.new(-0.28 + (index - 1) * 0.14, -0.32, 0)
		weldTo(head, bristle)
	end

	local toolWeld = Instance.new("Weld")
	toolWeld.Name = "ToolWeld"
	toolWeld.Part0 = hand
	toolWeld.Part1 = handle
	toolWeld.C0 = gripOffset
	toolWeld.C1 = CFrame.new()
	toolWeld.Parent = model

	model.PrimaryPart = handle
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.35)
		attachTool(player)
	end)

	if player.Character then
		task.defer(attachTool, player)
	end

	task.spawn(function()
		local dataFolder = waitForDataFolder(player)
		local equippedTool = dataFolder and dataFolder:FindFirstChild("EquippedTool")
		if equippedTool then
			equippedTool.Changed:Connect(function()
				attachTool(player)
			end)
		end
	end)
end

_G.GEI.ToolVisualManager = {
	Attach = attachTool,
}

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(watchPlayer, player)
end
