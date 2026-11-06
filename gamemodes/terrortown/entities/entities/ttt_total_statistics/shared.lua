ENT.Type = "point"
ENT.Base = "base_point"

TotalStats = {}

local StringCapitalize = string.Capitalize
local StringLower = string.lower
local StringSub = string.sub

local function LowerFirst(str)
	return StringLower(StringSub(str, 1, 1)) .. StringSub(str, 2)
end

function TotalStats.GetRecordNames(name)
	local lower = LowerFirst(name)
	local upper = StringCapitalize(name)
	return upper, lower
end

function TotalStats.GetValue(record, name, default)
	if not default then default = 0 end
	local upper, lower = TotalStats.GetRecordNames(name)
	return record[upper] or record[lower] or default
end