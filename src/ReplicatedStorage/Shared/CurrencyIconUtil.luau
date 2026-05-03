local CurrencyIconUtil = {}

local CURRENCY_ALIASES = {
	Cash = "Coin",
	Coins = "Coin",
	Coin = "Coin",
	Diamond = "Diamond",
	Diamonds = "Diamond",
	Waste = "Waste",
}

local function isUsableImageId(imageId)
	return type(imageId) == "string"
		and imageId ~= ""
		and imageId ~= "0"
		and imageId ~= "rbxassetid://0"
end

function CurrencyIconUtil.GetCurrencyIcon(assetIds, currencyName)
	local icons = assetIds and assetIds.Icons
	if type(icons) ~= "table" or type(currencyName) ~= "string" then
		return nil
	end

	local iconName = CURRENCY_ALIASES[currencyName] or currencyName
	local imageId = icons[iconName]
	if isUsableImageId(imageId) then
		return imageId
	end

	return nil
end

function CurrencyIconUtil.ApplyToImage(imageLabel, assetIds, currencyName)
	if not imageLabel then
		return false
	end

	local imageId = CurrencyIconUtil.GetCurrencyIcon(assetIds, currencyName)
	if imageId then
		imageLabel.Image = imageId
		imageLabel.Visible = true
		return true
	end

	imageLabel.Image = ""
	imageLabel.Visible = false
	return false
end

return CurrencyIconUtil
