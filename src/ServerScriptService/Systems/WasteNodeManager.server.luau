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
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local workspaceUtilModule = sharedFolder and sharedFolder:WaitForChild("WorkspaceUtil", 10)
local WorkspaceUtil = workspaceUtilModule and require(workspaceUtilModule)
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

local function getMainBasePart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	local main = instance:FindFirstChild("Main", true)
	if main and main:IsA("BasePart") then
		return main
	end

	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function getOrCreateSpawnSurface()
	local folder = Workspace:FindFirstChild("SpawnSurfaces")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpawnSurfaces"
		folder.Parent = Workspace
	end

	local surfaceName = GameData.Spawn.SurfaceName or "SpawnSurface1"
	local existing = folder:FindFirstChild(surfaceName)
	local existingPart = getMainBasePart(existing)
	if existingPart then
		return existingPart
	end

	local part = Instance.new("Part")
	part.Name = surfaceName
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
	part.Material = Enum.Material.Concrete
	part.Color = Color3.fromRGB(74, 84, 90)
	local worldConfig = GameData.World and GameData.World.SpawnSurface or {}
	part.Size = worldConfig.Size or Vector3.new(80, 1, 60)
	part.Position = worldConfig.Position or Vector3.new(0, 1, 20)
	part:SetAttribute("ZoneId", "Zone1")
	part.Parent = folder

	warnOnce("EmergencySpawnSurfaceCreated", "[WasteNodeManager] SpawnSurface1 was missing or invalid. Created an emergency Workspace.SpawnSurfaces.SpawnSurface1 so the game stays playable.")
	return part
end

local function getWasteZone()
	local wasteZone, path
	if WorkspaceUtil then
		wasteZone, path = WorkspaceUtil.Find(GameData.Spawn.WasteZoneName or "WasteZone", GameData.Spawn.WasteZoneFolders, { SearchDescendants = true })
	else
		wasteZone = Workspace:FindFirstChild(GameData.Spawn.WasteZoneName or "WasteZone", true)
		path = wasteZone and wasteZone:GetFullName() or "Workspace.WasteZone"
	end

	if wasteZone then
		return wasteZone
	end

	local folder = Workspace:FindFirstChild("WasteZone")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WasteZone"
		folder.Parent = Workspace
	end

	warnOnce("WasteZoneAutoCreated", "[WasteNodeManager] WasteZone was missing. Created Workspace.WasteZone automatically so wastes can spawn.")
	return folder
end

local function getSpawnSurface()
	local surface, path
	if WorkspaceUtil then
		surface, path = WorkspaceUtil.Find(GameData.Spawn.SurfaceName or "SpawnSurface1", GameData.Spawn.SurfaceFolders, { SearchDescendants = true })
	else
		surface = Workspace:FindFirstChild(GameData.Spawn.SurfaceName or "SpawnSurface1", true)
		path = surface and surface:GetFullName() or "Workspace.SpawnSurface1"
	end

	local surfacePart = getMainBasePart(surface)
	if surfacePart then
		if not surfacePart:GetAttribute("ZoneId") then
			surfacePart:SetAttribute("ZoneId", "Zone1")
		end
		return surfacePart
	end

	warnOnce("SpawnSurfaceAutoFallback", "[WasteNodeManager] " .. tostring(path or "SpawnSurface1") .. " is missing or has no BasePart. Using an emergency SpawnSurface1 fallback.")
	return getOrCreateSpawnSurface()
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

local function vectorFromAttributes(instance, prefix)
	local x = instance:GetAttribute(prefix .. "X")
	local y = instance:GetAttribute(prefix .. "Y")
	local z = instance:GetAttribute(prefix .. "Z")
	if type(x) == "number" and type(y) == "number" and type(z) == "number" then
		return Vector3.new(x, y, z)
	end

	return nil
end

local function setVectorAttributes(instance, prefix, vector)
	instance:SetAttribute(prefix .. "X", vector.X)
	instance:SetAttribute(prefix .. "Y", vector.Y)
	instance:SetAttribute(prefix .. "Z", vector.Z)
end

