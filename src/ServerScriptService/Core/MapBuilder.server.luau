local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. MapBuilder stopped.")
	return
end

local GameData = require(gameDataModule)

-- CONFIGURATION FACILE À MODIFIER

local MAP_CONFIG = {
	Folders = {
		WasteZone = GameData.Spawn.WasteZoneName,
		MapDecor = "MapDecor",
	},

	LobbyFloor = {
		Name = "LobbyFloor",
		Position = GameData.World.LobbyFloor.Position,
		Size = GameData.World.LobbyFloor.Size,
		Color = GameData.World.LobbyFloor.Color,
		Material = Enum.Material.SmoothPlastic,
	},

	SpawnLocation = {
		Name = "SpawnLocation",
		Position = GameData.World.SpawnLocation.Position,
		Size = Vector3.new(9, 1, 9),
		Color = Color3.fromRGB(255, 219, 92),
		Material = Enum.Material.Neon,
	},

	WasteArea = {
		Name = GameData.Spawn.SurfaceName,
		Label = "WASTE AREA",
		Position = GameData.World.SpawnSurface.Position,
		Size = GameData.World.SpawnSurface.Size,
		Color = GameData.World.SpawnSurface.Color,
		Material = Enum.Material.Grass,
		LabelColor = Color3.fromRGB(223, 255, 191),
	},

	SellZone = {
		Name = "SellZone",
		Label = "SELL",
		Position = GameData.World.SellZone.Position,
		Size = GameData.World.SellZone.Size,
		Color = GameData.World.SellZone.Color,
		Material = Enum.Material.Neon,
		LabelColor = Color3.fromRGB(197, 255, 206),
	},

	BuyZone = {
		Name = "BuyZone",
		Label = "SHOP",
		Position = GameData.World.BuyZone.Position,
		Size = GameData.World.BuyZone.Size,
		Color = GameData.World.BuyZone.Color,
		Material = Enum.Material.Neon,
		LabelColor = Color3.fromRGB(214, 226, 255),
	},

	Border = {
		Height = 2.2,
		Thickness = 1.2,
		Color = Color3.fromRGB(51, 61, 58),
		ZoneColor = Color3.fromRGB(31, 40, 38),
		Material = Enum.Material.Slate,
	},
}

local function ensureFolder(name)
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if existing then
		existing.Name = name .. "_Old"
		warn("[GEI] Renamed non-folder workspace object to keep required folder name available:", existing.Name)
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

local function ensureBasePart(parent, name, className)
	local expectedClassName = className or "Part"
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == expectedClassName then
		return existing
	end

	if existing then
		existing.Name = name .. "_Old"
		warn("[GEI] Renamed non-part object to keep required part name available:", existing.Name)
	end

	local part = Instance.new(expectedClassName)
	part.Name = name
	part.Parent = parent
	return part
end

local function applyPart(part, config)
	part.Anchored = true
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = config.CanCollide ~= false
	part.CanQuery = config.CanQuery ~= false
	part.CanTouch = config.CanTouch == true
	part.Color = config.Color
	part.Material = config.Material or Enum.Material.SmoothPlastic
	part.Position = config.Position
	part.Size = config.Size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Transparency = config.Transparency or 0

	if config.Orientation then
		part.Orientation = config.Orientation
	else
		part.Orientation = Vector3.zero
	end
end

local function applySpawnLocation(spawnLocation, config)
	applyPart(spawnLocation, {
		CanTouch = true,
		Color = config.Color,
		Material = config.Material,
		Position = config.Position,
		Size = config.Size,
		Transparency = 0.05,
	})

	spawnLocation.Duration = 0
	spawnLocation.Enabled = true
	spawnLocation.Neutral = true
end

local function ensureBillboard(part, text, textColor)
	local billboard = part:FindFirstChild("ZoneBillboard")
	if billboard and not billboard:IsA("BillboardGui") then
		billboard:Destroy()
		billboard = nil
	end

	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "ZoneBillboard"
		billboard.Parent = part
	end

	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(240, 56)
	billboard.StudsOffset = Vector3.new(0, 5, 0)

	for _, child in ipairs(billboard:GetChildren()) do
		if child:IsA("TextLabel") and child.Name ~= "Label" then
			child:Destroy()
		end
	end

	local label = billboard:FindFirstChild("Label")
	if label and not label:IsA("TextLabel") then
		label:Destroy()
		label = nil
	end

	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Parent = billboard
	end

	label.BackgroundColor3 = Color3.fromRGB(22, 25, 27)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true

	local corner = label:FindFirstChild("Corner") or Instance.new("UICorner")
	corner.Name = "Corner"
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label

	local constraint = label:FindFirstChild("TextSizeConstraint") or Instance.new("UITextSizeConstraint")
	constraint.Name = "TextSizeConstraint"
	constraint.MaxTextSize = 26
	constraint.MinTextSize = 12
	constraint.Parent = label
