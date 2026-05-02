local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. ClientManager stopped.")
	return
end

local GameData = require(gameDataModule)
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotes then
	warn("[GEI] Remotes folder is missing. ClientManager stopped.")
	return
end

local equipItemRemote = remotes:WaitForChild("EquipItem", 10)
local sellFeedbackRemote = remotes:WaitForChild("SellFeedback", 10)
local attackFeedbackRemote = remotes:WaitForChild("AttackFeedback", 10)
local playerDataRemote = remotes:WaitForChild("PlayerDataUpdate", 10)

local playerGui = player:WaitForChild("PlayerGui", 10)
local playerData = player:WaitForChild("PlayerData", 10)
if not playerGui or not playerData then
	warn("[GEI] PlayerGui or PlayerData missing. ClientManager stopped.")
	return
end

local gui = playerGui:FindFirstChild("MainHUD")
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "MainHUD"
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = playerGui
end

for _, child in ipairs(gui:GetChildren()) do
	if child:GetAttribute("GEIClientManaged") then
		child:Destroy()
	end
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

local topStats = new("Frame", {
	Name = "TopStats",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(20, 24, 26),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(438, 46),
}, gui)
topStats:SetAttribute("GEIClientManaged", true)

new("UICorner", { CornerRadius = UDim.new(0, 14) }, topStats)
new("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 1,
	Transparency = 0.82,
}, topStats)

local statLayout = new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, topStats)

new("UIPadding", {
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
}, topStats)

local statLabels = {}

local function createStatPill(name, title, color, layoutOrder)
	local pill = new("Frame", {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(34, 39, 42),
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(134, 34),
	}, topStats)
	new("UICorner", { CornerRadius = UDim.new(0, 11) }, pill)
	new("UIStroke", {
		Color = color,
		Thickness = 1.3,
		Transparency = 0.28,
	}, pill)

	local titleLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.new(0.42, -8, 1, -6),
		Text = title,
		TextColor3 = color,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, pill)
	new("UITextSizeConstraint", {
		MaxTextSize = 14,
		MinTextSize = 8,
	}, titleLabel)

	local valueLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(0.42, 0, 0, 3),
		Size = UDim2.new(0.58, -10, 1, -6),
		Text = "0",
		TextColor3 = Color3.fromRGB(244, 247, 248),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, pill)
	new("UITextSizeConstraint", {
		MaxTextSize = 16,
		MinTextSize = 8,
	}, valueLabel)

	statLabels[name] = valueLabel
end

createStatPill("Cash", "Cash", Color3.fromRGB(116, 231, 139), 1)
createStatPill("Waste", "Waste", Color3.fromRGB(255, 211, 112), 2)
createStatPill("Diamonds", "Diamonds", Color3.fromRGB(126, 216, 255), 3)

local toolbar = new("Frame", {
	Name = "ToolBar",
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = Color3.fromRGB(21, 24, 27),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Position = UDim2.new(0.5, 0, 1, -22),
	Size = UDim2.fromOffset(106, 86),
}, gui)
toolbar:SetAttribute("GEIClientManaged", true)
new("UICorner", { CornerRadius = UDim.new(0, 16) }, toolbar)
new("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 1,
	Transparency = 0.76,
}, toolbar)

local slotsFrame = new("Frame", {
	Name = "Slots",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -16, 1, -16),
}, toolbar)

local floatingText = new("TextLabel", {
	Name = "FloatingText",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(340, 52),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextStrokeTransparency = 0.45,
	Visible = false,
}, gui)
floatingText:SetAttribute("GEIClientManaged", true)
new("UITextSizeConstraint", {
	MaxTextSize = 32,
	MinTextSize = 14,
}, floatingText)

local function getValue(name)
	local valueObject = playerData:FindFirstChild(name)
	return valueObject and valueObject.Value or 0
end

local function getOwnedTools()
	local ownedTools = playerData:FindFirstChild("OwnedTools")
	local result = {}
	if not ownedTools then
		return result
	end

	for _, toolId in ipairs(GameData.ToolOrder) do
		local ownedValue = ownedTools:FindFirstChild(toolId)
		if ownedValue and ownedValue:IsA("BoolValue") and ownedValue.Value == true then
			table.insert(result, toolId)
		end
	end

	return result
end

