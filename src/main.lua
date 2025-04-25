----------------------------------------------------------
--    ADVANCED LAWNMOWER SIMULATOR: PLAYDATE EDITION    --
----------------------------------------------------------
-- Author:  Andy Thomas (aka @andyific)                 --
-- Company: Digific Ltd (digific.com)                   --
-- Website: advancedlawnmowersimulator.com/playdate     --
----------------------------------------------------------
-- This is a 'tribute' to a the original ALS on the     --
-- ZX Spectrum; The April Fool 'Your Sinclair'magazine  --
-- once published on their cover tape & written by the  --
-- legendary Duncan MacDonald (RIP).                    --
--                                                      --
-- Previously, I made another tribute to the game waaay --
-- back in 2006 that ended up becoming a mildly         --
-- successful Facebook app (complete with statistics    --
-- and other sorts of gubbins),                         --
--                                                      --
-- EVERY platform needs a version of ALS, so might as   --
-- well make one for the Playdate to get to grips with  --
-- the SDK & participate in #RaeJam2025.                --
--                                                      --
-- I'm REALLY looking forward to 'getting that grass'   --
-- by cranking to mow... ! :D                           --
----------------------------------------------------------

import 'CoreLibs/graphics'
import 'CoreLibs/sprites'
--
import 'CoreLibs/animation'
import 'CoreLibs/object'
import 'CoreLibs/timer'
import 'CoreLibs/crank'

import 'lib/utilities'
import 'lib/zx'
import 'lib/als'

local allowDebug = false

local pd <const> = playdate
local scn <const> = pd.display
local gfx <const> = pd.graphics
local spr <const> = gfx.sprite

local crank

local config = {}
local stats = {}

local currentScene
local sceneSprites = {}
local sceneBtnState
local sceneHasInputError

local backgroundImage

local z = 1

local menu = pd.getSystemMenu()
local crankTicksPerRevolution = 360

local zx = zx()
local als = als(zx)

----------------------------------------------------------------------------------------------------

function resetCrank()
	crank = {
		moving = false,
		position = pd.getCrankPosition(),
		ticks = nil,
	}
end

function updateCrank()
	local crankPosition = pd.getCrankPosition()

	crank = {
		moving = (crank.position ~= crankPosition),
		position = crankPosition,
		ticks = pd.getCrankTicks(1),
	}
end

spr.setBackgroundDrawingCallback(
	function(x, y, width, height)
		if backgroundImage ~= nil then
			backgroundImage:draw(0, 0)
		end
	end
)

function setBackground(value)
	if value ~= nil then
		if backgroundImage == nil then
			backgroundImage = gfx.image.new(scn.getSize())
		end

		gfx.pushContext(backgroundImage)

		gfx.setDitherPattern(value)

		gfx.fillRect(
			0,
			0,
			backgroundImage.width,
			backgroundImage.height
		)

		gfx.popContext()
	else
		backgroundImage = nil
	end

	spr.redrawBackground()
end

function removeAllTimers()
    local timers = pd.timer.allTimers()

    for _, timer in ipairs(timers) do
        timer:remove()
        timer = nil
    end
end

----------------------------------------------------------------------------------------------------

function loadFromStorage(filename, defaults)
	local data = playdate.datastore.read(filename)

	if data == nil then
		data = {}
	end

	values = {}

	for key, value in pairs(defaults) do
    	if data[key] ~= nil then
    		values[key] = data[key]
    	else
    		values[key] = value
    	end
	end

	return values
end

function saveToStorage(data)
	for filename, values in pairs(data) do
		playdate.datastore.write(
			values,
			filename
		)
	end
end

function loadConfig()
	config = loadFromStorage('config', {
		beeper = 1,
	})

	zx:beeper(config.beeper)
end

function loadStats()
	stats = loadFromStorage('stats', {
		good = 0,
		bad = 0,
		deaths = 0,
	})

	als:setMenuImage(stats)
end

----------------------------------------------------------------------------------------------------

function setSceneTo(value, sprites, background)
	currentScene = value
	sceneHasInputError = false
	setBackground(background)
	spr.removeSprites(sceneSprites)
	sceneSprites = sprites
	resetSceneBtnState()
