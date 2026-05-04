local TweenService = game:GetService("TweenService")

local ButtonEffects = {}

local stateByButton = setmetatable({}, { __mode = "k" })

local function clampColor(value)
	return math.clamp(value, 0, 255)
end

local function shiftColor(color, amount)
	return Color3.fromRGB(
		clampColor(math.floor(color.R * 255 + amount)),
		clampColor(math.floor(color.G * 255 + amount)),
		clampColor(math.floor(color.B * 255 + amount))
	)
end

local function getScale(button)
	local scale = button:FindFirstChild("ButtonEffectScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end

	scale = Instance.new("UIScale")
	scale.Name = "ButtonEffectScale"
	scale.Scale = 1
	scale.Parent = button
	return scale
end

local function tween(instance, properties, duration)
	local tweenInfo = TweenInfo.new(duration or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local activeTween = TweenService:Create(instance, tweenInfo, properties)
	activeTween:Play()
	return activeTween
end

local function applyVisual(button, pressed)
	local state = stateByButton[button]
	if not state then
		return
	end

	local scale = getScale(button)
	if state.Disabled then
		button.AutoButtonColor = false
		button.Active = false
		tween(button, {
			BackgroundColor3 = state.DisabledColor,
			BackgroundTransparency = state.DisabledTransparency,
			TextTransparency = state.DisabledTextTransparency,
		}, 0.1)
		tween(scale, { Scale = 1 }, 0.1)
		return
	end

	button.AutoButtonColor = false
	button.Active = true

	local targetColor = state.NormalColor
	if pressed then
		targetColor = state.PressColor
	elseif state.Hovered then
		targetColor = state.HoverColor
	end

	tween(button, {
		BackgroundColor3 = targetColor,
		BackgroundTransparency = state.NormalTransparency,
		TextTransparency = state.NormalTextTransparency,
	}, 0.1)
	tween(scale, { Scale = pressed and 0.96 or (state.Hovered and 1.035 or 1) }, 0.1)
end

function ButtonEffects.Apply(button, options)
	if not button or not button:IsA("GuiButton") then
		return nil
	end

	options = type(options) == "table" and options or {}
	local normalColor = options.NormalColor or button.BackgroundColor3
	local state = stateByButton[button] or {}
	state.NormalColor = normalColor
	state.HoverColor = options.HoverColor or shiftColor(normalColor, 18)
	state.PressColor = options.PressColor or shiftColor(normalColor, -18)
	state.DisabledColor = options.DisabledColor or Color3.fromRGB(91, 98, 103)
	state.NormalTransparency = options.NormalTransparency or button.BackgroundTransparency
	state.DisabledTransparency = options.DisabledTransparency or 0.18
	state.NormalTextTransparency = options.NormalTextTransparency or button.TextTransparency
	state.DisabledTextTransparency = options.DisabledTextTransparency or 0.28
	state.Disabled = options.Disabled == true
	state.Hovered = false
	stateByButton[button] = state

	if not state.Connected then
		state.Connected = true
		button.MouseEnter:Connect(function()
			local currentState = stateByButton[button]
			if currentState then
				currentState.Hovered = true
				applyVisual(button, false)
			end
		end)
		button.MouseLeave:Connect(function()
			local currentState = stateByButton[button]
			if currentState then
				currentState.Hovered = false
				applyVisual(button, false)
			end
		end)
		button.MouseButton1Down:Connect(function()
			if ButtonEffects.IsEnabled(button) then
				applyVisual(button, true)
			end
		end)
		button.MouseButton1Up:Connect(function()
			applyVisual(button, false)
		end)
		button.Destroying:Connect(function()
			stateByButton[button] = nil
		end)
	end

	applyVisual(button, false)
	return state
end

function ButtonEffects.SetState(button, options)
	local state = stateByButton[button]
	if not state then
		return ButtonEffects.Apply(button, options)
	end

	options = type(options) == "table" and options or {}
	if options.NormalColor then
		state.NormalColor = options.NormalColor
		state.HoverColor = options.HoverColor or shiftColor(options.NormalColor, 18)
		state.PressColor = options.PressColor or shiftColor(options.NormalColor, -18)
	end
	if options.DisabledColor then
		state.DisabledColor = options.DisabledColor
	end
	if options.Disabled ~= nil then
		state.Disabled = options.Disabled == true
	end

	applyVisual(button, false)
	return state
end

function ButtonEffects.SetEnabled(button, enabled)
	return ButtonEffects.SetState(button, { Disabled = not enabled })
end

function ButtonEffects.IsEnabled(button)
	local state = stateByButton[button]
	return state == nil or state.Disabled ~= true
end

return ButtonEffects
