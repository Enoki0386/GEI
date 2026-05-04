local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer

local MAX_LOADING_SECONDS = 8
local PLAYER_GUI_TIMEOUT = 5
local FADE_SECONDS = 0.35
local startedAt = os.clock()

local function new(className, properties, parent)
	local instance = Instance.new(className)
	for propertyName, value in pairs(properties or {}) do
		instance[propertyName] = value
	end
	instance.Parent = parent
	return instance
end

local function tween(instance, tweenInfo, goals)
	local createdTween = TweenService:Create(instance, tweenInfo, goals)
	createdTween:Play()
	return createdTween
end

local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_TIMEOUT)
local gui = nil
local statusLabel = nil
local progressFill = nil
local percentLabel = nil

local function setStatus(text, progress)
	if statusLabel then
		statusLabel.Text = text
	end

	local clampedProgress = math.clamp(progress or 0, 0, 1)
	if percentLabel then
		percentLabel.Text = tostring(math.floor(clampedProgress * 100)) .. "%"
	end

	if progressFill then
		tween(progressFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(clampedProgress, 1),
		})
	end
end

if playerGui then
	gui = new("ScreenGui", {
		Name = "GarbageEmpireLoading",
		DisplayOrder = 1000,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	local background = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(8, 11, 14),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, gui)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 24, 29)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(10, 14, 18)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 8, 11)),
		}),
		Rotation = 90,
	}, background)

	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(18, 23, 28),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 0, 214),
	}, background)
	new("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
	new("UIStroke", {
		Color = Color3.fromRGB(92, 232, 152),
		Thickness = 1.4,
		Transparency = 0.38,
	}, panel)
	new("UIPadding", {
		PaddingBottom = UDim.new(0, 26),
		PaddingLeft = UDim.new(0, 30),
		PaddingRight = UDim.new(0, 30),
		PaddingTop = UDim.new(0, 28),
	}, panel)
	new("UISizeConstraint", {
		MaxSize = Vector2.new(430, 214),
		MinSize = Vector2.new(280, 190),
	}, panel)

	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Size = UDim2.new(1, 0, 0, 48),
		Text = "Garbage Empire",
		TextColor3 = Color3.fromRGB(244, 250, 246),
		TextScaled = true,
		TextStrokeTransparency = 0.86,
	}, panel)
	new("UITextSizeConstraint", {
		MaxTextSize = 36,
		MinTextSize = 18,
	}, title)

	statusLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "Chargement du monde...",
		TextColor3 = Color3.fromRGB(174, 190, 198),
		TextScaled = true,
	}, panel)
	new("UITextSizeConstraint", {
		MaxTextSize = 15,
		MinTextSize = 9,
	}, statusLabel)

	local progressBack = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(31, 38, 43),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 112),
		Size = UDim2.new(1, 0, 0, 16),
	}, panel)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, progressBack)
	new("UIStroke", {
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.86,
	}, progressBack)

	progressFill = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(92, 232, 152),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, progressBack)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, progressFill)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 232, 152)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(99, 201, 255)),
		}),
		Rotation = 0,
	}, progressFill)

	percentLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(0, 144),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "0%",
		TextColor3 = Color3.fromRGB(118, 235, 168),
		TextScaled = true,
	}, panel)
	new("UITextSizeConstraint", {
		MaxTextSize = 14,
		MinTextSize = 8,
	}, percentLabel)

	setStatus("Chargement du monde...", 0.08)
end

local function getRemainingTime()
	return math.max(0, MAX_LOADING_SECONDS - (os.clock() - startedAt))
end

local function waitForChildWithinBudget(parent, childName, timeoutSeconds)
	if not parent or getRemainingTime() <= 0 then
		return nil
	end

	local timeout = math.min(timeoutSeconds, getRemainingTime())
	return parent:FindFirstChild(childName) or parent:WaitForChild(childName, timeout)
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

local function waitForMainHUDReady(timeoutSeconds)
	if not playerGui or getRemainingTime() <= 0 then
		return nil
	end

	local endAt = os.clock() + math.min(timeoutSeconds, getRemainingTime())
	while os.clock() < endAt do
		local mainHud = playerGui:FindFirstChild("MainHUD")
		if mainHud and mainHud:IsA("ScreenGui") and mainHud:FindFirstChild("TopStats") and mainHud:FindFirstChild("ToolBar") then
			return mainHud
		end
		task.wait(0.08)
	end

	return nil
end

setStatus("Chargement des assets...", 0.18)
waitForChildWithinBudget(ReplicatedStorage, "GameData", 1.5)
waitForChildWithinBudget(ReplicatedStorage, "Remotes", 1.5)

local preloadAssets = {}
for _, folderName in ipairs({ "ToolModels", "WasteModels", "PetModels", "Sounds" }) do
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	for _, asset in ipairs(collectPreloadAssets(folder)) do
		table.insert(preloadAssets, asset)
	end
end

if #preloadAssets > 0 and getRemainingTime() > 0 then
	setStatus("Chargement des assets...", 0.34)

	local preloadDone = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preloadAssets)
		end)
		preloadDone = true
	end)

	while not preloadDone and getRemainingTime() > 3.25 do
		task.wait(0.08)
	end
end

setStatus("Chargement du joueur...", 0.62)
waitForChildWithinBudget(player, "PlayerData", 1.5)

setStatus("Chargement de l'interface...", 0.78)
waitForMainHUDReady(1.75)

setStatus("Pret !", 1)
task.wait(0.18)

if gui then
	local tweens = {}
	for _, descendant in ipairs(gui:GetDescendants()) do
		if descendant:IsA("Frame") then
			table.insert(tweens, tween(descendant, TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}))
		elseif descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			table.insert(tweens, tween(descendant, TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}))
		elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			table.insert(tweens, tween(descendant, TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
				ImageTransparency = 1,
			}))
		elseif descendant:IsA("UIStroke") then
			table.insert(tweens, tween(descendant, TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
			}))
		end
	end

	local firstTween = tweens[1]
	if firstTween then
		firstTween.Completed:Wait()
	end

	gui:Destroy()
end
