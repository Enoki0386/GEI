local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 10)
if not gameDataModule then
	warn("[GEI] GameData is missing. WasteNodeManager stopped.")
	return
end

local GameData = require(gameDataModule)
local random = Random.new()
local attackCooldowns = {}
local shownWarnings = {}

local function warnOnce(key, message)
	if shownWarnings[key] then
		return
	end

	shownWarnings[key] = true
	warn(message)
end

local function waitForPlayerManager()
	local startTime = os.clock()
	while not (_G.GEI and _G.GEI.PlayerManager) do
		if os.clock() - startTime > 10 then
			warn("[GEI] Waiting for PlayerManager...")
			startTime = os.clock()
		end
		task.wait(0.1)
	end

	return _G.GEI.PlayerManager
end

local function ensureRemote(remoteName)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild(remoteName)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = remotes
	end

	return remote
end

local function getWasteZone()
	local wasteZone = Workspace:FindFirstChild(GameData.Spawn.WasteZoneName)
	if wasteZone and wasteZone:IsA("Folder") then
		return wasteZone
	end

	if wasteZone then
		warnOnce(
			"WasteZoneWrongType",
			"[WasteNodeManager] Workspace.WasteZone exists but must be a Folder. Replace it manually in Roblox Studio."
		)
	else
		warnOnce(
			"WasteZoneMissing",
			"[WasteNodeManager] Missing Workspace.WasteZone. Create a Folder named WasteZone in Workspace."
		)
	end

	return nil
end

local function getSpawnSurface()
	local surface = Workspace:FindFirstChild(GameData.Spawn.SurfaceName)
	if surface and surface:IsA("BasePart") then
		return surface
	end

	if surface then
		warnOnce(
			"SpawnSurfaceWrongType",
			"[WasteNodeManager] Workspace.SpawnSurface1 exists but must be a Part/BasePart. Replace it manually in Roblox Studio."
		)
	else
		warnOnce(
			"SpawnSurfaceMissing",
			"[WasteNodeManager] Missing Workspace.SpawnSurface1. Create a Part named SpawnSurface1. Recommended size: 80, 1, 60."
		)
	end

	return nil
end

local function fireClient(player, remoteName, ...)
	local remote = ensureRemote(remoteName)
	remote:FireClient(player, ...)
end

