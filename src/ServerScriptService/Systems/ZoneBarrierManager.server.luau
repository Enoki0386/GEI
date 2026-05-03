local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World1Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World1Data"))

local function getPartFromObject(object)
	if not object then
		return nil
	end
	if object:IsA("BasePart") then
		return object
	end
	if object:IsA("Model") then
		return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
	end
	return object:FindFirstChildWhichIsA("BasePart", true)
end

local function addBillboard(part, title, subtitle)
	if part:FindFirstChild("GEIZoneBillboard") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GEIZoneBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Size = UDim2.fromOffset(260, 90)
	billboard.StudsOffset = Vector3.new(0, math.max(5, part.Size.Y / 2 + 3), 0)
	billboard.Parent = part

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(17, 22, 27)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Position = UDim2.fromOffset(10, 8)
	titleLabel.Size = UDim2.new(1, -20, 0, 32)
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 232, 112)
	titleLabel.TextScaled = true
	titleLabel.Parent = frame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.Position = UDim2.fromOffset(10, 44)
	subtitleLabel.Size = UDim2.new(1, -20, 0, 28)
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(214, 226, 232)
	subtitleLabel.TextScaled = true
	subtitleLabel.Parent = frame
end

local function teleportToSpawn(player, spawnName)
	local spawnPart = workspace:FindFirstChild(spawnName, true)
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(spawnPart.Position + Vector3.new(0, 5, 0))
	end
end

local function setupBarrier(zoneId, zone)
	local object = workspace:FindFirstChild(zone.BarrierName, true)
	local part = getPartFromObject(object)
	if not part then
		return
	end

	addBillboard(part, zone.DisplayName, tostring(zone.Cost) .. " " .. tostring(zone.Currency or "Cash"))
	local prompt = part:FindFirstChild("GEIUnlockPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GEIUnlockPrompt"
		prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	prompt.ActionText = "Unlock"
	prompt.ObjectText = zone.DisplayName

	if part:GetAttribute("GEIZonePromptConnected") then
		return
	end
	part:SetAttribute("GEIZonePromptConnected", true)
	prompt.Triggered:Connect(function(player)
		if not (_G.GEI and _G.GEI.WorldProgress) then
			return
		end
		local success, message = _G.GEI.WorldProgress.UnlockZone(player, zoneId, false)
		print("[ZoneBarrier]", player.Name, zoneId, success, message)
		if success then
			teleportToSpawn(player, zone.SpawnName)
		end
	end)
end

local function setupPortal()
	local portal = workspace:FindFirstChild(World1Data.Portal.Name, true)
	local part = getPartFromObject(portal)
	if not part then
		return
	end
	addBillboard(part, World1Data.Portal.DisplayName, "Locked until Boss Waste is defeated")
	local prompt = part:FindFirstChild("GEIPortalPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GEIPortalPrompt"
		prompt.ActionText = "Enter"
		prompt.ObjectText = "World 2"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	if part:GetAttribute("GEIPortalPromptConnected") then
		return
	end
	part:SetAttribute("GEIPortalPromptConnected", true)
	prompt.Triggered:Connect(function(player)
		local progress = _G.GEI and _G.GEI.WorldProgress and _G.GEI.WorldProgress.Get(player)
		if progress and progress.UnlockedZones.Zone4 and progress.BossDefeated then
			print("[Portal]", player.Name, "can enter World 2. World 2 scene is not created yet.")
		else
			print("[Portal]", player.Name, World1Data.Portal.LockedMessage)
		end
	end)
end

while true do
	for zoneId, zone in pairs(World1Data.Zones) do
		setupBarrier(zoneId, zone)
	end
	setupPortal()
	task.wait(3)
end
