local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 20)
if not gameDataModule then
	warn("[PetClient] Missing ReplicatedStorage.GameData. Pet UI disabled.")
	return
end

local GameData = require(gameDataModule)
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 20)
local soundUtilModule = sharedFolder and sharedFolder:WaitForChild("SoundUtil", 20)
local SoundUtil = soundUtilModule and require(soundUtilModule)
local uiIconUtilsModule = sharedFolder and sharedFolder:WaitForChild("UIIconUtils", 20)
local UIIconUtils = uiIconUtilsModule and require(uiIconUtilsModule)
local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
if not remotes then
	warn("[PetClient] Missing ReplicatedStorage.Remotes. Pet UI disabled.")
	return
end

local hatchEggRemote = remotes:WaitForChild("HatchEgg", 20)
local equipPetRemote = remotes:WaitForChild("EquipPet", 20)
local unequipPetRemote = remotes:WaitForChild("UnequipPet", 20)
local destroyPetRemote = remotes:WaitForChild("DestroyPet", 20)
local fusePetRemote = remotes:WaitForChild("FusePet", 20)
local petInventoryUpdatedRemote = remotes:WaitForChild("PetInventoryUpdated", 20)
local playerDataRemote = remotes:WaitForChild("PlayerDataUpdate", 20)
local playerGui = player:WaitForChild("PlayerGui", 20)

if not hatchEggRemote or not equipPetRemote or not unequipPetRemote or not destroyPetRemote or not fusePetRemote or not petInventoryUpdatedRemote or not playerGui then
	warn("[PetClient] Required pet remotes or PlayerGui are missing. Pet UI disabled.")
	return
end

local STARTER_EGG_ID = "StarterEgg"
local FOLLOW_OFFSETS = {
	Vector3.new(-3, 2, 3),
	Vector3.new(3, 2, 3),
	Vector3.new(0, 2.5, 4.5),
}

local currentPets = {
	Inventory = {},
	Equipped = {},
	MaxEquipped = (GameData.Pets and GameData.Pets.MaxEquipped) or 3,
	MaxStorage = (GameData.Pets and (GameData.Pets.MaxStorage or GameData.Pets.BasePetStorage)) or 30,
	Discovered = {},
	Buffs = GameData.Pets and GameData.Pets.DefaultBuffs or {
		CashMultiplier = 1,
		DamageMultiplier = 1,
		BackpackMultiplier = 1,
	},
}
local selectedPetUid = nil
local followerModels = {}
local eggOverlayGui = nil
local eggPromptConnected = false
local eggWarningShown = false
local currentHatcherPart = nil
local hatchInProgress = false

local function new(className, properties, parent)
	local instance = Instance.new(className)
	for propertyName, value in pairs(properties or {}) do
		instance[propertyName] = value
	end
	instance.Parent = parent
	return instance
end

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end

	return tostring(value)
end

local function formatMultiplier(value)
	return string.format("x%.2f", tonumber(value) or 1)
end

local function getRarityColor(rarity)
	local colors = GameData.Pets and GameData.Pets.RarityColors or {}
	return colors[rarity] or Color3.fromRGB(255, 255, 255)
end

local function getPetConfig(petId)
	return GameData.GetPet(petId)
end

local function getPetDisplayName(petData)
	local config = petData and getPetConfig(petData.PetId)
	local name = config and config.Name or (petData and petData.PetId) or "Pet"
	if petData and petData.Variant == "Golden" then
		return "Golden " .. name
	end
	return name
end

local function getVariantDisplayName(variant)
	if variant == "Golden" then
		return "Golden"
	end
	return variant or "Normal"
end

local function getEquippedSet()
	local result = {}
	for _, petUid in ipairs(currentPets.Equipped or {}) do
		result[petUid] = true
	end
	return result
end

local function getPetByUid(petUid)
	for _, petData in ipairs(currentPets.Inventory or {}) do
		if petData.Uid == petUid then
			return petData
		end
	end
	return nil
end

local function countNormalCopies(petId)
	local count = 0
	local equippedSet = getEquippedSet()
	local hasEquippedCopy = false
	for _, petData in ipairs(currentPets.Inventory or {}) do
		if petData.PetId == petId and (petData.Variant or "Normal") == "Normal" then
			count += 1
			if equippedSet[petData.Uid] then
				hasEquippedCopy = true
			end
		end
	end
	return count, hasEquippedCopy
end