local function calculateInteractionRadius(size)
	local interactionConfig = GameData.Interaction or {}
	local halfSurface = math.max(size.X, size.Z) / 2
	local extraRange = interactionConfig.ExtraRangeFromSurface or 2.5
	local minRange = interactionConfig.MinRange or 3.5
	local maxRange = interactionConfig.MaxRange or 9
	return math.clamp(halfSurface + extraRange, minRange, maxRange)
end

local function getRandomHPForWaste(wasteConfig)
	local hpRange = wasteConfig.HPRange
	if type(hpRange) == "table" and type(hpRange[1]) == "number" and type(hpRange[2]) == "number" then
		local minHP = math.floor(math.min(hpRange[1], hpRange[2]))
		local maxHP = math.floor(math.max(hpRange[1], hpRange[2]))
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

local function safeVector3(value)
	if typeof(value) == "Vector3" then
		return value
	end

	return Vector3.new(0, 0, 0)
end

local function getWasteModelTuning(zoneId, wasteId, variantName)
	local config = GameData.WasteModelConfig or {}
	local zoneConfig = config[zoneId] or config.Zone1 or {}
	local wasteConfig = zoneConfig[wasteId] or {}
	local defaultConfig = wasteConfig.Default or {}
	local variantConfig = wasteConfig[variantName] or {}

	return {
		Version = type(variantConfig.Version) == "number" and variantConfig.Version
			or type(defaultConfig.Version) == "number" and defaultConfig.Version
			or 1,
		VisualOffset = safeVector3(variantConfig.VisualOffset or defaultConfig.VisualOffset),
		VisualRotation = safeVector3(variantConfig.VisualRotation or defaultConfig.VisualRotation),
		VisualScale = type(variantConfig.VisualScale) == "number" and variantConfig.VisualScale
			or type(defaultConfig.VisualScale) == "number" and defaultConfig.VisualScale
			or 1,
		RingOffset = safeVector3(variantConfig.RingOffset or defaultConfig.RingOffset),
		RingRadiusOffset = type(variantConfig.RingRadiusOffset) == "number" and variantConfig.RingRadiusOffset
			or type(defaultConfig.RingRadiusOffset) == "number" and defaultConfig.RingRadiusOffset
			or 0,
		BillboardOffset = safeVector3(variantConfig.BillboardOffset or defaultConfig.BillboardOffset),
	}
end

local function getBillboardYOffset(modelTuning)
	local offset = modelTuning and modelTuning.BillboardOffset
	if typeof(offset) == "Vector3" then
		return offset.Y
	end

	return 4
end

local function getBillboardBaseCenter(ringCenter, boundsCenter)
	return Vector3.new(ringCenter.X, boundsCenter.Y, ringCenter.Z)
end

local function createOrUpdateBillboardAnchor(wasteModel, baseCenter)
	local anchor = wasteModel:FindFirstChild("BillboardAnchor")
	if anchor and not anchor:IsA("BasePart") then
		anchor:Destroy()
		anchor = nil
	end

	if not anchor then
		anchor = Instance.new("Part")
		anchor.Name = "BillboardAnchor"
		anchor.Parent = wasteModel
	end

	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(baseCenter)

	return anchor
end

local function findWasteBillboard(wasteModel)
	local anchor = wasteModel:FindFirstChild("BillboardAnchor")
	local billboard = anchor and anchor:FindFirstChild("WasteBillboard")
	if billboard and billboard:IsA("BillboardGui") then
		return billboard
	end

	local primaryPart = wasteModel.PrimaryPart
	billboard = primaryPart and primaryPart:FindFirstChild("WasteBillboard")
	if billboard and billboard:IsA("BillboardGui") then
		return billboard
	end

	return nil
end

local function getWasteCenter(wasteModel)
	local center = vectorFromAttributes(wasteModel, "InteractionCenter")
	if center then
		return center
	end

	local primaryPart = wasteModel.PrimaryPart
	if primaryPart then
		return primaryPart.Position
	end

	return nil
end

local function getWasteSize(wasteModel)
	local size = vectorFromAttributes(wasteModel, "InteractionSize")
	if size then
		return size
	end

	local primaryPart = wasteModel.PrimaryPart
	if primaryPart then
		return primaryPart.Size
	end

	return nil
