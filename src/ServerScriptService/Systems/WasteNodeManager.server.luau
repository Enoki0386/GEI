local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. WasteNodeManager stopped.")
	return
end

local GameData = require(gameDataModule)
local random = Random.new()
local attackCooldowns = {}
local shownWarnings = {}

local function warnOnce(key, message)
	if shownWarnings[key] then
		return
	end

	shownWarnings[key] = true
	warn(message)
end

local function waitForPlayerManager()
	local startTime = os.clock()
	while not (_G.GEI and _G.GEI.PlayerManager) do
		if os.clock() - startTime > 10 then
			warn("[GEI] Waiting for PlayerManager...")
			startTime = os.clock()
		end
		task.wait(0.1)
	end

	return _G.GEI.PlayerManager
end

local function ensureRemote(remoteName)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild(remoteName)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = remotes
	end

	return remote
end

local function getWasteZone()
	local wasteZone = Workspace:FindFirstChild(GameData.Spawn.WasteZoneName)
	if wasteZone and wasteZone:IsA("Folder") then
		return wasteZone
	end

	if wasteZone then
		warnOnce(
			"WasteZoneWrongType",
			"[WasteNodeManager] Workspace.WasteZone exists but must be a Folder. Replace it manually in Roblox Studio."
		)
	else
		warnOnce(
			"WasteZoneMissing",
			"[WasteNodeManager] Missing Workspace.WasteZone. Create a Folder named WasteZone in Workspace."
		)
	end

	return nil
end

local function getSpawnSurface()
	local surface = Workspace:FindFirstChild(GameData.Spawn.SurfaceName)
	if surface and surface:IsA("BasePart") then
		return surface
	end

	if surface then
		warnOnce(
			"SpawnSurfaceWrongType",
			"[WasteNodeManager] Workspace.SpawnSurface1 exists but must be a Part/BasePart. Replace it manually in Roblox Studio."
		)
	else
		warnOnce(
			"SpawnSurfaceMissing",
			"[WasteNodeManager] Missing Workspace.SpawnSurface1. Create a Part named SpawnSurface1. Recommended size: 80, 1, 60."
		)
	end

	return nil
end

local function fireClient(player, remoteName, ...)
	local remote = ensureRemote(remoteName)
	remote:FireClient(player, ...)
end