local function setPetsSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end

	currentPets.Inventory = type(snapshot.Inventory) == "table" and snapshot.Inventory or {}
	currentPets.Equipped = type(snapshot.Equipped) == "table" and snapshot.Equipped or {}
	currentPets.MaxEquipped = type(snapshot.MaxEquipped) == "number" and snapshot.MaxEquipped or currentPets.MaxEquipped
	currentPets.MaxStorage = type(snapshot.MaxStorage) == "number" and snapshot.MaxStorage or currentPets.MaxStorage
	currentPets.Discovered = type(snapshot.Discovered) == "table" and snapshot.Discovered or currentPets.Discovered
	currentPets.Buffs = type(snapshot.Buffs) == "table" and snapshot.Buffs or currentPets.Buffs

	if selectedPetUid and not getPetByUid(selectedPetUid) then
		selectedPetUid = nil
	end
end

local function getErrorMessage(reason)
	local messages = {
		NotEnoughCash = "Not enough Cash.",
		InventoryFull = "Inventory full.",
		MaxEquipped = "You already have 3 pets equipped.",
		DestroyEquipped = "Unequip this pet before destroying it.",
		FuseEquipped = "Unequip pets before fusing them.",
		NotEnoughDuplicates = "Not enough duplicates to fuse.",
		InvalidEgg = "Invalid egg.",
		HatchCooldown = "Please wait for the egg to finish opening.",
		InvalidPet = "Invalid pet.",
		NotOwned = "This pet is not in your inventory.",
	}
	return messages[reason] or "Action unavailable."
end

local function invokePetRemote(remote, ...)
	local ok, response = pcall(function(...)
		return remote:InvokeServer(...)
	end, ...)

	if not ok then
		warn("[PetClient] Remote request failed:", response)
		return { Success = false, Error = "RequestFailed" }
	end

	if type(response) ~= "table" then
		return { Success = false, Error = "BadResponse" }
	end

	if response.Pets then
		setPetsSnapshot(response.Pets)
	end

	return response
end

local gui = playerGui:FindFirstChild("GEIPets")
if gui then
	gui:Destroy()
end

gui = new("ScreenGui", {
	Name = "GEIPets",
	DisplayOrder = 35,
	IgnoreGuiInset = false,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local inventoryButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(24, 30, 35),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(1, -22, 1, -122),
	Size = UDim2.fromOffset(120, 42),
	Text = "Inventory",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, inventoryButton)
new("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 1,
	Transparency = 0.72,
}, inventoryButton)
new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8 }, inventoryButton)

local overlay = new("Frame", {
	Name = "InventoryOverlay",
	BackgroundColor3 = Color3.fromRGB(6, 9, 12),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
}, gui)

local panel = new("Frame", {
	Name = "InventoryPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(18, 23, 28),
	BackgroundTransparency = 0.02,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.8, 0.74),
}, overlay)
new("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.72 }, panel)
new("UISizeConstraint", { MaxSize = Vector2.new(1040, 620), MinSize = Vector2.new(700, 430) }, panel)
local panelScale = new("UIScale", { Scale = 0.92 }, panel)

local title = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(24, 18),
	Size = UDim2.new(0.42, 0, 0, 36),
	Text = "Inventory",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
new("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 14 }, title)

local storageLabel = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(24, 58),
	Size = UDim2.fromOffset(190, 24),
	Text = "Storage 0/30",
	TextColor3 = Color3.fromRGB(190, 205, 212),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }, storageLabel)

local equippedLabel = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(220, 58),
	Size = UDim2.fromOffset(160, 24),
	Text = "Equipped 0/3",
	TextColor3 = Color3.fromRGB(190, 205, 212),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }, equippedLabel)

local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(37, 45, 51),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(1, -18, 0, 18),
	Size = UDim2.fromOffset(38, 38),
	Text = "X",
	TextColor3 = Color3.fromRGB(235, 241, 244),
	TextScaled = true,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, closeButton)
new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }, closeButton)

local messageLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(25, 31, 36),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.new(0.5, 0, 0, 18),
	Size = UDim2.fromOffset(390, 34),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	Visible = false,
	ZIndex = 6,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, messageLabel)
new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8 }, messageLabel)

local inventoryFrame = new("ScrollingFrame", {
	Active = true,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(12, 16, 20),
	BackgroundTransparency = 0.28,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	Position = UDim2.fromOffset(24, 96),
	ScrollBarImageColor3 = Color3.fromRGB(98, 112, 120),
	ScrollBarThickness = 5,
	Size = UDim2.new(1, -354, 1, -120),
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 16) }, inventoryFrame)

local gridLayout = new("UIGridLayout", {
	CellPadding = UDim2.fromOffset(12, 12),
	CellSize = UDim2.fromOffset(154, 132),
	FillDirectionMaxCells = 4,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, inventoryFrame)
new("UIPadding", {
	PaddingTop = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingBottom = UDim.new(0, 12),
}, inventoryFrame)

local detailsPanel = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Color3.fromRGB(26, 32, 38),
	BackgroundTransparency = 0.02,
	BorderSizePixel = 0,
	Position = UDim2.new(1, -24, 0, 96),
	Size = UDim2.new(0, 300, 1, -120),
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, detailsPanel)
new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.8 }, detailsPanel)

