local pd <const> = playdate
local gfx <const> = pd.graphics
local scn <const> = pd.display
local snd <const> = pd.sound
local spr <const> = gfx.sprite

class('zx', {
	colour = {
		ink = 'black',
		paper = 'clear',
	},
	font = gfx.font.new('assets/zxspeccy'),
	scale = 2,
	flashed = false,
}).extends()

function zx:init()
	zx.super.init(self)
	zx.chrSize = zx.font:getHeight()

	zx.beeper = {
		volume = 0.6,

		enabled = function(status)
			if status == nil then
				return zx.beeper.synth ~= nil
			elseif status == 1 or status == true and zx.beeper.synth == nil then
				zx.beeper.synth = snd.synth.new(snd.kWaveSquare)
			elseif zx.beeper.synth ~= nil then
				zx.beeper.stop()
				zx.beeper.synth = nil
			end
		end,

		beep = function(duration, pitch)
			if not zx.beeper.enabled() or zx.beeper.beeping() then
				return
			end

			zx.beeper.synth:playMIDINote(
				pitch + 60,
				zx.beeper.volume,
				duration
			)
		end,

		beeping = function()
			return zx.beeper.synth ~= nil and zx.beeper.synth:isPlaying()
		end,

		stop = function()
			if zx.beeper.beeping() then
				zx.beeper.synth:stop()
			end
		end
	}

	zx.flashing = {
		enabled = function(status)
			if status == nil then
				return zx.flashing.timer ~= nil
			elseif status == 1 or status == true and zx.flashing.timer == nil then
				zx.flashing.timer = pd.timer.new(
					zx.flashing.interval,
					zx.flashing.callback
				)

				zx.flashing.timer.repeats = true
				zx.flashing.timer.discardOnCompletion = false
			elseif zx.flashing.timer ~= nil then
				zx.flashing.timer:remove()
				zx.flashing.timer = nil
			end
		end,

		interval = self:getFrameMs(16),

		callback = function()
			zx.flashed = not zx.flashed
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- BEEPER
----------------------------------------------------------------------------------------------------
function zx:beep(duration, pitch)
	self.beeper.beep(
		duration,
		pitch
	)
end

----------------------------------------------------------------------------------------------------
-- TIMING
----------------------------------------------------------------------------------------------------

function zx:getFrameMs(value)
	-- 1 frame = 20ms (ref: https://worldofspectrum.org/faq/reference/48kreference.htm)
	return value * 20
end

function zx:pause(frames, callback)
	if zx.pauseTimer == nil then
		zx.pauseTimer = pd.timer.performAfterDelay(
			zx:getFrameMs(frames),
			function()
				zx.pauseTimer = nil

				if type(callback) == 'function' then
					callback()
				end
			end
		)
	end
end

function zx:skipPause()
	if zx.pauseTimer ~= nil then
		zx.pauseTimer:remove()
	end

	zx.pauseTimer = nil
end

----------------------------------------------------------------------------------------------------
-- SCREEN
----------------------------------------------------------------------------------------------------

function zx:getChrCoords(x, y, scale)
	local chrSize = zx.chrSize * (scale or zx.scale)
	return (x * chrSize), (y * chrSize)
end

function zx:ink(colour)
	zx.colour.ink = colour or zx.colour.ink

	gfx.setColor(
		zx:gfxColour(zx.colour.ink)
	)
end

function zx:paper(colour)
	zx.colour.paper = colour or zx.colour.paper

	gfx.clear(
		zx:gfxColour(zx.colour.paper)
	)
end

function zx:flash()
	-- ensure that the flashed ink will be black or white
	if zx.colour.paper ~= 'clear' then
		zx.colour.ink, zx.colour.paper = zx.colour.paper, zx.colour.ink
	end
end

function zx:gfxColour(value)
	return gfx['kColor' .. value:gsub("^%l", string.upper)] or nil
end

----------------------------------------------------------------------------------------------------
-- TEXT / DATA PRINTING
----------------------------------------------------------------------------------------------------

-- print value to the current context
function zx:print(value, x, y, width, height)
	if zx.colour.ink ~= 'black' then
		gfx.setImageDrawMode(gfx.kDrawModeInverted)
	else
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
	end

	if type(value) == 'table' and #value == 8 then
		gfx.setPattern(value)

		gfx.fillRect(
			x,
			y,
			width or zx.chrSize,
			height or zx.chrSize
		)
	else
		zx.font:drawText(
			value,
			x,
			y,
			width,
			height
		)
	end

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

-- print value to a new image
function zx:printToImg(value, width, height)
	if type(value) == 'table' and #value == 8 then
		width = width or zx.chrSize
		height = height or zx.chrSize
	end

	local img = gfx.image.new(
		width,
		height
	)

	gfx.pushContext(img)

	zx:paper()

	zx:ink()

	zx:print(
		value,
		0,
		0,
		width,
		height
	)

	gfx.popContext()

	return img
end

----------------------------------------------------------------------------------------------------
-- SPRITE
----------------------------------------------------------------------------------------------------

function zx:sprite(args)
	local sprite = spr.new()

	args = args or {}

	local scale = clamp(
		args.scale or zx.scale,
		1,
		2
	)

	sprite.flashing = args.flashing or false
	sprite.swapColoursIfFlashReduced = ((args.ink or zx.colour.ink) == 'black')

	sprite.flashed = ternary(
		(sprite.flashing and sprite.swapColoursIfFlashReduced),
		zx.flashed,
		nil
	)

	sprite.moveToChr = function(sprite, chrX, chrY)
		local x, y = zx:getChrCoords(
			chrX,
			chrY,
			sprite:getScale()
		)

		local offsetX, offsetY = sprite:getCenter()

		sprite:moveTo(
			x + (sprite.width * offsetX),
			y + (sprite.height * offsetY)
		)
	end

	sprite.getTextProperties = function(sprite)
		-- text value
		local text = ''

		if args.text ~= nil then
			text = args.text
		elseif args.str ~= nil then
			text = gfx.getLocalizedText(args.str)
		end

		-- maximum character per line
		local maxChrsPerLine = args.maxChrsPerLine or (scn.getWidth() / zx.chrSize) / scale

		if type(args.x) == 'number' then
			maxChrsPerLine -= args.x

			-- make bordered & cenetered text have equal character spacing on each side
			if args.bordered or args.centered then
				maxChrsPerLine -= args.x
			end
		end

		-- use bordered text?
		if args.bordered then
			text = als:borderedText(
				text,
				maxChrsPerLine
			)
		end

		local width, height = gfx.getTextSizeForMaxWidth(
			text,
			math.ceil(maxChrsPerLine * zx.chrSize),
			nil,
			zx.font
		)

		-- bordered text heights are getting miscalculated, so patch it using line breaks for now & fix later...
		if args.bordered then
			local _, lineBreaks = text:gsub("\n","")
			height = zx.chrSize * (lineBreaks + 1)
		elseif args.maxLines then
			height = zx.chrSize * args.maxLines
		end

		sprite.text = {
			value = text,
			maxChrsPerLine = maxChrsPerLine,
			width = width,
			height = height,
		}
	end

	sprite.drawImg = function(sprite, x, y)
		-- get a scaled version of the sprite's image
		local img = sprite.img:scaledImage(scale)

		-- set as inverted if flashed
		img:setInverted(sprite.flashed)

		img:draw(x, y)
	end

	sprite.draw = function(sprite, x, y, width, height)
		gfx.setClipRect(
			x,
			y,
			width,
			height
		)

		-- draw the sprite's image in position
		sprite:drawImg(0, 0)

		gfx.clearClipRect()
	end

	sprite.update = function(sprite)
		local flashingEnabled = zx.flashing.enabled()

		if flashingEnabled and sprite.flashing and zx.flashed ~= sprite.flashed then
			sprite.flashed = zx.flashed
			sprite:markDirty()
		elseif not flashingEnabled and sprite.flashing ~= sprite.flashed then
			sprite.flashed = (sprite.flashing and sprite.swapColoursIfFlashReduced)
			sprite:markDirty()
		end
	end

	sprite.print = function(sprite, args)
		if args.text ~= nil or args.str ~= nil then
			sprite:getTextProperties()

			-- if text set as centered, calculate a value for args.x
			if (type(args.x) ~= 'number' or args.centered) then
				args.x = (sprite.text.maxChrsPerLine / 2) - (string.len(sprite.text.value) / 2)
			end
		end

		-- generate 'unflashed' and  'flashed' images
		local previousColours = {
			ink = zx.colour.ink,
			paper = zx.colour.paper,
		}

		zx.colour = {
			ink = args.ink or zx.colour.ink,
			paper = args.paper or zx.colour.paper,
		}

		sprite.img = zx:printToImg(
			sprite.text.value,
			sprite.text.width,
			sprite.text.height
		)

		zx.colour = previousColours

		-- scale the sprite up
		sprite:setSize(
			sprite.text.width * scale,
			sprite.text.height * scale
		)

		sprite:setScale(scale)

		sprite:moveToChr(
			args.x,
			args.y
		)

		sprite:markDirty()
	end

	if args.text ~= nil or args.str ~= nil then
		sprite:print(args)
	end

	sprite:add()

	return sprite
end
