local ReplicatedStorage = game:GetService("ReplicatedStorage")

_G.GEI = _G.GEI or {}

local REMOTE_NAMES = {
	"RequestAttack",
	"EquipItem",
	"BuyItem",
	"PlayerDataUpdate",
	"AttackFeedback",
	"SellFeedback",
	"ShopState",
	"PurchaseResult",
	"TutorialProgress",
}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

for _, remoteName in ipairs(REMOTE_NAMES) do
	if not remotesFolder:FindFirstChild(remoteName) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = remotesFolder
	end
end

_G.GEI.Remotes = remotesFolder
