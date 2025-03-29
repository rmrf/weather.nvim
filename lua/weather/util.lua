local result = {}

-- Merges everything from `a` into `b`. subtables are merged too.
result.table_deep_merge = function(a, b)
	for k, v in pairs(a) do
		if type(v) == "table" and type(b[k]) == "table" then
			result.table_deep_merge(v, b[k])
		else
			b[k] = v
		end
	end
end

-- Check if string empty
result.is_empty = function(s)
	return s == nil or s == ""
end

return result
