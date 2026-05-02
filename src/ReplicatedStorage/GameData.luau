local GameData = {}

-- CONFIGURATION FACILE À MODIFIER

GameData.Spawn = {
	SurfaceName = "SpawnSurface1",
	WasteZoneName = "WasteZone",
	MaxWasteNodes = 18,
	SpawnInterval = 2.5,
	MinDistanceBetweenWaste = 8,
	MinDistanceFromPlayers = 12,
	MaxSpawnAttempts = 45,
	RingSegmentCount = 28,
	DefaultRingRadius = 8,
	MaxRingRadius = 16,
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
		Position = Vector3.new(0, 1.1, 20),
		Size = Vector3.new(80, 1, 60),
		Color = Color3.fromRGB(87, 136, 82),
	},
	SpawnLocation = {
		Position = Vector3.new(0, 3, -35),
	},
	SellZone = {
		Position = Vector3.new(-45, 2, -10),
		Size = Vector3.new(22, 1, 18),
		Color = Color3.fromRGB(88, 211, 117),
	},
	BuyZone = {
		Position = Vector3.new(45, 2, -10),
		Size = Vector3.new(22, 1, 18),
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
		Description = "Starter cleaner.",
	},
	Crusher = {
		Id = "Crusher",
		Name = "Crusher",
		Price = 250,
		Damage = 22,
		Range = 20,
		Cooldown = 0.5,
		Color = Color3.fromRGB(237, 103, 88),
		Description = "Breaks tougher piles faster.",
	},
	VacuumWand = {
		Id = "VacuumWand",
		Name = "Vacuum Wand",
		Price = 1200,
		Damage = 55,
		Range = 24,
		Cooldown = 0.42,
		Color = Color3.fromRGB(95, 211, 210),
		Description = "Longer range and high damage.",
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
		RingRadius = 7,
		VisualSize = Vector3.new(4, 2.4, 4),
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
		RingRadius = 9,
		VisualSize = Vector3.new(5, 3, 5),
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
		RingRadius = 11,
		VisualSize = Vector3.new(6, 3.6, 6),
	},
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
