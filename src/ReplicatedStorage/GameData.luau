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
	BackgroundTransparency = 0.35,
	HPBarHeight = 8,
	HitShakeDistance = 0.18,
	HitScaleAmount = 1.08,
	HitTweenTime = 0.08,
	RarityColors = {
		Common = Color3.fromRGB(80, 255, 120),
		Rare = Color3.fromRGB(80, 170, 255),
		Epic = Color3.fromRGB(190, 90, 255),
		Legendary = Color3.fromRGB(255, 210, 60),
	},
}

local DEFAULT_WASTE_MODEL_TUNING = {
	Version = 3,
	VisualOffset = Vector3.new(0, 0, 0),
	VisualRotation = Vector3.new(90, 0, 0),
	VisualScale = 1,
	RingOffset = Vector3.new(0, 0, 0),
	RingRadiusOffset = 0,
	BillboardOffset = Vector3.new(0, 4, 0),
}

GameData.WasteModelConfig = {
	Zone1 = {
		CommonWaste = {
			Default = {
				Version = 3,
				VisualOffset = Vector3.new(0, 0.382, 0),
				VisualRotation = Vector3.new(0, 0, 0),
				VisualScale = 1,
				RingOffset = Vector3.new(0, 4.812, 0),
				RingRadiusOffset = 0,
				BillboardOffset = Vector3.new(0, 4, 0),
			},
			TrashPile = {
				Version = 3,
				VisualOffset = Vector3.new(0, 0, 0),
				VisualRotation = Vector3.new(90, 0, 0),
				VisualScale = 1,
				RingOffset = Vector3.new(0, 0, 0),
				RingRadiusOffset = 0,
				BillboardOffset = Vector3.new(0, 4, 0),
			},
		},
		RareWaste = {
			Default = {
				Version = 3,
				VisualOffset = Vector3.new(0, 1.556, 0),
				VisualRotation = Vector3.new(0, 0, 0),
				VisualScale = 1,
				RingOffset = Vector3.new(0, 0.264, 0),
				RingRadiusOffset = 0,
				BillboardOffset = Vector3.new(0, 4, 0),
			},
			GarbageBags = {
				Version = 3,
				VisualOffset = Vector3.new(0, -0.25, 0),
				VisualRotation = Vector3.new(90, 0, 0),
				VisualScale = 1,
				RingOffset = Vector3.new(0, 0, 0),
				RingRadiusOffset = 0,
				BillboardOffset = Vector3.new(0, 4, 0),
			},
		},
		EpicWaste = {
			Default = {
				Version = 3,
				VisualOffset = Vector3.new(0, 1.588, 0),
				VisualRotation = Vector3.new(0, 0, 0),
				VisualScale = 1,
				RingOffset = Vector3.new(0, 0.020, 0),
				RingRadiusOffset = 0,
				BillboardOffset = Vector3.new(0, 4.5, 0),
			},
			Barrel = {
				Version = 3,
				VisualOffset = Vector3.new(0, -0.15, 0),
				VisualRotation = Vector3.new(90, 0, 0),
				VisualScale = 1,
				RingOffset = Vector3.new(0, 0, 0),
				RingRadiusOffset = 0,
				BillboardOffset = Vector3.new(0, 4.5, 0),
			},
		},
		LegendaryWaste = {
			Default = {
				Version = 3,
				VisualOffset = Vector3.new(0, 4, 0),
				VisualRotation = Vector3.new(0, 0, 0),
				VisualScale = 1,
				RingOffset = Vector3.new(0, 0.022, 0),
				RingRadiusOffset = 0.5,
				BillboardOffset = Vector3.new(0, 5.5, 0),
			},
			Boxes = {
				Version = 3,
				VisualOffset = Vector3.new(0, 2, 0),
				VisualRotation = Vector3.new(0, 0, 0),
				VisualScale = 1,
				RingOffset = Vector3.new(0, 3.945, 0),
				RingRadiusOffset = 0.5,
				BillboardOffset = Vector3.new(0, 5.5, 0),
			},
		},
	},
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
	Hit = "",
	Break = "",
	Sell = "",
	Error = "",
	Coin = "",
	Footstep = "",
	Jump = "",
}

