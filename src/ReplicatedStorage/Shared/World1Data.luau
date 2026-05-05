local World1Data = {}

World1Data.Admin = {
	UserIds = {
		[1990396002] = true,
	},
}

World1Data.Zones = {
	Zone2 = {
		Id = "Zone2",
		DisplayName = "Zone 2",
		BarrierName = "Zone2Barrier",
		SpawnName = "SpawnSurface2",
		Cost = 5000,
		Currency = "Cash",
		Requires = nil,
	},
	Zone3 = {
		Id = "Zone3",
		DisplayName = "Zone 3",
		BarrierName = "Zone3Barrier",
		SpawnName = "SpawnSurface3",
		Cost = 25000,
		Currency = "Cash",
		Requires = "Zone2",
	},
	MachineZone = {
		Id = "MachineZone",
		DisplayName = "Machine Zone",
		BarrierName = "ZoneMachineBarrier",
		SpawnName = "MachinePlatform",
		Cost = 0,
		Currency = "Cash",
		Requires = "Zone3",
		LockedText = "Unlock Zone 3 first",
	},
	Zone4 = {
		Id = "Zone4",
		DisplayName = "Boss Zone",
		BarrierName = "Zone4Barrier",
		SpawnName = "SpawnSurface4",
		Cost = 100000,
		Currency = "Cash",
		Requires = "Zone3",
	},
	Portal = {
		Id = "Portal",
		DisplayName = "Portal",
		BarrierName = "Zone5Barrier",
		SpawnName = "PortalDimension2",
		Cost = 0,
		Currency = "Cash",
		Requires = "Zone4",
		RequiresBossDefeated = true,
		LockedText = "Defeat the Boss first",
	},
}

World1Data.Portal = {
	Name = "PortalDimension2",
	DisplayName = "World 2 Portal",
	RequiresZone = "Zone4",
	RequiresBossDefeated = true,
	LockedMessage = "Defeat Boss Waste to unlock World 2.",
}

World1Data.Machines = {
	Recycler = {
		DisplayName = "Recycler",
		ObjectName = "Recycler",
		InputWaste = 25,
		Duration = 5,
		CashReward = 85,
	},
	Crusher = {
		DisplayName = "Crusher",
		ObjectName = "Crusher",
		InputWaste = 70,
		Duration = 8,
		CashReward = 280,
		DiamondsReward = 1,
	},
	Compressor = {
		DisplayName = "Compressor",
		ObjectName = "Compressor",
		InputWaste = 160,
		Duration = 12,
		CashReward = 820,
		DiamondsReward = 2,
	},
	AutoSorter = {
		DisplayName = "Auto Sorter",
		ObjectName = "Sorter",
		InputWaste = 300,
		Duration = 18,
		CashReward = 1900,
		DiamondsReward = 4,
	},
}

World1Data.DiamondUpgrades = {
	Speed = {
		DisplayName = "Speed",
		MaxLevel = 10,
		BaseCost = 25,
		CostGrowth = 1.65,
		PerLevel = 1.5,
		Unit = "WalkSpeed",
	},
	Damage = {
		DisplayName = "Damage",
		MaxLevel = 10,
		BaseCost = 35,
		CostGrowth = 1.7,
		PerLevel = 0.10,
		Unit = "Multiplier",
	},
	MachineEfficiency = {
		DisplayName = "Machine Efficiency",
		MaxLevel = 10,
		BaseCost = 30,
		CostGrowth = 1.7,
		PerLevel = 0.12,
		Unit = "Multiplier",
	},
	PetBuff = {
		DisplayName = "Pet Buffs",
		MaxLevel = 8,
		BaseCost = 45,
		CostGrowth = 1.8,
		PerLevel = 0.05,
		Unit = "Multiplier",
	},
	DiamondChance = {
		DisplayName = "Diamond Chance",
		MaxLevel = 8,
		BaseCost = 40,
		CostGrowth = 1.75,
		PerLevel = 0.02,
		Unit = "Chance",
	},
}

World1Data.Boss = {
	AreaName = "BossWasteArea",
	BossName = "BossWaste",
	DisplayName = "Boss Waste",
	MaxHP = 3500,
	RespawnTime = 180,
	HitCooldown = 0.35,
	Rewards = {
		Cash = 12500,
		Diamonds = 75,
	},
}

World1Data.VIP = {
	ZoneName = "VIPZone",
	GamepassId = 0,
	BenefitsText = "+10% Cash, +1 Pet Storage later, VIP Egg later",
}

World1Data.Collection = {
	ButtonText = "Index",
}

function World1Data.IsAdmin(player)
	return player ~= nil and World1Data.Admin.UserIds[player.UserId] == true
end

function World1Data.GetUpgradeCost(upgradeId, currentLevel)
	local upgrade = World1Data.DiamondUpgrades[upgradeId]
	if not upgrade then
		return nil
	end
	return math.floor(upgrade.BaseCost * (upgrade.CostGrowth ^ math.max(0, currentLevel or 0)))
end

return World1Data
