local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

task.delay(6, function()
	local mainHud = playerGui:FindFirstChild("MainHUD")
	if mainHud and mainHud:FindFirstChild("TopStats") then
		return
	end

	local existing = playerGui:FindFirstChild("GEIFallbackHUD")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "GEIFallbackHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "FallbackStats"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 10)
	frame.Size = UDim2.fromOffset(470, 42)
	frame.BackgroundColor3 = Color3.fromRGB(18, 23, 28)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Parent = frame

	local function readValue(folder, name, fallback)
		local value = folder and folder:FindFirstChild(name)
		return value and value.Value or fallback
	end

	local function refresh()
		local leaderstats = player:FindFirstChild("leaderstats")
		local data = player:FindFirstChild("PlayerData")
		local cash = readValue(leaderstats, "Cash", 0)
		local diamonds = readValue(leaderstats, "Diamonds", 0)
		local waste = readValue(data, "WasteCount", 0)
		local maxWaste = readValue(data, "MaxWaste", 0)
		label.Text = "Cash " .. tostring(cash) .. "   |   Waste " .. tostring(waste) .. "/" .. tostring(maxWaste) .. "   |   Diamonds " .. tostring(diamonds)
	end

	refresh()
	while gui.Parent do
		refresh()
		task.wait(0.25)
	end
end)