end

function updateSceneBtnState()
	local _, pressed, released = pd.getButtonState()
	local previousBtnState = sceneBtnState

	if released > 0 then
		sceneBtnState &= (~released)

		if sceneBtnState ~= previousBtnState and type(onSceneBtnRelease) == 'function' then
			log(currentScene .. ' input released: ' .. released)
			onSceneBtnRelease(released)
		end
	end

	if pressed > 0 then
		sceneBtnState |= pressed

		if sceneBtnState ~= previousBtnState and type(onSceneBtnPress) == 'function' then
			log(currentScene .. ' input pressed: ' .. pressed)
			onSceneBtnPress(pressed)
		end
	end
end


function resetSceneBtnState(invalidInputs)
	sceneBtnState = 0
	sceneHasInputError = false
end

pd.inputHandlers.push({
	AButtonDown = updateSceneBtnState,
	AButtonUp = updateSceneBtnState,
	BButtonDown = updateSceneBtnState,
	BButtonUp = updateSceneBtnState,
	downButtonDown = updateSceneBtnState,
	downButtonUp = updateSceneBtnState,
	leftButtonDown = updateSceneBtnState,
	leftButtonUp = updateSceneBtnState,
	rightButtonDown = updateSceneBtnState,
	rightButtonUp = updateSceneBtnState,
	upButtonDown = updateSceneBtnState,
	upButtonUp = updateSceneBtnState,
})

----------------------------------------------------------------------------------------------------

-- TODO: shove this in the game
function mowSound()
	z += 1

	if z > 1 then
		z = 0
	end

	-- 'Engine' sound - loops quickly if no input, otherwise delayed
	if pd.buttonIsPressed('a') then
		if z == 0 then
			zx:beep(.005, -12)
		else
			zx:beep(.002, -5)
		end
	end
end

function wellMownSound()
	-- 'Well Mown' sound - played when lawn is fully mown
	zx:beep(.5, 12)
end

----------------------------------------------------------------------------------------------------

function showTitleScreen()
	setSceneTo('title', {
		zx:printToSprite({
			ref = 'game-title',
			x = 1,
			y = 0.5,
			paper = 'white',
			flash = 1,
			border = 1,
		}),

		zx:printToSprite({
			ref = 'about',
			x = 1,
			y = 5.5,
		}),

		zx:printToSprite({
			ref = 'start',
			y = 13.5,
			centered = 1,
		}),
	})

	als:resetMower()

	onSceneUpdate = function()
		if sceneHasInputError then
			zx:beep(.5, 5)
		end
	end

	onSceneBtnRelease = function(released)
		if sceneHasInputError and sceneBtnState == 0 then
			sceneHasInputError = false
		end
	end

	onSceneBtnPress = function(pressed)
		if sceneBtnState == pd.kButtonA | pd.kButtonB then
			showCreditsScene()
		elseif sceneBtnState == pd.kButtonA then
			showPickMowerScreen()
		else
			sceneHasInputError = true
		end
	end
end

function showPickMowerScreen()
	setSceneTo('pickMower', {
		zx:printToSprite({
			ref = 'game-title',
			x = 1,
			y = 0.5,
			paper = 'white',
			flash = 1,
			border = 1,
		}),

		zx:printToSprite({
			ref = 'choose-machine',
			x = 1,
			y = 5.5,
		}),

		zx:printToSprite({
			ref = 'mower-1',
			x = 3,
			y = 7.5,
		}),

		zx:printToSprite({
			ref = 'mower-2',
			x = 3,
			y = 8.5,
		}),

		zx:printToSprite({
			ref = 'mower-3',
			x = 3,
			y = 9.5,
		}),

		zx:printToSprite({
			ref = 'mower-4',
			x = 3,
			y = 10.5,
		}),

		zx:printToSprite({
			ref = 'mower-5',
			x = 3,
			y = 11.5,
		}),

		zx:printToSprite({
			ref = 'mower-6',
			x = 3,
			y = 12.5,
		}),

		zx:printToSprite({
			ref = 'cursor',
			x = 1,
			y = 6.5 + als.mower.type,
		})
	})

	local cursor = sceneSprites[9]

	onSceneUpdate = function()
		if sceneHasInputError then
			zx:beep(.5, 5)
		end
	end

	onSceneBtnRelease = function(released)
		if sceneHasInputError and sceneBtnState == 0 then
			sceneHasInputError = false
		end
	end

	onSceneBtnPress = function(pressed)
		if sceneBtnState == pd.kButtonUp or pressed == pd.kButtonDown then
			if (als.mower.type % 2 == 0) then
				zx:beep(.005, -12)
			else
				zx:beep(.002, -5)
			end

			if sceneBtnState == pd.kButtonUp then
				als.mower.type -= 1
			else
				als.mower.type += 1
			end

			if als.mower.type < 1 then
				als.mower.type = 6
			end

			if als.mower.type > 6 then
				als.mower.type = 1
			end

			cursor:moveToChr(
				1,
				6.5 + als.mower.type
			)
		elseif sceneBtnState == pd.kButtonA then
			if als.mower.type == 6 then
				showMowerIsWorkingScreen()
			else
				showMowerIsBrokenScreen()
			end
		elseif sceneBtnState == pd.kButtonB then
			showTitleScreen()
		else
			sceneHasInputError = true
		end
	end
