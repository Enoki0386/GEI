local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

local function new(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local gui = playerGui:FindFirstChild("GEICollectionIndex")
if gui then gui:Destroy() end

gui = new("ScreenGui", {
	Name = "GEICollectionIndex",
	DisplayOrder = 36,
	ResetOnSpawn = false,
}, playerGui)

local button = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	BackgroundColor3 = Color3.fromRGB(24, 30, 35),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(1, -22, 1, -172),
	Size = UDim2.fromOffset(120, 42),
	Text = "Index",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, button)

local overlay = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(6, 9, 12),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
}, gui)

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(18, 23, 28),
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(760, 520),
}, overlay)
new("UICorner", { CornerRadius = UDim.new(0, 20) }, panel)
new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.75, Thickness = 1 }, panel)
local scale = new("UIScale", { Scale = 0.92 }, panel)

new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(22, 16),
	Size = UDim2.new(1, -80, 0, 38),
	Text = "Collection Index",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Color3.fromRGB(42, 50, 58),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(34, 34),
	Text = "X",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, close)

local list = new("ScrollingFrame", {
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(12, 16, 20),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	Position = UDim2.fromOffset(22, 70),
	ScrollBarThickness = 5,
	Size = UDim2.new(1, -44, 1, -92),
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, list)
local layout = new("UIGridLayout", {
	CellPadding = UDim2.fromOffset(12, 12),
	CellSize = UDim2.fromOffset(210, 95),
	FillDirectionMaxCells = 3,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, list)

local function getDiscoveredPets()
	local result = {}
	local data = player:FindFirstChild("PlayerData")
	local discovered = data and data:FindFirstChild("Pets") and data.Pets:FindFirstChild("Discovered")
	if discovered then
		for _, child in ipairs(discovered:GetChildren()) do
			if child:IsA("BoolValue") and child.Value == true then
				result[child.Name] = true
			end
		end
	end
	return result
end

local function rarityColor(rarity)
	return (GameData.Pets and GameData.Pets.RarityColors and GameData.Pets.RarityColors[rarity]) or Color3.fromRGB(255, 255, 255)
end

local function makeCard(title, subtitle, color, discovered, order)
	local card = new("Frame", {
		BackgroundColor3 = discovered and Color3.fromRGB(24, 31, 36) or Color3.fromRGB(38, 41, 44),
		BackgroundTransparency = discovered and 0.05 or 0.25,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, list)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, card)
	local stripe = new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 7, 1, 0),
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, stripe)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -28, 0, 34),
		Text = discovered and title or "???",
		TextColor3 = discovered and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 166, 170),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(18, 50),
		Size = UDim2.new(1, -28, 0, 28),
		Text = subtitle,
		TextColor3 = discovered and color or Color3.fromRGB(130, 136, 140),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
end

local function refresh()
	for _, child in ipairs(list:GetChildren()) do
		if child ~= layout and not child:IsA("UIPadding") then child:Destroy() end
	end
	local discovered = getDiscoveredPets()
	local order = 0
	for _, egg in pairs(GameData.Eggs or {}) do
		for _, pet in ipairs(egg.Pets or {}) do
			order += 1
			makeCard(pet.Name or pet.PetId, (pet.Rarity or "Pet") .. " • " .. tostring(pet.Chance or "?") .. "%", rarityColor(pet.Rarity), discovered[pet.PetId] == true, order)
		end
	end
	for _, wasteId in ipairs(GameData.WasteOrder or {}) do
		local waste = GameData.WasteTypes[wasteId]
		if waste then
			order += 1
			makeCard(waste.Name, waste.Rarity .. " Waste", (GameData.WasteDisplay.RarityColors or {})[waste.Rarity] or waste.AccentColor, true, order)
		end
	end
end

button.Activated:Connect(function()
	refresh()
	overlay.Visible = true
	scale.Scale = 0.9
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end)

close.Activated:Connect(function()
	overlay.Visible = false
end)