end

local function ensureBorderPart(folder, name, position, size, color)
	local part = ensureBasePart(folder, name, "Part")
	applyPart(part, {
		CanTouch = false,
		Color = color,
		Material = MAP_CONFIG.Border.Material,
		Position = position,
		Size = size,
	})
	part:SetAttribute("GEIMapManaged", true)
	return part
end

local function createRectBorder(folder, prefix, center, size, color)
	local height = MAP_CONFIG.Border.Height
	local thickness = MAP_CONFIG.Border.Thickness
	local y = center.Y + size.Y / 2 + height / 2
	local xHalf = size.X / 2
	local zHalf = size.Z / 2

	ensureBorderPart(
		folder,
		prefix .. "_Border_N",
		Vector3.new(center.X, y, center.Z - zHalf - thickness / 2),
		Vector3.new(size.X + thickness * 2, height, thickness),
		color
	)
	ensureBorderPart(
		folder,
		prefix .. "_Border_S",
		Vector3.new(center.X, y, center.Z + zHalf + thickness / 2),
		Vector3.new(size.X + thickness * 2, height, thickness),
		color
	)
	ensureBorderPart(
		folder,
		prefix .. "_Border_W",
		Vector3.new(center.X - xHalf - thickness / 2, y, center.Z),
		Vector3.new(thickness, height, size.Z),
		color
	)
	ensureBorderPart(
		folder,
		prefix .. "_Border_E",
		Vector3.new(center.X + xHalf + thickness / 2, y, center.Z),
		Vector3.new(thickness, height, size.Z),
		color
	)
end

local function ensureDecorPart(folder, name, position, size, color, material, transparency)
	local part = ensureBasePart(folder, name, "Part")
	applyPart(part, {
		CanCollide = false,
		CanTouch = false,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Position = position,
		Size = size,
		Transparency = transparency or 0,
	})
	part:SetAttribute("GEIMapManaged", true)
	return part
end

local function buildDecor(folder)
	createRectBorder(folder, "Lobby", MAP_CONFIG.LobbyFloor.Position, MAP_CONFIG.LobbyFloor.Size, MAP_CONFIG.Border.Color)
	createRectBorder(folder, "WasteArea", MAP_CONFIG.WasteArea.Position, MAP_CONFIG.WasteArea.Size, MAP_CONFIG.Border.ZoneColor)
	createRectBorder(folder, "SellZone", MAP_CONFIG.SellZone.Position, MAP_CONFIG.SellZone.Size, Color3.fromRGB(31, 88, 49))
	createRectBorder(folder, "ShopZone", MAP_CONFIG.BuyZone.Position, MAP_CONFIG.BuyZone.Size, Color3.fromRGB(43, 56, 113))

	ensureDecorPart(
		folder,
		"Path_To_Waste",
		Vector3.new(0, 1.16, -10),
		Vector3.new(12, 0.18, 34),
		Color3.fromRGB(184, 178, 151),
		Enum.Material.Concrete
	)
	ensureDecorPart(
		folder,
		"Path_To_Sell",
		Vector3.new(-26, 1.17, -22),
		Vector3.new(30, 0.18, 8),
		Color3.fromRGB(178, 194, 161),
		Enum.Material.Concrete
	)
	ensureDecorPart(
		folder,
		"Path_To_Shop",
		Vector3.new(26, 1.17, -22),
		Vector3.new(30, 0.18, 8),
		Color3.fromRGB(162, 175, 213),
		Enum.Material.Concrete
	)
	ensureDecorPart(
		folder,
		"Sell_Kiosk",
		Vector3.new(-45, 3.2, -23),
		Vector3.new(10, 4, 2),
		Color3.fromRGB(56, 144, 75),
		Enum.Material.SmoothPlastic
	)
	ensureDecorPart(
		folder,
		"Shop_Kiosk",
		Vector3.new(45, 3.2, -23),
		Vector3.new(10, 4, 2),
		Color3.fromRGB(68, 91, 187),
		Enum.Material.SmoothPlastic
	)
	ensureDecorPart(
		folder,
		"Lobby_Center_Marker",
		Vector3.new(0, 1.18, -35),
		Vector3.new(18, 0.2, 18),
		Color3.fromRGB(142, 154, 150),
		Enum.Material.SmoothPlastic,
		0.08
	)

	for index, position in ipairs({
		Vector3.new(-55, 3.1, 42),
		Vector3.new(55, 3.1, 42),
		Vector3.new(-55, 3.1, -50),
		Vector3.new(55, 3.1, -50),
	}) do
		local post = ensureDecorPart(
			folder,
			"Corner_Post_" .. tostring(index),
			position,
			Vector3.new(3, 4.2, 3),
			Color3.fromRGB(63, 70, 68),
			Enum.Material.Wood
		)
		post.Shape = Enum.PartType.Cylinder
	end
