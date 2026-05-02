local GameData = {}

-- CONFIGURATION FACILE À MODIFIER

-- DEBUG MODE: mettre Enabled = false avant publication
GameData.Debug = {
	Enabled = false,
	StartingCash = 5000,
	StartingDiamonds = 500,
	StartingWaste = 0,
	ToolDamageMultiplier = 1,
}

GameData.Spawn = {
	SurfaceName = "SpawnSurface1",
	WasteZoneName = "WasteZone",
	DensityPerStud = 0.003,
	MinNodes = 8,
	MaxNodes = 60,
	SpawnInterval = 2.5,
	MinDistanceBetweenWaste = 8,
	MinDistanceFromPlayers = 12,
	MaxSpawnAttempts = 45,
}

GameData.Player = {
	WalkSpeed = 22,
}

GameData.WasteDisplay = {
	BillboardMaxDistance = 45,
	BillboardSize = Vector2.new(180, 78),
	HPBarHeight = 8,
	HitShakeDistance = 0.18,
	HitScaleAmount = 1.08,
	HitTweenTime = 0.08,
}

GameData.Interaction = {
	ExtraRangeFromSurface = 2.5,
	MinRange = 3.5,
	MaxRange = 9,
}

GameData.InteractionCircle = {
	SegmentCount = 18,
	SegmentLengthRatio = 0.62,
	Thickness = 0.06,
	HeightOffset = 0.08,
	RotationSpeed = 12,
	InRangeScale = 1.03,
	DisplayDistance = 55,
	IdleTransparency = 0.45,
	InRangeTransparency = 0.1,
	Color = Color3.fromRGB(255, 238, 131),
	InRangeColor = Color3.fromRGB(125, 255, 159),
}

GameData.Animations = {
	BrushSwing = "rbxassetid://0", -- à remplacer plus tard
}

GameData.Sounds = {
	WasteHit = "",
	WasteBreak = "",
	Sell = "",
	Buy = "",
	Error = "",
	Footstep = "",
	Jump = "",
}

GameData.Economy = {
	WasteCashValue = 1,
	SellCooldown = 1,
	StartingCash = 0,
	StartingDiamonds = 0,
}

GameData.World = {
	LobbyFloor = {
		Position = Vector3.new(0, 0, 0),
		Size = Vector3.new(120, 2, 120),
		Color = Color3.fromRGB(112, 123, 118),
	},
	SpawnSurface = {
		Position = Vector3.new(0, 1, 20),
		Size = Vector3.new(80, 1, 60),
		Color = Color3.fromRGB(87, 136, 82),
	},
	SpawnLocation = {
		Position = Vector3.new(0, 3, -35),
	},
	SellZone = {
		Position = Vector3.new(-35, 1.5, -10),
		Size = Vector3.new(20, 1, 16),
		Color = Color3.fromRGB(88, 211, 117),
	},
	BuyZone = {
		Position = Vector3.new(35, 1.5, -10),
		Size = Vector3.new(20, 1, 16),
		Color = Color3.fromRGB(102, 138, 237),
	},
}

GameData.ToolOrder = {
	"Brush",
	"Crusher",
	"VacuumWand",
}

GameData.Tools = {
	Brush = {
		Id = "Brush",
		Name = "Brush",
		Price = 0,
		Damage = 8,
		Range = 18,
		Cooldown = 0.45,
		Color = Color3.fromRGB(245, 190, 86),
		Description = "A trusty starter brush for cleaning small piles.",
		ModelName = "Brush",
		Visual = {
			HandleColor = Color3.fromRGB(242, 178, 80),
			BristleColor = Color3.fromRGB(232, 239, 224),
			GripOffset = CFrame.new(0.55, -0.75, -0.35) * CFrame.Angles(math.rad(-70), math.rad(18), math.rad(12)),
			SwingOffset = CFrame.new(0.1, -0.15, -0.55) * CFrame.Angles(math.rad(-35), math.rad(0), math.rad(-18)),
		},
	},
	Crusher = {
		Id = "Crusher",
		Name = "Crusher",
		Price = 250,
		Damage = 22,
		Range = 20,
		Cooldown = 0.5,
		Color = Color3.fromRGB(237, 103, 88),
		Description = "A heavier cleaner that breaks tougher piles faster.",
		ModelName = "Crusher",
		Visual = {
			HandleColor = Color3.fromRGB(95, 98, 104),
			BristleColor = Color3.fromRGB(237, 103, 88),
			GripOffset = CFrame.new(0.6, -0.72, -0.36) * CFrame.Angles(math.rad(-68), math.rad(14), math.rad(10)),
			SwingOffset = CFrame.new(0.12, -0.16, -0.58) * CFrame.Angles(math.rad(-38), math.rad(0), math.rad(-18)),
		},
	},
	VacuumWand = {
		Id = "VacuumWand",
		Name = "Vacuum Wand",
		Price = 1200,
		Damage = 55,
		Range = 24,
		Cooldown = 0.42,
		Color = Color3.fromRGB(95, 211, 210),
		Description = "A focused cleanup wand with strong power.",
		ModelName = "VacuumWand",
		Visual = {
			HandleColor = Color3.fromRGB(55, 73, 92),
			BristleColor = Color3.fromRGB(95, 211, 210),
			GripOffset = CFrame.new(0.58, -0.72, -0.36) * CFrame.Angles(math.rad(-72), math.rad(16), math.rad(12)),
			SwingOffset = CFrame.new(0.1, -0.14, -0.65) * CFrame.Angles(math.rad(-30), math.rad(0), math.rad(-16)),
		},
	},
}

