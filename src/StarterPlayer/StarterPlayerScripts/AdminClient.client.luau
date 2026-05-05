local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
if not remotes then
	return
end

local adminCheck = remotes:WaitForChild("AdminCheck", 20)
local adminCommand = remotes:WaitForChild("AdminCommand", 20)
if not adminCheck or not adminCommand then
	return
end

local ok, result = pcall(function()
	return adminCheck:InvokeServer()
end)
if not ok or type(result) ~= "table" or result.IsAdmin ~= true then
	return
end

local gui = playerGui:FindFirstChild("GEIAdminPanel")
if gui then
	gui:Destroy()
end

gui = Instance.new("ScreenGui")
gui.Name = "GEIAdminPanel"
gui.DisplayOrder = 100
 gui.ResetOnSpawn = false
gui.Parent = playerGui

local function new(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(18, 23, 29),
	BackgroundTransparency = 0.03,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 420),
	Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, panel)
new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.75, Thickness = 1 }, panel)
local scale = new("UIScale", { Scale = 0.92 }, panel)

new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(18, 14),
	Size = UDim2.new(1, -36, 0, 34),
	Text = "Admin Panel",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Color3.fromRGB(42, 50, 58),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(34, 34),
	Text = "X",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, close)

local status = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(18, 54),
	Size = UDim2.new(1, -36, 0, 26),
	Text = "F8 to toggle. Server-validated commands.",
	TextColor3 = Color3.fromRGB(180, 202, 213),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local list = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 92),
	Size = UDim2.new(1, -36, 1, -110),
}, panel)
local grid = new("UIGridLayout", {
	CellPadding = UDim2.fromOffset(10, 10),
	CellSize = UDim2.fromOffset(166, 46),
	FillDirectionMaxCells = 3,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)

local commands = {
	{ "AddCash", "+10K Cash", { Amount = 10000 } },
	{ "AddDiamonds", "+500 Diamonds", { Amount = 500 } },
	{ "FillWaste", "Fill Waste", {} },
	{ "ClearWaste", "Clear Waste", {} },
	{ "GiveCrusher", "Give Crusher", {} },
	{ "GiveLargeBag", "Give Large Bag", {} },
	{ "GivePet", "Give Pet", { PetId = "GoldenRaccoon" } },
	{ "GiveGoldenPet", "Golden Pet", { PetId = "GoldenRaccoon" } },
	{ "UnlockZone2", "Unlock Zone 2", {} },
	{ "UnlockZone3", "Unlock Zone 3", {} },
	{ "UnlockZone4", "Unlock Boss Zone", {} },
	{ "UnlockAllZones", "Unlock All Zones", {} },
	{ "ResetZones", "Reset Zones", {} },
	{ "Teleport", "TP Lobby", { Target = "SpawnLocation" } },
	{ "Teleport", "TP Zone 2", { Target = "SpawnSurface2" } },
	{ "Teleport", "TP Zone 3", { Target = "SpawnSurface3" } },
	{ "Teleport", "TP Boss", { Target = "SpawnSurface4" } },
}

local function runCommand(command, payload)
	status.Text = "Running " .. tostring(command) .. "..."
	local success, response = pcall(function()
		return adminCommand:InvokeServer(command, payload)
	end)
	if not success or type(response) ~= "table" then
		status.Text = "Command failed."
		return
	end
	status.Text = response.Success and (response.Message or "Done") or (response.Error or response.Message or "Rejected")
end

for index, commandInfo in ipairs(commands) do
	local command, label, payload = commandInfo[1], commandInfo[2], commandInfo[3]
	local button = new("TextButton", {
		BackgroundColor3 = Color3.fromRGB(40, 52, 62),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		LayoutOrder = index,
		Text = label,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
	}, list)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, button)
	button.Activated:Connect(function()
		runCommand(command, payload)
	end)
end

local function setVisible(visible)
	panel.Visible = visible
	if visible then
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

close.Activated:Connect(function()
	setVisible(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F8 then
		setVisible(not panel.Visible)
	end
end)
