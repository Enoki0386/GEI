local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. ShopClient stopped.")
	return
end

local GameData = require(gameDataModule)
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotes then
	warn("[GEI] Remotes folder is missing. ShopClient stopped.")
	return
end

local buyItemRemote = remotes:WaitForChild("BuyItem", 10)
local equipItemRemote = remotes:WaitForChild("EquipItem", 10)
local shopStateRemote = remotes:WaitForChild("ShopState", 10)
local purchaseResultRemote = remotes:WaitForChild("PurchaseResult", 10)
local playerDataRemote = remotes:WaitForChild("PlayerDataUpdate", 10)
local playerGui = player:WaitForChild("PlayerGui", 10)
local playerData = player:WaitForChild("PlayerData", 10)

if not buyItemRemote or not equipItemRemote or not shopStateRemote or not playerGui or not playerData then
	warn("[GEI] ShopClient could not find required objects.")
	return
end

local function new(className, properties, parent)
	local instance = Instance.new(className)
	for propertyName, value in pairs(properties or {}) do
		instance[propertyName] = value
	end
	instance.Parent = parent
	return instance
end

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end

	return tostring(value)
end

local gui = playerGui:FindFirstChild("GEIShop")
if gui then
	gui:Destroy()
end

gui = new("ScreenGui", {
	Name = "GEIShop",
	DisplayOrder = 30,
	IgnoreGuiInset = false,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local overlay = new("Frame", {
	Name = "Overlay",
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.58,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
}, gui)

local panel = new("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(238, 242, 240),
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.72, 0.68),
}, overlay)
new("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
new("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 2,
	Transparency = 0.12,
}, panel)
new("UISizeConstraint", {
	MaxSize = Vector2.new(860, 560),
	MinSize = Vector2.new(520, 360),
}, panel)

local panelScale = new("UIScale", {
	Scale = 0.92,
}, panel)

local title = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(24, 18),
	Size = UDim2.new(1, -88, 0, 34),
	Text = "Shop",
	TextColor3 = Color3.fromRGB(24, 29, 31),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
new("UITextSizeConstraint", {
	MaxTextSize = 30,
	MinTextSize = 16,
}, title)

local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(221, 227, 226),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.new(1, -18, 0, 18),
	Size = UDim2.fromOffset(38, 38),
	Text = "X",
	TextColor3 = Color3.fromRGB(37, 43, 45),
	TextScaled = true,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, closeButton)
new("UITextSizeConstraint", {
	MaxTextSize = 20,
	MinTextSize = 10,
}, closeButton)

local tabs = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 68),
	Size = UDim2.new(1, -48, 0, 44),
}, panel)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabs)

local gridHolder = new("ScrollingFrame", {
	Name = "Grid",
	Active = true,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	Position = UDim2.fromOffset(24, 126),
	ScrollBarImageColor3 = Color3.fromRGB(93, 103, 108),
	ScrollBarThickness = 5,
	Size = UDim2.new(1, -48, 1, -150),
}, panel)

