local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local activeGripTweens = {}

local function getRootPart()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getEquippedToolId()
	local equippedTool = playerData:FindFirstChild("EquippedTool")
	return equippedTool and equippedTool.Value or "Brush"
end

local function getEquippedToolConfig()
	return GameData.GetTool(getEquippedToolId())
end

local function getEquippedNativeTool()
	local character = player.Character
	if not character then
		return nil
	end

	local tool = character:FindFirstChild(getEquippedToolId())
	if tool and tool:IsA("Tool") and tool:GetAttribute("GEINativeTool") == true then
		return tool
	end

	return nil
end

local function isToolEquipped()
	local equippedValue = playerData:FindFirstChild("IsToolEquipped")
	return equippedValue ~= nil and equippedValue.Value == true and getEquippedNativeTool() ~= nil
end

local function getHorizontalDistance(a, b)
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function calculateFallbackInteractionRadius(hitbox)
	local interactionConfig = GameData.Interaction or {}
	local halfSurface = math.max(hitbox.Size.X, hitbox.Size.Z) / 2
	local extraRange = interactionConfig.ExtraRangeFromSurface or 2.5
	local minRange = interactionConfig.MinRange or 4
	local maxRange = interactionConfig.MaxRange or 12
	return math.clamp(halfSurface + extraRange, minRange, maxRange)
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

local function isWasteAttackable(wasteModel, root)
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

	local interactionRadius = wasteModel:GetAttribute("InteractionRadius") or calculateFallbackInteractionRadius(hitbox)
	return getHorizontalDistance(root.Position, hitbox.Position) <= interactionRadius
end

local function findNearestWaste()
	local root = getRootPart()
	if not root or not isToolEquipped() then
		return nil
	end

	local wasteZone = Workspace:FindFirstChild(GameData.Spawn.WasteZoneName)
	if not wasteZone then
		return nil
	end

	local mousePosition = mouse.Hit and mouse.Hit.Position or root.Position
	local bestModel = nil
	local bestScore = math.huge

	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
			if hitbox and isWasteAttackable(wasteModel, root) then
				local playerDistance = getHorizontalDistance(root.Position, hitbox.Position)
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
	if not root or not isToolEquipped() then
		return nil
	end

	local mouseTargetModel = getWasteModelFromInstance(mouse.Target)
	if mouseTargetModel and isWasteAttackable(mouseTargetModel, root) then
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

local function getAnimationId()
	local animations = GameData.Animations or {}
	local animationId = animations.BrushSwing
	if type(animationId) ~= "string" or animationId == "" or animationId == "0" or animationId == "rbxassetid://0" then
		return nil
	end

	return animationId
end

local function tryPlayRobloxAnimation()
	local animationId = getAnimationId()
	if not animationId then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if humanoid and not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	if not humanoid or not animator then
		return false
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local ok, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok or not trackOrError then
		warn("[ToolClient] Could not load Brush swing animation. Fallback swing will be used:", trackOrError)
		animation:Destroy()
		return false
	end

	local track = trackOrError
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.04)

	task.delay(1.2, function()
		if track.IsPlaying then
			track:Stop(0.08)
		end
		track:Destroy()
		animation:Destroy()
	end)

	return true
end

local function playNativeToolEffects(tool)
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle then
		return
	end

	local particles = handle:FindFirstChild("SwingParticles")
	if particles and particles:IsA("ParticleEmitter") then
		particles:Emit(6)
	end

	local sound = handle:FindFirstChild("HitSound")
	if sound and sound:IsA("Sound") and sound.SoundId ~= "" and sound.SoundId ~= "rbxassetid://0" then
		sound:Play()
	end
end