end

function showMowerIsBrokenScreen(selectedMower)
	setSceneTo('brokenMower', {
		zx:printToSprite({
			ref = 'mower-broken',
			x = 1,
			y = 5.5,
		}),

		zx:printToSprite({
			ref = 'mower-' .. als.mower.type,
			x = 1,
			y = 7.5,
		}),
	})

	zx:pause(
		200,
		showPickMowerScreen
	)

	onSceneUpdate = 0

	onSceneBtnRelease = 0

	onSceneBtnPress = function(pressed)
		zx:skipPause()
		showPickMowerScreen()
	end
end

function showMowerIsWorkingScreen()
	setSceneTo('workingMower', {
		zx:printToSprite({
			ref = 'mower-working',
			x = 1,
			y = 2,
		}),

		zx:printToSprite({
			ref = 'mower-' .. als.mower.type,
			x = 1,
			y = 3,
		}),

		zx:printToSprite({
			ref = als:getInstructionsRef(),
			x = 1,
			y = 6,
			maxChrsPerLine = 24,
		}),

		zx:printToSprite({
			ref = 'start',
			x = 1,
			y = 12,
		})
	})

	local instructions = sceneSprites[3]

	onSceneUpdate = function()
		instructionsRef = als:getInstructionsRef()

		if instructionsRef ~= instructions.ref then
			instructions:remove()

			sceneSprites[3] = zx:printToSprite({
				ref = instructionsRef,
				x = 1,
				y = 6,
				maxChrsPerLine = 24,
			})

			instructions = sceneSprites[3]
		end

		if sceneHasInputError then
			zx:beep(.5, 5)
		end
	end

	onSceneBtnRelease = function(released)
		if sceneHasInputError and sceneBtnState == 0 then
			sceneHasInputError = false
		end
	end

	onSceneBtnPress = function(pressed)
		if sceneBtnState == pd.kButtonA then
			showGameScreen()
		else
			sceneHasInputError = true
		end
	end
end

function showGameScreen()
	setSceneTo('game', {
		als:sprSky(),
		als:sprGrass(),
		als:sprMower(),
	})

	-- are we going to die or not?
	local exp = math.random(0, 3)

	resetCrank()

	onSceneUpdate = function()
		if als.crankToMow then
			local crankPosition = pd.getCrankPosition()

			crank = {
				moving = (crank.position ~= crankPosition),
				position = crankPosition,
				ticks = pd.getCrankTicks(1),
			}

			if crank.moving then
				print('crank is moving: ' .. crank.position)
			end

			if crank.ticks > 0 then
				print('crank ticks: ' .. crank.ticks)
			end
		end
	end

	onSceneBtnRelease = function(released)
		-- do nothing right now...
	end

	onSceneBtnPress = function(pressed)
		if sceneBtnState == pd.kButtonA then
			if exp == 2 then
				showKilledScreen()
			else
				showCompletedScreen()
			end
		end
	end
end