local preview = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(90, 100, 106),
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(18, 18),
	Size = UDim2.fromOffset(64, 64),
}, detailsPanel)
new("UICorner", { CornerRadius = UDim.new(0, 16) }, preview)

local detailTitle = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(94, 16),
	Size = UDim2.new(1, -112, 0, 42),
	Text = "Select a Pet",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, detailsPanel)
new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 10 }, detailTitle)

local detailMeta = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(94, 58),
	Size = UDim2.new(1, -112, 0, 24),
	Text = "",
	TextColor3 = Color3.fromRGB(190, 205, 212),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, detailsPanel)
new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, detailMeta)

local detailDescription = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Position = UDim2.fromOffset(18, 96),
	Size = UDim2.new(1, -36, 0, 56),
	Text = "Click a pet to view its bonuses.",
	TextColor3 = Color3.fromRGB(205, 216, 222),
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, detailsPanel)
new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }, detailDescription)

local detailBuffs = new("TextLabel", {
	BackgroundColor3 = Color3.fromRGB(16, 20, 24),
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(18, 164),
	Size = UDim2.new(1, -36, 0, 76),
	Text = "",
	TextColor3 = Color3.fromRGB(230, 238, 242),
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
}, detailsPanel)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, detailBuffs)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, detailBuffs)
new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }, detailBuffs)

local buffsPanel = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundColor3 = Color3.fromRGB(18, 23, 28),
	BackgroundTransparency = 0.03,
	BorderSizePixel = 0,
	Position = UDim2.new(1, -24, 0.52, 0),
	Size = UDim2.fromOffset(250, 132),
	ZIndex = 4,
}, overlay)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, buffsPanel)
new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.78 }, buffsPanel)

local buffsTitle = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(14, 12),
	Size = UDim2.new(1, -28, 0, 26),
	Text = "Total Buffs",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
}, buffsPanel)
new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }, buffsTitle)

local totalBuffs = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(14, 44),
	Size = UDim2.new(1, -28, 1, -56),
	Text = "",
	TextColor3 = Color3.fromRGB(202, 215, 222),
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 5,
}, buffsPanel)
new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, totalBuffs)

local equipButton = new("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(75, 121, 219),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(0, 18, 1, -112),
	Size = UDim2.new(1, -36, 0, 34),
	Text = "Equip",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
}, detailsPanel)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, equipButton)
new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8 }, equipButton)

local destroyButton = new("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(180, 76, 69),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(0, 18, 1, -68),
	Size = UDim2.new(0.48, -8, 0, 34),
	Text = "Destroy",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
}, detailsPanel)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, destroyButton)
new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8 }, destroyButton)

local fuseButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(227, 174, 67),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(1, -18, 1, -68),
	Size = UDim2.new(0.48, -8, 0, 34),
	Text = "Fuse",
	TextColor3 = Color3.fromRGB(31, 26, 16),
	TextScaled = true,
}, detailsPanel)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, fuseButton)
new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8 }, fuseButton)

local destroyConfirmOverlay = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(6, 8, 11),
	BackgroundTransparency = 0.38,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 40,
}, gui)

local destroyConfirmPanel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(24, 30, 36),
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(360, 180),
	ZIndex = 41,
}, destroyConfirmOverlay)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, destroyConfirmPanel)
new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.76 }, destroyConfirmPanel)
local destroyConfirmScale = new("UIScale", { Scale = 0.92 }, destroyConfirmPanel)

local destroyConfirmTitle = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(18, 18),
	Size = UDim2.new(1, -36, 0, 34),
	Text = "Destroy this pet?",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	ZIndex = 42,
}, destroyConfirmPanel)
new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 12 }, destroyConfirmTitle)

local destroyConfirmText = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Position = UDim2.fromOffset(22, 60),
	Size = UDim2.new(1, -44, 0, 48),
	Text = "This pet will be permanently deleted.",
	TextColor3 = Color3.fromRGB(208, 220, 226),
	TextScaled = true,
	TextWrapped = true,
	ZIndex = 42,
}, destroyConfirmPanel)
new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 9 }, destroyConfirmText)

local destroyCancelButton = new("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(64, 74, 82),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(0, 22, 1, -18),
	Size = UDim2.new(0.5, -30, 0, 38),
	Text = "Cancel",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	ZIndex = 42,
}, destroyConfirmPanel)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, destroyCancelButton)
new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 9 }, destroyCancelButton)

local destroyConfirmButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(190, 73, 66),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(1, -22, 1, -18),
	Size = UDim2.new(0.5, -30, 0, 38),
	Text = "Destroy",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	ZIndex = 42,
}, destroyConfirmPanel)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, destroyConfirmButton)
new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 9 }, destroyConfirmButton)

