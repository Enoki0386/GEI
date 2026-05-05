local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. ShopClient stopped.")
	return
end

local GameData = require(gameDataModule)
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local soundUtilModule = sharedFolder and sharedFolder:WaitForChild("SoundUtil", 10)
local SoundUtil = soundUtilModule and require(soundUtilModule)
local uiIconUtilsModule = sharedFolder and sharedFolder:WaitForChild("UIIconUtils", 10)
local UIIconUtils = uiIconUtilsModule and require(uiIconUtilsModule)
local notificationModule = sharedFolder and sharedFolder:WaitForChild("NotificationClient", 10)
local NotificationClient = notificationModule and require(notificationModule)
local numberFormatModule = sharedFolder and sharedFolder:WaitForChild("NumberFormat", 10)
local NumberFormat = numberFormatModule and require(numberFormatModule)
local buttonEffectsModule = sharedFolder and sharedFolder:WaitForChild("ButtonEffects", 10)
local ButtonEffects = buttonEffectsModule and require(buttonEffectsModule)
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
local playerData = player:WaitForChild("PlayerData", 60)

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

local formatNumber = NumberFormat and NumberFormat.Compact or tostring

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
	if category == "Tool" then
		local isToolEquipped = playerData:FindFirstChild("IsToolEquipped")
		return equipped ~= nil and equipped.Value == itemId and isToolEquipped ~= nil and isToolEquipped.Value == true
	end

	return equipped ~= nil and equipped.Value == itemId
end

local function getStatus(category, itemId, config)
	local owned = ownsItem(category, itemId)
	local equipped = isEquipped(category, itemId)
	if equipped then
		return "Equipped", Color3.fromRGB(77, 172, 104)
	elseif owned then
		return "Equip", Color3.fromRGB(75, 121, 219)
	elseif getLeaderCash() >= config.Price then
		return "Buy", Color3.fromRGB(58, 174, 97)
	end

	return "Buy", Color3.fromRGB(119, 127, 132)
end

local function getConfig(category, itemId)
	if category == "Tool" then
		return GameData.Tools[itemId]
	elseif category == "Backpack" then
		return GameData.Backpacks[itemId]
	end

	return nil
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
	BackgroundColor3 = Color3.fromRGB(7, 10, 13),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
}, gui)

local panel = new("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(234, 240, 238),
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.78, 0.7),
}, overlay)
new("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
new("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 2,
	Transparency = 0.1,
}, panel)
new("UISizeConstraint", {
	MaxSize = Vector2.new(980, 600),
	MinSize = Vector2.new(640, 420),
}, panel)

local panelScale = new("UIScale", {
	Scale = 0.92,
}, panel)
local panelTargetScale = 1

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function applyResponsiveShop()
	local viewport = getViewportSize()
	local safeSize = Vector2.new(math.max(320, viewport.X - 24), math.max(360, viewport.Y - 24))
	local baseSize = Vector2.new(640, 420)
	panelTargetScale = math.clamp(math.min(safeSize.X / baseSize.X, safeSize.Y / baseSize.Y), 0.55, 1)
	if overlay.Visible then
		panelScale.Scale = panelTargetScale
	end
end

local title = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(24, 18),
	Size = UDim2.new(1, -88, 0, 34),
	Text = "Shop",
	TextColor3 = Color3.fromRGB(23, 28, 31),
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
	BackgroundColor3 = Color3.fromRGB(54, 62, 67),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.new(1, -18, 0, 18),
	Size = UDim2.fromOffset(38, 38),
	Text = "X",
	TextColor3 = Color3.fromRGB(235, 241, 244),
	TextScaled = true,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, closeButton)
if ButtonEffects then
	ButtonEffects.Apply(closeButton, {
		NormalColor = Color3.fromRGB(54, 62, 67),
		HoverColor = Color3.fromRGB(67, 76, 82),
		PressColor = Color3.fromRGB(38, 45, 50),
	})
end
new("UITextSizeConstraint", {
	MaxTextSize = 20,
	MinTextSize = 10,
}, closeButton)

local tabs = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 68),
	Size = UDim2.new(1, -48, 0, 42),
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
	Size = UDim2.new(1, -338, 1, -150),
}, panel)

local gridLayout = new("UIGridLayout", {
	CellPadding = UDim2.fromOffset(12, 12),
	CellSize = UDim2.fromOffset(158, 160),
	FillDirectionMaxCells = 3,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, gridHolder)

local detailsPanel = new("Frame", {
	Name = "DetailsPanel",
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Color3.fromRGB(23, 29, 33),
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	Position = UDim2.new(1, -24, 0, 126),
	Size = UDim2.new(0, 276, 1, -150),
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, detailsPanel)
new("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 1,
	Transparency = 0.78,
}, detailsPanel)

local detailSwatch = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(18, 18),
	Size = UDim2.fromOffset(46, 46),
}, detailsPanel)
new("UICorner", { CornerRadius = UDim.new(0, 13) }, detailSwatch)

