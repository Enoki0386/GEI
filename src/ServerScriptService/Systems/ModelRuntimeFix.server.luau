local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[ModelRuntimeFix] Missing ReplicatedStorage.GameData. Runtime model fixes disabled.")
	return
end

local GameData = require(gameDataModule)
local warned = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end

	warned[key] = true
	warn(message)
end

local function safeVector3(value)
	if typeof(value) == "Vector3" then
		return value
	end

	return Vector3.new(0, 0, 0)
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
		RingOffset = safeVector3(variantConfig.RingOffset or defaultConfig.RingOffset),
		RingRadiusOffset = type(variantConfig.RingRadiusOffset) == "number" and variantConfig.RingRadiusOffset
			or type(defaultConfig.RingRadiusOffset) == "number" and defaultConfig.RingRadiusOffset
			or 0,
		BillboardOffset = safeVector3(variantConfig.BillboardOffset or defaultConfig.BillboardOffset),
	}
end

local function getBillboardYOffset(tuning)
	local offset = tuning and tuning.BillboardOffset
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

local function needsBillboardAnchorFix(wasteModel)
	local anchor = wasteModel:FindFirstChild("BillboardAnchor")
	if not (anchor and anchor:IsA("BasePart")) then
		return true
	end

	local anchoredBillboard = anchor:FindFirstChild("WasteBillboard")
	if anchoredBillboard and anchoredBillboard:IsA("BillboardGui") then
		return false
	end

	local primaryPart = wasteModel.PrimaryPart
	local oldBillboard = primaryPart and primaryPart:FindFirstChild("WasteBillboard")
	return oldBillboard ~= nil
end

local function choosePrimaryPart(visual)
	if visual:IsA("BasePart") then
		return visual
	end

	local main = visual:FindFirstChild("Main", true)
	if main and main:IsA("BasePart") then
		visual.PrimaryPart = main
		return main
	end

	if visual.PrimaryPart then
		return visual.PrimaryPart
	end

	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			visual.PrimaryPart = descendant
			return descendant
		end
	end

	return nil
end

local function getVisualBounds(visual)
	if visual:IsA("Model") then
		return visual:GetBoundingBox()
	elseif visual:IsA("BasePart") then
		return visual.CFrame, visual.Size
	end

	return CFrame.new(), Vector3.new(1, 1, 1)
end

local function calculateInteractionRadius(size)
	local interactionConfig = GameData.Interaction or {}
	local halfSurface = math.max(size.X, size.Z) / 2
	local extraRange = interactionConfig.ExtraRangeFromSurface or 2.5
	local minRange = interactionConfig.MinRange or 3.5
	local maxRange = interactionConfig.MaxRange or 9
	return math.clamp(halfSurface + extraRange, minRange, maxRange)
end

local function pivotVisual(visual, basePosition, tuning)
	local rotation = tuning.VisualRotation
	local cframe = CFrame.new(basePosition + tuning.VisualOffset)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))

	if visual:IsA("Model") then
		visual:PivotTo(cframe)
	elseif visual:IsA("BasePart") then
		visual.CFrame = cframe
	end
end

local function recreateRing(wasteModel, boundsCenter, boundsSize, wasteConfig, tuning)
	local oldRing = wasteModel:FindFirstChild("RangeRing")
	if oldRing then
		oldRing:Destroy()
	end

	local ringConfig = GameData.InteractionCircle
	local ringFolder = Instance.new("Folder")
	ringFolder.Name = "RangeRing"
	ringFolder.Parent = wasteModel

	local radius = math.clamp(
		calculateInteractionRadius(boundsSize) + tuning.RingRadiusOffset,
		(GameData.Interaction and GameData.Interaction.MinRange) or 3.5,
		(GameData.Interaction and GameData.Interaction.MaxRange) or 9
	)
	local segmentCount = ringConfig.SegmentCount
	local segmentLength = ((math.pi * 2 * radius) / segmentCount) * ringConfig.SegmentLengthRatio
	local center = Vector3.new(
		boundsCenter.X + tuning.RingOffset.X,
		boundsCenter.Y - boundsSize.Y / 2 + ringConfig.HeightOffset + tuning.RingOffset.Y,
		boundsCenter.Z + tuning.RingOffset.Z
	)

	wasteModel:SetAttribute("InteractionRadius", radius)
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