local function getRootPart(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function isFarFromPlayers(position)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = getRootPart(player)
		if root and (root.Position - position).Magnitude < GameData.Spawn.MinDistanceFromPlayers then
			return false
		end
	end

	return true
end

local function isFarFromWaste(position, wasteZone)
	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
			if hitbox and (hitbox.Position - position).Magnitude < GameData.Spawn.MinDistanceBetweenWaste then
				return false
			end
		end
	end

	return true
end

local function countActiveWaste(wasteZone)
	local count = 0
	for _, wasteModel in ipairs(wasteZone:GetChildren()) do
		if wasteModel:IsA("Model") and wasteModel:GetAttribute("GEIWasteNode") then
			count += 1
		end
	end

	return count
end

local function findSpawnPosition(surface, wasteZone)
	local margin = 6
	local halfX = math.max(1, surface.Size.X / 2 - margin)
	local halfZ = math.max(1, surface.Size.Z / 2 - margin)
	local surfaceTopY = surface.Position.Y + surface.Size.Y / 2

	for _ = 1, GameData.Spawn.MaxSpawnAttempts do
		local position = Vector3.new(
			surface.Position.X + random:NextNumber(-halfX, halfX),
			surfaceTopY,
			surface.Position.Z + random:NextNumber(-halfZ, halfZ)
		)

		if isFarFromPlayers(position) and isFarFromWaste(position, wasteZone) then
			return position
		end
	end

	return nil
end

local function createBillboard(hitbox, wasteConfig)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WasteBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(190, 72)
	billboard.StudsOffset = Vector3.new(0, hitbox.Size.Y / 2 + 2.1, 0)
	billboard.Parent = hitbox

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(22, 25, 27)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Position = UDim2.fromOffset(8, 4)
	nameLabel.Size = UDim2.new(1, -16, 0, 30)
	nameLabel.Text = wasteConfig.Name
	nameLabel.TextColor3 = wasteConfig.AccentColor
	nameLabel.TextScaled = true
	nameLabel.Parent = frame

	local nameConstraint = Instance.new("UITextSizeConstraint")
	nameConstraint.MaxTextSize = 20
	nameConstraint.MinTextSize = 10
	nameConstraint.Parent = nameLabel

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HPLabel"
	hpLabel.BackgroundTransparency = 1
	hpLabel.Font = Enum.Font.GothamMedium
	hpLabel.Position = UDim2.fromOffset(8, 36)
	hpLabel.Size = UDim2.new(1, -16, 0, 28)
	hpLabel.Text = tostring(wasteConfig.MaxHP) .. " / " .. tostring(wasteConfig.MaxHP)
	hpLabel.TextColor3 = Color3.fromRGB(242, 246, 248)
	hpLabel.TextScaled = true
	hpLabel.Parent = frame

	local hpConstraint = Instance.new("UITextSizeConstraint")
	hpConstraint.MaxTextSize = 19
	hpConstraint.MinTextSize = 10
	hpConstraint.Parent = hpLabel
end

local function updateHPBillboard(wasteModel)
	local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
	if not hitbox then
		return
	end

	local billboard = hitbox:FindFirstChild("WasteBillboard")
	local frame = billboard and billboard:FindFirstChild("Frame")
	local hpLabel = frame and frame:FindFirstChild("HPLabel")
	if hpLabel and hpLabel:IsA("TextLabel") then
		local currentHP = math.max(0, math.floor(wasteModel:GetAttribute("CurrentHP") or 0))
		local maxHP = math.max(1, math.floor(wasteModel:GetAttribute("MaxHP") or 1))
		hpLabel.Text = tostring(currentHP) .. " / " .. tostring(maxHP)
	end
end

local function createRangeRing(wasteModel, hitbox, wasteConfig)
	local ringFolder = Instance.new("Folder")
	ringFolder.Name = "RangeRing"
	ringFolder.Parent = wasteModel

	local radius = math.clamp(wasteConfig.RingRadius or GameData.Spawn.DefaultRingRadius, 4, GameData.Spawn.MaxRingRadius)
	local segmentCount = GameData.Spawn.RingSegmentCount
	local segmentLength = math.max(0.9, (2 * math.pi * radius) / (segmentCount * 2.4))
	local center = Vector3.new(hitbox.Position.X, hitbox.Position.Y - hitbox.Size.Y / 2 + 0.12, hitbox.Position.Z)

	wasteModel:SetAttribute("RingRadius", radius)
	wasteModel:SetAttribute("RingSegmentCount", segmentCount)

	for index = 1, segmentCount do
		local angle = ((index - 1) / segmentCount) * math.pi * 2
		local segment = Instance.new("Part")
		segment.Name = "RingSegment"
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.Color = wasteConfig.AccentColor
		segment.Material = Enum.Material.Neon
		segment.Size = Vector3.new(segmentLength, 0.08, 0.18)
		segment.Transparency = 0.42
		segment:SetAttribute("SegmentIndex", index)
		segment:SetAttribute("SegmentCount", segmentCount)
		segment.CFrame = CFrame.new(center)
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, 0, -radius)
			* CFrame.Angles(0, math.pi / 2, 0)
		segment.Parent = ringFolder
	end
end

local function createWasteNode(spawnPosition, wasteZone)
	local wasteId, wasteConfig = GameData.GetRandomWasteType(random)
	local size = wasteConfig.VisualSize
	local hitboxPosition = spawnPosition + Vector3.new(0, size.Y / 2, 0)

	local model = Instance.new("Model")
	model.Name = wasteConfig.Name
	model:SetAttribute("GEIWasteNode", true)
	model:SetAttribute("WasteId", wasteId)
	model:SetAttribute("Rarity", wasteConfig.Rarity)
	model:SetAttribute("CurrentHP", wasteConfig.MaxHP)
	model:SetAttribute("MaxHP", wasteConfig.MaxHP)
	model:SetAttribute("WasteReward", wasteConfig.WasteReward)
	model:SetAttribute("DiamondChance", wasteConfig.DiamondChance)
	model:SetAttribute("DiamondReward", wasteConfig.DiamondReward)

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.Color = wasteConfig.Color
	hitbox.Material = Enum.Material.SmoothPlastic
	hitbox.Position = hitboxPosition
	hitbox.Shape = Enum.PartType.Ball
	hitbox.Size = size
	hitbox.Parent = model

	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Anchored = true
	accent.CanCollide = false
	accent.CanTouch = false
	accent.Color = wasteConfig.AccentColor
	accent.Material = Enum.Material.SmoothPlastic
	accent.Position = hitboxPosition + Vector3.new(0.6, size.Y * 0.3, -0.4)
	accent.Shape = Enum.PartType.Ball
	accent.Size = size * 0.42
	accent.Parent = model

	model.PrimaryPart = hitbox
	createBillboard(hitbox, wasteConfig)
	createRangeRing(model, hitbox, wasteConfig)
	model.Parent = wasteZone
