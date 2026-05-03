local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local TIMEOUTS = {
	Core = 15,
	PlayerData = 20,
	HUD = 25,
}

local function new(className, properties, parent)
	local instance = Instance.new(className)
	for propertyName, value in pairs(properties or {}) do
		instance[propertyName] = value
	end
	instance.Parent = parent
	return instance
end

local playerGui = player:WaitForChild("PlayerGui", TIMEOUTS.Core)
local gui = nil

if playerGui then
	gui = new("ScreenGui", {
		Name = "GEILoading",
		DisplayOrder = 1000,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	local background = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(11, 15, 18),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, gui)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 24, 29)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 11, 14)),
		}),
		Rotation = 90,
	}, background)

	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(360, 52),
		Text = "Loading GEI...",
		TextColor3 = Color3.fromRGB(244, 248, 250),
		TextScaled = true,
		TextStrokeTransparency = 0.8,
	}, background)

	new("UITextSizeConstraint", {
		MaxTextSize = 32,
		MinTextSize = 14,
	}, label)

	local subLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromOffset(360, 28),
		Text = "Preparing tools, waste models, and HUD",
		TextColor3 = Color3.fromRGB(166, 180, 188),
		TextScaled = true,
	}, background)

	new("UITextSizeConstraint", {
		MaxTextSize = 14,
		MinTextSize = 8,
	}, subLabel)
end

local function waitForChildWithLog(parent, childName, timeoutSeconds, label)
	if not parent then
		warn("[Loading] Cannot wait for " .. label .. " because parent is missing.")
		return nil
	end

	local child = parent:FindFirstChild(childName) or parent:WaitForChild(childName, timeoutSeconds)
	if child then
		print("[Loading] " .. label .. " ready")
	else
		warn("[Loading] Timed out waiting for " .. label .. ". Continuing with fallback startup.")
	end

	return child
end

local function collectPreloadAssets(folder)
	local assets = {}
	if not folder then
		return assets
	end

	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("MeshPart")
			or descendant:IsA("Decal")
			or descendant:IsA("Texture")
			or descendant:IsA("Sound")
			or descendant:IsA("Animation")
			or descendant:IsA("ImageLabel")
			or descendant:IsA("ImageButton")
		then
			table.insert(assets, descendant)
		end
	end

	return assets
end

local function waitForMainHUDReady(parent, timeoutSeconds)
	if not parent then
		warn("[Loading] Cannot wait for MainHUD because PlayerGui is missing.")
		return nil
	end

	local startedAt = os.clock()
	while os.clock() - startedAt < timeoutSeconds do
		local mainHud = parent:FindFirstChild("MainHUD")
		if mainHud and mainHud:IsA("ScreenGui") and mainHud:FindFirstChild("TopStats") and mainHud:FindFirstChild("ToolBar") then
			print("[Loading] MainHUD ready")
			return mainHud
		end
		task.wait(0.1)
	end

	warn("[Loading] Timed out waiting for MainHUD. Continuing with fallback startup.")
	return nil
end

local gameDataModule = waitForChildWithLog(ReplicatedStorage, "GameData", TIMEOUTS.Core, "GameData")
waitForChildWithLog(ReplicatedStorage, "Remotes", TIMEOUTS.Core, "Remotes")

local preloadAssets = {}
for _, folderName in ipairs({ "ToolModels", "WasteModels", "PetModels", "Sounds" }) do
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	for _, asset in ipairs(collectPreloadAssets(folder)) do
		table.insert(preloadAssets, asset)
	end
end

if #preloadAssets > 0 then
	local preloadDone = false
	local preloadOk = false
	local preloadError = nil

	task.spawn(function()
		preloadOk, preloadError = pcall(function()
			ContentProvider:PreloadAsync(preloadAssets)
		end)
		preloadDone = true
	end)

	local startedAt = os.clock()
	while not preloadDone and os.clock() - startedAt < 10 do
		task.wait(0.1)
	end

	if preloadDone and preloadOk then
		print("[Loading] Preloaded " .. tostring(#preloadAssets) .. " asset instances")
	elseif preloadDone then
		warn("[Loading] Preload skipped after error:", preloadError)
	else
		warn("[Loading] Preload timed out. Continuing startup.")
	end
end

waitForChildWithLog(player, "PlayerData", TIMEOUTS.PlayerData, "PlayerData")

waitForMainHUDReady(playerGui, TIMEOUTS.HUD)

if gameDataModule then
	task.wait(0.15)
end

if gui then
	local background = gui:FindFirstChildOfClass("Frame")
	if background then
		local fade = TweenService:Create(background, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		fade:Play()
		fade.Completed:Wait()
	end
	gui:Destroy()
end