end

local function hasEquippedNativeTool(player, toolId)
	local character = player.Character
	if not character then
		return false
	end

	local tool = character:FindFirstChild(toolId)
	return tool ~= nil and tool:IsA("Tool") and tool:GetAttribute("GEINativeTool") == true
end

local function isFarFromPlayers(position, minDistance)
	minDistance = minDistance or GameData.Spawn.MinDistanceFromPlayers
	for _, player in ipairs(Players:GetPlayers()) do
		local root = getRootPart(player)
		if root and (root.Position - position).Magnitude < minDistance then
			return false
		end
	end

	return true
end

local function isFarFromWaste(position, wasteZone, minDistance)
	minDistance = minDistance or GameData.Spawn.MinDistanceBetweenWaste
	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			local center = getWasteCenter(wasteModel)
			if center and (center - position).Magnitude < minDistance then
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

local function getAdaptiveSpawnDistances(surface)
	local shortestSide = math.max(1, math.min(surface.Size.X, surface.Size.Z))
	local playerDistance = math.min(GameData.Spawn.MinDistanceFromPlayers or 12, math.max(4, shortestSide * 0.25))
	local wasteDistance = math.min(GameData.Spawn.MinDistanceBetweenWaste or 8, math.max(3, shortestSide * 0.16))
	return playerDistance, wasteDistance
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
	local playerDistance, wasteDistance = getAdaptiveSpawnDistances(surface)

	for _ = 1, GameData.Spawn.MaxSpawnAttempts do
		local position = Vector3.new(
			surface.Position.X + random:NextNumber(-halfX, halfX),
			surfaceTopY,
			surface.Position.Z + random:NextNumber(-halfZ, halfZ)
		)

		if isFarFromPlayers(position, playerDistance) and isFarFromWaste(position, wasteZone, wasteDistance) then
			return position
		end
	end

	for _ = 1, GameData.Spawn.MaxSpawnAttempts do
		local position = Vector3.new(
			surface.Position.X + random:NextNumber(-halfX, halfX),
			surfaceTopY,
			surface.Position.Z + random:NextNumber(-halfZ, halfZ)
		)

		if isFarFromPlayers(position, 3) and isFarFromWaste(position, wasteZone, math.max(2.5, wasteDistance * 0.65)) then
			return position
		end
	end

	return nil
end

local function createBillboard(wasteModel, wasteConfig, maxHP, billboardBaseCenter, modelTuning)
	local displayConfig = GameData.WasteDisplay
	local rarityColors = displayConfig.RarityColors or GameData.RarityColors or {}
	local rarityColor = GameData.GetRarityColor and GameData.GetRarityColor(wasteConfig.Rarity) or rarityColors[wasteConfig.Rarity] or wasteConfig.AccentColor
	local anchor = createOrUpdateBillboardAnchor(wasteModel, billboardBaseCenter)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WasteBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = displayConfig.BillboardMaxDistance
	billboard.Size = UDim2.fromOffset(displayConfig.BillboardSize.X, displayConfig.BillboardSize.Y)
	billboard.Adornee = anchor
	billboard.StudsOffset = Vector3.new(0, getBillboardYOffset(modelTuning), 0)
	billboard.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(22, 25, 27)
	frame.BackgroundTransparency = displayConfig.BackgroundTransparency or 0.35
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
	nameLabel.TextColor3 = rarityColor
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
	hpLabel.Text = tostring(maxHP) .. " HP"
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
	barFill.BackgroundColor3 = rarityColor
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.Parent = barBack

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(1, 0)
	barFillCorner.Parent = barFill
end

local function updateHPBillboard(wasteModel)
	local billboard = findWasteBillboard(wasteModel)
	local frame = billboard and billboard:FindFirstChild("Frame")
	local hpLabel = frame and frame:FindFirstChild("HPLabel")
	local barBack = frame and frame:FindFirstChild("HPBarBack")
	local barFill = barBack and barBack:FindFirstChild("HPBarFill")
	local currentHP = math.max(0, math.floor(wasteModel:GetAttribute("CurrentHP") or 0))
	local maxHP = math.max(1, math.floor(wasteModel:GetAttribute("MaxHP") or 1))

	if hpLabel and hpLabel:IsA("TextLabel") then
		hpLabel.Text = tostring(currentHP) .. " HP"
	end

	if barFill and barFill:IsA("Frame") then
		barFill.Size = UDim2.fromScale(math.clamp(currentHP / maxHP, 0, 1), 1)
	end
