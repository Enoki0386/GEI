local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World1Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World1Data"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

local function getPartFromObject(object)
	if not object then return nil end
	if object:IsA("BasePart") then return object end
	if object:IsA("Model") then return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true) end
	return object:FindFirstChildWhichIsA("BasePart", true)
end

local function getDiamonds(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local diamonds = leaderstats and leaderstats:FindFirstChild("Diamonds")
	return diamonds
end

local function getUpgradeLevel(player, upgradeId)
	if _G.GEI and _G.GEI.WorldProgress and _G.GEI.WorldProgress.GetUpgradeLevel then
		return _G.GEI.WorldProgress.GetUpgradeLevel(player, upgradeId)
	end
	return 0
end

local function setUpgradeLevel(player, upgradeId, level)
	if _G.GEI and _G.GEI.WorldProgress and _G.GEI.WorldProgress.SetUpgradeLevel then
		_G.GEI.WorldProgress.SetUpgradeLevel(player, upgradeId, level)
	end
end

local function applyRuntimeStats(player)
	local data = player:FindFirstChild("PlayerData")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local speedLevel = getUpgradeLevel(player, "Speed")
		humanoid.WalkSpeed = ((GameData.Player and GameData.Player.WalkSpeed) or 22) + speedLevel * World1Data.DiamondUpgrades.Speed.PerLevel
	end
	if data then
		local equippedTool = data:FindFirstChild("EquippedTool")
		local damageValue = data:FindFirstChild("ToolDamage")
		local tool = equippedTool and GameData.GetTool(equippedTool.Value)
		if damageValue and tool then
			local petMultiplier = 1
			if _G.GEI and _G.GEI.PetManager and _G.GEI.PetManager.GetPetBuffs then
				local buffs = _G.GEI.PetManager.GetPetBuffs(player)
				petMultiplier = type(buffs.DamageMultiplier) == "number" and buffs.DamageMultiplier or 1
			end
			local damageLevel = getUpgradeLevel(player, "Damage")
			local upgradeMultiplier = 1 + damageLevel * World1Data.DiamondUpgrades.Damage.PerLevel
			damageValue.Value = math.max(1, math.floor((tool.Damage or 1) * petMultiplier * upgradeMultiplier))
		end
	end
end

local function addBillboard(part, upgradeId, upgrade)
	if part:FindFirstChild("GEIUpgradeBillboard") then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GEIUpgradeBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 75
	billboard.Size = UDim2.fromOffset(250, 95)
	billboard.StudsOffset = Vector3.new(0, math.max(5, part.Size.Y / 2 + 3), 0)
	billboard.Parent = part
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(15, 17, 25)
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
	title.Text = upgrade.DisplayName
	title.TextColor3 = Color3.fromRGB(95, 205, 255)
	title.TextScaled = true
	title.Parent = frame
	local info = Instance.new("TextLabel")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.GothamBold
	info.Position = UDim2.fromOffset(10, 42)
	info.Size = UDim2.new(1, -20, 0, 36)
	info.Text = "Press E to upgrade"
	info.TextColor3 = Color3.fromRGB(220, 232, 236)
	info.TextScaled = true
	info.TextWrapped = true
	info.Parent = frame
end

local function upgrade(player, upgradeId)
	local config = World1Data.DiamondUpgrades[upgradeId]
	if not config then return end
	local currentLevel = getUpgradeLevel(player, upgradeId)
	if currentLevel >= config.MaxLevel then
		print("[DiamondUpgrade] Max level", upgradeId)
		return
	end
	local cost = World1Data.GetUpgradeCost(upgradeId, currentLevel)
	local diamonds = getDiamonds(player)
	if not diamonds or diamonds.Value < cost then
		print("[DiamondUpgrade] Not enough Diamonds", player.Name, upgradeId)
		return
	end
	diamonds.Value -= cost
	setUpgradeLevel(player, upgradeId, currentLevel + 1)
	applyRuntimeStats(player)
	print("[DiamondUpgrade]", player.Name, upgradeId, "->", currentLevel + 1)
end

local function setupUpgrade(upgradeId, upgradeConfig)
	local shop = workspace:FindFirstChild("UpgradeShop2", true)
	local object = shop and shop:FindFirstChild(upgradeId .. "Upgrade", true)
		or shop and shop:FindFirstChild(upgradeId, true)
		or workspace:FindFirstChild(upgradeId .. "Upgrade", true)
	local part = getPartFromObject(object)
	if not part then return end
	addBillboard(part, upgradeId, upgradeConfig)
	local prompt = part:FindFirstChild("GEIUpgradePrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GEIUpgradePrompt"
		prompt.ActionText = "Upgrade"
		prompt.ObjectText = upgradeConfig.DisplayName
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	if part:GetAttribute("GEIUpgradeConnected") then return end
	part:SetAttribute("GEIUpgradeConnected", true)
	prompt.Triggered:Connect(function(player)
		upgrade(player, upgradeId)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyRuntimeStats(player)
	end)
end)

while true do
	for upgradeId, upgradeConfig in pairs(World1Data.DiamondUpgrades) do
		setupUpgrade(upgradeId, upgradeConfig)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		applyRuntimeStats(player)
	end
	task.wait(3)
end
