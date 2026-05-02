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
local playerGui = player:WaitForChild("PlayerGui", 10)
local playerData = player:WaitForChild("PlayerData", 10)
if not tutorialRemote or not playerGui or not playerData then
	warn("[GEI] TutorialClient could not find required objects.")
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
frame.Position = UDim2.new(0.5, 0, 1, -116)
frame.Size = UDim2.fromOffset(292, 38)
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

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.Position = UDim2.fromOffset(12, 4)
label.Size = UDim2.new(1, -24, 1, -8)
label.Text = ""
label.TextColor3 = Color3.fromRGB(240, 244, 245)
label.TextScaled = true
label.Parent = frame

local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MaxTextSize = 17
textConstraint.MinTextSize = 9
textConstraint.Parent = label

local completed = {
	ClickedWaste = false,
	SoldWaste = false,
	OpenedShop = false,
}

local currentText = nil

local function getWasteCount()
	local waste = playerData:FindFirstChild("WasteCount")
	return waste and waste.Value or 0
end

local function getNextText()
	if not completed.SoldWaste then
		if getWasteCount() <= 0 then
			return "Click a Waste Node"
		end
		return "Sell your Waste"
	end
	if not completed.OpenedShop then
		return "Open the Shop"
	end

	return nil
end

local function setPrompt(text)
	if currentText == text then
		return
	end

	currentText = text
	if not text then
		local tween = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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
	label.Text = text
	frame.Size = UDim2.fromOffset(270, 34)
	TweenService:Create(frame, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(292, 38),
	}):Play()
end

local function refresh()
	setPrompt(getNextText())
end

tutorialRemote.OnClientEvent:Connect(function(stepName)
	if completed[stepName] ~= nil then
		completed[stepName] = true
		refresh()
	end
end)

local wasteValue = playerData:WaitForChild("WasteCount", 10)
if wasteValue then
	wasteValue.Changed:Connect(refresh)
end

refresh()
