from pathlib import Path
import re

ROOT = Path('.')

def read(path):
    return path.read_text(encoding='utf-8')

def write(path, text):
    path.write_text(text, encoding='utf-8')
    print(f'UPDATED {path}')

def replace_between(text, start_marker, end_marker, replacement, label):
    start = text.find(start_marker)
    if start == -1:
        print(f'{label}: START NOT FOUND')
        return text
    end = text.find(end_marker, start)
    if end == -1:
        print(f'{label}: END NOT FOUND')
        return text
    print(f'{label}: OK')
    return text[:start] + replacement + text[end:]

# 1) WasteNodeManager: make WasteZone/SpawnSurface lookup robust and self-healing
waste_path = ROOT / 'src/ServerScriptService/Systems/WasteNodeManager.server.luau'
if waste_path.exists():
    text = read(waste_path)
    new_block = r'''local function getMainBasePart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	local main = instance:FindFirstChild("Main", true)
	if main and main:IsA("BasePart") then
		return main
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

local function getOrCreateSpawnSurface()
	local folder = Workspace:FindFirstChild("SpawnSurfaces")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpawnSurfaces"
		folder.Parent = Workspace
	end

	local surfaceName = GameData.Spawn.SurfaceName or "SpawnSurface1"
	local existing = folder:FindFirstChild(surfaceName)
	local existingPart = getMainBasePart(existing)
	if existingPart then
		return existingPart
	end

	local part = Instance.new("Part")
	part.Name = surfaceName
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
	part.Material = Enum.Material.Concrete
	part.Color = Color3.fromRGB(74, 84, 90)
	local worldConfig = GameData.World and GameData.World.SpawnSurface or {}
	part.Size = worldConfig.Size or Vector3.new(80, 1, 60)
	part.Position = worldConfig.Position or Vector3.new(0, 1, 20)
	part:SetAttribute("ZoneId", "Zone1")
	part.Parent = folder

	warnOnce("EmergencySpawnSurfaceCreated", "[WasteNodeManager] SpawnSurface1 was missing or invalid. Created an emergency Workspace.SpawnSurfaces.SpawnSurface1 so the game stays playable.")
	return part
end

local function getWasteZone()
	local wasteZone, path
	if WorkspaceUtil then
		wasteZone, path = WorkspaceUtil.Find(GameData.Spawn.WasteZoneName or "WasteZone", GameData.Spawn.WasteZoneFolders, { SearchDescendants = true })
	else
		wasteZone = Workspace:FindFirstChild(GameData.Spawn.WasteZoneName or "WasteZone", true)
		path = wasteZone and wasteZone:GetFullName() or "Workspace.WasteZone"
	end

	if wasteZone then
		return wasteZone
	end

	local folder = Workspace:FindFirstChild("WasteZone")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WasteZone"
		folder.Parent = Workspace
	end

	warnOnce("WasteZoneAutoCreated", "[WasteNodeManager] WasteZone was missing. Created Workspace.WasteZone automatically so wastes can spawn.")
	return folder
end

local function getSpawnSurface()
	local surface, path
	if WorkspaceUtil then
		surface, path = WorkspaceUtil.Find(GameData.Spawn.SurfaceName or "SpawnSurface1", GameData.Spawn.SurfaceFolders, { SearchDescendants = true })
	else
		surface = Workspace:FindFirstChild(GameData.Spawn.SurfaceName or "SpawnSurface1", true)
		path = surface and surface:GetFullName() or "Workspace.SpawnSurface1"
	end

	local surfacePart = getMainBasePart(surface)
	if surfacePart then
		if not surfacePart:GetAttribute("ZoneId") then
			surfacePart:SetAttribute("ZoneId", "Zone1")
		end
		return surfacePart
	end

	warnOnce("SpawnSurfaceAutoFallback", "[WasteNodeManager] " .. tostring(path or "SpawnSurface1") .. " is missing or has no BasePart. Using an emergency SpawnSurface1 fallback.")
	return getOrCreateSpawnSurface()
end

'''
    text = replace_between(text, 'local function getWasteZone()', 'local function fireClient', new_block, 'Patch WasteNodeManager zone/surface lookup')
    write(waste_path, text)
else:
    print('MISSING WasteNodeManager')

