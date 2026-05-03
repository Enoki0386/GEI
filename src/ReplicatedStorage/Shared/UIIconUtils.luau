local AssetIds = require(script.Parent:WaitForChild("AssetIds"))

local UIIconUtils = {}

local CURRENCY_ALIASES = {
	Cash = "Coin",
	Coin = "Coin",
	Coins = "Coin",
	Diamond = "Diamond",
	Diamonds = "Diamond",
	Trash = "Waste",
	Waste = "Waste",
}

local function isUsableImageId(imageId)
	return type(imageId) == "string"
		and imageId ~= ""
		and imageId ~= "0"
		and imageId ~= "rbxassetid://0"
end

local function canApplyImage(instance)
	return instance and (instance:IsA("ImageLabel") or instance:IsA("ImageButton"))
end

function UIIconUtils.GetIcon(iconName)
	if type(iconName) ~= "string" then
		return ""
	end

	local imageId = AssetIds.Icons and AssetIds.Icons[iconName]
	if isUsableImageId(imageId) then
		return imageId
	end

	return ""
end

function UIIconUtils.GetCurrencyIcon(currencyName)
	if type(currencyName) ~= "string" then
		return ""
	end

	local iconName = CURRENCY_ALIASES[currencyName] or currencyName
	return UIIconUtils.GetIcon(iconName)
end

function UIIconUtils.ApplyIcon(imageLabel, iconName)
	if not canApplyImage(imageLabel) then
		return false
	end

	local imageId = UIIconUtils.GetIcon(iconName)
	if imageId ~= "" then
		imageLabel.Image = imageId
		imageLabel.Visible = true
		return true
	end

	imageLabel.Image = ""
	imageLabel.Visible = false
	return false
end

function UIIconUtils.ApplyCurrencyIcon(imageLabel, currencyName)
	if not canApplyImage(imageLabel) then
		return false
	end

	local imageId = UIIconUtils.GetCurrencyIcon(currencyName)
	if imageId ~= "" then
		imageLabel.Image = imageId
		imageLabel.Visible = true
		return true
	end

	imageLabel.Image = ""
	imageLabel.Visible = false
	return false
end

return UIIconUtils
