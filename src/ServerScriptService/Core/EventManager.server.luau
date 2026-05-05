local ReplicatedStorage = game:GetService("ReplicatedStorage")

_G.GEI = _G.GEI or {}

local REMOTE_NAMES = {
	"RequestAttack",
	"EquipItem",
	"BuyItem",
	"PlayerDataUpdate",
	"AttackFeedback",
	"SellFeedback",
	"TeleportToSell",
	"ShopState",
	"PurchaseResult",
	"TutorialProgress",
	"PetInventoryUpdated",
	"PetError",
	"PetHatchResult",
	"ZoneFeedback",
}

local REMOTE_FUNCTION_NAMES = {
	"HatchEgg",
	"EquipPet",
	"UnequipPet",
	"DestroyPet",
	"FusePet",
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

for _, remoteName in ipairs(REMOTE_FUNCTION_NAMES) do
	local existing = remotesFolder:FindFirstChild(remoteName)
	if existing and not existing:IsA("RemoteFunction") then
		existing:Destroy()
		existing = nil
	end

	if not existing then
		local remote = Instance.new("RemoteFunction")
		remote.Name = remoteName
		remote.Parent = remotesFolder
	end
end

_G.GEI.Remotes = remotesFolder