end

local function getWasteModelFromTarget(target)
	if typeof(target) ~= "Instance" then
		return nil
	end

	local current = target
	while current and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("GEIWasteNode") then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function handleAttack(player, target)
	local PlayerManager = waitForPlayerManager()
	local dataFolder = PlayerManager.GetDataFolder(player)
	local root = getRootPart(player)
	local wasteModel = getWasteModelFromTarget(target)

	if not dataFolder or not root or not wasteModel then
		return
	end

	local hitbox = wasteModel.PrimaryPart or wasteModel:FindFirstChild("Hitbox")
	if not hitbox then
		return
	end

	local currentHP = wasteModel:GetAttribute("CurrentHP")
	if type(currentHP) ~= "number" or currentHP <= 0 then
		return
	end

	local equippedTool = dataFolder:FindFirstChild("EquippedTool")
	local wasteCount = dataFolder:FindFirstChild("WasteCount")
	local maxWaste = dataFolder:FindFirstChild("MaxWaste")
	local toolDamage = dataFolder:FindFirstChild("ToolDamage")
	local toolRange = dataFolder:FindFirstChild("ToolRange")

	if not equippedTool or not wasteCount or not maxWaste or not toolDamage or not toolRange then
		return
	end

	if wasteCount.Value >= maxWaste.Value then
		fireClient(player, "AttackFeedback", {
			Target = wasteModel,
			Reason = "BackpackFull",
		})
		return
	end

	local toolConfig = GameData.GetTool(equippedTool.Value)
	if not toolConfig then
		return
	end

	local now = os.clock()
	local nextAllowedAttack = attackCooldowns[player] or 0
	if now < nextAllowedAttack then
		return
	end

	local distance = (root.Position - hitbox.Position).Magnitude
	local allowedDistance = toolRange.Value + math.max(hitbox.Size.X, hitbox.Size.Z) / 2
	if distance > allowedDistance then
		fireClient(player, "AttackFeedback", {
			Target = wasteModel,
			Reason = "OutOfRange",
		})
		return
	end

	attackCooldowns[player] = now + toolConfig.Cooldown

	local newHP = math.max(0, currentHP - toolDamage.Value)
	wasteModel:SetAttribute("CurrentHP", newHP)
	updateHPBillboard(wasteModel)

	fireClient(player, "TutorialProgress", "ClickedWaste")

	local feedback = {
		Target = wasteModel,
		Damage = toolDamage.Value,
		RemainingHP = newHP,
		Destroyed = false,
		WasteGained = 0,
		DiamondsGained = 0,
	}

	if newHP <= 0 then
		feedback.Destroyed = true
		feedback.WasteGained = PlayerManager.AddWaste(player, wasteModel:GetAttribute("WasteReward") or 0)

		local diamondChance = wasteModel:GetAttribute("DiamondChance") or 0
		if random:NextNumber() <= diamondChance then
			feedback.DiamondsGained = PlayerManager.AddDiamonds(player, wasteModel:GetAttribute("DiamondReward") or 1)
		end

		task.delay(0.18, function()
			if wasteModel.Parent then
				wasteModel:Destroy()
			end
		end)
	end

	fireClient(player, "AttackFeedback", feedback)
end

ensureRemote("RequestAttack").OnServerEvent:Connect(handleAttack)

Players.PlayerRemoving:Connect(function(player)
	attackCooldowns[player] = nil
end)

task.spawn(function()
	while true do
		local surface = getSpawnSurface()
		local wasteZone = getWasteZone()

		if surface and wasteZone then
			local activeWaste = countActiveWaste(wasteZone)

			while activeWaste < GameData.Spawn.MaxWasteNodes do
				local spawnPosition = findSpawnPosition(surface, wasteZone)
				if not spawnPosition then
					break
				end

				createWasteNode(spawnPosition, wasteZone)
				activeWaste += 1
			end
		end

		task.wait(GameData.Spawn.SpawnInterval)
	end
end)