local function refreshStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	local diamonds = leaderstats and leaderstats:FindFirstChild("Diamonds")
	local waste = getValue("WasteCount")
	local maxWaste = getValue("MaxWaste")

	statLabels.Cash.Text = formatNumber(cash and cash.Value or 0)
	statLabels.Diamonds.Text = formatNumber(diamonds and diamonds.Value or 0)
	statLabels.Waste.Text = formatNumber(waste) .. " / " .. formatNumber(maxWaste)
end

local function refreshToolbar()
	for _, child in ipairs(slotsFrame:GetChildren()) do
		child:Destroy()
	end

	local ownedTools = getOwnedTools()
	local equippedToolValue = playerData:FindFirstChild("EquippedTool")
	local equippedTool = equippedToolValue and equippedToolValue.Value or "Brush"
	local slotCount = math.max(1, #ownedTools)
	toolbar.Size = UDim2.fromOffset(math.max(106, slotCount * 88 + 18), 86)

	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, slotsFrame)

	for index, toolId in ipairs(ownedTools) do
		local toolConfig = GameData.GetTool(toolId)
		local selected = toolId == equippedTool
		local slot = new("Frame", {
			Name = toolId .. "Slot",
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.fromOffset(78, 70),
		}, slotsFrame)

		local button = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = true,
			BackgroundColor3 = selected and toolConfig.Color or Color3.fromRGB(43, 48, 52),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = selected and UDim2.fromOffset(70, 64) or UDim2.fromOffset(62, 56),
			Text = toolConfig.Name .. "\n" .. tostring(toolConfig.Damage) .. " DMG",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
		}, slot)
		new("UICorner", { CornerRadius = UDim.new(0, 13) }, button)
		new("UIStroke", {
			Color = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(122, 132, 139),
			Thickness = selected and 2.4 or 1,
			Transparency = selected and 0.05 or 0.5,
		}, button)
		new("UITextSizeConstraint", {
			MaxTextSize = 15,
			MinTextSize = 8,
		}, button)

		button.Activated:Connect(function()
			if equipItemRemote then
				equipItemRemote:FireServer("Tool", toolId)
			end
		end)
	end
end

local function refreshAll()
	refreshStats()
	refreshToolbar()
end

local activeTween = nil
local function showFloating(text, color)
	if activeTween then
		activeTween:Cancel()
	end

	floatingText.Text = text
	floatingText.TextColor3 = color
	floatingText.Visible = true
	floatingText.TextTransparency = 0
	floatingText.Position = UDim2.fromScale(0.5, 0.43)

	local tween = TweenService:Create(floatingText, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.36),
		TextTransparency = 1,
	})
	activeTween = tween
	tween:Play()
	tween.Completed:Connect(function()
		if activeTween == tween then
			floatingText.Visible = false
			activeTween = nil
		end
	end)
end

local function bindValueSignals(parent)
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant:IsA("ValueBase") then
			descendant.Changed:Connect(refreshAll)
		end
	end

	parent.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ValueBase") then
			descendant.Changed:Connect(refreshAll)
			refreshAll()
		end
	end)
end

bindValueSignals(playerData)
local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
	bindValueSignals(leaderstats)
end

if playerDataRemote then
	playerDataRemote.OnClientEvent:Connect(refreshAll)
end

if sellFeedbackRemote then
	sellFeedbackRemote.OnClientEvent:Connect(function(cashEarned)
		showFloating("+" .. formatNumber(cashEarned) .. " Cash", Color3.fromRGB(119, 242, 143))
	end)
end

if attackFeedbackRemote then
	attackFeedbackRemote.OnClientEvent:Connect(function(feedback)
		if type(feedback) ~= "table" then
			return
		end

		if feedback.Reason == "BackpackFull" then
			showFloating("Backpack full", Color3.fromRGB(255, 210, 101))
		elseif feedback.WasteGained and feedback.WasteGained > 0 then
			local text = "+" .. formatNumber(feedback.WasteGained) .. " Waste"
			if feedback.DiamondsGained and feedback.DiamondsGained > 0 then
				text ..= "  +" .. formatNumber(feedback.DiamondsGained) .. " Diamonds"
			end
			showFloating(text, Color3.fromRGB(255, 225, 128))
		end
	end)
end

statLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	topStats.Size = UDim2.fromOffset(math.max(438, statLayout.AbsoluteContentSize.X + 24), 46)
end)

refreshAll()