local function updateBillboard(wasteModel, primaryPart, billboardBaseCenter, tuning)
	local anchor = createOrUpdateBillboardAnchor(wasteModel, billboardBaseCenter)
	local billboard = anchor:FindFirstChild("WasteBillboard")
	if not (billboard and billboard:IsA("BillboardGui")) then
		billboard = primaryPart:FindFirstChild("WasteBillboard")
	end

	if billboard and billboard:IsA("BillboardGui") then
		billboard.Adornee = anchor
		billboard.StudsOffset = Vector3.new(0, getBillboardYOffset(tuning), 0)
		billboard.Parent = anchor
	end
end

local function applyRuntimeFix(wasteModel)
	local wasteId = wasteModel:GetAttribute("WasteType") or wasteModel:GetAttribute("WasteId")
	local variantName = wasteModel:GetAttribute("VisualVariant")
	local zoneId = wasteModel:GetAttribute("ZoneId") or "Zone1"
	if type(wasteId) ~= "string" or type(variantName) ~= "string" then
		return
	end

	local wasteConfig = GameData.GetWasteType(wasteId)
	if not wasteConfig then
		return
	end

	local tuning = getWasteModelTuning(zoneId, wasteId, variantName)
	if wasteModel:GetAttribute("ModelConfigVersion") == tuning.Version and not needsBillboardAnchorFix(wasteModel) then
		return
	end

	local visual = wasteModel:FindFirstChild("VisualModel")
	if not visual or not (visual:IsA("Model") or visual:IsA("BasePart")) then
		warnOnce("MissingVisual_" .. wasteId .. "_" .. variantName, "[ModelRuntimeFix] Waste " .. wasteId .. "/" .. variantName .. " has no VisualModel to refresh.")
		return
	end

	local basePosition = vectorFromAttributes(wasteModel, "NodeBasePosition")
	if not basePosition then
		basePosition = vectorFromAttributes(wasteModel, "VisualCenter") or vectorFromAttributes(wasteModel, "InteractionCenter")
	end
	if not basePosition then
		warnOnce("MissingBasePosition_" .. wasteId .. "_" .. variantName, "[ModelRuntimeFix] Waste " .. wasteId .. "/" .. variantName .. " has no position attributes. New spawns will be configurable.")
		return
	end

	pivotVisual(visual, basePosition, tuning)
	local primaryPart = choosePrimaryPart(visual)
	if not primaryPart then
		return
	end

	wasteModel.PrimaryPart = primaryPart
	local boundsCFrame, boundsSize = getVisualBounds(visual)
	local ringCenter = recreateRing(wasteModel, boundsCFrame.Position, boundsSize, wasteConfig, tuning)
	local billboardBaseCenter = getBillboardBaseCenter(ringCenter, boundsCFrame.Position)
	updateBillboard(wasteModel, primaryPart, billboardBaseCenter, tuning)
	wasteModel:SetAttribute("ModelConfigVersion", tuning.Version)
	print(string.format("[ModelRuntimeFix] Refreshed %s/%s Version=%d", wasteId, variantName, tuning.Version))
end

local function getWasteZone()
	return Workspace:FindFirstChild((GameData.Spawn and GameData.Spawn.WasteZoneName) or "WasteZone")
end

task.spawn(function()
	while true do
		local wasteZone = getWasteZone()
		if wasteZone then
			for _, child in ipairs(wasteZone:GetChildren()) do
				if child:IsA("Model") and child:GetAttribute("GEIWasteNode") == true then
					applyRuntimeFix(child)
				end
			end
		end

		task.wait(2)
	end
end)

task.defer(function()
	local wasteZone = getWasteZone()
	if wasteZone then
		wasteZone.ChildAdded:Connect(function(child)
			task.wait(0.15)
			if child:IsA("Model") and child:GetAttribute("GEIWasteNode") == true then
				applyRuntimeFix(child)
			end
		end)
	end
end)