GameData.Economy = {
	WasteCashValue = 1,
	SellCooldown = 1,
	StartingCash = 0,
	StartingDiamonds = 0,
}

GameData.Pets = {
	MaxEquipped = 3,
	DefaultBuffs = {
		CashMultiplier = 1,
		DamageMultiplier = 1,
		BackpackMultiplier = 1,
	},
	RarityColors = {
		Common = Color3.fromRGB(80, 255, 120),
		Rare = Color3.fromRGB(80, 170, 255),
		Epic = Color3.fromRGB(190, 90, 255),
		Legendary = Color3.fromRGB(255, 210, 60),
	},
}

GameData.Eggs = {
	StarterEgg = {
		Id = "StarterEgg",
		DisplayName = "Starter Egg",
		Price = 500,
		Currency = "Cash",
		Pets = {
			{
				PetId = "GarbageRat",
				Name = "Garbage Rat",
				Rarity = "Common",
				Chance = 50,
				Buffs = {
					CashMultiplier = 1.05,
				},
			},
			{
				PetId = "TrashCat",
				Name = "Trash Cat",
				Rarity = "Common",
				Chance = 30,
				Buffs = {
					BackpackMultiplier = 1.05,
				},
			},
			{
				PetId = "RecycleDog",
				Name = "Recycle Dog",
				Rarity = "Rare",
				Chance = 15,
				Buffs = {
					CashMultiplier = 1.10,
					DamageMultiplier = 1.05,
				},
			},
			{
				PetId = "ToxicSlime",
				Name = "Toxic Slime",
				Rarity = "Epic",
				Chance = 4,
				Buffs = {
					CashMultiplier = 1.20,
					DamageMultiplier = 1.10,
				},
			},
			{
				PetId = "GoldenRaccoon",
				Name = "Golden Raccoon",
				Rarity = "Legendary",
				Chance = 1,
				Buffs = {
					CashMultiplier = 1.35,
					DamageMultiplier = 1.20,
					BackpackMultiplier = 1.10,
				},
			},
		},
	},
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
	"Broom",
	"Vacuum",
	"Hammer",
	"Crusher",
}

GameData.ToolModelConfig = {
	Brush = {
		ModelName = "Brush",
		GripPosition = Vector3.new(0.55, -0.75, -0.35),
		GripRotation = Vector3.new(-70, 18, 12),
		VisualScale = 1,
	},
	Broom = {
		ModelName = "Broom",
		GripPosition = Vector3.new(0.6, -0.72, -0.36),
		GripRotation = Vector3.new(-68, 14, 10),
		VisualScale = 1,
	},
	Vacuum = {
		ModelName = "Vacuum",
		GripPosition = Vector3.new(0.58, -0.72, -0.36),
		GripRotation = Vector3.new(-72, 16, 12),
		VisualScale = 1,
	},
	Hammer = {
		ModelName = "Hammer",
		GripPosition = Vector3.new(0.62, -0.7, -0.34),
		GripRotation = Vector3.new(-66, 10, 8),
		VisualScale = 1,
	},
	Crusher = {
		ModelName = "Crusher",
		GripPosition = Vector3.new(0.6, -0.72, -0.36),
		GripRotation = Vector3.new(-68, 14, 10),
		VisualScale = 1,
	},
}