local detailTitle = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(76, 16),
	Size = UDim2.new(1, -94, 0, 48),
	Text = "Choose an item",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, detailsPanel)
new("UITextSizeConstraint", {
	MaxTextSize = 22,
	MinTextSize = 11,
}, detailTitle)

local detailDescription = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Position = UDim2.fromOffset(18, 78),
	Size = UDim2.new(1, -36, 0, 54),
	Text = "Select an item to view details.",
	TextColor3 = Color3.fromRGB(207, 218, 222),
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, detailsPanel)
new("UITextSizeConstraint", {
	MaxTextSize = 15,
	MinTextSize = 9,
}, detailDescription)

local detailStats = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 150),
	Size = UDim2.new(1, -36, 1, -230),
}, detailsPanel)
local detailStatsLayout = new("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, detailStats)

local detailAction = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(58, 174, 97),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.new(1, -36, 0, 42),
	Text = "Buy",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
}, detailsPanel)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, detailAction)
if ButtonEffects then
	ButtonEffects.Apply(detailAction, {
		NormalColor = Color3.fromRGB(58, 174, 97),
		DisabledColor = Color3.fromRGB(87, 96, 101),
	})
end
new("UITextSizeConstraint", {
	MaxTextSize = 18,
	MinTextSize = 10,
}, detailAction)

local activeTab = "Tools"
local selectedCategory = "Tool"
local selectedItemId = "Brush"
local tabButtons = {}
local function showNotification(text, color)
	if NotificationClient then
		NotificationClient.Show(text, {
			Type = color == Color3.fromRGB(255, 177, 137) and "Error" or "Success",
			Color = color,
		})
	end
end

local function clearDetailsStats()
	for _, child in ipairs(detailStats:GetChildren()) do
		if child ~= detailStatsLayout then
			child:Destroy()
		end
	end
end

local function addDetailRow(labelText, valueText, layoutOrder, currencyName)
	local row = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(35, 43, 47),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 34),
	}, detailStats)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, row)

	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(0.48, -12, 1, -8),
		Text = labelText,
		TextColor3 = Color3.fromRGB(160, 176, 182),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	new("UITextSizeConstraint", {
		MaxTextSize = 13,
		MinTextSize = 8,
	}, label)

	local icon = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "",
		Position = UDim2.new(0.48, 0, 0.5, -9),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(18, 18),
		Visible = false,
	}, row)
	local hasIcon = UIIconUtils and UIIconUtils.ApplyCurrencyIcon(icon, currencyName)

	local value = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = hasIcon and UDim2.new(0.48, 22, 0, 4) or UDim2.new(0.48, 0, 0, 4),
		Size = hasIcon and UDim2.new(0.52, -32, 1, -8) or UDim2.new(0.52, -10, 1, -8),
		Text = valueText,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
	new("UITextSizeConstraint", {
		MaxTextSize = 14,
		MinTextSize = 8,
	}, value)
end

local function refreshDetails()
	local config = getConfig(selectedCategory, selectedItemId)
	if not config then
		return
	end

	detailSwatch.BackgroundColor3 = config.Color
	detailTitle.Text = config.Name
	detailDescription.Text = config.Description or "No description yet."
	clearDetailsStats()

	if selectedCategory == "Tool" then
		addDetailRow("Damage", tostring(config.Damage), 1)
		addDetailRow("Cooldown", string.format("%.2fs", config.Cooldown or 0), 2)
	else
		addDetailRow("Capacity", formatNumber(config.Capacity), 1)
	end
	addDetailRow("Price", config.Price <= 0 and "Free" or formatNumber(config.Price) .. " Cash", 10, config.Price > 0 and "Cash" or nil)

	local buttonText, buttonColor = getStatus(selectedCategory, selectedItemId, config)
	detailAction.Text = buttonText
	detailAction.BackgroundColor3 = buttonColor
	detailAction.AutoButtonColor = buttonText ~= "Equipped"
	if ButtonEffects then
		ButtonEffects.SetState(detailAction, {
			NormalColor = buttonColor,
			Disabled = buttonText == "Equipped",
			DisabledColor = Color3.fromRGB(87, 96, 101),
		})
	end
end

local function clearGrid()
	for _, child in ipairs(gridHolder:GetChildren()) do
		if child ~= gridLayout then
			child:Destroy()
		end
	end
end

local function selectItem(category, itemId)
	selectedCategory = category
	selectedItemId = itemId
	refreshDetails()