local gridLayout = new("UIGridLayout", {
	CellPadding = UDim2.fromOffset(12, 12),
	CellSize = UDim2.fromOffset(166, 184),
	FillDirectionMaxCells = 4,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, gridHolder)

local activeTab = "Tools"
local tabButtons = {}

local function getLeaderCash()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash and cash.Value or 0
end

local function ownsItem(category, itemId)
	local folderName = category == "Tool" and "OwnedTools" or "OwnedBackpacks"
	local folder = playerData:FindFirstChild(folderName)
	local owned = folder and folder:FindFirstChild(itemId)
	return owned ~= nil and owned:IsA("BoolValue") and owned.Value == true
end

local function isEquipped(category, itemId)
	local valueName = category == "Tool" and "EquippedTool" or "EquippedBackpack"
	local equipped = playerData:FindFirstChild(valueName)
	return equipped ~= nil and equipped.Value == itemId
end

local function clearGrid()
	for _, child in ipairs(gridHolder:GetChildren()) do
		if child ~= gridLayout then
			child:Destroy()
		end
	end
end

local function createItemCard(category, itemId, config, layoutOrder)
	local owned = ownsItem(category, itemId)
	local equipped = isEquipped(category, itemId)
	local canAfford = getLeaderCash() >= config.Price

	local card = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, gridHolder)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
	new("UIStroke", {
		Color = equipped and Color3.fromRGB(70, 196, 112) or Color3.fromRGB(214, 221, 222),
		Thickness = equipped and 2.2 or 1,
		Transparency = equipped and 0.02 or 0.1,
	}, card)

	local swatch = new("Frame", {
		BackgroundColor3 = config.Color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(42, 42),
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 11) }, swatch)

	local itemName = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(66, 12),
		Size = UDim2.new(1, -78, 0, 42),
		Text = config.Name,
		TextColor3 = Color3.fromRGB(24, 29, 31),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	new("UITextSizeConstraint", {
		MaxTextSize = 17,
		MinTextSize = 9,
	}, itemName)

	local statsText
	if category == "Tool" then
		statsText = tostring(config.Damage) .. " Damage\n" .. tostring(config.Range) .. " Range"
	else
		statsText = tostring(config.Capacity) .. " Capacity"
	end

	local stats = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -28, 0, 44),
		Text = statsText,
		TextColor3 = Color3.fromRGB(79, 89, 94),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, card)
	new("UITextSizeConstraint", {
		MaxTextSize = 15,
		MinTextSize = 8,
	}, stats)

	local price = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(14, 116),
		Size = UDim2.new(1, -28, 0, 22),
		Text = config.Price <= 0 and "Free" or formatNumber(config.Price) .. " Cash",
		TextColor3 = Color3.fromRGB(36, 116, 64),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	new("UITextSizeConstraint", {
		MaxTextSize = 14,
		MinTextSize = 8,
	}, price)

	local buttonText = "Buy"
	local buttonColor = canAfford and Color3.fromRGB(43, 153, 86) or Color3.fromRGB(150, 158, 162)
	if owned then
		buttonText = equipped and "Equipped" or "Equip"
		buttonColor = equipped and Color3.fromRGB(86, 159, 108) or Color3.fromRGB(58, 113, 204)
	end

	local button = new("TextButton", {
		AutoButtonColor = not equipped,
		BackgroundColor3 = buttonColor,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(0, 14, 1, -42),
		Size = UDim2.new(1, -28, 0, 30),
		Text = buttonText,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
	new("UITextSizeConstraint", {
		MaxTextSize = 15,
		MinTextSize = 8,
	}, button)

	button.Activated:Connect(function()
		if equipped then
			return
		end

		if owned then
			equipItemRemote:FireServer(category, itemId)
		else
			buyItemRemote:FireServer(category, itemId)
		end
	end)
end

local function refreshTabs()
	for tabName, button in pairs(tabButtons) do
		local selected = tabName == activeTab
		button.BackgroundColor3 = selected and Color3.fromRGB(38, 45, 49) or Color3.fromRGB(220, 226, 226)
		button.TextColor3 = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(39, 45, 48)
	end
end

local function refreshGrid()
	clearGrid()
	refreshTabs()

	if activeTab == "Tools" then
		for index, toolId in ipairs(GameData.ToolOrder) do
			createItemCard("Tool", toolId, GameData.Tools[toolId], index)
		end
	else
		for index, backpackId in ipairs(GameData.BackpackOrder) do
			createItemCard("Backpack", backpackId, GameData.Backpacks[backpackId], index)
		end
	end
end

local function createTab(tabName, text, layoutOrder)
	local button = new("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(220, 226, 226),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(128, 40),
		Text = text,
		TextColor3 = Color3.fromRGB(39, 45, 48),
		TextScaled = true,
	}, tabs)
	new("UICorner", { CornerRadius = UDim.new(0, 13) }, button)
	new("UITextSizeConstraint", {
		MaxTextSize = 17,
		MinTextSize = 9,
	}, button)

	button.Activated:Connect(function()
		activeTab = tabName
		refreshGrid()
	end)

	tabButtons[tabName] = button
end

createTab("Tools", "Tools", 1)
createTab("Backpacks", "Backpacks", 2)

local openTween = nil
local function openShop()
	if openTween then
		openTween:Cancel()
	end

	overlay.Visible = true
	panelScale.Scale = 0.88
	openTween = TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	refreshGrid()
	openTween:Play()
end

local function closeShop()
	if openTween then
		openTween:Cancel()
	end

	local tween = TweenService:Create(panelScale, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.9,
	})
	tween:Play()
	tween.Completed:Connect(function()
		overlay.Visible = false
	end)
end

closeButton.Activated:Connect(closeShop)

shopStateRemote.OnClientEvent:Connect(function(isOpen)
	if isOpen then
		openShop()
	else
		closeShop()
	end
end)

if playerDataRemote then
	playerDataRemote.OnClientEvent:Connect(refreshGrid)
end

if purchaseResultRemote then
	purchaseResultRemote.OnClientEvent:Connect(function()
		refreshGrid()
	end)
end

playerData.DescendantAdded:Connect(refreshGrid)
for _, descendant in ipairs(playerData:GetDescendants()) do
	if descendant:IsA("ValueBase") then
		descendant.Changed:Connect(refreshGrid)
	end
end

local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
	for _, descendant in ipairs(leaderstats:GetDescendants()) do
		if descendant:IsA("ValueBase") then
			descendant.Changed:Connect(refreshGrid)
		end
	end
end

refreshGrid()