end

local function buildMap()
	local wasteZone = ensureFolder(MAP_CONFIG.Folders.WasteZone)
	local decorFolder = ensureFolder(MAP_CONFIG.Folders.MapDecor)

	local lobbyFloor = ensureBasePart(Workspace, MAP_CONFIG.LobbyFloor.Name, "Part")
	applyPart(lobbyFloor, {
		CanTouch = false,
		Color = MAP_CONFIG.LobbyFloor.Color,
		Material = MAP_CONFIG.LobbyFloor.Material,
		Position = MAP_CONFIG.LobbyFloor.Position,
		Size = MAP_CONFIG.LobbyFloor.Size,
	})

	local wasteArea = ensureBasePart(Workspace, MAP_CONFIG.WasteArea.Name, "Part")
	applyPart(wasteArea, {
		CanTouch = false,
		Color = MAP_CONFIG.WasteArea.Color,
		Material = MAP_CONFIG.WasteArea.Material,
		Position = MAP_CONFIG.WasteArea.Position,
		Size = MAP_CONFIG.WasteArea.Size,
	})
	ensureBillboard(wasteArea, MAP_CONFIG.WasteArea.Label, MAP_CONFIG.WasteArea.LabelColor)

	local sellZone = ensureBasePart(Workspace, MAP_CONFIG.SellZone.Name, "Part")
	applyPart(sellZone, {
		CanCollide = false,
		CanTouch = true,
		Color = MAP_CONFIG.SellZone.Color,
		Material = MAP_CONFIG.SellZone.Material,
		Position = MAP_CONFIG.SellZone.Position,
		Size = MAP_CONFIG.SellZone.Size,
		Transparency = 0.28,
	})
	ensureBillboard(sellZone, MAP_CONFIG.SellZone.Label, MAP_CONFIG.SellZone.LabelColor)

	local buyZone = ensureBasePart(Workspace, MAP_CONFIG.BuyZone.Name, "Part")
	applyPart(buyZone, {
		CanCollide = false,
		CanTouch = true,
		Color = MAP_CONFIG.BuyZone.Color,
		Material = MAP_CONFIG.BuyZone.Material,
		Position = MAP_CONFIG.BuyZone.Position,
		Size = MAP_CONFIG.BuyZone.Size,
		Transparency = 0.28,
	})
	ensureBillboard(buyZone, MAP_CONFIG.BuyZone.Label, MAP_CONFIG.BuyZone.LabelColor)

	local spawnLocation = Workspace:FindFirstChild(MAP_CONFIG.SpawnLocation.Name)
	if spawnLocation and not spawnLocation:IsA("SpawnLocation") then
		spawnLocation.Name = MAP_CONFIG.SpawnLocation.Name .. "_Old"
		warn("[GEI] Renamed non-SpawnLocation object to keep SpawnLocation available:", spawnLocation.Name)
		spawnLocation = nil
	end

	if not spawnLocation then
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = MAP_CONFIG.SpawnLocation.Name
		spawnLocation.Parent = Workspace
	end
	applySpawnLocation(spawnLocation, MAP_CONFIG.SpawnLocation)

	wasteZone:SetAttribute("GEIMapManaged", true)
	decorFolder:SetAttribute("GEIMapManaged", true)
	lobbyFloor:SetAttribute("GEIMapManaged", true)
	wasteArea:SetAttribute("GEIMapManaged", true)
	sellZone:SetAttribute("GEIMapManaged", true)
	buyZone:SetAttribute("GEIMapManaged", true)
	spawnLocation:SetAttribute("GEIMapManaged", true)

	buildDecor(decorFolder)
end

buildMap()