end

local function triggerSelectedAction()
	local config = getConfig(selectedCategory, selectedItemId)
	if not config then
		return
	end

	if isEquipped(selectedCategory, selectedItemId) then
		return
	end

	if ownsItem(selectedCategory, selectedItemId) then
		equipItemRemote:FireServer(selectedCategory, selectedItemId)
	else
		buyItemRemote:FireServer(selectedCategory, selectedItemId)
	end
end

local function createItemCard(category, itemId, config, layoutOrder)
	local selected = selectedCategory == category and selectedItemId == itemId
	local owned = ownsItem(category, itemId)
	local equipped = isEquipped(category, itemId)
	local buttonText, buttonColor = getStatus(category, itemId, config)

	local card = new("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = selected and Color3.fromRGB(252, 255, 246) or Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Text = "",
	}, gridHolder)
	if ButtonEffects then
		ButtonEffects.Apply(card, {
			NormalColor = selected and Color3.fromRGB(252, 255, 246) or Color3.fromRGB(255, 255, 255),
			HoverColor = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(242, 248, 246),
			PressColor = Color3.fromRGB(228, 236, 234),
		})
	end
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
	new("UIStroke", {
		Color = selected and config.Color or (equipped and Color3.fromRGB(70, 196, 112) or Color3.fromRGB(214, 221, 222)),
		Thickness = selected and 2.6 or (equipped and 2 or 1),
		Transparency = selected and 0 or 0.12,
	}, card)

	local swatch = new("Frame", {
		BackgroundColor3 = config.Color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(40, 40),
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 11) }, swatch)

	local itemName = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(62, 11),
		Size = UDim2.new(1, -72, 0, 38),
		Text = config.Name,
		TextColor3 = Color3.fromRGB(24, 29, 31),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	new("UITextSizeConstraint", {
		MaxTextSize = 16,
		MinTextSize = 9,
	}, itemName)

	local statText
	if category == "Tool" then
		statText = tostring(config.Damage) .. " Damage"
	else
		statText = formatNumber(config.Capacity) .. " Capacity"
	end

	local stats = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 0, 24),
		Text = statText,
		TextColor3 = Color3.fromRGB(70, 80, 85),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	new("UITextSizeConstraint", {
		MaxTextSize = 13,
		MinTextSize = 8,
	}, stats)

	local priceIconId = UIIconUtils and UIIconUtils.GetCurrencyIcon("Cash")
	local priceHasIcon = config.Price > 0 and priceIconId ~= nil and priceIconId ~= ""
	local priceIcon = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "",
		Position = UDim2.fromOffset(12, 94),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(16, 16),
		Visible = false,
	}, card)
	if priceHasIcon then
		priceIcon.Image = priceIconId
		priceIcon.Visible = true
	end

	local price = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = priceHasIcon and UDim2.fromOffset(32, 91) or UDim2.fromOffset(12, 91),
		Size = priceHasIcon and UDim2.new(1, -44, 0, 22) or UDim2.new(1, -24, 0, 22),
		Text = config.Price <= 0 and "Free" or formatNumber(config.Price) .. " Cash",
		TextColor3 = Color3.fromRGB(36, 116, 64),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	new("UITextSizeConstraint", {
		MaxTextSize = 13,
		MinTextSize = 8,
	}, price)

	local action = new("TextButton", {
		AutoButtonColor = buttonText ~= "Equipped",
		BackgroundColor3 = buttonColor,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(0, 12, 1, -38),
		Size = UDim2.new(1, -24, 0, 28),
		Text = buttonText,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, action)
	if ButtonEffects then
		ButtonEffects.Apply(action, {
			NormalColor = buttonColor,
			Disabled = buttonText == "Equipped",
			DisabledColor = Color3.fromRGB(92, 101, 106),
		})
	end
	new("UITextSizeConstraint", {
		MaxTextSize = 14,
		MinTextSize = 8,
	}, action)

	card.Activated:Connect(function()
		selectItem(category, itemId)
	end)

	action.Activated:Connect(function()
		if ButtonEffects and not ButtonEffects.IsEnabled(action) then
			return
		end
		selectItem(category, itemId)
		triggerSelectedAction()
	end)
end

local function refreshTabs()
	for tabName, button in pairs(tabButtons) do
		local selected = tabName == activeTab
		local buttonColor = selected and Color3.fromRGB(37, 44, 48) or Color3.fromRGB(220, 228, 228)
		button.BackgroundColor3 = buttonColor
		button.TextColor3 = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(39, 45, 48)
		if ButtonEffects then
			ButtonEffects.SetState(button, { NormalColor = buttonColor })
		end
	end
end

local function refreshGrid()
	clearGrid()
	refreshTabs()
	applyResponsiveShop()

	if activeTab == "Tools" then
		for index, toolId in ipairs(GameData.ToolOrder) do
			createItemCard("Tool", toolId, GameData.Tools[toolId], index)
		end
	else
		for index, backpackId in ipairs(GameData.BackpackOrder) do
			createItemCard("Backpack", backpackId, GameData.Backpacks[backpackId], index)
		end
	end

	refreshDetails()
end

local function createTab(tabName, text, category, firstItemId, layoutOrder)
	local button = new("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(220, 228, 228),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(136, 40),
		Text = text,
		TextColor3 = Color3.fromRGB(39, 45, 48),
		TextScaled = true,
	}, tabs)
	new("UICorner", { CornerRadius = UDim.new(0, 13) }, button)
	if ButtonEffects then
		ButtonEffects.Apply(button, { NormalColor = Color3.fromRGB(220, 228, 228) })
	end
	new("UITextSizeConstraint", {
		MaxTextSize = 17,
		MinTextSize = 9,
	}, button)

	button.Activated:Connect(function()
		activeTab = tabName
		selectItem(category, firstItemId)
		refreshGrid()
	end)

	tabButtons[tabName] = button
