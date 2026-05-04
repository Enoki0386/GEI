local Workspace = game:GetService("Workspace")

local WorkspaceUtil = {}

local warned = {}

local function splitPath(path)
	local result = {}
	for segment in string.gmatch(path, "[^/]+") do
		table.insert(result, segment)
	end
	return result
end

local function findFolder(path)
	local current = Workspace
	for _, segment in ipairs(splitPath(path)) do
		current = current and current:FindFirstChild(segment)
		if not current then
			return nil
		end
	end
	return current
end

function WorkspaceUtil.Find(name, folderPaths, options)
	options = type(options) == "table" and options or {}
	folderPaths = type(folderPaths) == "table" and folderPaths or {}

	for _, folderPath in ipairs(folderPaths) do
		local folder = findFolder(folderPath)
		local found = folder and folder:FindFirstChild(name)
		if found then
			return found, "Workspace." .. folderPath .. "." .. name
		end
	end

	local rootFound = Workspace:FindFirstChild(name)
	if rootFound then
		return rootFound, "Workspace." .. name
	end

	if options.SearchDescendants ~= false then
		local descendant = Workspace:FindFirstChild(name, true)
		if descendant then
			return descendant, descendant:GetFullName()
		end
	end

	return nil, "Workspace." .. name
end

function WorkspaceUtil.WarnOnce(key, message)
	if warned[key] then
		return
	end

	warned[key] = true
	warn(message)
end

return WorkspaceUtil
