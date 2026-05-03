local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local ORIGIN_RADIUS = 8

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isPossiblePetFollower(instance)
	if not (instance:IsA("Model") or instance:IsA("BasePart")) then
		return false
	end
	if instance:GetAttribute("GEIPetFollower") == true then
		return true
	end
	local name = string.lower(instance.Name)
	return string.find(name, "pet") ~= nil and (string.find(name, "follow") ~= nil or string.find(name, "follower") ~= nil)
end

local function getPosition(instance)
	if instance:IsA("BasePart") then
		return instance.Position
	end
	local part = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function moveNearRoot(instance, root)
	local target = root.CFrame * CFrame.new(math.random(-3, 3), 2.5, math.random(3, 5))
	if instance:IsA("BasePart") then
		instance.CFrame = target
	elseif instance:IsA("Model") then
		pcall(function()
			instance:PivotTo(target)
		end)
	end
end

RunService.RenderStepped:Connect(function()
	local root = getRoot()
	if not root then return end
	for _, instance in ipairs(Workspace:GetChildren()) do
		if isPossiblePetFollower(instance) then
			local position = getPosition(instance)
			if position and position.Magnitude < ORIGIN_RADIUS then
				moveNearRoot(instance, root)
			end
		end
	end
end)
