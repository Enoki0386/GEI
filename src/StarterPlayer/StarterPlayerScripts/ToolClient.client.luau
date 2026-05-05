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
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local soundUtilModule = sharedFolder and sharedFolder:WaitForChild("SoundUtil", 10)
local SoundUtil = soundUtilModule and require(soundUtilModule)
local workspaceUtilModule = sharedFolder and sharedFolder:WaitForChild("WorkspaceUtil", 10)
local WorkspaceUtil = workspaceUtilModule and require(workspaceUtilModule)
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotes then
	warn("[GEI] Remotes folder is missing. ToolClient stopped.")
	return
end

local requestAttackRemote = remotes:WaitForChild("RequestAttack", 10)
local attackFeedbackRemote = remotes:WaitForChild("AttackFeedback", 10)
local playerData = player:WaitForChild("PlayerData", 60)

if not requestAttackRemote or not playerData then
	warn("[GEI] ToolClient could not find required remotes or PlayerData.")
	return
end

local localCooldownUntil = 0
local isPrimaryAttackDown = false
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

local function vectorFromAttributes(instance, prefix)
	local x = instance:GetAttribute(prefix .. "X")
	local y = instance:GetAttribute(prefix .. "Y")
	local z = instance:GetAttribute(prefix .. "Z")
	if type(x) == "number" and type(y) == "number" and type(z) == "number" then
		return Vector3.new(x, y, z)
	end

	return nil
end

local function getWasteCenter(wasteModel)
	local center = vectorFromAttributes(wasteModel, "InteractionCenter")
	if center then
		return center
	end

	local primaryPart = wasteModel.PrimaryPart
	return primaryPart and primaryPart.Position or nil
end

local function getWasteSize(wasteModel)
	local size = vectorFromAttributes(wasteModel, "InteractionSize")
	if size then
		return size
	end

	local primaryPart = wasteModel.PrimaryPart
	return primaryPart and primaryPart.Size or nil
end

local function calculateFallbackInteractionRadius(size)
	local interactionConfig = GameData.Interaction or {}
	local halfSurface = math.max(size.X, size.Z) / 2
	local extraRange = interactionConfig.ExtraRangeFromSurface or 2.5
	local minRange = interactionConfig.MinRange or 3.5
	local maxRange = interactionConfig.MaxRange or 9
	return math.clamp(halfSurface + extraRange, minRange, maxRange)
end

local function getWasteZone()
	if WorkspaceUtil then
		return WorkspaceUtil.Find(GameData.Spawn.WasteZoneName, GameData.Spawn.WasteZoneFolders, { SearchDescendants = false })
	end

	return Workspace:FindFirstChild(GameData.Spawn.WasteZoneName)
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

	local center = getWasteCenter(wasteModel)
	local size = getWasteSize(wasteModel)
	if not center or not size then
		return false
	end

	local currentHP = wasteModel:GetAttribute("CurrentHP")
	if type(currentHP) ~= "number" or currentHP <= 0 then
		return false
	end

	local interactionRadius = wasteModel:GetAttribute("InteractionRadius") or calculateFallbackInteractionRadius(size)
	return getHorizontalDistance(root.Position, center) <= interactionRadius
end

local function findNearestWaste()
	local root = getRootPart()
	if not root or not isToolEquipped() then
		return nil
	end

	local wasteZone = getWasteZone()
	if not wasteZone then
		return nil
	end

	local mousePosition = mouse.Hit and mouse.Hit.Position or root.Position
	local bestModel = nil
	local bestScore = math.huge

	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			local center = getWasteCenter(wasteModel)
			if center and isWasteAttackable(wasteModel, root) then
				local playerDistance = getHorizontalDistance(root.Position, center)
				local mouseDistance = (mousePosition - center).Magnitude
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
	local baseGrip = tool.Grip
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isPrimaryAttackDown = true
		requestAttack()
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isPrimaryAttackDown = false
	end
end)

if attackFeedbackRemote then
	attackFeedbackRemote.OnClientEvent:Connect(function(feedback)
		if type(feedback) == "table" and (feedback.Reason == "OutOfRange" or feedback.Reason == "ToolUnequipped") then
			localCooldownUntil = 0
		end
		if type(feedback) == "table" and feedback.Target and (feedback.Damage or feedback.Destroyed) then
			if SoundUtil then
				SoundUtil.Play(feedback.Destroyed and "Break" or "Hit", GameData, feedback.Target.PrimaryPart)
			end
			playTargetFlash(feedback.Target)
		end
	end)
end

RunService.RenderStepped:Connect(function()
	if isPrimaryAttackDown then
		requestAttack()
	end

	local root = getRootPart()
	local wasteZone = getWasteZone()
	if not root or not wasteZone then
		return
	end

	local timeNow = os.clock()
	local ringConfig = GameData.InteractionCircle

	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			local center = getWasteCenter(wasteModel)
			local size = getWasteSize(wasteModel)
			local ring = wasteModel:FindFirstChild("RangeRing")
			if center and size and ring then
				local distanceToWaste = getHorizontalDistance(root.Position, center)
				local visible = distanceToWaste <= ringConfig.DisplayDistance
				local radius = wasteModel:GetAttribute("InteractionRadius") or calculateFallbackInteractionRadius(size)
				local inRange = distanceToWaste <= radius
				local visualRadius = radius
				local ringCenter = center

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
						segment.CFrame = CFrame.new(ringCenter + Vector3.new(math.cos(angle) * visualRadius, 0, math.sin(angle) * visualRadius))
							* CFrame.Angles(0, -angle - math.pi / 2, 0)
					end
				end
			end
		end
	end
end)
