local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotes then
	warn("[GEI] Remotes folder is missing. TutorialClient stopped.")
	return
end

local tutorialRemote = remotes:WaitForChild("TutorialProgress", 10)
local purchaseResultRemote = remotes:WaitForChild("PurchaseResult", 10)
local petHatchResultRemote = remotes:WaitForChild("PetHatchResult", 10)
local petInventoryUpdatedRemote = remotes:WaitForChild("PetInventoryUpdated", 10)
local playerGui = player:WaitForChild("PlayerGui", 10)
local playerData = player:WaitForChild("PlayerData", 60)
if not tutorialRemote or not playerGui or not playerData then
	warn("[GEI] TutorialClient could not find required objects.")
	return
end

local gui = playerGui:FindFirstChild("MainHUD")
if gui and not gui:IsA("ScreenGui") then
	gui:Destroy()
	gui = nil
end

if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "MainHUD"
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = playerGui
end

for _, child in ipairs(gui:GetChildren()) do
	if child:GetAttribute("GEITutorialManaged") then
		child:Destroy()
	end
end

local frame = Instance.new("Frame")
frame.Name = "TutorialPrompt"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.BackgroundColor3 = Color3.fromRGB(25, 29, 32)
frame.BackgroundTransparency = 0.08
frame.BorderSizePixel = 0
frame.Position = UDim2.new(0.5, 0, 1, -118)
frame.Size = UDim2.fromOffset(420, 42)
frame.Visible = true
frame:SetAttribute("GEITutorialManaged", true)
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 13)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Thickness = 1
stroke.Transparency = 0.78
stroke.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingBottom = UDim.new(0, 7)
padding.PaddingLeft = UDim.new(0, 11)
padding.PaddingRight = UDim.new(0, 12)
padding.PaddingTop = UDim.new(0, 7)
padding.Parent = frame

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 9)
layout.Parent = frame

local stepLabel = Instance.new("TextLabel")
stepLabel.BackgroundColor3 = Color3.fromRGB(255, 206, 76)
stepLabel.BackgroundTransparency = 0.05
stepLabel.BorderSizePixel = 0
stepLabel.Font = Enum.Font.GothamBold
stepLabel.LayoutOrder = 1
stepLabel.Size = UDim2.fromOffset(45, 24)
stepLabel.Text = "1/5"
stepLabel.TextColor3 = Color3.fromRGB(28, 25, 20)
stepLabel.TextSize = 13
stepLabel.Parent = frame

local stepCorner = Instance.new("UICorner")
stepCorner.CornerRadius = UDim.new(0, 9)
stepCorner.Parent = stepLabel

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.LayoutOrder = 2
label.Size = UDim2.new(1, -54, 1, 0)
label.Text = ""
label.TextColor3 = Color3.fromRGB(240, 244, 245)
label.TextScaled = false
label.TextSize = 15
label.TextWrapped = true
label.TextXAlignment = Enum.TextXAlignment.Left
label.Parent = frame

local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MaxTextSize = 17
textConstraint.MinTextSize = 9
textConstraint.Parent = label

local completed = {
	ClickedWaste = false,
	BackpackFilled = false,
	SoldWaste = false,
	OpenedShop = false,
	BoughtItem = false,
	HatchedEgg = false,
}

local tutorialSteps = {
	{ Key = "ClickedWaste", Text = "Click a Waste Node to break it." },
	{ Key = "BackpackFilled", Text = "Your backpack fills up." },
	{ Key = "SoldWaste", Text = "Go to the SellZone to sell." },
	{ Key = "BoughtItem", Text = "Buy better tools at the Shop." },
	{ Key = "HatchedEgg", Text = "Open eggs to get bonus pets." },
}

local currentStepKey = nil

local function getWasteCount()
	local waste = playerData:FindFirstChild("WasteCount")
	return waste and waste.Value or 0
end

local function hasBoughtUpgrade()
	local ownedTools = playerData:FindFirstChild("OwnedTools")
	if ownedTools then
		for _, child in ipairs(ownedTools:GetChildren()) do
			if child:IsA("BoolValue") and child.Value and child.Name ~= "Brush" then
				return true
			end
		end
	end

	local ownedBackpacks = playerData:FindFirstChild("OwnedBackpacks")
	if ownedBackpacks then
		for _, child in ipairs(ownedBackpacks:GetChildren()) do
			if child:IsA("BoolValue") and child.Value and child.Name ~= "SmallBag" then
				return true
			end
		end
	end

	return false
end

local function hasAnyPet()
	local petsFolder = playerData:FindFirstChild("Pets")
	local inventory = petsFolder and petsFolder:FindFirstChild("Inventory")
	return inventory ~= nil and #inventory:GetChildren() > 0
end

local function syncDerivedProgress()
	if getWasteCount() > 0 then
		completed.ClickedWaste = true
		completed.BackpackFilled = true
	end

	if hasBoughtUpgrade() then
		completed.BoughtItem = true
	end

	if hasAnyPet() then
		completed.HatchedEgg = true
	end
end

local function getNextStep()
	syncDerivedProgress()

	for index, step in ipairs(tutorialSteps) do
		if not completed[step.Key] then
			return step, index
		end
	end

	return nil, nil
end

local function setPrompt(step, index)
	local nextStepKey = step and step.Key or nil
	if currentStepKey == nextStepKey then
		return
	end

	currentStepKey = nextStepKey
	if not step then
		local tween = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		}):Play()
		TweenService:Create(stepLabel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
		tween:Play()
		tween.Completed:Connect(function()
			frame.Visible = false
		end)
		return
	end

	frame.Visible = true
	frame.BackgroundTransparency = 0.08
	label.TextTransparency = 0
	stepLabel.BackgroundTransparency = 0.05
	stepLabel.TextTransparency = 0
	stepLabel.Text = string.format("%d/%d", index, #tutorialSteps)
	label.Text = step.Text
	frame.Size = UDim2.fromOffset(394, 38)
	TweenService:Create(frame, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(420, 42),
	}):Play()
end

local function refresh()
	local step, index = getNextStep()
	setPrompt(step, index)
end

tutorialRemote.OnClientEvent:Connect(function(stepName)
	if completed[stepName] ~= nil then
		completed[stepName] = true
		refresh()
	end
end)

if purchaseResultRemote then
	purchaseResultRemote.OnClientEvent:Connect(function(ok, reason)
		if ok and reason == "Bought" then
			completed.BoughtItem = true
			refresh()
		end
	end)
end

if petHatchResultRemote then
	petHatchResultRemote.OnClientEvent:Connect(function(response)
		if type(response) == "table" and response.Success then
			completed.HatchedEgg = true
			refresh()
		end
	end)
end

if petInventoryUpdatedRemote then
	petInventoryUpdatedRemote.OnClientEvent:Connect(refresh)
end

local wasteValue = playerData:WaitForChild("WasteCount", 10)
if wasteValue then
	wasteValue.Changed:Connect(refresh)
end

local ownedToolsFolder = playerData:FindFirstChild("OwnedTools")
if ownedToolsFolder then
	ownedToolsFolder.ChildAdded:Connect(refresh)
	ownedToolsFolder.ChildRemoved:Connect(refresh)
end

local ownedBackpacksFolder = playerData:FindFirstChild("OwnedBackpacks")
if ownedBackpacksFolder then
	ownedBackpacksFolder.ChildAdded:Connect(refresh)
	ownedBackpacksFolder.ChildRemoved:Connect(refresh)
end

refresh()