local messageTween = nil
local function showMessage(text, color)
	if messageTween then
		messageTween:Cancel()
	end

	messageLabel.Text = text
	messageLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	messageLabel.TextTransparency = 0
	messageLabel.BackgroundTransparency = 0.08
	messageLabel.Visible = true
	messageTween = TweenService:Create(messageLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 1.5), {
		TextTransparency = 1,
		BackgroundTransparency = 1,
	})
	messageTween:Play()
	messageTween.Completed:Connect(function()
		if messageTween then
			messageLabel.Visible = false
			messageTween = nil
		end
	end)
end

local function getPetBuffText(petData)
	local config = petData and getPetConfig(petData.PetId)
	local buffs = config and config.Buffs or {}
	local goldenMultiplier = (GameData.Pets and GameData.Pets.GoldenBuffMultiplier) or 1.5
	local rows = {}
	local buffLabels = {
		BackpackMultiplier = "Backpack",
		CashMultiplier = "Cash",
		DamageMultiplier = "Damage",
	}
	for _, buffName in ipairs({ "CashMultiplier", "DamageMultiplier", "BackpackMultiplier" }) do
		local value = buffs[buffName]
		if type(value) == "number" then
			local finalValue = value
			if petData.Variant == "Golden" then
				finalValue = 1 + ((value - 1) * goldenMultiplier)
			end
			table.insert(rows, (buffLabels[buffName] or buffName) .. " " .. formatMultiplier(finalValue))
		end
	end
	return #rows > 0 and table.concat(rows, "\n") or "No bonus"
end

local function refreshDetails()
	local petData = selectedPetUid and getPetByUid(selectedPetUid)
	local equippedSet = getEquippedSet()
	local buffs = currentPets.Buffs or {}
	local hasInventory = #(currentPets.Inventory or {}) > 0
	totalBuffs.Text = "Total Buffs: Cash " .. formatMultiplier(buffs.CashMultiplier)
		.. " | Damage " .. formatMultiplier(buffs.DamageMultiplier)
		.. " | Backpack " .. formatMultiplier(buffs.BackpackMultiplier)

	if not petData then
		preview.BackgroundColor3 = Color3.fromRGB(90, 100, 106)
		detailTitle.Text = hasInventory and "Select a pet" or "No pet selected"
		detailMeta.Text = ""
		detailDescription.Text = hasInventory and "Select a pet to view its details." or "Open an egg to get a bonus pet."
		detailBuffs.Text = "Total buffs are shown on the side."
		equipButton.Text = "Equip"
		equipButton.AutoButtonColor = false
		destroyButton.AutoButtonColor = false
		fuseButton.AutoButtonColor = false
		return
	end

	local config = getPetConfig(petData.PetId)
	local rarityColor = config and getRarityColor(config.Rarity) or Color3.fromRGB(255, 255, 255)
	local equipped = equippedSet[petData.Uid] == true
	local normalCopies = countNormalCopies(petData.PetId)
	preview.BackgroundColor3 = petData.Variant == "Golden" and Color3.fromRGB(255, 210, 60) or rarityColor
	detailTitle.Text = getPetDisplayName(petData)
	detailMeta.Text = (config and config.Rarity or "Unknown") .. " | " .. getVariantDisplayName(petData.Variant) .. " | " .. (equipped and "Equipped" or "Not Equipped")
	detailMeta.TextColor3 = rarityColor
	detailDescription.Text = config and config.Description or "A bonus pet for Garbage Empire."
	detailBuffs.Text = getPetBuffText(petData)
	equipButton.Text = equipped and "Unequip" or "Equip"
	equipButton.AutoButtonColor = true
	destroyButton.AutoButtonColor = true
	fuseButton.AutoButtonColor = (petData.Variant ~= "Golden" and normalCopies >= 3)
	fuseButton.BackgroundTransparency = fuseButton.AutoButtonColor and 0 or 0.55
end