GameData.Tools = {
	Brush = {
		Id = "Brush",
		Name = "Brush",
		Price = 0,
		Damage = 8,
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
	Broom = {
		Id = "Broom",
		Name = "Broom",
		Price = 150,
		Damage = 16,
		Cooldown = 0.43,
		Color = Color3.fromRGB(98, 184, 126),
		Description = "A wider sweep for clearing early piles faster.",
		ModelName = "Broom",
		Visual = {
			HandleColor = Color3.fromRGB(130, 91, 56),
			BristleColor = Color3.fromRGB(98, 184, 126),
			GripOffset = CFrame.new(0.6, -0.72, -0.36) * CFrame.Angles(math.rad(-68), math.rad(14), math.rad(10)),
			SwingOffset = CFrame.new(0.12, -0.16, -0.58) * CFrame.Angles(math.rad(-38), math.rad(0), math.rad(-18)),
		},
	},
	Vacuum = {
		Id = "Vacuum",
		Name = "Vacuum",
		Price = 650,
		Damage = 34,
		Cooldown = 0.4,
		Color = Color3.fromRGB(95, 211, 210),
		Description = "A focused vacuum that pulls through tougher trash.",
		ModelName = "Vacuum",
		Visual = {
			HandleColor = Color3.fromRGB(55, 73, 92),
			BristleColor = Color3.fromRGB(95, 211, 210),
			GripOffset = CFrame.new(0.58, -0.72, -0.36) * CFrame.Angles(math.rad(-72), math.rad(16), math.rad(12)),
			SwingOffset = CFrame.new(0.1, -0.14, -0.65) * CFrame.Angles(math.rad(-30), math.rad(0), math.rad(-16)),
		},
	},
	Hammer = {
		Id = "Hammer",
		Name = "Hammer",
		Price = 1600,
		Damage = 70,
		Cooldown = 0.55,
		Color = Color3.fromRGB(247, 190, 80),
		Description = "A heavy hammer for smashing dense waste piles.",
		ModelName = "Hammer",
		Visual = {
			HandleColor = Color3.fromRGB(95, 98, 104),
			BristleColor = Color3.fromRGB(247, 190, 80),
			GripOffset = CFrame.new(0.62, -0.7, -0.34) * CFrame.Angles(math.rad(-66), math.rad(10), math.rad(8)),
			SwingOffset = CFrame.new(0.14, -0.18, -0.6) * CFrame.Angles(math.rad(-42), math.rad(0), math.rad(-20)),
		},
	},
	Crusher = {
		Id = "Crusher",
		Name = "Crusher",
		Price = 4200,
		Damage = 130,
		Cooldown = 0.5,
		Color = Color3.fromRGB(237, 103, 88),
		Description = "A powerful late-game cleaner for massive piles.",
		ModelName = "Crusher",
		Visual = {
			HandleColor = Color3.fromRGB(95, 98, 104),
			BristleColor = Color3.fromRGB(237, 103, 88),
			GripOffset = CFrame.new(0.6, -0.72, -0.36) * CFrame.Angles(math.rad(-68), math.rad(14), math.rad(10)),
			SwingOffset = CFrame.new(0.12, -0.16, -0.58) * CFrame.Angles(math.rad(-38), math.rad(0), math.rad(-18)),
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
	"LegendaryWaste",
}

GameData.WasteTypes = {
	CommonWaste = {
		Id = "CommonWaste",
		Name = "Common Waste",
		Rarity = "Common",
		RarityWeight = 72,
		HPRange = { 15, 30 },
		MaxHP = 30,
		WasteReward = 5,
		WasteRewardPerHP = 0.24,
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
		HPRange = { 60, 90 },
		MaxHP = 90,
		WasteReward = 18,
		WasteRewardPerHP = 0.25,
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
		RarityWeight = 4.5,
		HPRange = { 150, 230 },
		MaxHP = 230,
		WasteReward = 50,
		WasteRewardPerHP = 0.28,
		DiamondChance = 0.3,
		DiamondReward = 3,
		Color = Color3.fromRGB(145, 86, 211),
		AccentColor = Color3.fromRGB(222, 171, 255),
		VisualSize = Vector3.new(6, 3.6, 6),
		ModelName = "EpicWaste",
	},
	LegendaryWaste = {
		Id = "LegendaryWaste",
		Name = "Legendary Waste",
		Rarity = "Legendary",
		RarityWeight = 0.5,
		HPRange = { 400, 650 },
		MaxHP = 650,
		WasteReward = 120,
		WasteRewardPerHP = 0.32,
		DiamondChance = 0.55,
		DiamondReward = 8,
		Color = Color3.fromRGB(239, 177, 64),
		AccentColor = Color3.fromRGB(255, 236, 132),
		VisualSize = Vector3.new(7.5, 4.4, 7.5),
		ModelName = "LegendaryWaste",
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

function GameData.GetEgg(eggId)
	return GameData.Eggs[eggId]
end

function GameData.GetPet(petId)
	for _, eggConfig in pairs(GameData.Eggs) do
		for _, petConfig in ipairs(eggConfig.Pets) do
			if petConfig.PetId == petId then
				return petConfig
			end
		end
	end

	return nil
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
