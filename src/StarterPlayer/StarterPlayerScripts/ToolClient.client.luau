local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. ToolClient stopped.")
	return
end

local GameData = require(gameDataModule)
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotes then
	warn("[GEI] Remotes folder is missing. ToolClient stopped.")
	return
end

local requestAttackRemote = remotes:WaitForChild("RequestAttack", 10)
local equipItemRemote = remotes:WaitForChild("EquipItem", 10)
local attackFeedbackRemote = remotes:WaitForChild("AttackFeedback", 10)
local playerData = player:WaitForChild("PlayerData", 10)

if not requestAttackRemote or not equipItemRemote or not playerData then
	warn("[GEI] ToolClient could not find required remotes or PlayerData.")
	return
end

local localCooldownUntil = 0

local function getRootPart()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getEquippedToolConfig()
	local equippedTool = playerData:FindFirstChild("EquippedTool")
	local toolId = equippedTool and equippedTool.Value or "Brush"
	return GameData.GetTool(toolId)
end

local function getToolRange()
	local toolRange = playerData:FindFirstChild("ToolRange")
	if toolRange then
		return toolRange.Value
	end

	local toolConfig = getEquippedToolConfig()
	return toolConfig and toolConfig.Range or 16
end

local function getWasteModelFromInstance(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end

	local current = instance
	while current and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("GEIWasteNode") then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function isWasteAttackable(wasteModel, root, range)
	if not wasteModel or not wasteModel.Parent then
		return false
	end

	local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
	if not hitbox then
		return false
	end

	local currentHP = wasteModel:GetAttribute("CurrentHP")
	if type(currentHP) ~= "number" or currentHP <= 0 then
		return false
	end

	return (root.Position - hitbox.Position).Magnitude <= range + math.max(hitbox.Size.X, hitbox.Size.Z) / 2
end

local function findNearestWaste()
	local root = getRootPart()
	if not root then
		return nil
	end

	local wasteZone = Workspace:FindFirstChild(GameData.Spawn.WasteZoneName)
	if not wasteZone then
		return nil
	end

	local range = getToolRange()
	local mousePosition = mouse.Hit and mouse.Hit.Position or root.Position
	local bestModel = nil
	local bestScore = math.huge

	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
			if hitbox and isWasteAttackable(wasteModel, root, range) then
				local playerDistance = (root.Position - hitbox.Position).Magnitude
				local mouseDistance = (mousePosition - hitbox.Position).Magnitude
				local score = playerDistance + mouseDistance * 0.25
				if score < bestScore then
					bestScore = score
					bestModel = wasteModel
				end
			end
		end
	end

	return bestModel
end

local function findTarget()
	local root = getRootPart()
	if not root then
		return nil
	end

	local range = getToolRange()
	local mouseTargetModel = getWasteModelFromInstance(mouse.Target)
	if mouseTargetModel and isWasteAttackable(mouseTargetModel, root, range) then
		return mouseTargetModel
	end

	return findNearestWaste()
end

local function playTargetFlash(target)
	if not target then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "AttackFlash"
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(255, 235, 151)
	highlight.OutlineTransparency = 0.05
	highlight.Parent = target
	Debris:AddItem(highlight, 0.12)
end

local function requestAttack()
	local now = os.clock()
	local toolConfig = getEquippedToolConfig()
	if not toolConfig or now < localCooldownUntil then
		return
	end

	local target = findTarget()
	if not target then
		return
	end

	localCooldownUntil = now + math.max(0.08, toolConfig.Cooldown * 0.65)
	playTargetFlash(target)
	requestAttackRemote:FireServer(target)
end

local function equipFirstToolSlot()
	local ownedTools = playerData:FindFirstChild("OwnedTools")
	if not ownedTools then
		return
	end

	for _, toolId in ipairs(GameData.ToolOrder) do
		local ownedValue = ownedTools:FindFirstChild(toolId)
		if ownedValue and ownedValue:IsA("BoolValue") and ownedValue.Value == true then
			equipItemRemote:FireServer("Tool", toolId)
			return
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		requestAttack()
	elseif input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.KeypadOne then
		equipFirstToolSlot()
	end
end)

if attackFeedbackRemote then
	attackFeedbackRemote.OnClientEvent:Connect(function(feedback)
		if type(feedback) == "table" and feedback.Target then
			playTargetFlash(feedback.Target)
		end
	end)
end

RunService.RenderStepped:Connect(function()
	local root = getRootPart()
	local wasteZone = Workspace:FindFirstChild(GameData.Spawn.WasteZoneName)
	if not root or not wasteZone then
		return
	end

	local range = getToolRange()
	local timeNow = os.clock()

	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
			local ring = wasteModel:FindFirstChild("RangeRing")
			if hitbox and ring then
				local radius = math.clamp(wasteModel:GetAttribute("RingRadius") or GameData.Spawn.DefaultRingRadius, 4, GameData.Spawn.MaxRingRadius)
				local inRange = (root.Position - hitbox.Position).Magnitude <= range + math.max(hitbox.Size.X, hitbox.Size.Z) / 2
				local visualRadius = radius + (inRange and 0.45 or 0)
				local center = Vector3.new(hitbox.Position.X, hitbox.Position.Y - hitbox.Size.Y / 2 + 0.12, hitbox.Position.Z)

				for _, segment in ipairs(ring:GetChildren()) do
					if segment:IsA("BasePart") then
						local baseLength = segment:GetAttribute("BaseLength")
						local baseDepth = segment:GetAttribute("BaseDepth")
						if not baseLength then
							baseLength = segment.Size.X
							baseDepth = segment.Size.Z
							segment:SetAttribute("BaseLength", baseLength)
							segment:SetAttribute("BaseDepth", baseDepth)
						end

						local index = segment:GetAttribute("SegmentIndex") or 1
						local count = segment:GetAttribute("SegmentCount") or GameData.Spawn.RingSegmentCount
						local angle = ((index - 1) / count) * math.pi * 2 + timeNow * 0.42
						segment.Size = Vector3.new(baseLength * (inRange and 1.15 or 1), 0.08, baseDepth * (inRange and 1.35 or 1))
						segment.Transparency = inRange and 0.12 or 0.42
						segment.CFrame = CFrame.new(center)
							* CFrame.Angles(0, angle, 0)
							* CFrame.new(0, 0, -visualRadius)
							* CFrame.Angles(0, math.pi / 2, 0)
					end
				end
			end
		end
	end
end)
