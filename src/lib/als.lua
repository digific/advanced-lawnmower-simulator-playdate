local pd <const> = playdate
local gfx <const> = pd.graphics
local scn <const> = pd.display
local spr <const> = gfx.sprite

class('als',
	{
		data = {
			unmown = {187, 170, 170, 238, 127, 85, 85, 215},
			mown = {85, 255, 170, 255, 85, 255, 170, 255},
			mower = {255, 255, 255, 255, 255, 224, 145, 145},
			man = {231, 231, 247, 151, 103, 239, 211, 187},
			cursor = {255, 207, 199, 195, 195, 199, 207, 255},
		},
	}
).extends()

function als:init(zx)
	als.super.init(self)

	self.zx = zx

	self.mower = als:resetMower()

	self.grass = {
		mowable = true,
		x = 0,
		y = 4,
	}

	self.motor = {
		engaged = false,
		firstBeep = false,
		callback = function()
			self.motor.firstBeep = not self.motor.firstBeep

			if self.motor.firstBeep then
				zx:beep(.005, -12)
			else
				zx:beep(.002, -5)
			end

			self.motor.timer = pd.timer.performAfterDelay(
				zx:getFrameMs(ternary(self.motor.engaged, 3, 1)),
				self.motor.callback
			)
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- GAME
----------------------------------------------------------------------------------------------------

function als:resetMower()
	self.mower = {
		type = 1,
		x = 23,
		y = 14,
	}
end

function als:isWorkingMower()
	return self.mower.type == 6
end

function als:setMowerType(value)
	self.mower.type = ring(value, 1, 6)
end

function als:stopMotor()
	zx.beeper.stop()

	if self.motor.timer ~= nil then
		self.motor.timer:remove()
		self.motor.timer = nil
	end

	self.motor.engaged = false
	self.motor.firstBeep = false
end

function als:startMotor()
	self.motor.callback()
end

function als:rndExp()
	self.exp = math.random(1, 3) == 2
end

function als:lawnMowed()
	return self.grass.mowable == false and self.mower.x == self.grass.x and self.mower.y == self.grass.y
end

function als:killed()
	local rockY, rockX = 12, 7
	return self.exp and self.mower.y == rockY and self.mower.x == rockX
end

function als:getMowRating(value)
	return ternary(
		value == 1 or value == 4 or value == 7 or value == 9 or value == 10,
		'good',
		'bad'
	)
end

----------------------------------------------------------------------------------------------------
-- SYSTEM
----------------------------------------------------------------------------------------------------
function als:setMenuImage(stats)
	local zx = self.zx
	local total = stats.good + stats.bad + stats.deaths
	if total == 0 then return end

	local img = gfx.image.new(
		200,
		120
	)

	local previousColours = {
		ink = zx.colour.ink,
		paper = zx.colour.paper,
	}

	gfx.pushContext(img)

	gfx.setDitherPattern(0)

	gfx.fillRect(
		0,
		0,
		img.width,
		img.height
	)

	local values = {
		good = ternary(stats.good < 9999, stats.good, gfx.getLocalizedText('stats-too-many-' .. math.random(1, 6))),
		bad = ternary(stats.bad < 9999, stats.bad, gfx.getLocalizedText('stats-too-many-' .. math.random(1, 6))),
		deaths = ternary(stats.deaths < 9999, stats.deaths, gfx.getLocalizedText('stats-too-many-' .. math.random(1, 6))),
		total = ternary(total < 9999, total, gfx.getLocalizedText('stats-too-many-' .. math.random(1, 6))),
	}

	local text = table.concat({
		als:borderedText(
			gfx.getLocalizedText('stats-title'),
			12
		),
		gfx.getLocalizedText('stats-good') .. gfx.getLocalizedText('stats-good-suffix') .. values.good,
		gfx.getLocalizedText('stats-bad') .. gfx.getLocalizedText('stats-bad-suffix') .. values.bad,
		gfx.getLocalizedText('stats-deaths') .. gfx.getLocalizedText('stats-deaths-suffix') .. values.deaths,
		gfx.getLocalizedText('stats-total') .. gfx.getLocalizedText('stats-total-suffix') .. values.total,
	}, '\n\n')

	zx:paper('black')
	zx:ink('white')

	zx:print(
		text,
		(img.width / 2) / 2,
		zx.chrSize * 1.5,
		img.width,
		zx.chrSize * 14
	)

	gfx.popContext()

	zx.super.colour = previousColours

	pd.setMenuImage(
		img:scaledImage(2),
		img.width / 2
	)
end

----------------------------------------------------------------------------------------------------
-- SPRITES
----------------------------------------------------------------------------------------------------
function als:sprSky()
	local sprite = zx.sprite()
	local scale = clamp(
		scale or zx.scale,
		1,
		2
	)

	sprite.img = gfx.image.new(
		scn.getWidth() / 2,
		(self.zx.chrSize * 4)
	)

	local house = gfx.image.new('assets/img/house')
	local sun = gfx.image.new('assets/img/sun')

	gfx.pushContext(sprite.img)

	house:draw(86, 7)
	sun:draw(129, 5)

	gfx.popContext()

	sprite:setSize(
		sprite.img.width * zx.scale,
		sprite.img.height * zx.scale
	)
	sprite:setScale(zx.scale)
	sprite:moveToChr(0, 0)

	sprite:add()

	return sprite
end

function als:sprGrass()
	local sprite = zx.sprite()
	local scale = clamp(
		scale or zx.scale,
		1,
		2
	)

	local chrX, chrY = self.grass.x, self.grass.y

	sprite.img = zx:printToImg(
		self.data.unmown,
		scn.getWidth() / scale,
		zx.chrSize * 11
	)

	sprite.mow = function(sprite, x, y)
		gfx.pushContext(sprite.img)

		zx:print(
			self.data.mown,
			(x - chrX) * zx.chrSize,
			(y - chrY) * zx.chrSize,
			zx.chrSize * 2,
			zx.chrSize
		)

		gfx.popContext()
	end

	sprite:setScale(zx.scale)

	sprite:setSize(
		sprite.img.width * zx.scale,
		sprite.img.height * zx.scale
	)

	sprite:moveToChr(chrX, chrY)

	sprite:add()

	return sprite
end

function als:sprMower()
	local sprite = zx.sprite()

	sprite.img = gfx.image.new(
		zx.chrSize * 2,
		zx.chrSize
	)

	sprite.startX = self.mower.x

	gfx.pushContext(sprite.img)

	zx:print(
		self.data.mower,
		0,
		0,
		zx.chrSize,
		zx.chrSize,
		'black',
		nil
	)

	zx:print(
		self.data.man,
		zx.chrSize,
		0,
		zx.chrSize,
		zx.chrSize,
		'black',
		nil
	)

	gfx.popContext()

	sprite.mow = function(sprite)
		self.mower.x -= 1

		if self.mower.x < 0 then
			if self.mower.y == self.grass.y then
				self.mower.x = 0
				self.grass.mowable = false
			else
				self.mower.y -= 1
				self.mower.x = sprite.startX
			end
		end

		if self.grass.mowable then
			sprite:moveToChr(
				self.mower.x,
				self.mower.y
			)
		end
	end

	sprite:setSize(
		sprite.img.width * zx.scale,
		sprite.img.height * zx.scale
	)

	sprite:setScale(zx.scale)

	sprite:moveToChr(
		self.mower.x,
		self.mower.y
	)

	sprite:add()

	return sprite
end

function als:sprBlood(callbackWhenComplete)
	local sprite = zx.sprite()
	local scale = clamp(
		scale or zx.scale,
		1,
		2
	)

	sprite.img = gfx.image.new(
		scn.getWidth() / scale,
		scn.getHeight() / scale
	)

	gfx.pushContext(sprite.img)

	gfx.clear(
		zx:gfxColour('black')
	)

	gfx.popContext()

	sprite.size = 0
	sprite.delay = 0
	sprite.beep = {
		pitch = 35,
		callback = function()
			zx:beep(0.002, sprite.beep.pitch)
			sprite.beep.pitch -= 5

			if sprite.beep.pitch < 15 then
				sprite.beep.pitch = 35
			else
				sprite.beep.timer = pd.timer.performAfterDelay(
					0.002,
					sprite.beep.callback
				)
			end
		end,
	}

	sprite.update = function(self)
		sprite.delay += 1

		if sprite.delay > 7 and sprite.size < (scn.getHeight() / (zx.chrSize * zx.scale)) then
			sprite.size += 1

			sprite:setSize(
				sprite.img.width * zx.scale,
				(zx.chrSize * sprite.size) * zx.scale
			)

			sprite:moveToChr(0, 0)

			sprite.delay = 0

			sprite.beep.callback()
		end

		if sprite.height == scn.getHeight() and type(callbackWhenComplete) == 'function' then
			zx:pause(
				zx:getFrameMs(2),
				callbackWhenComplete
			)
		end
	end

	sprite:setScale(zx.scale)

	sprite:setSize(
		sprite.img.width * zx.scale,
		(zx.chrSize * sprite.size) * zx.scale
	)

	sprite:moveToChr(0, 0)

	sprite:add()

	return sprite
end

function als:sprCursor(x, y)
	local sprite = zx.sprite()

	sprite.img = zx:printToImg(
		self.data.cursor
	)

	sprite:setSize(
		zx.chrSize * zx.scale,
		zx.chrSize * zx.scale
	)

	sprite:setScale(zx.scale)

	sprite:moveToChr(x, y)

	sprite:add()

	return sprite
end

----------------------------------------------------------------------------------------------------
-- BORDERED TEXT
----------------------------------------------------------------------------------------------------

function als:borderedText(text, maxChrsPerLine)
	maxChrsPerLine = maxChrsPerLine or 50

	-- split text into lines
	local lines = {}

	for l in string.gmatch(text, "([^\n]*)\n?") do
		table.insert(lines, l)
	end

	-- add borders & padding to the provided text value
	local paddingChrs

	for i = 1, #lines do
		paddingChrs = ((maxChrsPerLine - 2) - string.len(lines[i])) / 2
		lines[i] = table.concat({
			'*',
			string.rep(' ', math.floor(paddingChrs)),
			lines[i],
			string.rep(' ', math.ceil(paddingChrs)),
			'*'
		}, '')
	end

	-- prepend top border
	table.insert(
		lines,
		1,
		string.rep('*', maxChrsPerLine)
	)

	-- append bottom border
	table.insert(
		lines,
		string.rep('*', maxChrsPerLine)
	)

	return table.concat(lines, '\n')
end

----------------------------------------------------------------------------------------------------
-- SCROLLING MESSAGE
----------------------------------------------------------------------------------------------------

function als:scrollingText(index)
	-- concat the scroll prefix & text by index, then pad out to 100 chrs total length
	local text = gfx.getLocalizedText('scroll-prefix-' .. index) .. gfx.getLocalizedText('scroll-' .. index)
	local length = string.len(text)

	if length < 100 then
		text = text .. string.rep(' ', 100 - length)
	end

	return text
end

function als:scrollingMessage(index, x, y, chrs, scale)
	local sprite = zx.sprite()
	local scale = clamp(
		scale or zx.scale,
		1,
		2
	)

	sprite.index = index
	sprite.text = als:scrollingText(index)
	sprite.textLength = string.len(sprite.text)
	sprite.cursor = 0

	sprite.draw = function(sprite, x, y, width, height)
		-- scale up so that we adhere to the :setScale setting
		x *= scale
		y *= scale
		width *= scale
		height *= scale

		gfx.setClipRect(
			0,
			0,
			width,
			height
		)

		local scaledImg = sprite.img:scaledImage(scale)

		-- draw the scaled text in position
		scaledImg:draw(
			x + (sprite.cursor * (self.zx.chrSize * scale)),
			y
		)

		-- offset the cursor in front of or behind the text
		if sprite.cursor > 0 then
			sprite.cursor -= sprite.textLength
		else
			sprite.cursor += sprite.textLength
		end

		-- draw the scaled text again with the offset to plug in any gaps
		scaledImg:draw(
			x + (sprite.cursor * (self.zx.chrSize * scale)),
			y
		)

		gfx.clearClipRect()
	end

	sprite.scroll = function(sprite, amount)
		self.zx:beep(.04, 12)

		sprite.cursor = ring(
			sprite.cursor + amount,
			-sprite.textLength,
			sprite.textLength
		)

		sprite:markDirty()
	end

	-- create a full length image of the scrolling text
	local previousColours = {
		ink = zx.colour.ink,
		paper = zx.colour.paper,
	}

	zx:ink('white')
	zx:paper('black')

	sprite.img = zx:printToImg(
		sprite.text,
		string.len(sprite.text) * zx.chrSize,
		zx.chrSize
	)

	zx:ink(previousColours.ink)
	zx:paper(previousColours.paper)

	sprite:setSize(
		chrs * zx.chrSize,
		zx.chrSize
	)
	sprite:setScale(scale)
	sprite:moveToChr(x, y)
	sprite:add()

	return sprite
end