local function clearInventory()
	for _, child in ipairs(inventoryFrame:GetChildren()) do
		if child ~= gridLayout and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function refreshInventory()
	if gridLayout.Parent ~= inventoryFrame then
		gridLayout.Parent = inventoryFrame
	end
	clearInventory()
	local equippedSet = getEquippedSet()
	local inventory = currentPets.Inventory or {}
	local equippedCount = #(currentPets.Equipped or {})
	storageLabel.Text = "Storage " .. tostring(#inventory) .. "/" .. tostring(currentPets.MaxStorage or 30)
	equippedLabel.Text = equippedCount > 0 and ("Equipped " .. tostring(equippedCount) .. "/" .. tostring(currentPets.MaxEquipped or 3)) or "No pet equipped"

	if #inventory == 0 then
		gridLayout.Parent = nil
		local emptyFrame = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, inventoryFrame)

		local emptyTitle = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromScale(0.5, 0.43),
			Size = UDim2.new(1, -32, 0, 34),
			Text = "You do not have any pets yet.",
			TextColor3 = Color3.fromRGB(221, 232, 236),
			TextScaled = true,
		}, emptyFrame)
		new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }, emptyTitle)

		local emptyHint = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.new(1, -40, 0, 26),
			Text = "Open an egg to get one.",
			TextColor3 = Color3.fromRGB(162, 178, 186),
			TextScaled = true,
		}, emptyFrame)
		new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, emptyHint)

		refreshDetails()
		return
	end

	for index, petData in ipairs(inventory) do
		local config = getPetConfig(petData.PetId)
		local rarityColor = config and getRarityColor(config.Rarity) or Color3.fromRGB(255, 255, 255)
		local selected = petData.Uid == selectedPetUid
		local equipped = equippedSet[petData.Uid] == true
		local card = new("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = selected and Color3.fromRGB(43, 52, 58) or Color3.fromRGB(29, 36, 42),
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Text = "",
		}, inventoryFrame)
		new("UICorner", { CornerRadius = UDim.new(0, 15) }, card)
		new("UIStroke", {
			Color = petData.Variant == "Golden" and Color3.fromRGB(255, 210, 60) or rarityColor,
			Thickness = selected and 2.4 or (equipped and 2 or 1.2),
			Transparency = selected and 0 or 0.28,
		}, card)

		local swatch = new("Frame", {
			BackgroundColor3 = petData.Variant == "Golden" and Color3.fromRGB(255, 210, 60) or rarityColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(42, 42),
		}, card)
		new("UICorner", { CornerRadius = UDim.new(0, 12) }, swatch)

		local name = new("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(62, 10),
			Size = UDim2.new(1, -72, 0, 42),
			Text = getPetDisplayName(petData),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
		new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8 }, name)

		local meta = new("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(12, 66),
			Size = UDim2.new(1, -24, 0, 24),
			Text = (config and config.Rarity or "Unknown") .. (equipped and " | Equipped" or ""),
			TextColor3 = rarityColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
		new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 8 }, meta)

		card.Activated:Connect(function()
			selectedPetUid = petData.Uid
			refreshInventory()
		end)
	end

	refreshDetails()
end

local function refreshEggOverlay()
	if not eggOverlayGui then
		return
	end

	local listFrame = eggOverlayGui:FindFirstChild("List", true)
	if not listFrame then
		return
	end

	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local eggConfig = GameData.GetEgg(STARTER_EGG_ID)
	if not eggConfig then
		return
	end

	for index, petConfig in ipairs(eggConfig.Pets) do
		local discovered = currentPets.Discovered and currentPets.Discovered[petConfig.PetId] == true
		local color = discovered and getRarityColor(petConfig.Rarity) or Color3.fromRGB(95, 101, 106)
		local row = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(18, 22, 26),
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 24),
		}, listFrame)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, row)

		local dot = new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 7),
			Size = UDim2.fromOffset(10, 10),
		}, row)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)

		local label = new("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(24, 2),
			Size = UDim2.new(1, -72, 1, -4),
			Text = discovered and petConfig.Name or "???",
			TextColor3 = discovered and Color3.fromRGB(240, 246, 248) or Color3.fromRGB(145, 153, 158),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 7 }, label)

		local chance = new("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(1, -46, 2 / 24, 0),
			Size = UDim2.fromOffset(38, 20),
			Text = tostring(petConfig.Chance) .. "%",
			TextColor3 = color,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)
		new("UITextSizeConstraint", { MaxTextSize = 11, MinTextSize = 7 }, chance)
	end
end

local function refreshAll()
	refreshInventory()
	refreshEggOverlay()
end

local openTween = nil
local function openInventory()
	if openTween then
		openTween:Cancel()
	end
	overlay.Visible = true
	panelScale.Scale = 0.88
	refreshAll()
	openTween = TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	openTween:Play()
end

local function closeInventory()
	if openTween then
		openTween:Cancel()
	end
	local tween = TweenService:Create(panelScale, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.9 })
	tween:Play()
	tween.Completed:Connect(function()
		overlay.Visible = false
	end)
end

local function handlePetAction(response, successMessage)
	if response.Pets then
		setPetsSnapshot(response.Pets)
	end
	if response.Success or response.Ok then
		showMessage(successMessage or "OK", Color3.fromRGB(136, 255, 164))
	else
		local reason = response.Error or response.Reason
		showMessage(getErrorMessage(reason), Color3.fromRGB(255, 177, 137))
		if SoundUtil then
			SoundUtil.Play("Error", GameData, playerGui)
		end
	end
	refreshAll()
end

