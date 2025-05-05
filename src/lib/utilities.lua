local debugging = false

if false then
	debugging = true

	function debugMode(value)
		debugging = (value == 1 or value == true)
	end
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

function minmax(min, max)
	if min > max then
    	min, max = max, min
  	end

  	return min, max
  end

function clamp(value, min, max)
	min, max = minmax(min, max)

    return math.max(
    	math.min(value, max),
    	min
    )
end

function ring(value, min, max)
	min, max = minmax(min, max)

	return min + (value - min) % max
end
