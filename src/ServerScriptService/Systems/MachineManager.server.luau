local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World1Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World1Data"))

local running = {}

local function getPartFromObject(object)
	if not object then return nil end
	if object:IsA("BasePart") then return object end
	if object:IsA("Model") then return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true) end
	return object:FindFirstChildWhichIsA("BasePart", true)
end

local function getMachineLevel(player)
	if _G.GEI and _G.GEI.WorldProgress and _G.GEI.WorldProgress.GetUpgradeLevel then
		return _G.GEI.WorldProgress.GetUpgradeLevel(player, "MachineEfficiency")
	end
	return 0
end

local function addMachineBillboard(part, machine)
	if part:FindFirstChild("GEIMachineBillboard") then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GEIMachineBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 75
	billboard.Size = UDim2.fromOffset(250, 95)
	billboard.StudsOffset = Vector3.new(0, math.max(5, part.Size.Y / 2 + 3), 0)
	billboard.Parent = part

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(15, 21, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.fromOffset(10, 8)
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Text = machine.DisplayName
	title.TextColor3 = Color3.fromRGB(121, 255, 169)
	title.TextScaled = true
	title.Parent = frame

	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.GothamBold
	info.Position = UDim2.fromOffset(10, 42)
	info.Size = UDim2.new(1, -20, 0, 36)
	info.Text = string.format("%d Waste -> %d Cash", machine.InputWaste, machine.CashReward)
	info.TextColor3 = Color3.fromRGB(220, 232, 236)
	info.TextScaled = true
	info.TextWrapped = true
	info.Parent = frame
end

local function processMachine(player, machineId, machine, part)
	local key = tostring(player.UserId) .. ":" .. machineId
	if running[key] then return end
	local data = player:FindFirstChild("PlayerData")
	local waste = data and data:FindFirstChild("WasteCount")
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	local diamonds = leaderstats and leaderstats:FindFirstChild("Diamonds")
	if not waste or not cash then return end
	if waste.Value < machine.InputWaste then
		print("[Machine] Not enough Waste for", player.Name)
		return
	end
	running[key] = true
	waste.Value -= machine.InputWaste
	local efficiencyLevel = getMachineLevel(player)
	local efficiency = 1 + (efficiencyLevel * 0.12)
	local duration = math.max(1.5, machine.Duration / efficiency)
	local prompt = part:FindFirstChild("GEIMachinePrompt")
	if prompt then
		prompt.Enabled = false
	end
	task.delay(duration, function()
		if player.Parent then
			cash.Value += math.floor(machine.CashReward * efficiency)
			if diamonds and machine.DiamondsReward then
				diamonds.Value += math.floor(machine.DiamondsReward * math.max(1, efficiencyLevel))
			end
		end
		running[key] = nil
		if prompt then prompt.Enabled = true end
	end)
end

local function setupMachine(machineId, machine)
	local area = workspace:FindFirstChild("MachineArea", true)
	local object = (area and area:FindFirstChild(machine.ObjectName, true)) or workspace:FindFirstChild(machine.ObjectName, true)
	local part = getPartFromObject(object)
	if not part then return end
	addMachineBillboard(part, machine)
	local prompt = part:FindFirstChild("GEIMachinePrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GEIMachinePrompt"
		prompt.ActionText = "Process"
		prompt.ObjectText = machine.DisplayName
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	if part:GetAttribute("GEIMachineConnected") then return end
	part:SetAttribute("GEIMachineConnected", true)
	prompt.Triggered:Connect(function(player)
		processMachine(player, machineId, machine, part)
	end)
end

while true do
	for machineId, machine in pairs(World1Data.Machines) do
		setupMachine(machineId, machine)
	end
	task.wait(3)
end
