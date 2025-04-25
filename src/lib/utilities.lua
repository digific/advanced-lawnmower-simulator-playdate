local debugging = false

function isDebugging()
	return debugging
end

function setDebugging(value)
	debugging = (value == 1 or value == true)
end

function log(value)
	if debugging then
		print(value)
	end
end

function ternary(value, responseIfTrue, responseIfFalse)
	if value then
		return responseIfTrue or true
	else
		return responseIfFalse or false
	end
end

function clamp(value, min, max)
    return math.max(
    	math.min(value, max),
    	min
    )
end

function ring(value, min, max)
	if min > max then
    	min, max = max, min
  	end

	return min + (value - min) % (max - min)
end