local function getRootPart(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getHorizontalDistance(a, b)
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function calculateInteractionRadius(size)
	local interactionConfig = GameData.Interaction or {}
	local halfSurface = math.max(size.X, size.Z) / 2
	local extraRange = interactionConfig.ExtraRangeFromSurface or 2.5
	local minRange = interactionConfig.MinRange or 4
	local maxRange = interactionConfig.MaxRange or 12
	return math.clamp(halfSurface + extraRange, minRange, maxRange)
end

local function getRandomHPForWaste(wasteConfig)
	local hpRanges = GameData.WasteHPByRarity or {}
	local range = hpRanges[wasteConfig.Rarity]
	if range and type(range.Min) == "number" and type(range.Max) == "number" then
		local minHP = math.floor(math.min(range.Min, range.Max))
		local maxHP = math.floor(math.max(range.Min, range.Max))
		return random:NextInteger(minHP, maxHP)
	end

	return math.max(1, math.floor(wasteConfig.MaxHP or 1))
end

local function getRewardWasteForHP(wasteConfig, maxHP)
	local rewardPerHP = wasteConfig.WasteRewardPerHP
	if type(rewardPerHP) == "number" then
		return math.max(1, math.floor(maxHP * rewardPerHP + 0.5))
	end

	return math.max(1, math.floor(wasteConfig.WasteReward or 1))
end

local function getZoneId(surface)
	if surface then
		local zoneId = surface:GetAttribute("ZoneId")
		if type(zoneId) == "string" and zoneId ~= "" then
			return zoneId
		end
	end

	return "Zone1"
end

local function getVisualYOffset(zoneId, rarity)
	local offsets = GameData.WasteVisualOffsets or {}
	local zoneOffsets = offsets[zoneId] or offsets.Zone1
	local yOffset = zoneOffsets and zoneOffsets[rarity]
	if type(yOffset) == "number" then
		return yOffset
	end

	return 1.55
end

local function hasEquippedNativeTool(player, toolId)
	local character = player.Character
	if not character then
		return false
	end

	local tool = character:FindFirstChild(toolId)
	return tool ~= nil and tool:IsA("Tool") and tool:GetAttribute("GEINativeTool") == true
end

local function isFarFromPlayers(position)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = getRootPart(player)
		if root and (root.Position - position).Magnitude < GameData.Spawn.MinDistanceFromPlayers then
			return false
		end
	end

	return true
end

local function isFarFromWaste(position, wasteZone)
	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
			if hitbox and (hitbox.Position - position).Magnitude < GameData.Spawn.MinDistanceBetweenWaste then
				return false
			end
		end
	end

	return true
end

local function countActiveWaste(wasteZone)
	local count = 0
	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			count += 1
		end
	end

	return count
end

local function getTargetWasteCount(surface)
	local spawnConfig = GameData.Spawn
	local density = spawnConfig.DensityPerStud or 0.003
	local minNodes = spawnConfig.MinNodes or 8
	local maxNodes = spawnConfig.MaxNodes or 60
	local area = math.max(0, surface.Size.X * surface.Size.Z)
	return math.clamp(math.floor(area * density + 0.5), minNodes, maxNodes)
end

local function findSpawnPosition(surface, wasteZone)
	local margin = 6
	local halfX = math.max(1, surface.Size.X / 2 - margin)
	local halfZ = math.max(1, surface.Size.Z / 2 - margin)
	local surfaceTopY = surface.Position.Y + surface.Size.Y / 2

	for _ = 1, GameData.Spawn.MaxSpawnAttempts do
		local position = Vector3.new(
			surface.Position.X + random:NextNumber(-halfX, halfX),
			surfaceTopY,
			surface.Position.Z + random:NextNumber(-halfZ, halfZ)
		)

		if isFarFromPlayers(position) and isFarFromWaste(position, wasteZone) then
			return position
		end
	end

	return nil
end

local function createBillboard(hitbox, wasteConfig, maxHP)
	local displayConfig = GameData.WasteDisplay
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WasteBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = displayConfig.BillboardMaxDistance
	billboard.Size = UDim2.fromOffset(displayConfig.BillboardSize.X, displayConfig.BillboardSize.Y)
	billboard.StudsOffset = Vector3.new(0, hitbox.Size.Y / 2 + 2.1, 0)
	billboard.Parent = hitbox

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(22, 25, 27)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Position = UDim2.fromOffset(8, 4)
	nameLabel.Size = UDim2.new(1, -16, 0, 24)
	nameLabel.Text = wasteConfig.Name
	nameLabel.TextColor3 = wasteConfig.AccentColor
	nameLabel.TextScaled = true
	nameLabel.Parent = frame

	local nameConstraint = Instance.new("UITextSizeConstraint")
	nameConstraint.MaxTextSize = 18
	nameConstraint.MinTextSize = 10
	nameConstraint.Parent = nameLabel

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HPLabel"
	hpLabel.BackgroundTransparency = 1
	hpLabel.Font = Enum.Font.GothamBlack
	hpLabel.Position = UDim2.fromOffset(8, 28)
	hpLabel.Size = UDim2.new(1, -16, 0, 26)
	hpLabel.Text = tostring(maxHP)
	hpLabel.TextColor3 = Color3.fromRGB(242, 246, 248)
	hpLabel.TextScaled = true
	hpLabel.Parent = frame

	local hpConstraint = Instance.new("UITextSizeConstraint")
	hpConstraint.MaxTextSize = 24
	hpConstraint.MinTextSize = 10
	hpConstraint.Parent = hpLabel

	local barBack = Instance.new("Frame")
	barBack.Name = "HPBarBack"
	barBack.BackgroundColor3 = Color3.fromRGB(44, 49, 51)
	barBack.BorderSizePixel = 0
	barBack.Position = UDim2.new(0, 12, 1, -16)
	barBack.Size = UDim2.new(1, -24, 0, displayConfig.HPBarHeight)
	barBack.Parent = frame

	local barBackCorner = Instance.new("UICorner")
	barBackCorner.CornerRadius = UDim.new(1, 0)
	barBackCorner.Parent = barBack

	local barFill = Instance.new("Frame")
	barFill.Name = "HPBarFill"
	barFill.BackgroundColor3 = wasteConfig.AccentColor
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.Parent = barBack

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(1, 0)
	barFillCorner.Parent = barFill
end

local function updateHPBillboard(wasteModel)
	local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
	if not hitbox then
		return
	end

	local billboard = hitbox:FindFirstChild("WasteBillboard")
	local frame = billboard and billboard:FindFirstChild("Frame")
	local hpLabel = frame and frame:FindFirstChild("HPLabel")
	local barBack = frame and frame:FindFirstChild("HPBarBack")
	local barFill = barBack and barBack:FindFirstChild("HPBarFill")
	local currentHP = math.max(0, math.floor(wasteModel:GetAttribute("CurrentHP") or 0))
	local maxHP = math.max(1, math.floor(wasteModel:GetAttribute("MaxHP") or 1))

	if hpLabel and hpLabel:IsA("TextLabel") then
		hpLabel.Text = tostring(currentHP)
	end

	if barFill and barFill:IsA("Frame") then
		barFill.Size = UDim2.fromScale(math.clamp(currentHP / maxHP, 0, 1), 1)
	end
end

local function createRangeRing(wasteModel, hitbox, wasteConfig)
	local ringConfig = GameData.InteractionCircle
	local ringFolder = Instance.new("Folder")
	ringFolder.Name = "RangeRing"
	ringFolder.Parent = wasteModel

	local radius = calculateInteractionRadius(hitbox.Size)
	local segmentCount = ringConfig.SegmentCount
	local segmentLength = ((math.pi * 2 * radius) / segmentCount) * ringConfig.SegmentLengthRatio
	local center = Vector3.new(hitbox.Position.X, hitbox.Position.Y - hitbox.Size.Y / 2 + ringConfig.HeightOffset, hitbox.Position.Z)

	wasteModel:SetAttribute("InteractionRadius", radius)
	wasteModel:SetAttribute("RingSegmentCount", segmentCount)

	for index = 1, segmentCount do
		local angle = ((index - 1) / segmentCount) * math.pi * 2
		local segment = Instance.new("Part")
		segment.Name = "RingSegment"
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.Color = ringConfig.Color or wasteConfig.AccentColor
		segment.Material = Enum.Material.Neon
		segment.Size = Vector3.new(segmentLength, ringConfig.Thickness, ringConfig.Thickness)
		segment.Transparency = ringConfig.IdleTransparency
		segment:SetAttribute("SegmentIndex", index)
		segment:SetAttribute("SegmentCount", segmentCount)
		segment:SetAttribute("BaseLength", segmentLength)
		segment:SetAttribute("BaseThickness", ringConfig.Thickness)
		segment.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
			* CFrame.Angles(0, -angle - math.pi / 2, 0)
		segment.Parent = ringFolder
	end
end

local function getWasteVisualSource(wasteConfig)
	if type(wasteConfig.ModelName) ~= "string" or wasteConfig.ModelName == "" then
		return nil
	end

	local modelsFolder = ReplicatedStorage:FindFirstChild("WasteModels")
	local root = modelsFolder and modelsFolder:FindFirstChild(wasteConfig.ModelName)
	if not root then
		return nil
	end

	local variants = {}
	if root:IsA("Folder") then
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder") then
				table.insert(variants, child)
			end
		end

		if #variants == 0 then
			return root
		end
	elseif root:IsA("Model") then
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("Model") or child:IsA("Folder") then
				table.insert(variants, child)
			end
		end

		if #variants == 0 then
			return root
		end
	elseif root:IsA("BasePart") then
		return root
	end

	if #variants == 0 then
		return nil
	end

	return variants[random:NextInteger(1, #variants)]
end

local function setVisualPartProperties(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanQuery = false
		instance.CanTouch = false
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

local function pivotVisualToGround(visual, hitbox, zoneId, rarity)
	local yOffset = getVisualYOffset(zoneId, rarity)
	local groundY = hitbox.Position.Y - hitbox.Size.Y / 2
	local targetCFrame = CFrame.new(hitbox.Position.X, groundY + yOffset, hitbox.Position.Z)

	if visual:IsA("Model") then
		visual:PivotTo(targetCFrame)
	elseif visual:IsA("BasePart") then
		visual.CFrame = targetCFrame
	end
end

local function createConfiguredVisual(wasteModel, hitbox, wasteConfig, zoneId)
	local source = getWasteVisualSource(wasteConfig)
	if not source then
		return false
	end

	if source:IsA("BasePart") then
		local visualPart = source:Clone()
		visualPart.Name = "VisualModel"
		visualPart.Parent = wasteModel
		setVisualPartProperties(visualPart)
		pivotVisualToGround(visualPart, hitbox, zoneId, wasteConfig.Rarity)
	elseif source:IsA("Model") then
		local visualModel = source:Clone()
		visualModel.Name = "VisualModel"
		visualModel.Parent = wasteModel
		setVisualPartProperties(visualModel)
		pivotVisualToGround(visualModel, hitbox, zoneId, wasteConfig.Rarity)
	elseif source:IsA("Folder") then
		local visualModel = Instance.new("Model")
		visualModel.Name = "VisualModel"

		local sourceClone = source:Clone()
		for _, child in ipairs(sourceClone:GetChildren()) do
			child.Parent = visualModel
		end
		sourceClone:Destroy()

		visualModel.Parent = wasteModel
		setVisualPartProperties(visualModel)
		pivotVisualToGround(visualModel, hitbox, zoneId, wasteConfig.Rarity)
	else
		return false
	end

	hitbox.Transparency = 1
	return true
end

local function createFallbackVisual(wasteModel, hitbox, wasteConfig)
	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Anchored = true
	accent.CanCollide = false
	accent.CanTouch = false
	accent.Color = wasteConfig.AccentColor
	accent.Material = Enum.Material.SmoothPlastic
	accent.Position = hitbox.Position + Vector3.new(0.6, hitbox.Size.Y * 0.3, -0.4)
	accent.Shape = Enum.PartType.Ball
	accent.Size = hitbox.Size * 0.42
	accent.Parent = wasteModel
end

local function playHitFeedback(wasteModel)
	local displayConfig = GameData.WasteDisplay
	local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
	if not hitbox then
		return
	end

	local baseSize = hitbox:GetAttribute("BaseSize") or hitbox.Size
	hitbox:SetAttribute("BaseSize", baseSize)

	local originalCFrame = hitbox.CFrame
	local offset = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
	if offset.Magnitude > 0 then
		offset = offset.Unit * displayConfig.HitShakeDistance
	end

	local outTween = TweenService:Create(hitbox, TweenInfo.new(displayConfig.HitTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = originalCFrame + offset,
		Size = baseSize * displayConfig.HitScaleAmount,
	})
	local inTween = TweenService:Create(hitbox, TweenInfo.new(displayConfig.HitTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = originalCFrame,
		Size = baseSize,
	})

	outTween:Play()
	outTween.Completed:Connect(function()
		if hitbox.Parent then
			inTween:Play()
		end
	end)

	local highlight = Instance.new("Highlight")
	highlight.Name = "WasteHitHighlight"
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.58
	highlight.OutlineColor = Color3.fromRGB(255, 238, 131)
	highlight.OutlineTransparency = 0.08
	highlight.Parent = wasteModel
	Debris:AddItem(highlight, 0.14)

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "WasteHitParticles"
	particles.Color = ColorSequence.new(hitbox.Color)
	particles.Enabled = false
	particles.LightEmission = 0.35
	particles.Lifetime = NumberRange.new(0.16, 0.28)
	particles.Rate = 0
	particles.Speed = NumberRange.new(4, 8)
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Parent = hitbox
	particles:Emit(10)
	Debris:AddItem(particles, 0.5)
end

local function playDestroyFeedback(wasteModel)
	local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
	if not hitbox then
		return
	end

	local effectPart = Instance.new("Part")
	effectPart.Name = "WasteDestroyEffect"
	effectPart.Anchored = true
	effectPart.CanCollide = false
	effectPart.CanQuery = false
	effectPart.CanTouch = false
	effectPart.Transparency = 1
	effectPart.Size = Vector3.new(1, 1, 1)
	effectPart.CFrame = hitbox.CFrame
	effectPart.Parent = Workspace

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "WasteDestroyBurst"
	burst.Color = ColorSequence.new(hitbox.Color)
	burst.Enabled = false
	burst.LightEmission = 0.55
	burst.Lifetime = NumberRange.new(0.28, 0.45)
	burst.Rate = 0
	burst.Speed = NumberRange.new(7, 13)
	burst.SpreadAngle = Vector2.new(90, 90)
	burst.Parent = effectPart
	burst:Emit(24)
	Debris:AddItem(effectPart, 0.8)
end

local function createWasteNode(spawnPosition, wasteZone, surface)
	local wasteId, wasteConfig = GameData.GetRandomWasteType(random)
	local size = wasteConfig.VisualSize
	local hitboxPosition = spawnPosition + Vector3.new(0, size.Y / 2, 0)
	local maxHP = getRandomHPForWaste(wasteConfig)
	local rewardWaste = getRewardWasteForHP(wasteConfig, maxHP)
	local zoneId = getZoneId(surface)

	local model = Instance.new("Model")
	model.Name = wasteConfig.Name
	model:SetAttribute("GEIWasteNode", true)
	model:SetAttribute("ZoneId", zoneId)
	model:SetAttribute("WasteId", wasteId)
	model:SetAttribute("WasteType", wasteId)
	model:SetAttribute("ModelName", wasteConfig.ModelName or "")
	model:SetAttribute("Rarity", wasteConfig.Rarity)
	model:SetAttribute("CurrentHP", maxHP)
	model:SetAttribute("MaxHP", maxHP)
	model:SetAttribute("WasteReward", rewardWaste)
	model:SetAttribute("RewardWaste", rewardWaste)
	model:SetAttribute("RewardCash", 0)
	model:SetAttribute("DiamondChance", wasteConfig.DiamondChance)
	model:SetAttribute("DiamondReward", wasteConfig.DiamondReward)

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Anchored = true
	hitbox.CanCollide = true
	hitbox.CanTouch = false
	hitbox.Color = wasteConfig.Color
	hitbox.Material = Enum.Material.SmoothPlastic
	hitbox.Position = hitboxPosition
	hitbox.Shape = Enum.PartType.Ball
	hitbox.Size = size
	hitbox.Parent = model

	model.PrimaryPart = hitbox
	if not createConfiguredVisual(model, hitbox, wasteConfig, zoneId) then
		createFallbackVisual(model, hitbox, wasteConfig)
	end
	createBillboard(hitbox, wasteConfig, maxHP)
	createRangeRing(model, hitbox, wasteConfig)
	model.Parent = wasteZone
	CollectionService:AddTag(model, "WasteNode")
end

local function getWasteModelFromTarget(target)
	if typeof(target) ~= "Instance" then
		return nil
	end

	local current = target
	while current and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("GEIWasteNode") then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function handleAttack(player, target)
	local PlayerManager = waitForPlayerManager()
	local dataFolder = PlayerManager.GetDataFolder(player)
	local root = getRootPart(player)
	local wasteModel = getWasteModelFromTarget(target)

	if not dataFolder or not root or not wasteModel then
		return
	end

	local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
	if not hitbox then
		return
	end

	local currentHP = wasteModel:GetAttribute("CurrentHP")
	if type(currentHP) ~= "number" or currentHP <= 0 then
		return
	end

	local equippedTool = dataFolder:FindFirstChild("EquippedTool")
	local isToolEquipped = dataFolder:FindFirstChild("IsToolEquipped")
	local wasteCount = dataFolder:FindFirstChild("WasteCount")
	local maxWaste = dataFolder:FindFirstChild("MaxWaste")
	local toolDamage = dataFolder:FindFirstChild("ToolDamage")

	if not equippedTool or not isToolEquipped or not wasteCount or not maxWaste or not toolDamage then
		return
	end

	if isToolEquipped.Value ~= true or not hasEquippedNativeTool(player, equippedTool.Value) then
		fireClient(player, "AttackFeedback", {
			Target = wasteModel,
			Reason = "ToolUnequipped",
		})
		return
	end

	if wasteCount.Value >= maxWaste.Value then
		fireClient(player, "AttackFeedback", {
			Target = wasteModel,
			Reason = "BackpackFull",
		})
		return
	end

	local toolConfig = GameData.GetTool(equippedTool.Value)
	if not toolConfig then
		return
	end

	local now = os.clock()
	local nextAllowedAttack = attackCooldowns[player] or 0
	if now < nextAllowedAttack then
		return
	end

	local interactionRadius = wasteModel:GetAttribute("InteractionRadius") or calculateInteractionRadius(hitbox.Size)
	local distance = getHorizontalDistance(root.Position, hitbox.Position)
	if distance > interactionRadius then
		fireClient(player, "AttackFeedback", {
			Target = wasteModel,
			Reason = "OutOfRange",
		})
		return
	end

	attackCooldowns[player] = now + toolConfig.Cooldown

	local newHP = math.max(0, currentHP - toolDamage.Value)
	wasteModel:SetAttribute("CurrentHP", newHP)
	updateHPBillboard(wasteModel)
	playHitFeedback(wasteModel)

	fireClient(player, "TutorialProgress", "ClickedWaste")

	local feedback = {
		Target = wasteModel,
		Damage = toolDamage.Value,
		RemainingHP = newHP,
		Destroyed = false,
		WasteGained = 0,
		DiamondsGained = 0,
	}

	if newHP <= 0 then
		feedback.Destroyed = true
		feedback.WasteGained = PlayerManager.AddWaste(player, wasteModel:GetAttribute("RewardWaste") or wasteModel:GetAttribute("WasteReward") or 0)

		local diamondChance = wasteModel:GetAttribute("DiamondChance") or 0
		if random:NextNumber() <= diamondChance then
			feedback.DiamondsGained = PlayerManager.AddDiamonds(player, wasteModel:GetAttribute("DiamondReward") or 1)
		end

		playDestroyFeedback(wasteModel)

		task.delay(0.18, function()
			if wasteModel.Parent then
				wasteModel:Destroy()
			end
		end)
	end

	fireClient(player, "AttackFeedback", feedback)
end

ensureRemote("RequestAttack").OnServerEvent:Connect(handleAttack)

Players.PlayerRemoving:Connect(function(player)
	attackCooldowns[player] = nil
end)

task.spawn(function()
	while true do
		local surface = getSpawnSurface()
		local wasteZone = getWasteZone()

		if surface and wasteZone then
			local activeWaste = countActiveWaste(wasteZone)
			local targetWaste = getTargetWasteCount(surface)

			while activeWaste < targetWaste do
				local spawnPosition = findSpawnPosition(surface, wasteZone)
				if not spawnPosition then
					break
				end

				createWasteNode(spawnPosition, wasteZone, surface)
				activeWaste += 1
			end
		end

		task.wait(GameData.Spawn.SpawnInterval)
	end
end)
