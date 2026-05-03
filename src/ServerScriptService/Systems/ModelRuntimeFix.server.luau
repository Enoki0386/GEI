local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

-- CONFIGURATION FACILE À MODIFIER
-- VisualOffset = déplace uniquement le modèle visible
-- RingOffset = déplace uniquement le cercle
-- BillboardOffset = déplace uniquement le texte HP/nom
local CONFIG = {
	Version = 3,

	WasteZoneName = "WasteZone",
	SurfaceName = "SpawnSurface1",

	Waste = {
		Zone1 = {
			CommonWaste = {
				Default = {
					VisualOffset = Vector3.new(0, 0, 0),
					RingOffset = Vector3.new(0,9.907, 0),
					BillboardOffset = Vector3.new(0, 4, 0),
                    VisualRotation = Vector3.new(90, 0, 0),
					RingRadiusOffset = 0,
				},

				TrashPile = {
					VisualOffset = Vector3.new(0, 0, 0),
					RingOffset = Vector3.new(0, 0, 0),
					BillboardOffset = Vector3.new(0, 4, 0),
                    VisualRotation = Vector3.new(90, 0, 0),
					RingRadiusOffset = 0,
				},
			},

			RareWaste = {
				Default = {
					VisualOffset = Vector3.new(0, -0.25, 0),
					RingOffset = Vector3.new(0, 0, 0),
					BillboardOffset = Vector3.new(0, 4, 0),
                    VisualRotation = Vector3.new(90, 0, 0),
					RingRadiusOffset = 0,
				},

				GarbageBags = {
					VisualOffset = Vector3.new(0, -0.25, 0),
					RingOffset = Vector3.new(0, 0, 0),
					BillboardOffset = Vector3.new(0, 4, 0),
                    VisualRotation = Vector3.new(90, 0, 0),
					RingRadiusOffset = 0,
				},
			},

			EpicWaste = {
				Default = {
					VisualOffset = Vector3.new(0, -0.15, 0),
					RingOffset = Vector3.new(0, 0, 0),
					BillboardOffset = Vector3.new(0, 4.5, 0),
                    VisualRotation = Vector3.new(90, 0, 0),
					RingRadiusOffset = 0,
				},

				Barrel = {
					VisualOffset = Vector3.new(0, -0.15, 0),
					RingOffset = Vector3.new(0, 0, 0),
					BillboardOffset = Vector3.new(0, 4.5, 0),
                    VisualRotation = Vector3.new(90, 0, 0),
					RingRadiusOffset = 0,
				},
			},

			LegendaryWaste = {
				Default = {
					VisualOffset = Vector3.new(0, 0, 0),
					RingOffset = Vector3.new(0, 0, 0),
					BillboardOffset = Vector3.new(0, 5.5, 0),
                    VisualRotation = Vector3.new(90, 0, 0),
					RingRadiusOffset = 0.5,
				},

				Boxes = {
					VisualOffset = Vector3.new(0, 2, 0),
					RingOffset = Vector3.new(0, 3.945, 0),
					BillboardOffset = Vector3.new(0, 5.5, 0),
                    VisualRotation = Vector3.new(0, 0, 0),
					RingRadiusOffset = 0.5,
				},
			},
		},
	},

	Ring = {
		SegmentCount = 18,
		SegmentLengthRatio = 0.62,
		Thickness = 0.06,
		HeightOffset = 0.08,
		MinRadius = 3.5,
		MaxRadius = 9,
		ExtraRange = 2.5,
		Transparency = 0.45,
		Color = Color3.fromRGB(255, 238, 131),
	},
}

local warned = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end

	warned[key] = true
	warn(message)
end

local function getWasteZone()
	local zone = Workspace:FindFirstChild(CONFIG.WasteZoneName)
	if zone and zone:IsA("Folder") then
		return zone
	end

	return nil
end

local function getSurfaceTopY()
	local surface = Workspace:FindFirstChild(CONFIG.SurfaceName)
	if surface and surface:IsA("BasePart") then
		return surface.Position.Y + surface.Size.Y / 2
	end

	return 0
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

