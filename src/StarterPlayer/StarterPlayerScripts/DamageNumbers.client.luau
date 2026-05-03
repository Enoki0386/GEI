local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
local attackFeedback = remotes and remotes:WaitForChild("AttackFeedback", 20)
if not attackFeedback then return end

local function getDamageFromFeedback(feedback)
	if type(feedback) == "table" then
		for _, key in ipairs({ "Damage", "Amount", "DamageDealt" }) do
			if type(feedback[key]) == "number" then
				return math.floor(feedback[key])
			end
		end
	end
	local data = player:FindFirstChild("PlayerData")
	local damage = data and data:FindFirstChild("ToolDamage")
	return damage and math.floor(damage.Value) or 0
end

local function getTargetPart(feedback)
	if type(feedback) ~= "table" then return nil end
	local target = feedback.Target
	if typeof(target) ~= "Instance" then return nil end
	if target:IsA("BasePart") then return target end
	if target:IsA("Model") then return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

local function showNumber(part, amount)
	if not part or amount <= 0 then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumber"
	gui.AlwaysOnTop = true
	gui.MaxDistance = 100
	gui.Size = UDim2.fromOffset(100, 40)
	gui.StudsOffset = Vector3.new(math.random(-12, 12) / 10, 3 + math.random() * 1.5, math.random(-12, 12) / 10)
	gui.Adornee = part
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "-" .. tostring(amount)
	label.TextColor3 = Color3.fromRGB(255, 236, 121)
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(gui, 0.8)
end

attackFeedback.OnClientEvent:Connect(function(feedback)
	showNumber(getTargetPart(feedback), getDamageFromFeedback(feedback))
end)
