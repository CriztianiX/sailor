--
-- The "constructor"
local init = function(escape)
	if not escape then
		error("Missing constructor arguments")
	end

	local interpolate_query = function(query, ...)
	    local values = { ... }
	    local i = 0
	    return (query:gsub("%?", function()
	        i = i + 1
	        if values[i] == nil then
	            error("missing replacement " .. tostring(i) .. " for interpolated query")
	        end
	        return escape(values[i])
	end))
	end

	return interpolate_query
end

return {
	init = init
}