local destroyConfirmTween = nil
local pendingDestroyPetUid = nil

local function closeDestroyConfirmation()
	if destroyConfirmTween then
		destroyConfirmTween:Cancel()
	end

	pendingDestroyPetUid = nil
	local tween = TweenService:Create(destroyConfirmScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.9 })
	destroyConfirmTween = tween
	tween:Play()
	tween.Completed:Connect(function()
		if destroyConfirmTween == tween then
			destroyConfirmOverlay.Visible = false
			destroyConfirmTween = nil
		end
	end)
end

local function openDestroyConfirmation(petData)
	if not petData then
		return
	end

	pendingDestroyPetUid = petData.Uid
	destroyConfirmText.Text = getPetDisplayName(petData) .. " will be permanently deleted."
	destroyConfirmOverlay.Visible = true
	destroyConfirmScale.Scale = 0.9

	if destroyConfirmTween then
		destroyConfirmTween:Cancel()
	end
	destroyConfirmTween = TweenService:Create(destroyConfirmScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	destroyConfirmTween:Play()
end

equipButton.Activated:Connect(function()
	local petData = selectedPetUid and getPetByUid(selectedPetUid)
	if not petData then
		return
	end
	local equipped = getEquippedSet()[petData.Uid] == true
	local response = invokePetRemote(equipped and unequipPetRemote or equipPetRemote, petData.Uid)
	handlePetAction(response, equipped and "Pet unequipped." or "Pet equipped.")
end)

destroyButton.Activated:Connect(function()
	local petData = selectedPetUid and getPetByUid(selectedPetUid)
	if not petData then
		return
	end

	if getEquippedSet()[petData.Uid] then
		showMessage("Unequip this pet before destroying it.", Color3.fromRGB(255, 177, 137))
		if SoundUtil then
			SoundUtil.Play("Error", GameData, playerGui)
		end
		return
	end

	openDestroyConfirmation(petData)
end)

destroyCancelButton.Activated:Connect(closeDestroyConfirmation)

destroyConfirmButton.Activated:Connect(function()
	local petUid = pendingDestroyPetUid
	local petData = petUid and getPetByUid(petUid)
	if not petData then
		closeDestroyConfirmation()
		return
	end

	if getEquippedSet()[petUid] then
		closeDestroyConfirmation()
		showMessage("Unequip this pet before destroying it.", Color3.fromRGB(255, 177, 137))
		if SoundUtil then
			SoundUtil.Play("Error", GameData, playerGui)
		end
		return
	end

	closeDestroyConfirmation()
	local response = invokePetRemote(destroyPetRemote, petUid)
	handlePetAction(response, "Pet destroyed.")
end)

fuseButton.Activated:Connect(function()
	local petData = selectedPetUid and getPetByUid(selectedPetUid)
	if not petData then
		return
	end
	local response = invokePetRemote(fusePetRemote, petData.Uid)
	handlePetAction(response, "Fusion successful.")
end)

inventoryButton.Activated:Connect(function()
	if overlay.Visible then
		closeInventory()
	else
		openInventory()
	end
end)
closeButton.Activated:Connect(closeInventory)

local hatchGui = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(6, 8, 11),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 20,
}, gui)
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 20, 25)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 8, 11)),
	}),
	Rotation = 90,
}, hatchGui)

local hatchEgg = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(255, 226, 112),
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(120, 150),
	ZIndex = 21,
}, hatchGui)
new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, hatchEgg)

local hatchReveal = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromScale(0.5, 0.62),
	Size = UDim2.fromOffset(420, 90),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextWrapped = true,
	ZIndex = 21,
}, hatchGui)
new("UITextSizeConstraint", { MaxTextSize = 34, MinTextSize = 14 }, hatchReveal)

local function playHatchAnimation(response)
	local petData = response.Pet
	local petConfig = response.PetConfig or (petData and getPetConfig(petData.PetId))
	local rarityColor = petConfig and getRarityColor(petConfig.Rarity) or Color3.fromRGB(255, 255, 255)
	hatchGui.Visible = true
	hatchReveal.Text = ""
	hatchEgg.BackgroundColor3 = Color3.fromRGB(255, 226, 112)
	hatchEgg.Size = UDim2.fromOffset(120, 150)
	hatchEgg.Rotation = 0

	for index = 1, 6 do
		local rotation = index % 2 == 0 and 12 or -12
		local tween = TweenService:Create(hatchEgg, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Rotation = rotation,
		})
		tween:Play()
		tween.Completed:Wait()
	end

	local flash = TweenService:Create(hatchEgg, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Rotation = 0,
		Size = UDim2.fromOffset(180, 210),
		BackgroundColor3 = rarityColor,
	})
	flash:Play()
	flash.Completed:Wait()

	hatchReveal.TextColor3 = rarityColor
	hatchReveal.Text = "New Pet\n" .. (petData and getPetDisplayName(petData) or (petConfig and petConfig.Name) or "Pet")
	task.wait(1.35)
	hatchGui.Visible = false