local function findVariantSource(wasteId, preferredVariant)
    if preferredVariant == "Fallback" then
	    preferredVariant = nil
    end

	local modelsFolder = ReplicatedStorage:FindFirstChild("WasteModels")
	local rarityFolder = modelsFolder and modelsFolder:FindFirstChild(wasteId)

	if not rarityFolder then
		return nil, nil
	end

	if preferredVariant and preferredVariant ~= "" then
		local preferred = rarityFolder:FindFirstChild(preferredVariant)
		if preferred and hasBasePart(preferred) then
			return preferred, preferred.Name
		end
	end

	local variants = {}

	for _, child in ipairs(rarityFolder:GetChildren()) do
		if hasBasePart(child) then
			table.insert(variants, child)
		end
	end

	if #variants == 0 and hasBasePart(rarityFolder) then
		return rarityFolder, rarityFolder.Name
	end

	if #variants == 0 then
		return nil, nil
	end

	local chosen = variants[math.random(1, #variants)]
	return chosen, chosen.Name
end

local function getDirectPartCount(instance)
	local count = 0

	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("BasePart") then
			count += 1
		end
	end

	return count
end

local function flattenIfNeeded(model)
	local children = model:GetChildren()

	if getDirectPartCount(model) == 0 and #children == 1 and (children[1]:IsA("Model") or children[1]:IsA("Folder")) then
		local inner = children[1]

		for _, child in ipairs(inner:GetChildren()) do
			child.Parent = model
		end

		inner:Destroy()
	end
end

local function cloneAsVisualModel(source)
	local visual = Instance.new("Model")
	visual.Name = "VisualModel"

	if source:IsA("BasePart") then
		local part = source:Clone()
		part.Name = "Main"
		part.Parent = visual
	else
		local clone = source:Clone()

		for _, child in ipairs(clone:GetChildren()) do
			child.Parent = visual
		end

		clone:Destroy()
	end

	flattenIfNeeded(visual)

	return visual
end

local function getBaseParts(instance)
	local parts = {}

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function prepareVisualModel(model)
	local largestPart = nil
	local largestVolume = -1

	for _, part in ipairs(getBaseParts(model)) do
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = true
		part.CanQuery = true

		local volume = part.Size.X * part.Size.Y * part.Size.Z

		if volume > largestVolume then
			largestVolume = volume
			largestPart = part
		end
	end

	if largestPart then
		model.PrimaryPart = largestPart
	end

	return largestPart
end

local function getVectorAttribute(instance, prefix)
	local x = instance:GetAttribute(prefix .. "X")
	local y = instance:GetAttribute(prefix .. "Y")
	local z = instance:GetAttribute(prefix .. "Z")

	if type(x) == "number" and type(y) == "number" and type(z) == "number" then
		return Vector3.new(x, y, z)
	end

	return nil
end

local function setVectorAttribute(instance, prefix, vector)
	instance:SetAttribute(prefix .. "X", vector.X)
	instance:SetAttribute(prefix .. "Y", vector.Y)
	instance:SetAttribute(prefix .. "Z", vector.Z)
end

local function getTuning(zoneId, wasteId, variantName)
	local zoneConfig = CONFIG.Waste[zoneId] or CONFIG.Waste.Zone1 or {}
	local wasteConfig = zoneConfig[wasteId] or {}
	local defaultConfig = wasteConfig.Default or {}
	local variantConfig = wasteConfig[variantName] or {}

    return {
	VisualOffset = variantConfig.VisualOffset or defaultConfig.VisualOffset or Vector3.new(0, 0, 0),
	VisualRotation = variantConfig.VisualRotation or defaultConfig.VisualRotation or Vector3.new(0, 0, 0),
	RingOffset = variantConfig.RingOffset or defaultConfig.RingOffset or Vector3.new(0, 0, 0),
	BillboardOffset = variantConfig.BillboardOffset or defaultConfig.BillboardOffset or Vector3.new(0, 4, 0),
	RingRadiusOffset = variantConfig.RingRadiusOffset or defaultConfig.RingRadiusOffset or 0,
    }   
end

local function clearOldVisuals(waste)
	local oldRing = waste:FindFirstChild("RangeRing")
	if oldRing then
		oldRing:Destroy()
	end

	local oldVisual = waste:FindFirstChild("VisualModel")
	if oldVisual then
		oldVisual:Destroy()
	end

	for _, descendant in ipairs(waste:GetDescendants()) do
		if descendant:IsA("BillboardGui") and descendant.Name == "WasteBillboard" then
			descendant:Destroy()
		end
	end
end

local function createBillboard(waste, primaryPart, center, tuning)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WasteBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = (GameData.WasteDisplay and GameData.WasteDisplay.BillboardMaxDistance) or 45
	billboard.Size = UDim2.fromOffset(180, 78)
	billboard.StudsOffset = center + tuning.BillboardOffset - primaryPart.Position
	billboard.Parent = primaryPart

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
	nameLabel.Text = waste.Name
	nameLabel.TextColor3 = Color3.fromRGB(190, 230, 120)
	nameLabel.TextScaled = true
	nameLabel.Parent = frame

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HPLabel"
	hpLabel.BackgroundTransparency = 1
	hpLabel.Font = Enum.Font.GothamBlack
	hpLabel.Position = UDim2.fromOffset(8, 28)
	hpLabel.Size = UDim2.new(1, -16, 0, 26)
	hpLabel.Text = tostring(math.floor(waste:GetAttribute("CurrentHP") or 1))
	hpLabel.TextColor3 = Color3.fromRGB(242, 246, 248)
	hpLabel.TextScaled = true
	hpLabel.Parent = frame

	local barBack = Instance.new("Frame")
	barBack.Name = "HPBarBack"
	barBack.BackgroundColor3 = Color3.fromRGB(44, 49, 51)
	barBack.BorderSizePixel = 0
	barBack.Position = UDim2.new(0, 12, 1, -16)
	barBack.Size = UDim2.new(1, -24, 0, 8)
	barBack.Parent = frame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBack

	local fill = Instance.new("Frame")
	fill.Name = "HPBarFill"
	fill.BackgroundColor3 = Color3.fromRGB(184, 229, 112)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp((waste:GetAttribute("CurrentHP") or 1) / (waste:GetAttribute("MaxHP") or 1), 0, 1), 1)
	fill.Parent = barBack

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
end

local function createRing(waste, center, size, tuning)
	local cfg = CONFIG.Ring

	local folder = Instance.new("Folder")
	folder.Name = "RangeRing"
	folder.Parent = waste

	local radius = math.clamp(
		math.max(size.X, size.Z) / 2 + cfg.ExtraRange + tuning.RingRadiusOffset,
		cfg.MinRadius,
		cfg.MaxRadius
	)

	local ringCenter = Vector3.new(
		center.X,
		center.Y - size.Y / 2 + cfg.HeightOffset,
		center.Z
	) + tuning.RingOffset

	waste:SetAttribute("InteractionRadius", radius)
	setVectorAttribute(waste, "InteractionCenter", ringCenter)
	setVectorAttribute(waste, "InteractionSize", size)
	setVectorAttribute(waste, "VisualCenter", center)

	local segmentCount = cfg.SegmentCount
	local segmentLength = ((math.pi * 2 * radius) / segmentCount) * cfg.SegmentLengthRatio

	for index = 1, segmentCount do
		local angle = ((index - 1) / segmentCount) * math.pi * 2

		local segment = Instance.new("Part")
		segment.Name = "RingSegment"
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanTouch = false
		segment.CanQuery = false
		segment.Material = Enum.Material.Neon
		segment.Color = cfg.Color
		segment.Transparency = cfg.Transparency
		segment.Size = Vector3.new(segmentLength, cfg.Thickness, cfg.Thickness)
		segment:SetAttribute("SegmentIndex", index)
		segment:SetAttribute("SegmentCount", segmentCount)
		segment:SetAttribute("BaseLength", segmentLength)
		segment:SetAttribute("BaseThickness", cfg.Thickness)
		segment.CFrame = CFrame.new(ringCenter + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
			* CFrame.Angles(0, -angle - math.pi / 2, 0)
		segment.Parent = folder
	end
end

local function fixWaste(waste)
	if not waste:IsA("Model") then
		return
	end

	if not waste:GetAttribute("GEIWasteNode") then
		return
	end

    if waste:GetAttribute("RuntimeModelFixVersion") == CONFIG.Version then
        return
    end

	local wasteId = waste:GetAttribute("WasteId") or waste:GetAttribute("WasteType")
	local zoneId = waste:GetAttribute("ZoneId") or "Zone1"

	if type(wasteId) ~= "string" then
		return
	end

	local source, variantName = findVariantSource(wasteId, waste:GetAttribute("VisualVariant"))

	if not source then
		warnOnce("MissingModel_" .. wasteId, "[ModelRuntimeFix] Missing model for " .. wasteId)
		waste:SetAttribute("RuntimeModelFixVersion", CONFIG.Version)
		return
	end

	local oldCenter = getVectorAttribute(waste, "VisualCenter")
		or getVectorAttribute(waste, "InteractionCenter")
		or (waste.PrimaryPart and waste.PrimaryPart.Position)
		or Vector3.new(0, getSurfaceTopY(), 0)

	local tuning = getTuning(zoneId, wasteId, variantName)

	clearOldVisuals(waste)

	local visual = cloneAsVisualModel(source)
	visual.Parent = waste

	local primaryPart = prepareVisualModel(visual)

	if not primaryPart then
		visual:Destroy()
		waste:SetAttribute("RuntimeModelFixVersion", CONFIG.Version)
		return
	end

	local basePosition = Vector3.new(oldCenter.X, getSurfaceTopY(), oldCenter.Z)
    local rotation = tuning.VisualRotation or Vector3.new(0, 0, 0)

    visual:PivotTo(
        CFrame.new(basePosition + tuning.VisualOffset)
            * CFrame.Angles(
                math.rad(rotation.X),
                math.rad(rotation.Y),
                math.rad(rotation.Z)
            )
    )

	local boundsCFrame, boundsSize = visual:GetBoundingBox()

	waste.PrimaryPart = primaryPart
	waste:SetAttribute("VisualVariant", variantName)
	waste:SetAttribute("VisualModelName", source.Name)
	waste:SetAttribute("RuntimeModelFixVersion", CONFIG.Version)

	createBillboard(waste, primaryPart, boundsCFrame.Position, tuning)
	createRing(waste, boundsCFrame.Position, boundsSize, tuning)

	print("[ModelRuntimeFix] Loaded " .. wasteId .. "/" .. variantName .. " offset=" .. tostring(tuning.VisualOffset))
end

local function scanWaste()
	local zone = getWasteZone()
	if not zone then
		return
	end

	for _, child in ipairs(zone:GetChildren()) do
		fixWaste(child)
	end
end

task.spawn(function()
	while true do
		scanWaste()
		task.wait(1)
	end
end)

task.defer(function()
	local zone = getWasteZone()

	if zone then
		zone.ChildAdded:Connect(function(child)
			task.wait(0.15)
			fixWaste(child)
		end)
	end
end)