local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local gameDataModule = ReplicatedStorage:WaitForChild("GameData", 20)
if not gameDataModule then
	warn("[PetClient] Missing ReplicatedStorage.GameData. Pet UI disabled.")
	return
end

local GameData = require(gameDataModule)
local soundUtilModule = ReplicatedStorage:WaitForChild("Shared", 20)
	and ReplicatedStorage.Shared:WaitForChild("SoundUtil", 20)
local SoundUtil = soundUtilModule and require(soundUtilModule)
local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
if not remotes then
	warn("[PetClient] Missing ReplicatedStorage.Remotes. Pet UI disabled.")
	return
end

local hatchEggRemote = remotes:WaitForChild("HatchEgg", 20)
local equipPetRemote = remotes:WaitForChild("EquipPet", 20)
local unequipPetRemote = remotes:WaitForChild("UnequipPet", 20)
local petInventoryUpdatedRemote = remotes:WaitForChild("PetInventoryUpdated", 20)
local playerDataRemote = remotes:WaitForChild("PlayerDataUpdate", 20)
local playerGui = player:WaitForChild("PlayerGui", 20)

if not hatchEggRemote or not equipPetRemote or not unequipPetRemote or not petInventoryUpdatedRemote or not playerGui then
	warn("[PetClient] Required pet remotes or PlayerGui are missing. Pet UI disabled.")
	return
end

local STARTER_EGG_ID = "StarterEgg"
local currentPets = {
	Inventory = {},
	Equipped = {},
	MaxEquipped = (GameData.Pets and GameData.Pets.MaxEquipped) or 3,
	Buffs = GameData.Pets and GameData.Pets.DefaultBuffs or {
		CashMultiplier = 1,
		DamageMultiplier = 1,
		BackpackMultiplier = 1,
	},
}

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
	value = tonumber(value) or 1
	return string.format("x%.2f", value)
end

local function getEquippedSet()
	local result = {}
	for _, petUid in ipairs(currentPets.Equipped or {}) do
		result[petUid] = true
	end
	return result
end

local function getRarityColor(rarity)
	local colors = GameData.Pets and GameData.Pets.RarityColors or {}
	return colors[rarity] or Color3.fromRGB(255, 255, 255)
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

local openButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(28, 34, 39),
	BackgroundTransparency = 0.02,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(1, -22, 1, -122),
	Size = UDim2.fromOffset(86, 42),
	Text = "Eggs",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, openButton)
new("UIStroke", {
	Color = Color3.fromRGB(255, 210, 85),
	Thickness = 1.5,
	Transparency = 0.16,
}, openButton)
new("UITextSizeConstraint", {
	MaxTextSize = 17,
	MinTextSize = 9,
}, openButton)

local overlay = new("Frame", {
	Name = "Overlay",
	BackgroundColor3 = Color3.fromRGB(6, 9, 12),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
}, gui)

local panel = new("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(19, 24, 29),
	BackgroundTransparency = 0.02,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.74, 0.72),
}, overlay)
new("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
new("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 1,
	Transparency = 0.72,
}, panel)
new("UISizeConstraint", {
	MaxSize = Vector2.new(920, 580),
	MinSize = Vector2.new(620, 420),
}, panel)

local panelScale = new("UIScale", {
	Scale = 0.92,
}, panel)

local title = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(24, 18),
	Size = UDim2.new(1, -86, 0, 36),
	Text = "Pets & Eggs",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
new("UITextSizeConstraint", {
	MaxTextSize = 30,
	MinTextSize = 14,
}, title)

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
new("UITextSizeConstraint", {
	MaxTextSize = 18,
	MinTextSize = 10,
}, closeButton)

local eggPanel = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(27, 34, 40),
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(24, 74),
	Size = UDim2.new(0, 260, 1, -98),
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, eggPanel)

local eggConfig = GameData.GetEgg(STARTER_EGG_ID)
local eggTitle = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(18, 18),
	Size = UDim2.new(1, -36, 0, 34),
	Text = eggConfig and eggConfig.DisplayName or "Starter Egg",
	TextColor3 = Color3.fromRGB(255, 226, 112),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, eggPanel)
new("UITextSizeConstraint", {
	MaxTextSize = 24,
	MinTextSize = 12,
}, eggTitle)

local eggPrice = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(18, 58),
	Size = UDim2.new(1, -36, 0, 28),
	Text = eggConfig and (formatNumber(eggConfig.Price) .. " Cash") or "Unavailable",
	TextColor3 = Color3.fromRGB(174, 236, 177),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, eggPanel)
new("UITextSizeConstraint", {
	MaxTextSize = 16,
	MinTextSize = 9,
}, eggPrice)

local hatchButton = new("TextButton", {
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(67, 174, 101),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(18, 102),
	Size = UDim2.new(1, -36, 0, 44),
	Text = "Hatch",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
}, eggPanel)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, hatchButton)
new("UITextSizeConstraint", {
	MaxTextSize = 20,
	MinTextSize = 10,
}, hatchButton)