end

local hatching = false
local function requestHatch()
	if hatching then
		return
	end
	hatching = true
	if hatchInProgress then
				return
			end
			hatchInProgress = true
			prompt.Enabled = false
			local response = invokePetRemote(hatchEggRemote, STARTER_EGG_ID)
	hatching = false
	if response.Success or response.Ok then
		if SoundUtil then
			SoundUtil.Play("Coin", GameData, playerGui)
		end
		task.spawn(playHatchAnimation, response)
	else
		local reason = response.Error or response.Reason
		showMessage(getErrorMessage(reason), Color3.fromRGB(255, 177, 137))
		if SoundUtil then
			SoundUtil.Play("Error", GameData, playerGui)
		end
	end
	refreshAll()
end

local function getHatcherPart(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end

	local main = instance:FindFirstChild("Main", true)
	if main then
		if main:IsA("BasePart") then
			return main
		end
		for _, descendant in ipairs(main:GetDescendants()) do
			if descendant:IsA("BasePart") then
				return descendant
			end
		end
	end

	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function findEggHatcher()
	local plaza = Workspace:FindFirstChild("EggPlaza")
	local hatcher = plaza and plaza:FindFirstChild("EggHatcher", true)
	return hatcher or Workspace:FindFirstChild("EggHatcher", true)
end

local function createEggOverlay(part)
	if eggOverlayGui then
		eggOverlayGui:Destroy()
	end

	local eggConfig = GameData.GetEgg(STARTER_EGG_ID)
	eggOverlayGui = new("BillboardGui", {
		Name = "GEIEggOverlay",
		Adornee = part,
		AlwaysOnTop = true,
		Enabled = false,
		MaxDistance = 120,
		Size = UDim2.fromOffset(250, 238),
		StudsOffset = Vector3.new(0, 6, 0),
	}, part)

	local frame = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(18, 22, 26),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, eggOverlayGui)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, frame)
	new("UIStroke", { Color = Color3.fromRGB(255, 226, 112), Thickness = 1.5, Transparency = 0.2 }, frame)

	local header = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 28),
		Text = eggConfig and eggConfig.DisplayName or "Starter Egg",
		TextColor3 = Color3.fromRGB(255, 226, 112),
		TextScaled = true,
	}, frame)
	new("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 10 }, header)

	local priceCurrency = eggConfig and (eggConfig.Currency or "Cash") or "Cash"
	local priceIconId = UIIconUtils and UIIconUtils.GetCurrencyIcon(priceCurrency)
	local hasPriceIcon = eggConfig ~= nil and priceIconId ~= nil and priceIconId ~= ""
	local priceIcon = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "",
		Position = UDim2.fromOffset(12, 42),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(16, 16),
		Visible = false,
	}, frame)
	if hasPriceIcon then
		priceIcon.Image = priceIconId
		priceIcon.Visible = true
	end

	local price = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = hasPriceIcon and UDim2.fromOffset(34, 38) or UDim2.fromOffset(12, 38),
		Size = hasPriceIcon and UDim2.new(1, -46, 0, 22) or UDim2.new(1, -24, 0, 22),
		Text = eggConfig and ("Price: " .. formatNumber(eggConfig.Price) .. " " .. priceCurrency) or "Unavailable",
		TextColor3 = Color3.fromRGB(180, 238, 184),
		TextScaled = true,
	}, frame)
	new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, price)

	local listFrame = new("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -24, 1, -80),
	}, frame)
	new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
	refreshEggOverlay()
end

local function setupEggHatcher()
	local hatcher = findEggHatcher()
	local hatcherPart = getHatcherPart(hatcher)
	if not hatcherPart then
		if not eggWarningShown then
			eggWarningShown = true
			warn("[PetClient] Missing Workspace.EggPlaza.EggHatcher. Create EggPlaza > EggHatcher to enable map hatching.")
		end
		return
	end

	currentHatcherPart = hatcherPart
	createEggOverlay(hatcherPart)
	local prompt = hatcherPart:FindFirstChild("GEIEggPrompt")
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GEIEggPrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = hatcherPart
	end
	prompt.ActionText = "Open"
	prompt.ObjectText = "Starter Egg"
	if not eggPromptConnected then
		eggPromptConnected = true
		prompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer == nil or triggeringPlayer == player then
				requestHatch()
			end
		end)
	end
end

local function setFollowerPartProperties(instance, golden)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.Massless = true
		if golden then
			instance.Color = Color3.fromRGB(255, 210, 60)
		end
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			if golden then
				descendant.Color = Color3.fromRGB(255, 210, 60)
			end
		end
	end
