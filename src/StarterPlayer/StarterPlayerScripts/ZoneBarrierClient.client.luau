local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 20)
if not sharedFolder then
	return
end

local World1Data = require(sharedFolder:WaitForChild("World1Data"))
local WorkspaceUtil = require(sharedFolder:WaitForChild("WorkspaceUtil"))
local NotificationClient = require(sharedFolder:WaitForChild("NotificationClient"))
local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
local zoneFeedbackRemote = remotes and remotes:WaitForChild("ZoneFeedback", 20)

local function setBarrierLocalState(zoneId, unlocked)
	local zone = World1Data.Zones[zoneId]
	if not zone or not zone.BarrierName then
		return
	end

	local object = WorkspaceUtil.Find(zone.BarrierName, { "Barriers" }, { SearchDescendants = true })
	if not object then
		return
	end

	local parts = {}
	if object:IsA("BasePart") then
		table.insert(parts, object)
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		elseif descendant:IsA("BillboardGui") or descendant:IsA("ProximityPrompt") then
			descendant.Enabled = not unlocked
		end
	end

	for _, part in ipairs(parts) do
		part.LocalTransparencyModifier = unlocked and 0.78 or 0
		part.CanCollide = not unlocked
		part.CanTouch = not unlocked
		part.CanQuery = not unlocked
	end
end

local function refresh()
	local dataFolder = player:FindFirstChild("PlayerData")
	local progress = dataFolder and dataFolder:FindFirstChild("WorldProgress")
	local zones = progress and progress:FindFirstChild("UnlockedZones")

	for zoneId in pairs(World1Data.Zones) do
		local unlockedValue = zones and zones:FindFirstChild(zoneId)
		setBarrierLocalState(zoneId, unlockedValue ~= nil and unlockedValue.Value == true)
	end
end

local function bindProgress()
	local dataFolder = player:WaitForChild("PlayerData", 60)
	if not dataFolder then
		return
	end

	dataFolder.DescendantAdded:Connect(refresh)
	dataFolder.DescendantRemoving:Connect(function()
		task.defer(refresh)
	end)
	refresh()
end

task.defer(bindProgress)
workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "Barriers" or string.find(descendant.Name, "Barrier") then
		task.defer(refresh)
	end
end)

if zoneFeedbackRemote then
	zoneFeedbackRemote.OnClientEvent:Connect(function(success, message)
		NotificationClient.Show(message or (success and "Zone unlocked." or "Zone locked."), {
			Type = success and "Success" or "Error",
		})
	end)
end