local hatchResult = new("TextLabel", {
	BackgroundColor3 = Color3.fromRGB(16, 20, 24),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(18, 164),
	Size = UDim2.new(1, -36, 0, 68),
	Text = "Open an egg to get a passive pet.",
	TextColor3 = Color3.fromRGB(220, 230, 235),
	TextScaled = true,
	TextWrapped = true,
}, eggPanel)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, hatchResult)
new("UITextSizeConstraint", {
	MaxTextSize = 15,
	MinTextSize = 8,
}, hatchResult)

local buffsLabel = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(18, 250),
	Size = UDim2.new(1, -36, 0, 86),
	Text = "",
	TextColor3 = Color3.fromRGB(204, 216, 222),
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, eggPanel)
new("UITextSizeConstraint", {
	MaxTextSize = 15,
	MinTextSize = 8,
}, buffsLabel)

local equippedLabel = new("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.new(0, 306, 0, 76),
	Size = UDim2.new(1, -330, 0, 30),
	Text = "Equipped 0/3",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
new("UITextSizeConstraint", {
	MaxTextSize = 20,
	MinTextSize = 10,
}, equippedLabel)

local inventoryFrame = new("ScrollingFrame", {
	Active = true,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	Position = UDim2.fromOffset(306, 116),
	ScrollBarImageColor3 = Color3.fromRGB(98, 112, 120),
	ScrollBarThickness = 5,
	Size = UDim2.new(1, -330, 1, -140),
}, panel)

local gridLayout = new("UIGridLayout", {
	CellPadding = UDim2.fromOffset(12, 12),
	CellSize = UDim2.fromOffset(170, 142),
	FillDirectionMaxCells = 3,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, inventoryFrame)

local function clearInventory()
	for _, child in ipairs(inventoryFrame:GetChildren()) do
		if child ~= gridLayout then
			child:Destroy()
		end
	end
end

local function setPetsSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end

	currentPets.Inventory = type(snapshot.Inventory) == "table" and snapshot.Inventory or {}
	currentPets.Equipped = type(snapshot.Equipped) == "table" and snapshot.Equipped or {}
	currentPets.MaxEquipped = type(snapshot.MaxEquipped) == "number" and snapshot.MaxEquipped or currentPets.MaxEquipped
	currentPets.Buffs = type(snapshot.Buffs) == "table" and snapshot.Buffs or currentPets.Buffs
end

local function refreshPets()
	clearInventory()
	local equippedSet = getEquippedSet()
	local equippedCount = #(currentPets.Equipped or {})
	local maxEquipped = currentPets.MaxEquipped or 3
	local buffs = currentPets.Buffs or {}

	equippedLabel.Text = "Equipped " .. tostring(equippedCount) .. "/" .. tostring(maxEquipped)
	buffsLabel.Text = "Total buffs\nCash " .. formatMultiplier(buffs.CashMultiplier)
		.. "\nDamage " .. formatMultiplier(buffs.DamageMultiplier)
		.. "\nBackpack " .. formatMultiplier(buffs.BackpackMultiplier)

	if #(currentPets.Inventory or {}) == 0 then
		local empty = new("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = "No pets yet.",
			TextColor3 = Color3.fromRGB(180, 194, 201),
			TextScaled = true,
		}, inventoryFrame)
		new("UITextSizeConstraint", {
			MaxTextSize = 18,
			MinTextSize = 10,
		}, empty)
		return
	end

	for index, petData in ipairs(currentPets.Inventory) do
		local petConfig = GameData.GetPet(petData.PetId)
		local rarityColor = petConfig and getRarityColor(petConfig.Rarity) or Color3.fromRGB(255, 255, 255)
		local equipped = equippedSet[petData.Uid] == true
		local card = new("Frame", {
			BackgroundColor3 = equipped and Color3.fromRGB(36, 48, 42) or Color3.fromRGB(30, 37, 43),
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, inventoryFrame)
		new("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
		new("UIStroke", {
			Color = rarityColor,
			Thickness = equipped and 2.2 or 1.2,
			Transparency = equipped and 0.05 or 0.34,
		}, card)

		local name = new("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(1, -24, 0, 32),
			Text = petConfig and petConfig.Name or petData.PetId,
			TextColor3 = rarityColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
		new("UITextSizeConstraint", {
			MaxTextSize = 17,
			MinTextSize = 9,
		}, name)

		local rarity = new("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(12, 42),
			Size = UDim2.new(1, -24, 0, 24),
			Text = petConfig and petConfig.Rarity or "Unknown",
			TextColor3 = Color3.fromRGB(205, 216, 222),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
		new("UITextSizeConstraint", {
			MaxTextSize = 13,
			MinTextSize = 8,
		}, rarity)

		local action = new("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = equipped and Color3.fromRGB(95, 103, 108) or Color3.fromRGB(75, 121, 219),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0, 12, 1, -42),
			Size = UDim2.new(1, -24, 0, 30),
			Text = equipped and "Unequip" or "Equip",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
		}, card)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, action)
		new("UITextSizeConstraint", {
			MaxTextSize = 14,
			MinTextSize = 8,
		}, action)

		action.Activated:Connect(function()
			local remote = equipped and unequipPetRemote or equipPetRemote
			local ok, response = pcall(function()
				return remote:InvokeServer(petData.Uid)
			end)

			if ok and type(response) == "table" then
				if response.Pets then
					setPetsSnapshot(response.Pets)
				end
				if not response.Ok and SoundUtil then
					SoundUtil.Play("Error", GameData, playerGui)
				end
				if response.Reason == "MaxEquipped" then
					hatchResult.Text = "You can only equip " .. tostring(maxEquipped) .. " pets."
					hatchResult.TextColor3 = Color3.fromRGB(255, 190, 135)
				end
				refreshPets()
			else
				warn("[PetClient] Pet equip request failed:", response)
			end
		end)
	end
end

local openTween = nil
local function openPets()
	if openTween then
		openTween:Cancel()
	end

	overlay.Visible = true
	panelScale.Scale = 0.88
	refreshPets()
	openTween = TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	openTween:Play()
end

local function closePets()
	if openTween then
		openTween:Cancel()
	end

	local tween = TweenService:Create(panelScale, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.9,
	})
	tween:Play()
	tween.Completed:Connect(function()
		overlay.Visible = false
	end)
end

local hatching = false
hatchButton.Activated:Connect(function()
	if hatching then
		return
	end

	hatching = true
	hatchButton.Text = "Hatching..."
	local ok, response = pcall(function()
		return hatchEggRemote:InvokeServer(STARTER_EGG_ID)
	end)
	hatchButton.Text = "Hatch"
	hatching = false

	if not ok or type(response) ~= "table" then
		warn("[PetClient] Hatch request failed:", response)
		hatchResult.Text = "Hatch failed."
		hatchResult.TextColor3 = Color3.fromRGB(255, 177, 137)
		if SoundUtil then
			SoundUtil.Play("Error", GameData, playerGui)
		end
		return
	end

	if response.Pets then
		setPetsSnapshot(response.Pets)
	end

	if response.Ok then
		local petConfig = response.PetConfig or (response.Pet and GameData.GetPet(response.Pet.PetId))
		local petName = petConfig and petConfig.Name or "a pet"
		local rarity = petConfig and petConfig.Rarity or "Common"
		hatchResult.Text = "Hatched " .. petName .. "!"
		hatchResult.TextColor3 = getRarityColor(rarity)
		if SoundUtil then
			SoundUtil.Play("Coin", GameData, playerGui)
		end
	else
		local message = "Could not hatch."
		if response.Reason == "NotEnoughCash" then
			message = "Not enough Cash."
		elseif response.Reason == "UnknownEgg" then
			message = "Egg is not configured."
		end
		hatchResult.Text = message
		hatchResult.TextColor3 = Color3.fromRGB(255, 177, 137)
		if SoundUtil then
			SoundUtil.Play("Error", GameData, playerGui)
		end
	end

	refreshPets()
end)

openButton.Activated:Connect(openPets)
closeButton.Activated:Connect(closePets)

petInventoryUpdatedRemote.OnClientEvent:Connect(function(snapshot)
	setPetsSnapshot(snapshot)
	refreshPets()
end)

if playerDataRemote then
	playerDataRemote.OnClientEvent:Connect(function(snapshot)
		if type(snapshot) == "table" and type(snapshot.Pets) == "table" then
			setPetsSnapshot(snapshot.Pets)
			refreshPets()
		end
	end)
end

local eggZoneWarned = false
local function setupEggZonePrompt(zone)
	if not zone then
		if not eggZoneWarned then
			eggZoneWarned = true
			warn("[PetClient] Optional Workspace.EggZone missing. You can still open Eggs from the UI button.")
		end
		return
	end

	if not zone:IsA("BasePart") then
		if not eggZoneWarned then
			eggZoneWarned = true
			warn("[PetClient] Workspace.EggZone exists but should be a BasePart for the egg prompt.")
		end
		return
	end

	local prompt = zone:FindFirstChild("GEIEggPrompt")
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GEIEggPrompt"
		prompt.ActionText = "Open Eggs"
		prompt.ObjectText = "Starter Egg"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = zone
	end

	prompt.Triggered:Connect(openPets)
end

setupEggZonePrompt(Workspace:FindFirstChild("EggZone"))
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "EggZone" then
		task.defer(setupEggZonePrompt, child)
	end
end)

refreshPets()