function showKilledScreen()
	setSceneTo('killed', {
		zx:printToSprite({
			ref = 'killed',
			y = 6.5,
			centered = 1,
		}),

		zx:printToSprite({
			ref = 'restart',
			y = 13.5,
			centered = 1,
		}),
	}, .75)

	stats.deaths += 1

	als:setMenuImage(stats)

	onSceneUpdate = function()
		if sceneHasInputError then
			zx:beep(.5, 5)
		end
	end

	onSceneBtnRelease = function(released)
		if sceneHasInputError and sceneBtnState == 0 then
			sceneHasInputError = false
		end
	end

	onSceneBtnPress = function(pressed)
		if sceneBtnState == pd.kButtonA then
			showTitleScreen()
		else
			sceneHasInputError = true
		end
	end
end

function showCompletedScreen()
	local msg = math.random(1, 10)

	setSceneTo('completed', {
		als:scrollingMessage(
			msg,
			2,
			7,
			21
		),

		zx:printToSprite({
			ref = 'restart',
			y = 13.5,
			centered = 1,
			ink = 'white'
		}),
	}, 0)

	gfx.pushContext(backgroundImage)

	gfx.setColor(gfx.kColorWhite)

	gfx.setLineWidth(zx.scale)

	-- message border
	gfx.drawRect(
		1.5 * (zx.chrSize * zx.scale),
		6.5 * (zx.chrSize * zx.scale),
		22 * (zx.chrSize * zx.scale),
		2 * (zx.chrSize * zx.scale)
	)

	-- scene border
	gfx.drawRect(
		zx.scale,
		zx.scale,
		scn.getWidth() - (zx.scale * 2),
		scn.getHeight() - (zx.scale * 2)
	)

	gfx.popContext()

	local scrollingMessage = sceneSprites[1]

	-- get a mow rating & update the stats
	local mowRating = als:getMowRating(msg);
	stats[mowRating] += 1

	als:setMenuImage(stats)

	local scrollDelay = 0

	onSceneUpdate = function()
		scrollDelay += 1

		if scrollDelay > 3 then
			scrollingMessage:scroll(-1)
			scrollDelay = 0
		end
	end

	onSceneBtnRelease = 0

	onSceneBtnPress = function(pressed)
		showTitleScreen()
	end
end

function showCreditsScene()
	setSceneTo('credits', {
		zx:printToSprite({
			ref = 'credits-title',
			x = 1,
			y = 0.5,
			paper = 'white',
			flash = 1,
			border = 1,
		}),

		zx:printToSprite({
			ref = 'credits',
			x = 1,
			y = 4.5,
		}),

		zx:printToSprite({
			ref = 'return',
			y = 13.5,
			centered = 1,
		}),
	})

	onSceneUpdate = function()
		if sceneHasInputError then
			zx:beep(.5, 5)
		end
	end

	onSceneBtnRelease = function(released)
		if sceneHasInputError and sceneBtnState == 0 then
			sceneHasInputError = false
		end
	end

	onSceneBtnPress = function(pressed)
		if sceneBtnState == pd.kButtonB then
			showTitleScreen()
		else
			sceneHasInputError = true
		end
	end
end

----------------------------------------------------------------------------------------------------

scn.setRefreshRate(30)

function pd.update()
	spr.update()
	pd.timer.updateTimers()

	if type(onSceneUpdate) == 'function' then
		onSceneUpdate()
	end

	if isDebugging() then
		pd.drawFPS(385, 0)
	end
end

pd.crankDocked = als.updateCrankToMow
pd.crankUndocked = als.updateCrankToMow

function pd.gameWillTerminate()
	saveToStorage({
		config = config,
		stats = stats
	})
end

function pd.deviceWillSleep()
    saveToStorage({
		config = config,
		stats = stats
	})
end

----------------------------------------------------------------------------------------------------

loadConfig()
loadStats()

menu:addCheckmarkMenuItem(
	'Beeper',
	config.beeper,
	function(value)
		config.beeper = value and 1 or 0
		zx:beeper(config.beeper)
	end
)

if allowDebug then
	menu:addCheckmarkMenuItem(
		'Debug',
		isDebugging(),
		function(value)
			setDebugging(value)
		end
	)
end

-- let's get this 80's mowing party started yo...
showTitleScreen()
