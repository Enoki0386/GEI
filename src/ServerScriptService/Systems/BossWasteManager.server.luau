local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World1Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World1Data"))

local bossState = {
	Part = nil,
	CurrentHP = World1Data.Boss.MaxHP,
	Alive = true,
	LastHit = {},
}

local function getBossAreaPart()
	local area = workspace:FindFirstChild(World1Data.Boss.AreaName, true)
	if area and area:IsA("BasePart") then return area end
	if area and area:IsA("Model") then return area.PrimaryPart or area:FindFirstChildWhichIsA("BasePart", true) end
	return area and area:FindFirstChildWhichIsA("BasePart", true) or nil
end

local function ensureBossPart()
	local existing = workspace:FindFirstChild(World1Data.Boss.BossName, true)
	if existing and existing:IsA("BasePart") then
		bossState.Part = existing
		return existing
	elseif existing and existing:IsA("Model") then
		local part = existing.PrimaryPart or existing:FindFirstChildWhichIsA("BasePart", true)
		bossState.Part = part
		return part
	end

	local area = getBossAreaPart()
	if not area then return nil end
	local part = Instance.new("Part")
	part.Name = World1Data.Boss.BossName
	part.Anchored = true
	part.CanCollide = true
	part.Size = Vector3.new(14, 14, 14)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(105, 86, 62)
	part.Position = area.Position + Vector3.new(0, area.Size.Y / 2 + 7, 0)
	part.Parent = workspace
	bossState.Part = part
	return part
end

local function updateBillboard()
	local part = bossState.Part
	if not part then return end
	local billboard = part:FindFirstChild("GEIBossBillboard")
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "GEIBossBillboard"
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 140
		billboard.Size = UDim2.fromOffset(330, 105)
		billboard.StudsOffset = Vector3.new(0, 10, 0)
		billboard.Parent = part
		local frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.BackgroundColor3 = Color3.fromRGB(24, 15, 15)
		frame.BackgroundTransparency = 0.08
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = billboard
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.Position = UDim2.fromOffset(12, 8)
		title.Size = UDim2.new(1, -24, 0, 34)
		title.Text = World1Data.Boss.DisplayName
		title.TextColor3 = Color3.fromRGB(255, 209, 91)
		title.TextScaled = true
		title.Parent = frame
		local hp = Instance.new("TextLabel")
		hp.Name = "HP"
		hp.BackgroundTransparency = 1
		hp.Font = Enum.Font.GothamBlack
		hp.Position = UDim2.fromOffset(12, 42)
		hp.Size = UDim2.new(1, -24, 0, 28)
		hp.TextColor3 = Color3.fromRGB(255, 255, 255)
		hp.TextScaled = true
		hp.Parent = frame
		local bar = Instance.new("Frame")
		bar.Name = "BarBack"
		bar.BackgroundColor3 = Color3.fromRGB(55, 42, 42)
		bar.BorderSizePixel = 0
		bar.Position = UDim2.new(0, 16, 1, -20)
		bar.Size = UDim2.new(1, -32, 0, 8)
		bar.Parent = frame
		Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = Color3.fromRGB(255, 81, 72)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = bar
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	end
	local frame = billboard:FindFirstChild("Frame")
	local hp = frame and frame:FindFirstChild("HP")
	local fill = frame and frame:FindFirstChild("BarBack") and frame.BarBack:FindFirstChild("Fill")
	if hp then hp.Text = tostring(math.max(0, math.floor(bossState.CurrentHP))) .. " HP" end
	if fill then fill.Size = UDim2.fromScale(math.clamp(bossState.CurrentHP / World1Data.Boss.MaxHP, 0, 1), 1) end
end

local function respawnBoss()
	bossState.CurrentHP = World1Data.Boss.MaxHP
	bossState.Alive = true
	local part = ensureBossPart()
	if part then
		part.Transparency = 0
		part.CanCollide = true
		part:SetAttribute("CurrentHP", bossState.CurrentHP)
		part:SetAttribute("MaxHP", World1Data.Boss.MaxHP)
	end
	updateBillboard()
end

local function reward(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	local diamonds = leaderstats and leaderstats:FindFirstChild("Diamonds")
	if cash then cash.Value += World1Data.Boss.Rewards.Cash end
	if diamonds then diamonds.Value += World1Data.Boss.Rewards.Diamonds end
	if _G.GEI and _G.GEI.WorldProgress then
		_G.GEI.WorldProgress.SetBossDefeated(player, true)
	end
end

local function hitBoss(player)
	if not bossState.Alive then return end
	local now = os.clock()
	if bossState.LastHit[player] and now - bossState.LastHit[player] < World1Data.Boss.HitCooldown then return end
	bossState.LastHit[player] = now
	local data = player:FindFirstChild("PlayerData")
	local damageValue = data and data:FindFirstChild("ToolDamage")
	local damage = math.max(1, math.floor((damageValue and damageValue.Value) or 10))
	bossState.CurrentHP -= damage
	local part = bossState.Part
	if part then
		part:SetAttribute("CurrentHP", bossState.CurrentHP)
	end
	updateBillboard()
	if bossState.CurrentHP <= 0 then
		bossState.Alive = false
		if part then
			part.Transparency = 0.65
			part.CanCollide = false
		end
		reward(player)
		task.delay(World1Data.Boss.RespawnTime, respawnBoss)
	end
end

local function setupPrompt()
	local part = ensureBossPart()
	if not part then return end
	local prompt = part:FindFirstChild("GEIBossPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GEIBossPrompt"
		prompt.ActionText = "Hit"
		prompt.ObjectText = World1Data.Boss.DisplayName
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	if part:GetAttribute("GEIBossConnected") then return end
	part:SetAttribute("GEIBossConnected", true)
	prompt.Triggered:Connect(hitBoss)
end

while true do
	setupPrompt()
	updateBillboard()
	task.wait(2)
end
