local pd <const> = playdate
local gfx <const> = pd.graphics
local scn <const> = pd.display
local snd <const> = pd.sound
local spr <const> = gfx.sprite

class('zx', {
	font = gfx.font.new('assets/font/zxspeccy'),
	ink = 'black',
	paper = 'clear',
	beeperSynth = nil,
	volume = 0.6,
	pauseTimer = nil,
	scale = 2,
}).extends()

function zx:init()
	zx.super.init(self)
	zx.chrSize = zx.font:getHeight()
end

----------------------------------------------------------------------------------------------------
-- BEEPER
----------------------------------------------------------------------------------------------------
function zx:beeper(enabled)
	if enabled == nil then
		return self.beeperSynth ~= nil
	elseif enabled == 1 or enabled == true then
		if self.beeperSynth == nil then
			self.beeperSynth = snd.synth.new(snd.kWaveSquare)
		end
	else
		if self.beeperSynth ~= nil and self.beeperSynth:isPlaying() then
			self.beeperSynth:stop()
		end

		self.beeperSynth = nil
	end
end

function zx:beep(duration, pitch)
	if self.beeperSynth == nil or self.beeperSynth:isPlaying() then
		return
	end

	self.beeperSynth:playMIDINote(
		pitch + 60,
		self.volume,
		duration
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
	if self.pauseTimer == nil then
		self.pauseTimer = pd.timer.performAfterDelay(
			zx:getFrameMs(frames),
			function()
				self.pauseTimer = nil
				callback()
			end
		)
	end
end

function zx:skipPause()
	if self.pauseTimer ~= nil then
		self.pauseTimer:remove()
	end

	self.pauseTimer = nil
end

----------------------------------------------------------------------------------------------------
-- SPRITES
----------------------------------------------------------------------------------------------------
zx.moveSpriteToChr = function(self, x, y)
	local chrX, chrY = zx:getChrCoords(
		x,
		y,
		self:getScale()
	)

	local width, height = self:getSize()

	self:moveTo(
		chrX + width / 2,
		chrY + height / 2
	)
end

----------------------------------------------------------------------------------------------------
-- TEXT
----------------------------------------------------------------------------------------------------
function zx:getChrCoords(x, y, scale)
	local chrSize = zx.chrSize * (scale or zx.scale);
	return (x * chrSize), (y * chrSize)
end

function zx:printToSprite(args)
	local sprite = spr.new()
	sprite.ref = args.ref or nil

	local text = ''
	local ink = args.ink or zx.ink
	local paper = args.paper or zx.paper
	local flash = args.flash or 0
	local border = args.border or 0
	local centered = args.centered or 0
	local x = args.x or 0
	local y = args.y or 0

	if args.text ~= nil then
		text = args.text
	elseif args.ref ~= nil then
		text = gfx.getLocalizedText(args.ref)
	end

	local scale = clamp(
		args.scale or zx.scale,
		1,
		2
	)

	local maxChrsPerLine = args.maxChrsPerLine or (scn.getWidth() / zx.chrSize) / scale

	maxChrsPerLine -= x

	if border == 1 or centered == 1 then
		maxChrsPerLine -= x
	end

	if border == 1 then
		text = als:borderedText(
			text,
			maxChrsPerLine
		)
	end

	if centered == 1 then
		x = (maxChrsPerLine / 2) - (string.len(text) / 2)
	end

	local width, height = gfx.getTextSizeForMaxWidth(
		text,
		math.ceil(maxChrsPerLine * zx.chrSize),
		nil,
		zx.font
	)

	-- override the height with maxLines if set
	if args.maxLines then
		height = zx.chrSize * args.maxLines
	end

	-- bordered text heights are getting miscalculated, so patch it using line breaks for now & fix later...
	if border == 1 then
		local _, lineBreaks = text:gsub("\n","")
		height = zx.chrSize * (lineBreaks + 1)
	elseif args.maxLines then
		height = zx.chrSize * args.maxLines
	end

	if flash == 1 then
		sprite.frames = zx:printToImgTable(
			text,
			width,
			height,
			ink,
			paper
		)

		-- FLASH on a ZX Spectrum swaps the palette every 16 frames (1 frame = 20ms)
		sprite.animation = gfx.animation.loop.new(
			zx:getFrameMs(16),
			sprite.frames,
			1
		)

		sprite:setImage(sprite.animation:image())

		sprite.update = function(self)
			self:setImage(self.animation:image())
		end
	else
		sprite:setImage(
			zx:printToImg(
				text,
				width,
				height,
				ink,
				paper
			)
		)
	end

	sprite.moveToChr = zx.moveSpriteToChr

	sprite:setScale(scale)

	sprite:moveToChr(x, y)

	sprite:add()

	return sprite
end

-- print flashing text to an imagetable
function zx:printToImgTable(text, width, height, ink, paper)
	local imgTable = gfx.imagetable.new(2)

	for i = 1, #imgTable do
		if i == 2 then
			-- ensure that the flashed ink will be black or white
			if paper == 'clear' then
				paper = ternary(
					ink == 'black',
					'white',
					'black'
				)
			end

			-- swap paper/ink for the flashed image
			ink, paper = paper, ink
		end

		imgTable:setImage(
			i,
			zx:printToImg(
				text,
				width,
				height,
				paper,
				ink
			)
		)
	end

	return imgTable
end

-- print text to a new image
function zx:printToImg(text, width, height, ink, paper)
	local img = gfx.image.new(
		width,
		height
	)

	gfx.pushContext(img)

	zx:print(
		text,
		0,
		0,
		width,
		height,
		ink,
		paper
	)

	gfx.popContext()

	return img
end

-- print text to the current context
function zx:print(text, x, y, width, height, ink, paper)
	ink = ink or zx.ink
	paper = paper or zx.paper

	if ink ~= 'black' then
		gfx.setImageDrawMode(gfx.kDrawModeInverted)
	else
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
	end

	-- paper (background colour)
	gfx.clear(gfx['kColor' .. paper:gsub("^%l", string.upper)])

	-- ink (foreground colour)
	gfx.setColor(gfx['kColor' .. ink:gsub("^%l", string.upper)])

	zx.font:drawText(
		text,
		x,
		y,
		width,
		height
	)

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