end

local function createRangeRing(wasteModel, boundsCenter, boundsSize, wasteConfig, modelTuning)
	local ringConfig = GameData.InteractionCircle
	local ringFolder = Instance.new("Folder")
	ringFolder.Name = "RangeRing"
	ringFolder.Parent = wasteModel

	local radius = math.clamp(
		calculateInteractionRadius(boundsSize) + modelTuning.RingRadiusOffset,
		(GameData.Interaction and GameData.Interaction.MinRange) or 3.5,
		(GameData.Interaction and GameData.Interaction.MaxRange) or 9
	)
	local segmentCount = ringConfig.SegmentCount
	local segmentLength = ((math.pi * 2 * radius) / segmentCount) * ringConfig.SegmentLengthRatio
	local ringOffset = modelTuning.RingOffset
	local center = Vector3.new(
		boundsCenter.X + ringOffset.X,
		boundsCenter.Y - boundsSize.Y / 2 + ringConfig.HeightOffset + ringOffset.Y,
		boundsCenter.Z + ringOffset.Z
	)

	wasteModel:SetAttribute("InteractionRadius", radius)
	wasteModel:SetAttribute("RingSegmentCount", segmentCount)
	setVectorAttributes(wasteModel, "InteractionCenter", center)
	setVectorAttributes(wasteModel, "InteractionSize", boundsSize)
	setVectorAttributes(wasteModel, "VisualCenter", boundsCenter)

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

	return center
end

