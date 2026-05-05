local Workspace = game:GetService("Workspace")

local function ensureFolder(name, parent)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function hasBasePart(instance)
	if not instance then
		return false
	end
	if instance:IsA("BasePart") then
		return true
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return true
		end
	end
	return false
end

local spawnSurfaces = ensureFolder("SpawnSurfaces", Workspace)
if not hasBasePart(spawnSurfaces:FindFirstChild("SpawnSurface1")) and not hasBasePart(Workspace:FindFirstChild("SpawnSurface1")) then
	local part = Instance.new("Part")
	part.Name = "SpawnSurface1"
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
	part.Material = Enum.Material.Concrete
	part.Color = Color3.fromRGB(74, 84, 90)
	part.Size = Vector3.new(80, 1, 60)
	part.Position = Vector3.new(0, 1, 20)
	part:SetAttribute("ZoneId", "Zone1")
	part.Parent = spawnSurfaces
	warn("[RecoveryGuard] Created emergency SpawnSurfaces/SpawnSurface1 fallback.")
end

if not Workspace:FindFirstChild("WasteZone") then
	ensureFolder("WasteZone", Workspace)
	warn("[RecoveryGuard] Created missing Workspace/WasteZone folder.")
end

ensureFolder("Barriers", Workspace)
ensureFolder("Areas", Workspace)
ensureFolder("MachineArea", Workspace)

print("[RecoveryGuard] Workspace safety checks completed.")