end

createTab("Tools", "Tools", "Tool", GameData.ToolOrder[1], 1)
createTab("Backpacks", "Backpacks", "Backpack", GameData.BackpackOrder[1], 2)

detailAction.Activated:Connect(function()
	if ButtonEffects and not ButtonEffects.IsEnabled(detailAction) then
		return
	end
	triggerSelectedAction()
end)

local openTween = nil
local function openShop()
	if openTween then
		openTween:Cancel()
	end

	overlay.Visible = true
	applyResponsiveShop()
	panelScale.Scale = panelTargetScale * 0.88
	openTween = TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = panelTargetScale,
	})
	refreshGrid()
	openTween:Play()
end

local function closeShop()
	if openTween then
		openTween:Cancel()
	end

	local tween = TweenService:Create(panelScale, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = panelTargetScale * 0.9,
	})
	tween:Play()
	tween.Completed:Connect(function()
		overlay.Visible = false
	end)
end

closeButton.Activated:Connect(closeShop)

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveShop)
end

shopStateRemote.OnClientEvent:Connect(function(isOpen)
	if isOpen then
		openShop()
	else
		closeShop()
	end
end)

if playerDataRemote then
	playerDataRemote.OnClientEvent:Connect(function()
		refreshGrid()
	end)
end

if purchaseResultRemote then
	purchaseResultRemote.OnClientEvent:Connect(function(ok, reason, category, itemId)
		local config = getConfig(category, itemId)
		local itemName = config and config.Name or tostring(itemId)

		if ok then
			if reason == "Bought" then
				if SoundUtil then
					SoundUtil.Play("Coin", GameData, playerGui)
				end
				showNotification(itemName .. " bought.", Color3.fromRGB(136, 255, 164))
			elseif reason == "Equipped" then
				showNotification(itemName .. " equipped.", Color3.fromRGB(179, 212, 255))
			elseif reason == "Unequipped" then
				showNotification(itemName .. " unequipped.", Color3.fromRGB(207, 218, 222))
			else
				showNotification(itemName .. " updated.", Color3.fromRGB(220, 235, 255))
			end
		else
			if SoundUtil then
				SoundUtil.Play("Error", GameData, playerGui)
			end

			local message = "Purchase unavailable: " .. itemName
			if reason == "NotEnoughCash" then
				message = "Not enough Cash."
			elseif reason == "NotEnoughDiamonds" then
				message = "Not enough Diamonds."
			elseif reason == "UnknownCategory" then
				message = "Invalid shop category."
			elseif reason == "DataMissing" then
				message = "Player data is not ready yet."
			end
			warn("[ShopClient]", message, "reason:", reason)
			showNotification(message, Color3.fromRGB(255, 177, 137))
		end

		refreshGrid()
	end)
end

playerData.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ValueBase") then
		descendant.Changed:Connect(refreshGrid)
	end
	refreshGrid()
end)

for _, descendant in ipairs(playerData:GetDescendants()) do
	if descendant:IsA("ValueBase") then
		descendant.Changed:Connect(refreshGrid)
	end
end

local leaderstats = player:WaitForChild("leaderstats", 60)
if leaderstats then
	leaderstats.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ValueBase") then
			descendant.Changed:Connect(refreshGrid)
		end
		refreshGrid()
	end)

	for _, descendant in ipairs(leaderstats:GetDescendants()) do
		if descendant:IsA("ValueBase") then
			descendant.Changed:Connect(refreshGrid)
		end
	end
end

refreshGrid()
