local pd <const> = playdate
local gfx <const> = pd.graphics
local scn <const> = pd.display
local spr <const> = gfx.sprite

class('als',
	{
		zx = nil,
		crankToMow = not pd.isCrankDocked(),
		motorEngaged = false,
		dead = 0,
		mower = {
			type = 1,
			x = 0,
			y = 0,
		},
	}
).extends()

function als:init(zx)
	als.super.init(self)
	self.zx = zx
end

----------------------------------------------------------------------------------------------------
-- SYSTEM
----------------------------------------------------------------------------------------------------
function als:updateCrankToMow()
	als.crankToMow = not pd.isCrankDocked()
end

function als:setMenuImage(stats)
	local total = stats.good + stats.bad + stats.deaths

	if total == 0 then return end

	scnWidth, scnHeight = pd.display.getSize()

	local img = gfx.image.new(
		scnWidth / 2,
		scnHeight / 2
	)

	gfx.pushContext(img)

	gfx.setDitherPattern(0)

	gfx.fillRect(
		0,
		0,
		img.width,
		img.height
	)

	local values = {
		total = ternary(total < 9999, total, gfx.getLocalizedText('statistics-too-many-' .. math.random(1, 5))),
		good = ternary(stats.good < 9999, stats.good, gfx.getLocalizedText('statistics-too-many-' .. math.random(1, 5))),
		bad = ternary(stats.bad < 9999, stats.bad, gfx.getLocalizedText('statistics-too-many-' .. math.random(1, 5))),
		deaths = ternary(stats.deaths < 9999, stats.deaths, gfx.getLocalizedText('statistics-too-many-' .. math.random(1, 5))),
	}

	zx:print(
		table.concat({
			als:borderedText(
				gfx.getLocalizedText('statistics-title'),
				12
			),
			gfx.getLocalizedText('statistics-total') .. gfx.getLocalizedText('statistics-total-suffix') .. values.total,
			gfx.getLocalizedText('statistics-good') .. gfx.getLocalizedText('statistics-good-suffix') .. values.good,
			gfx.getLocalizedText('statistics-bad') .. gfx.getLocalizedText('statistics-bad-suffix') .. values.bad,
			gfx.getLocalizedText('statistics-deaths') .. gfx.getLocalizedText('statistics-deaths-suffix') .. values.deaths,
		}, '\n\n'),
		0,
		zx.chrSize * 1.5,
		img.width,
		zx.chrSize * 14,
		'white',
		'black'
	)

	gfx.popContext()

	pd.setMenuImage(
		img:scaledImage(2)
	)
end

----------------------------------------------------------------------------------------------------
-- SPRITES
----------------------------------------------------------------------------------------------------
function als:sprSky()
	local sprite = spr.new()

	local img = gfx.image.new(
		scn.getWidth(),
		(self.zx.chrSize * 8)
	)

	gfx.pushContext(img)

	-- draw house
	gfx.drawLine(
		173,
		64,
		173,
		34
	)

	gfx.drawLine(
		173,
		34,
		193,
		14
	)

	gfx.drawLine(
		193,
		14,
		213,
		34
	)

	gfx.drawLine(
		213,
		34,
		213,
		64
	)

	-- draw sun
	gfx.drawCircleAtPoint(
		274,
		26,
		15
	)

	gfx.popContext()

	sprite.moveToChr = zx.moveSpriteToChr

	sprite:setImage(img)
	sprite:setScale(1)
	sprite:moveToChr(0, 0)
	sprite:add()

	return sprite
end

function als:sprGrass()
	local sprite = spr.new()
	local scale = clamp(
		scale or self.zx.scale,
		1,
		2
	)

	local img = gfx.image.new(
		scn.getWidth() / scale,
		(self.zx.chrSize * 11)
	)

	print('grass: ', img.width, img.height)

	gfx.pushContext(img)

	gfx.setDitherPattern(.6)

	gfx.fillRect(
		0,
		0,
		img.width,
		img.height
	)

	gfx.popContext()

	sprite.moveToChr = zx.moveSpriteToChr

	sprite:setImage(img)
	sprite:setScale(scale)
	sprite:moveToChr(0, 4)
	sprite:add()

	return sprite
end

function als:sprMower()
	local sprite = spr.new()
	local scale = clamp(
		scale or self.zx.scale,
		1,
		2
	)

	sprite.moveToChr = zx.moveSpriteToChr

	sprite:setSize(
		scn.getWidth() / scale,
		scn.getHeight() / scale
	)
	sprite:setScale(scale)
	sprite:moveToChr(10, 10)
	sprite:add()

	return sprite
end

----------------------------------------------------------------------------------------------------
-- MOWER
----------------------------------------------------------------------------------------------------

function als:resetMower()
	self.mower = {
		type = 1,
		x = 0,
		y = 0,
	}
end

function als:getMowRating(value)
	return ternary(
		value == 1 or value == 4 or value == 7 or value == 9 or value == 10,
		'good',
		'bad'
	)
end

----------------------------------------------------------------------------------------------------
-- TEXT
----------------------------------------------------------------------------------------------------

function als:getInstructionsRef()
	return 'instructions-for-' .. ternary(self.crankToMow, 'crank', 'btns')
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

	return table.concat(lines, '\n');
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
	local sprite = spr.new()
	local scale = clamp(
		scale or self.zx.scale,
		1,
		2
	)

	sprite.index = index
	sprite.text = als:scrollingText(index)
	sprite.textLength = string.len(sprite.text)
	sprite.cursor = 0
	sprite.zx = self.zx

	sprite.moveToChr = zx.moveSpriteToChr
	sprite.draw = function(self, x, y, width, height)
		-- scale up so that we adhere to the :setScale setting
		x *= scale
		y *= scale
		width *= scale
		height *= scale

		gfx.setClipRect(0, 0, width, height)

		local cursor = self.cursor

		-- draw the text in position
		sprite.img:drawScaled(
			x + (cursor * (self.zx.chrSize * scale)),
			y,
			scale
		)

		-- offset the cursor in front of or behind the text
		if cursor > 0 then
			cursor -= self.textLength
		else
			cursor += self.textLength
		end

		-- draw the text again with the offset to plug in any gaps
		sprite.img:drawScaled(
			x + (cursor * (self.zx.chrSize * scale)),
			y,
			scale
		)

		gfx.clearClipRect()
	end

	sprite.scroll = function(self, amount)
		self.zx:beep(.04, 12)

		self.cursor = ring(
			self.cursor + amount,
			-self.textLength,
			self.textLength
		)

		self:markDirty()
	end

	-- create a full length image of the scrolling text
	sprite.img = self.zx:printToImg(
		sprite.text,
		string.len(sprite.text) * self.zx.chrSize,
		zx.chrSize,
		'white',
		'black'
	)

	sprite:setSize(
		chrs * self.zx.chrSize,
		self.zx.chrSize
	)
	sprite:setScale(scale)
	sprite:moveToChr(x, y)
	sprite:add()

	return sprite
end