end

local function getPetModelSource(petData)
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	if not folder then
		return nil
	end
	local goldenName = "Golden" .. petData.PetId
	if petData.Variant == "Golden" and folder:FindFirstChild(goldenName) then
		return folder:FindFirstChild(goldenName), false
	end
	return folder:FindFirstChild(petData.PetId), petData.Variant == "Golden"
end

local function createFallbackPetVisual(petData)
	local config = getPetConfig(petData.PetId)
	local model = Instance.new("Model")
	model.Name = "PetFollower_" .. petData.Uid
	local part = Instance.new("Part")
	part.Name = "Main"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Material = Enum.Material.SmoothPlastic
	part.Color = petData.Variant == "Golden" and Color3.fromRGB(255, 210, 60) or (config and getRarityColor(config.Rarity) or Color3.fromRGB(180, 190, 195))
	part.Parent = model
	model.PrimaryPart = part
	return model
end

local function clonePetVisual(petData)
	local source, forceGoldenColor = getPetModelSource(petData)
	local visual
	if source then
		if source:IsA("Model") then
			visual = source:Clone()
		elseif source:IsA("Folder") then
			visual = Instance.new("Model")
			local sourceClone = source:Clone()
			for _, child in ipairs(sourceClone:GetChildren()) do
				child.Parent = visual
			end
			sourceClone:Destroy()
		elseif source:IsA("BasePart") then
			visual = Instance.new("Model")
			local partClone = source:Clone()
			partClone.Parent = visual
		end
	end

	if not visual then
		visual = createFallbackPetVisual(petData)
	end

	visual.Name = "PetFollower_" .. petData.Uid
	setFollowerPartProperties(visual, forceGoldenColor == true)
	local main = visual:FindFirstChild("Main", true)
	if main and main:IsA("BasePart") then
		visual.PrimaryPart = main
	elseif not visual.PrimaryPart then
		for _, descendant in ipairs(visual:GetDescendants()) do
			if descendant:IsA("BasePart") then
				visual.PrimaryPart = descendant
				break
			end
		end
	end
	visual.Parent = Workspace
	return visual
end

local function clearFollowers()
	for _, visual in pairs(followerModels) do
		if visual and visual.Parent then
			visual:Destroy()
		end
	end
	followerModels = {}
end

local function rebuildFollowers()
	clearFollowers()
	local equippedSet = getEquippedSet()
	for _, petData in ipairs(currentPets.Inventory or {}) do
		if equippedSet[petData.Uid] then
			followerModels[petData.Uid] = clonePetVisual(petData)
		end
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		if eggOverlayGui then
			eggOverlayGui.Enabled = false
		end
		return
	end

	if eggOverlayGui and currentHatcherPart and currentHatcherPart.Parent then
		local distance = (root.Position - currentHatcherPart.Position).Magnitude
		eggOverlayGui.Enabled = distance <= 18
	end

	local equippedSet = getEquippedSet()
	local petIndex = 0
	for _, petData in ipairs(currentPets.Inventory or {}) do
		local visual = followerModels[petData.Uid]
		if equippedSet[petData.Uid] and visual and visual.PrimaryPart then
			petIndex += 1
			local offset = FOLLOW_OFFSETS[petIndex] or Vector3.new(0, 2, 4 + petIndex)
			local bob = math.sin(os.clock() * 3 + petIndex) * 0.18
			local target = root.CFrame * CFrame.new(offset + Vector3.new(0, bob, 0))
			local current = visual:GetPivot()
			visual:PivotTo(current:Lerp(target, math.clamp(deltaTime * 8, 0, 1)))
		end
	end
end)

petInventoryUpdatedRemote.OnClientEvent:Connect(function(snapshot)
	setPetsSnapshot(snapshot)
	refreshAll()
	rebuildFollowers()
end)

if playerDataRemote then
	playerDataRemote.OnClientEvent:Connect(function(snapshot)
		if type(snapshot) == "table" and type(snapshot.Pets) == "table" then
			setPetsSnapshot(snapshot.Pets)
			refreshAll()
			rebuildFollowers()
		end
	end)
end

player.CharacterAdded:Connect(function()
	task.wait(0.25)
	rebuildFollowers()
end)

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "EggPlaza" or descendant.Name == "EggHatcher" or descendant.Name == "Main" then
		task.defer(setupEggHatcher)
	end
end)

local petErrorRemote = remotes:WaitForChild("PetError", 20)
if petErrorRemote then
	petErrorRemote.OnClientEvent:Connect(function(reason, snapshot)
		if snapshot then
			setPetsSnapshot(snapshot)
		end
		showMessage(getErrorMessage(reason), Color3.fromRGB(255, 177, 137))
		refreshAll()
	end)
end

setupEggHatcher()
refreshAll()