local function playFallbackSwing(tool, toolConfig)
	if not tool or not toolConfig then
		return
	end

	if activeGripTweens[tool] then
		activeGripTweens[tool]:Cancel()
		activeGripTweens[tool] = nil
	end

	local visualConfig = toolConfig.Visual or {}
	local baseGrip = visualConfig.GripOffset or tool.Grip
	local swingOffset = visualConfig.SwingOffset or (CFrame.new(0, -0.1, -0.45) * CFrame.Angles(math.rad(-30), 0, math.rad(-12)))
	tool.Grip = baseGrip

	local outTween = TweenService:Create(tool, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Grip = baseGrip * swingOffset,
	})
	local inTween = TweenService:Create(tool, TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Grip = baseGrip,
	})

	activeGripTweens[tool] = outTween
	outTween:Play()
	outTween.Completed:Connect(function()
		if tool.Parent then
			activeGripTweens[tool] = inTween
			inTween:Play()
		end
	end)
	inTween.Completed:Connect(function()
		if activeGripTweens[tool] == inTween then
			activeGripTweens[tool] = nil
		end
	end)
end

local function playToolSwing()
	local tool = getEquippedNativeTool()
	local toolConfig = getEquippedToolConfig()
	if not tool or not toolConfig then
		return
	end

	playNativeToolEffects(tool)
	if not tryPlayRobloxAnimation() then
		playFallbackSwing(tool, toolConfig)
	end
end

local function requestAttack()
	local now = os.clock()
	local toolConfig = getEquippedToolConfig()
	if not toolConfig or not isToolEquipped() or now < localCooldownUntil then
		return
	end

	local target = findTarget()
	if not target then
		return
	end

	localCooldownUntil = now + math.max(0.08, toolConfig.Cooldown * 0.65)
	playToolSwing()
	playTargetFlash(target)
	requestAttackRemote:FireServer(target)
end

local function toggleFirstToolSlot()
	local ownedTools = playerData:FindFirstChild("OwnedTools")
	if not ownedTools then
		return
	end

	for _, toolId in ipairs(GameData.ToolOrder) do
		local ownedValue = ownedTools:FindFirstChild(toolId)
		if ownedValue and ownedValue:IsA("BoolValue") and ownedValue.Value == true then
			equipItemRemote:FireServer("Tool", toolId, "Toggle")
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
		toggleFirstToolSlot()
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

	local timeNow = os.clock()
	local ringConfig = GameData.InteractionCircle

	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
			local ring = wasteModel:FindFirstChild("RangeRing")
			if hitbox and ring then
				local distanceToWaste = getHorizontalDistance(root.Position, hitbox.Position)
				local visible = distanceToWaste <= ringConfig.DisplayDistance
				local radius = wasteModel:GetAttribute("InteractionRadius") or calculateFallbackInteractionRadius(hitbox)
				local inRange = distanceToWaste <= radius
				local visualRadius = radius
				local center = Vector3.new(hitbox.Position.X, hitbox.Position.Y - hitbox.Size.Y / 2 + ringConfig.HeightOffset, hitbox.Position.Z)

				for _, segment in ipairs(ring:GetChildren()) do
					if segment:IsA("BasePart") then
						local baseLength = segment:GetAttribute("BaseLength") or segment.Size.X
						local baseThickness = segment:GetAttribute("BaseThickness") or ringConfig.Thickness
						local index = segment:GetAttribute("SegmentIndex") or 1
						local count = segment:GetAttribute("SegmentCount") or ringConfig.SegmentCount
						local angle = ((index - 1) / count) * math.pi * 2 + timeNow * math.rad(ringConfig.RotationSpeed)

						segment.Size = Vector3.new(
							baseLength * (inRange and ringConfig.InRangeScale or 1),
							baseThickness * (inRange and 1.25 or 1),
							baseThickness * (inRange and 1.25 or 1)
						)
						segment.Color = inRange and ringConfig.InRangeColor or ringConfig.Color
						segment.Transparency = visible and (inRange and ringConfig.InRangeTransparency or ringConfig.IdleTransparency) or 1
						segment.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * visualRadius, 0, math.sin(angle) * visualRadius))
							* CFrame.Angles(0, -angle - math.pi / 2, 0)
					end
				end
			end
		end
	end
end)
