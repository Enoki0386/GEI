local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. SpawnManager stopped.")
	return
end

local GameData = require(gameDataModule)

local function ensureBasePart(name, className)
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		return existing, false
	end

	if existing then
		existing.Name = name .. "_Old"
		warn("[GEI] Renamed non-part workspace object to keep required name available:", existing.Name)
	end

	local part = Instance.new(className or "Part")
	part.Name = name
	part.Parent = Workspace
	return part, true
end

local function ensureFolder(name)
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if existing then
		existing.Name = name .. "_Old"
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

local function applyPartProperties(part, properties)
	for propertyName, value in pairs(properties) do
		part[propertyName] = value
	end
end

local function ensureZoneLabel(part, text, color)
	local existing = part:FindFirstChild("ZoneBillboard")
	if existing then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(220, 52)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 0.18
	label.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 24
	textConstraint.MinTextSize = 12
	textConstraint.Parent = label
end

local baseplate = ensureBasePart("GEIBaseplate", "Part")
applyPartProperties(baseplate, {
	Anchored = true,
	CanCollide = true,
	Color = GameData.World.Baseplate.Color,
	Material = Enum.Material.Slate,
	Position = GameData.World.Baseplate.Position,
	Size = GameData.World.Baseplate.Size,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
})

local spawnSurface = ensureBasePart(GameData.Spawn.SurfaceName, "Part")
applyPartProperties(spawnSurface, {
	Anchored = true,
	CanCollide = true,
	Color = GameData.World.SpawnSurface.Color,
	Material = Enum.Material.Grass,
	Position = GameData.World.SpawnSurface.Position,
	Size = GameData.World.SpawnSurface.Size,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
})

ensureFolder(GameData.Spawn.WasteZoneName)

local sellZone = ensureBasePart("SellZone", "Part")
applyPartProperties(sellZone, {
	Anchored = true,
	CanCollide = false,
	CanTouch = true,
	Color = GameData.World.SellZone.Color,
	Material = Enum.Material.Neon,
	Position = GameData.World.SellZone.Position,
	Size = GameData.World.SellZone.Size,
	Transparency = 0.42,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
})
ensureZoneLabel(sellZone, "SELL", Color3.fromRGB(184, 255, 194))

local buyZone = ensureBasePart("BuyZone", "Part")
applyPartProperties(buyZone, {
	Anchored = true,
	CanCollide = false,
	CanTouch = true,
	Color = GameData.World.BuyZone.Color,
	Material = Enum.Material.Neon,
	Position = GameData.World.BuyZone.Position,
	Size = GameData.World.BuyZone.Size,
	Transparency = 0.42,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
})
ensureZoneLabel(buyZone, "SHOP", Color3.fromRGB(196, 222, 255))

local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
if spawnLocation and not spawnLocation:IsA("SpawnLocation") then
	spawnLocation.Name = "SpawnLocation_Old"
	spawnLocation = nil
end

if not spawnLocation then
	spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Parent = Workspace
end

applyPartProperties(spawnLocation, {
	Anchored = true,
	CanCollide = true,
	Color = Color3.fromRGB(255, 224, 125),
	Duration = 0,
	Material = Enum.Material.Neon,
	Neutral = true,
	Position = GameData.World.SpawnLocation.Position,
	Size = Vector3.new(8, 1, 8),
	Transparency = 0.1,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
})
