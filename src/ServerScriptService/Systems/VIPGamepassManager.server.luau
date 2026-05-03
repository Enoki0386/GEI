local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World1Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World1Data"))

local function getPartFromObject(object)
	if not object then return nil end
	if object:IsA("BasePart") then return object end
	if object:IsA("Model") then return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true) end
	return object:FindFirstChildWhichIsA("BasePart", true)
end

local function playerHasVIP(player)
	if World1Data.IsAdmin(player) then
		return true
	end
	local gamepassId = World1Data.VIP.GamepassId
	if type(gamepassId) ~= "number" or gamepassId <= 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return ok and owns == true
end

local function setupVIPZone()
	local zone = workspace:FindFirstChild(World1Data.VIP.ZoneName, true)
	local part = getPartFromObject(zone)
	if not part then return end
	local prompt = part:FindFirstChild("GEIVIPPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GEIVIPPrompt"
		prompt.ActionText = "Check"
		prompt.ObjectText = "VIP"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	if not part:FindFirstChild("GEIVIPBillboard") then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "GEIVIPBillboard"
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 70
		billboard.Size = UDim2.fromOffset(240, 80)
		billboard.StudsOffset = Vector3.new(0, 5, 0)
		billboard.Parent = part
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(28, 20, 7)
		frame.BackgroundTransparency = 0.1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = billboard
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.Size = UDim2.fromScale(1, 1)
		label.Text = "VIP Zone\n" .. World1Data.VIP.BenefitsText
		label.TextColor3 = Color3.fromRGB(255, 217, 92)
		label.TextScaled = true
		label.TextWrapped = true
		label.Parent = frame
	end
	if part:GetAttribute("GEIVIPConnected") then return end
	part:SetAttribute("GEIVIPConnected", true)
	prompt.Triggered:Connect(function(player)
		if playerHasVIP(player) then
			print("[VIP]", player.Name, "has VIP access")
		else
			print("[VIP]", player.Name, "does not own VIP yet. Add GamepassId in World1Data when ready.")
		end
	end)
end

while true do
	setupVIPZone()
	task.wait(4)
end