GameData.BackpackOrder = {
	"SmallBag",
	"MediumBag",
	"LargeBag",
}

GameData.Backpacks = {
	SmallBag = {
		Id = "SmallBag",
		Name = "Small Bag",
		Price = 0,
		Capacity = 50,
		Color = Color3.fromRGB(116, 85, 62),
		Size = Vector3.new(1.4, 1.6, 0.55),
		Description = "A simple starter bag.",
	},
	MediumBag = {
		Id = "MediumBag",
		Name = "Medium Bag",
		Price = 400,
		Capacity = 150,
		Color = Color3.fromRGB(64, 139, 190),
		Size = Vector3.new(1.7, 2.0, 0.65),
		Description = "More room before selling.",
	},
	LargeBag = {
		Id = "LargeBag",
		Name = "Large Bag",
		Price = 1800,
		Capacity = 500,
		Color = Color3.fromRGB(128, 88, 196),
		Size = Vector3.new(2.0, 2.35, 0.75),
		Description = "Built for longer cleanup runs.",
	},
}

GameData.WasteOrder = {
	"CommonWaste",
	"RareWaste",
	"EpicWaste",
}

GameData.WasteTypes = {
	CommonWaste = {
		Id = "CommonWaste",
		Name = "Common Waste",
		Rarity = "Common",
		RarityWeight = 72,
		MaxHP = 25,
		WasteReward = 5,
		DiamondChance = 0.03,
		DiamondReward = 1,
		Color = Color3.fromRGB(112, 156, 85),
		AccentColor = Color3.fromRGB(184, 229, 112),
		VisualSize = Vector3.new(4, 2.4, 4),
		ModelName = "CommonWaste",
	},
	RareWaste = {
		Id = "RareWaste",
		Name = "Rare Waste",
		Rarity = "Rare",
		RarityWeight = 23,
		MaxHP = 80,
		WasteReward = 18,
		DiamondChance = 0.12,
		DiamondReward = 1,
		Color = Color3.fromRGB(77, 142, 210),
		AccentColor = Color3.fromRGB(136, 205, 255),
		VisualSize = Vector3.new(5, 3, 5),
		ModelName = "RareWaste",
	},
	EpicWaste = {
		Id = "EpicWaste",
		Name = "Epic Waste",
		Rarity = "Epic",
		RarityWeight = 5,
		MaxHP = 200,
		WasteReward = 50,
		DiamondChance = 0.3,
		DiamondReward = 3,
		Color = Color3.fromRGB(145, 86, 211),
		AccentColor = Color3.fromRGB(222, 171, 255),
		VisualSize = Vector3.new(6, 3.6, 6),
		ModelName = "EpicWaste",
	},
}

GameData.FutureUnits = {
	Enabled = false,
	DisplayName = "Assistants",
	Slots = 3,
	Types = {},
}

function GameData.GetTool(toolId)
	return GameData.Tools[toolId]
end

function GameData.GetBackpack(backpackId)
	return GameData.Backpacks[backpackId]
end

function GameData.GetWasteType(wasteId)
	return GameData.WasteTypes[wasteId]
end

function GameData.GetCashForWaste(wasteAmount)
	return math.max(0, math.floor(wasteAmount * GameData.Economy.WasteCashValue))
end

function GameData.GetRandomWasteType(randomGenerator)
	local totalWeight = 0
	for _, wasteId in ipairs(GameData.WasteOrder) do
		totalWeight += GameData.WasteTypes[wasteId].RarityWeight
	end

	local roll = randomGenerator:NextNumber(0, totalWeight)
	local cursor = 0
	for _, wasteId in ipairs(GameData.WasteOrder) do
		local wasteConfig = GameData.WasteTypes[wasteId]
		cursor += wasteConfig.RarityWeight
		if roll <= cursor then
			return wasteId, wasteConfig
		end
	end

	local fallbackId = GameData.WasteOrder[1]
	return fallbackId, GameData.WasteTypes[fallbackId]
end

return GameData