# 2) SpawnManager: do not get stuck if SpawnSurface1 is nested/model; use same robust lookup style.
spawn_path = ROOT / 'src/ServerScriptService/Systems/SpawnManager.server.luau'
if spawn_path.exists():
    text = read(spawn_path)
    new_block = r'''local function getMainBasePart(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	local main = instance:FindFirstChild("Main", true)
	if main and main:IsA("BasePart") then
		return main
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

local function waitForRequiredPart(name, recommendedSize)
	local warned = false

	while true do
		local found, path
		if WorkspaceUtil then
			found, path = WorkspaceUtil.Find(name, GameData.Spawn.SurfaceFolders, { SearchDescendants = true })
		else
			found = Workspace:FindFirstChild(name, true)
			path = found and found:GetFullName() or ("Workspace." .. name)
		end

		local part = getMainBasePart(found)
		if part then
			return part
		end

		if not warned then
			warn("[SpawnManager] Missing or invalid " .. tostring(path or name) .. ". WasteNodeManager can create an emergency fallback, but you should keep a BasePart named " .. name .. ". Recommended size: " .. tostring(recommendedSize.X) .. ", " .. tostring(recommendedSize.Y) .. ", " .. tostring(recommendedSize.Z) .. ".")
			warned = true
		end

		task.wait(5)
	end
end

'''
    text = replace_between(text, 'local function waitForRequiredPart', 'task.spawn(function()', new_block, 'Patch SpawnManager lookup')
    write(spawn_path, text)
else:
    print('MISSING SpawnManager')

# 3) Client optional dependencies: do not block HUD/Pet UI for 20 seconds waiting on optional modules.
optional_module_names = ["SoundUtil", "UIIconUtils", "NotificationClient", "NumberFormat"]
for folder in [ROOT / 'src/StarterPlayer/StarterPlayerScripts']:
    if folder.exists():
        for path in folder.rglob('*.luau'):
            text = read(path)
            original = text
            for name in optional_module_names:
                text = text.replace(f'sharedFolder:WaitForChild("{name}", 20)', f'sharedFolder:FindFirstChild("{name}")')
                text = text.replace(f'sharedFolder and sharedFolder:WaitForChild("{name}", 20)', f'sharedFolder and sharedFolder:FindFirstChild("{name}")')
            if text != original:
                write(path, text)

# 4) Add a server recovery guard. It creates only missing safe containers/fallbacks.
recovery_server = ROOT / 'src/ServerScriptService/Systems/RecoveryGuard.server.luau'
recovery_server.parent.mkdir(parents=True, exist_ok=True)
recovery_server.write_text(r'''local Workspace = game:GetService("Workspace")

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
''', encoding='utf-8')
print(f'ADDED {recovery_server}')

# 5) Add a tiny fallback HUD that appears only if MainHUD failed completely.
fallback_hud = ROOT / 'src/StarterPlayer/StarterPlayerScripts/HudRecovery.client.luau'
fallback_hud.parent.mkdir(parents=True, exist_ok=True)
fallback_hud.write_text(r'''local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

task.delay(6, function()
	local mainHud = playerGui:FindFirstChild("MainHUD")
	if mainHud and mainHud:FindFirstChild("TopStats") then
		return
	end

	local existing = playerGui:FindFirstChild("GEIFallbackHUD")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "GEIFallbackHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "FallbackStats"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 10)
	frame.Size = UDim2.fromOffset(470, 42)
	frame.BackgroundColor3 = Color3.fromRGB(18, 23, 28)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Parent = frame

	local function readValue(folder, name, fallback)
		local value = folder and folder:FindFirstChild(name)
		return value and value.Value or fallback
	end

	local function refresh()
		local leaderstats = player:FindFirstChild("leaderstats")
		local data = player:FindFirstChild("PlayerData")
		local cash = readValue(leaderstats, "Cash", 0)
		local diamonds = readValue(leaderstats, "Diamonds", 0)
		local waste = readValue(data, "WasteCount", 0)
		local maxWaste = readValue(data, "MaxWaste", 0)
		label.Text = "Cash " .. tostring(cash) .. "   |   Waste " .. tostring(waste) .. "/" .. tostring(maxWaste) .. "   |   Diamonds " .. tostring(diamonds)
	end

	refresh()
	while gui.Parent do
		refresh()
		task.wait(0.25)
	end
end)
''', encoding='utf-8')
print(f'ADDED {fallback_hud}')

print('Recovery patch applied. Now run: git diff --check && git status')
