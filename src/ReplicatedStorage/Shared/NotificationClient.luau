local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local NotificationClient = {}

local TOAST_COLORS = {
	Success = Color3.fromRGB(135, 255, 166),
	Error = Color3.fromRGB(255, 169, 137),
	Warning = Color3.fromRGB(255, 216, 118),
	Info = Color3.fromRGB(199, 224, 255),
}

local MAX_TOASTS = 3
local DEFAULT_DURATION = 2.5
local DEDUPE_SECONDS = 0.75

local gui = nil
local holder = nil
local activeToasts = {}
local lastShown = {}

local function getPlayerGui()
	local player = Players.LocalPlayer
	return player and player:FindFirstChild("PlayerGui")
end

local function new(className, properties, parent)
	local instance = Instance.new(className)
	for propertyName, value in pairs(properties or {}) do
		instance[propertyName] = value
	end
	instance.Parent = parent
	return instance
end

local function ensureGui()
	local playerGui = getPlayerGui()
	if not playerGui then
		return nil
	end

	if gui and gui.Parent == playerGui and holder then
		return holder
	end

	gui = playerGui:FindFirstChild("GEINotifications")
	if not gui then
		gui = new("ScreenGui", {
			Name = "GEINotifications",
			DisplayOrder = 90,
			IgnoreGuiInset = false,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, playerGui)
	end

	holder = gui:FindFirstChild("ToastHolder")
	if not holder then
		holder = new("Frame", {
			Name = "ToastHolder",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 74),
			Size = UDim2.fromOffset(380, 150),
		}, gui)

		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}, holder)
	end

	return holder
end

local function removeToast(toast)
	for index, activeToast in ipairs(activeToasts) do
		if activeToast == toast then
			table.remove(activeToasts, index)
			break
		end
	end
	if toast.Parent then
		toast:Destroy()
	end
end

function NotificationClient.Show(text, options)
	if type(text) ~= "string" or text == "" then
		return
	end

	options = type(options) == "table" and options or {}
	local now = os.clock()
	if lastShown[text] and now - lastShown[text] < DEDUPE_SECONDS then
		return
	end
	lastShown[text] = now

	local toastHolder = ensureGui()
	if not toastHolder then
		return
	end

	while #activeToasts >= MAX_TOASTS do
		removeToast(activeToasts[1])
	end

	local toast = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(18, 23, 28),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		LayoutOrder = -math.floor(now * 1000),
		Size = UDim2.fromOffset(0, 42),
	}, toastHolder)
	table.insert(activeToasts, toast)

	new("UICorner", { CornerRadius = UDim.new(0, 13) }, toast)
	new("UIStroke", {
		Color = options.Color or TOAST_COLORS[options.Type or "Info"] or TOAST_COLORS.Info,
		Thickness = 1.4,
		Transparency = 0.25,
	}, toast)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}, toast)

	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = Color3.fromRGB(245, 250, 252),
		TextScaled = true,
		TextTransparency = 1,
		TextWrapped = true,
	}, toast)
	new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 9 }, label)

	local openTween = TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(360, 42),
	})
	local textInTween = TweenService:Create(label, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	})
	openTween:Play()
	textInTween:Play()

	task.delay(options.Duration or DEFAULT_DURATION, function()
		if not toast.Parent then
			return
		end

		local closeTween = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 36),
		})
		local textOutTween = TweenService:Create(label, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
		})
		closeTween:Play()
		textOutTween:Play()
		closeTween.Completed:Connect(function()
			removeToast(toast)
		end)
	end)
end

return NotificationClient
