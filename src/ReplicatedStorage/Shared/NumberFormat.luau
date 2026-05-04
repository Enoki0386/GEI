local NumberFormat = {}

local SUFFIXES = {
	"K",
	"M",
	"B",
	"T",
	"Qd",
	"Qn",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"QaD",
	"QnD",
	"SxD",
	"SpD",
	"OcD",
	"NoD",
}

local function trimDecimal(text)
	text = string.gsub(text, "%.0$", "")
	return text
end

function NumberFormat.Compact(value)
	local numberValue = tonumber(value) or 0
	if numberValue ~= numberValue then
		return "0"
	end

	local sign = numberValue < 0 and "-" or ""
	numberValue = math.abs(numberValue)

	if numberValue < 1000 then
		return sign .. tostring(math.floor(numberValue))
	end

	local tier = math.floor(math.log(numberValue) / math.log(1000))
	tier = math.clamp(tier, 1, #SUFFIXES)
	local scaled = numberValue / (1000 ^ tier)

	if scaled >= 999.5 and tier < #SUFFIXES then
		tier += 1
		scaled = numberValue / (1000 ^ tier)
	end

	local decimals = scaled < 10 and 1 or 0
	local formatted = trimDecimal(string.format("%." .. decimals .. "f", scaled))

	return sign .. formatted .. SUFFIXES[tier]
end

NumberFormat.Format = NumberFormat.Compact

return NumberFormat