local function hasBasePart(instance)
	if instance:IsA("BasePart") then
		return true
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return true
		end
	end

	return false
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
			if child:IsA("Model") and hasBasePart(child) then
				table.insert(variants, child)
			elseif child:IsA("Model") then
				warnOnce(
					"WasteModelEmptyVariant_" .. wasteConfig.ModelName .. "_" .. child.Name,
					"[WasteNodeManager] ReplicatedStorage.WasteModels." .. wasteConfig.ModelName .. "." .. child.Name .. " is a Model variant but has no Part or MeshPart. Add a Main Part/MeshPart."
				)
			elseif child:IsA("SpecialMesh") then
				warnOnce(
					"WasteModelSpecialMesh_" .. wasteConfig.ModelName .. "_" .. child.Name,
					"[WasteNodeManager] ReplicatedStorage.WasteModels." .. wasteConfig.ModelName .. "." .. child.Name .. " is a SpecialMesh. Put the SpecialMesh inside a Part or MeshPart named Main."
				)
			elseif child:IsA("BasePart") or child:IsA("Folder") then
				warnOnce(
					"WasteModelVariantNotModel_" .. wasteConfig.ModelName .. "_" .. child.Name,
					"[WasteNodeManager] ReplicatedStorage.WasteModels." .. wasteConfig.ModelName .. "." .. child.Name .. " should be a Model variant, for example " .. child.Name .. ".Main."
				)
			end
		end

	elseif root:IsA("Model") then
		if hasBasePart(root) then
			return root, root.Name, true
		end
	elseif root:IsA("BasePart") then
		return root, root.Name, true
	end

	if #variants == 0 then
		warnOnce(
			"WasteModelInvalid_" .. wasteConfig.ModelName,
			"[WasteNodeManager] ReplicatedStorage.WasteModels." .. wasteConfig.ModelName .. " exists but has no valid Model, Folder, Part, or MeshPart variant with a BasePart."
		)
		return nil
	end

	local source = variants[random:NextInteger(1, #variants)]
	return source, source.Name, true
end

local function setVisualPartProperties(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = true
		instance.CanQuery = true
		instance.CanTouch = true
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
			descendant.CanQuery = true
			descendant.CanTouch = true
		end
	end
end

local function choosePrimaryPart(visual)
	if visual:IsA("BasePart") then
		return visual
	end

	local mainPart = visual:FindFirstChild("Main", true)
	if mainPart and mainPart:IsA("BasePart") then
		if visual:IsA("Model") then
			visual.PrimaryPart = mainPart
		end
		return mainPart
	end

	if visual:IsA("Model") and visual.PrimaryPart then
		return visual.PrimaryPart
	end

	local largestPart = nil
	local largestVolume = -math.huge
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > largestVolume then
				largestVolume = volume
				largestPart = descendant
			end
		end
	end

	if visual:IsA("Model") and largestPart then
		visual.PrimaryPart = largestPart
	end

	return largestPart
end

local function getVisualBounds(visual)
	if visual:IsA("Model") then
		local cframe, size = visual:GetBoundingBox()
		return cframe, size
	elseif visual:IsA("BasePart") then
		return visual.CFrame, visual.Size
	end

	return CFrame.new(), Vector3.new(1, 1, 1)
end

local function cloneFolderAsModel(source)
	local visualModel = Instance.new("Model")
	visualModel.Name = "VisualModel"

	local sourceClone = source:Clone()
	for _, child in ipairs(sourceClone:GetChildren()) do
		child.Parent = visualModel
	end
	sourceClone:Destroy()

	return visualModel
end

local function applyVisualScale(visual, scale)
	if type(scale) ~= "number" or scale <= 0 or math.abs(scale - 1) < 0.001 then
		return
	end

	if visual:IsA("Model") then
		visual:ScaleTo(scale)
	elseif visual:IsA("BasePart") then
		visual.Size *= scale
	end
end

local function pivotVisualToSpawn(visual, spawnPosition, modelTuning)
	local rotation = modelTuning.VisualRotation
	local targetCFrame = CFrame.new(spawnPosition + modelTuning.VisualOffset)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))

	if visual:IsA("Model") then
		visual:PivotTo(targetCFrame)
	elseif visual:IsA("BasePart") then
		visual.CFrame = targetCFrame
	end
end

local function createConfiguredVisual(wasteModel, spawnPosition, wasteConfig, zoneId)
	local source, variantName = getWasteVisualSource(wasteConfig)
	if not source then
		return nil
	end

	local visual = nil
	if source:IsA("BasePart") then
		visual = source:Clone()
		visual.Name = "VisualModel"
	elseif source:IsA("Model") then
		visual = source:Clone()
		visual.Name = "VisualModel"
	elseif source:IsA("Folder") then
		visual = cloneFolderAsModel(source)
	else
		return nil
	end

	visual.Parent = wasteModel
	setVisualPartProperties(visual)
	local modelTuning = getWasteModelTuning(zoneId, wasteConfig.Id, variantName)
	applyVisualScale(visual, modelTuning.VisualScale)
	pivotVisualToSpawn(visual, spawnPosition, modelTuning)

	local primaryPart = choosePrimaryPart(visual)
	if not primaryPart then
		visual:Destroy()
		return nil
	end

	local boundsCFrame, boundsSize = getVisualBounds(visual)
	print(string.format(
		"[WasteSpawn] Rarity=%s Variant=%s ModelUsed=true Offset=%s",
		wasteConfig.Id,
		variantName,
		tostring(modelTuning.VisualOffset)
	))

	return {
		Instance = visual,
		PrimaryPart = primaryPart,
		BoundsCFrame = boundsCFrame,
		BoundsSize = boundsSize,
		ModelName = source.Name,
		VariantName = variantName,
		Tuning = modelTuning,
	}
end

local function createFallbackVisual(wasteModel, spawnPosition, wasteConfig, zoneId)
	local modelTuning = getWasteModelTuning(zoneId, wasteConfig.Id, "Default")
	local visualPart = Instance.new("Part")
	visualPart.Name = "VisualModel"
	visualPart.Anchored = true
	visualPart.CanCollide = true
	visualPart.CanQuery = true
	visualPart.CanTouch = true
	visualPart.Color = wasteConfig.Color
	visualPart.Material = Enum.Material.SmoothPlastic
	visualPart.Shape = Enum.PartType.Ball
	visualPart.Size = wasteConfig.VisualSize
	visualPart.Parent = wasteModel

	applyVisualScale(visualPart, modelTuning.VisualScale)
	pivotVisualToSpawn(visualPart, spawnPosition, modelTuning)
	print(string.format(
		"[WasteSpawn] Rarity=%s Variant=Fallback ModelUsed=false Offset=%s",
		wasteConfig.Id,
		tostring(modelTuning.VisualOffset)
	))

	return {
		Instance = visualPart,
		PrimaryPart = visualPart,
		BoundsCFrame = visualPart.CFrame,
		BoundsSize = visualPart.Size,
		ModelName = "fallback VisualModel",
		VariantName = "Fallback",
		Tuning = modelTuning,
	}
end

local function playHitFeedback(wasteModel)
	local displayConfig = GameData.WasteDisplay
	local primaryPart = wasteModel.PrimaryPart
	if not primaryPart then
		return
	end

	local baseSize = primaryPart:GetAttribute("BaseSize") or primaryPart.Size
	primaryPart:SetAttribute("BaseSize", baseSize)

	local originalCFrame = primaryPart.CFrame
	local offset = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
	if offset.Magnitude > 0 then
		offset = offset.Unit * displayConfig.HitShakeDistance
	end

	local outTween = TweenService:Create(primaryPart, TweenInfo.new(displayConfig.HitTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = originalCFrame + offset,
		Size = baseSize * displayConfig.HitScaleAmount,
	})
	local inTween = TweenService:Create(primaryPart, TweenInfo.new(displayConfig.HitTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = originalCFrame,
		Size = baseSize,
	})

	outTween:Play()
	outTween.Completed:Connect(function()
		if primaryPart.Parent then
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
	particles.Color = ColorSequence.new(primaryPart.Color)
	particles.Enabled = false
	particles.LightEmission = 0.35
	particles.Lifetime = NumberRange.new(0.16, 0.28)
	particles.Rate = 0
	particles.Speed = NumberRange.new(4, 8)
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Parent = primaryPart
	particles:Emit(10)
	Debris:AddItem(particles, 0.5)
end

local function playDestroyFeedback(wasteModel)
	local primaryPart = wasteModel.PrimaryPart
	if not primaryPart then
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
	effectPart.CFrame = primaryPart.CFrame
	effectPart.Parent = Workspace

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "WasteDestroyBurst"
	burst.Color = ColorSequence.new(primaryPart.Color)
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
	setVectorAttributes(model, "NodeBasePosition", spawnPosition)

	local visualInfo = createConfiguredVisual(model, spawnPosition, wasteConfig, zoneId)
	if not visualInfo then
		visualInfo = createFallbackVisual(model, spawnPosition, wasteConfig, zoneId)
	end

	model.PrimaryPart = visualInfo.PrimaryPart
	setVectorAttributes(model, "InteractionCenter", visualInfo.BoundsCFrame.Position)
	setVectorAttributes(model, "InteractionSize", visualInfo.BoundsSize)
	model:SetAttribute("VisualModelName", visualInfo.ModelName)
	model:SetAttribute("VisualVariant", visualInfo.VariantName)
	model:SetAttribute("ModelConfigVersion", visualInfo.Tuning.Version)

	local ringCenter = createRangeRing(model, visualInfo.BoundsCFrame.Position, visualInfo.BoundsSize, wasteConfig, visualInfo.Tuning)
	local billboardBaseCenter = getBillboardBaseCenter(ringCenter, visualInfo.BoundsCFrame.Position)
	createBillboard(model, wasteConfig, maxHP, billboardBaseCenter, visualInfo.Tuning)
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

	local primaryPart = wasteModel.PrimaryPart
	local boundsCenter = getWasteCenter(wasteModel)
	local boundsSize = getWasteSize(wasteModel)
	if not primaryPart or not boundsCenter or not boundsSize then
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

	local interactionRadius = wasteModel:GetAttribute("InteractionRadius") or calculateInteractionRadius(boundsSize)
	local distance = getHorizontalDistance(root.Position, boundsCenter)
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
