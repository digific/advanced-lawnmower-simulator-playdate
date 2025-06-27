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
import 'lib/cheevos'
import 'lib/zx'
import 'lib/als'

local pd <const> = playdate
local scn <const> = pd.display
local gfx <const> = pd.graphics
local spr <const> = gfx.sprite

local config = {}
local stats = {}

local scene = {}

local backgroundImage

local zx = zx()
local als = als(zx)
local cheevos = cheevos()

----------------------------------------------------------------------------------------------------
-- BACKGROUND
----------------------------------------------------------------------------------------------------

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

	return value
end

----------------------------------------------------------------------------------------------------
-- STORAGE
----------------------------------------------------------------------------------------------------

function loadFromStorage(filename, defaults)
	local data = pd.datastore.read(filename) or {}

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
		pd.datastore.write(
			values,
			filename
		)
	end
end

function loadConfig()
	config = loadFromStorage('config', {
		beeper = 1,
		crankiness = 1,
	})

	zx.beeper.enabled(config.beeper)
	zx.flashing.enabled(not pd.getReduceFlashing())
end

function loadStats()
	stats = loadFromStorage('stats', {
		good = 0,
		bad = 0,
		deaths = 0,
	})

	als:setMenuImage(stats)

	cheevos:progressed(stats)
end

----------------------------------------------------------------------------------------------------
-- SCENE MANAGEMENT
----------------------------------------------------------------------------------------------------

function setSceneTo(value, args)
	args = args or {}

	-- set up defined hooks
	local hooks = {
		beforeSceneChange = args.beforeSceneChange or nil,
		afterSceneChange = args.afterSceneChange or nil,
	}

	-- unset hooks from args
	args.beforeSceneChanges = nil
	args.afterSceneChanged = nil

	-- remove any old timers from the previous scene
	if type(scene.timers) == 'table' then
		for _, timer in pairs(scene.timers) do
			timer:remove()
			timer = nil
		end
	end

	-- remove any old sprites from the previous scene
	if type(scene.sprites) == 'table' then
		for _, sprite in pairs(scene.sprites) do
			sprite:remove()
		end
	end

	-- run hook before scene change
	if type(hooks.beforeSceneChange) == 'function' then
		hooks.beforeSceneChange()
	end

	-- set up the current scene
	scene = {
		current = value or nil,
		background = setBackground(args.background or nil),
		sprites = args.sprites or {},
		values = args.values or {},
		timers = {},

		btn = {
			state = 0,
			error = false,
		},

		crank = {
			ticksPerRevolution = args.crankTicksPerRevolution or 0,
			position = pd.getCrankPosition(),
		},
	}

	-- reset the crank ticks
	pd.getCrankTicks(scene.crank.ticksPerRevolution)

	-- add any defined functions
	for key, value in pairs(args) do
		if type(value) == 'function' and scene[key] == nil then
			scene[key] = value
		end
	end

	-- update the crank docked/undocked events
	pd.crankDocked = scene.onCrankDocked or nil
	pd.crankUndocked = scene.onCrankUndocked or nil

	-- set up any defined timers
	if type(args.timers) == 'table' then
		for key, values in pairs(args.timers) do
			scene.timers[key] = pd.timer.new(
				values.duration or 1000,
				values.callback or function() end,
				values.startValue or nil,
				values.endValue or nil,
				values.easingFunction  or nil
			)

			if values.settings ~= nil then
				for settingKey, settingValue in pairs(values.settings) do
					scene.timers[key][settingKey] = settingValue
				end
			end
		end
	end

	-- run hook after scene change
	if type(hooks.afterSceneChange) == 'function' then
		hooks.afterSceneChange()
	end
end

function updateSceneBtnState()
	local _, pressed, released = pd.getButtonState()
	local previousBtnState = scene.btn.state

	if released > 0 then
		scene.btn.state &= (~released)

		if scene.btn.state ~= previousBtnState and type(scene.onBtnRelease) == 'function' then
			scene.onBtnRelease(released)
		end
	end

	if pressed > 0 then
		scene.btn.state |= pressed

		if scene.btn.state ~= previousBtnState and type(scene.onBtnPress) == 'function' then
			scene.onBtnPress(pressed)
		end
	end
end

function updateSceneCranked(change, acceleratedChange)
	if change ~= 0 and type(scene.onCrankChange) == 'function' then
		scene.crank.position = pd.getCrankPosition()
		scene.onCrankChange(change, acceleratedChange)
	end

	if type(scene.onCrankTick) == 'function' then
		local crankTicks = pd.getCrankTicks(scene.crank.ticksPerRevolution)

		if crankTicks ~= 0 then
			scene.onCrankTick(crankTicks)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- SCENES
----------------------------------------------------------------------------------------------------

function showTitleScreen()
	setSceneTo('title', {
		sprites = {
			title = zx:sprite({
				str = 'game-title',
				x = 1,
				y = 0.5,
				bordered = true,
				flashing = true,
				paper = 'black',
				ink = 'white',
			}),

			about = zx:sprite({
				str = 'about',
				x = 1,
				y = 5.5,
			}),

			start = zx:sprite({
				str = 'start',
				y = 13.5,
				centered = 1,
			}),
		},

		beforeSceneChange = function()
			als:resetMower()
		end,

		onUpdate = function()
			if scene.btn.error then
				zx:beep(.5, 5)
			end
		end,

		onBtnRelease = function(released)
			if scene.btn.error and released ~= 0 then
				scene.btn.error = false
			end
		end,

		onBtnPress = function(pressed)
			if scene.btn.state == pd.kButtonUp | pd.kButtonA | pd.kButtonB then
				showCreditsScreen()
			elseif scene.btn.state == pd.kButtonA then
				showPickMowerScreen()
			else
				scene.btn.error = true
			end
		end,
	})
end

function showPickMowerScreen()
	setSceneTo('pickMower', {
		sprites = {
			title = zx:sprite({
				str = 'game-title',
				x = 1,
				y = 0.5,
				bordered = true,
				flashing = true,
				paper = 'black',
				ink = 'white',
			}),

			chooseMachine = zx:sprite({
				str = 'choose-machine',
				x = 1,
				y = 5.5,
			}),

			mower1 = zx:sprite({
				str = 'mower-1',
				x = 3,
				y = 7.5,
			}),

			mower2 = zx:sprite({
				str = 'mower-2',
				x = 3,
				y = 8.5,
			}),

			mower3 = zx:sprite({
				str = 'mower-3',
				x = 3,
				y = 9.5,
			}),

			mower4 = zx:sprite({
				str = 'mower-4',
				x = 3,
				y = 10.5,
			}),

			mower5 = zx:sprite({
				str = 'mower-5',
				x = 3,
				y = 11.5,
			}),

			mower6 = zx:sprite({
				str = 'mower-6',
				x = 3,
				y = 12.5,
			}),

			cursor = als:sprCursor(
				1.5,
				6.5 + als.mower.type
			),
		},

		crankTicksPerRevolution = 6,

		onUpdate = function()
			if scene.btn.error then
				zx:beep(.5, 5)
			end
		end,

		onBtnRelease = function(released)
			if scene.btn.error and scene.btn.state == 0 then
				scene.btn.error = false
			end
		end,

		onBtnPress = function(pressed)
			if scene.btn.state == pd.kButtonUp or scene.btn.state == pd.kButtonDown then
				zx:beep(.04, 12)

				als:setMowerType(ternary(
					scene.btn.state == pd.kButtonUp,
					als.mower.type - 1,
					als.mower.type + 1
				))

				scene.sprites.cursor:moveToChr(
					1.5,
					6.5 + als.mower.type
				)
			elseif scene.btn.state == pd.kButtonA then
				if als:isWorkingMower() then
					showMowerIsWorkingScreen()
				else
					showMowerIsBrokenScreen()
				end
			elseif scene.btn.state == pd.kButtonB then
				showTitleScreen()
			else
				scene.btn.error = true
			end
		end,

		onCrankTick = function(ticks)
			zx:beep(.04, 12)

			als:setMowerType(als.mower.type + ticks)

			scene.sprites.cursor:moveToChr(
				1.5,
				6.5 + als.mower.type
			)
		end,
	})
end

function showMowerIsBrokenScreen(selectedMower)
	setSceneTo('brokenMower', {
		sprites = {
			broken = zx:sprite({
				str = 'mower-broken',
				x = 1,
				y = 5.5,
			}),

			mower = zx:sprite({
				str = 'mower-' .. als.mower.type,
				x = 1,
				y = 7.5,
			}),
		},

		onBtnPress = function(pressed)
			zx:skipPause()
			showPickMowerScreen()
		end,

		afterSceneChange = function()
			zx:pause(
				200,
				showPickMowerScreen
			)

			cheevos:earned('chose-broken-mower')
		end,
	})
end

function showMowerIsWorkingScreen()
	setSceneTo('workingMower', {
		sprites = {
			working = zx:sprite({
				str = 'mower-working',
				x = 1,
				y = 2,
			}),

			mower = zx:sprite({
				str = 'mower-' .. als.mower.type,
				x = 1,
				y = 3,
			}),

			start = zx:sprite({
				str = 'start',
				x = 1,
				y = 12,
			})
		},

		values = {
			instructionsSpr = {
				str = nil,
				x = 1,
				y = 6,
				maxChrsPerLine = 24,
			},
		},

		instructionsText = function()
			return 'instructions-for-' .. ternary(pd.isCrankDocked(), 'btns', 'crank')
		end,

		updateInstructions = function()
			scene.values.instructionsSpr.str = scene.instructionsText()

			scene.sprites.instructions:print(
				scene.values.instructionsSpr
			)
		end,

		afterSceneChange = function()
			scene.values.instructionsSpr.str = scene.instructionsText()

			scene.sprites.instructions = zx:sprite(
				scene.values.instructionsSpr
			)

			cheevos:earned('chose-working-mower')
		end,

		onUpdate = function()
			if scene.btn.error then
				zx:beep(.5, 5)
			end
		end,

		onBtnRelease = function(released)
			if scene.btn.error and scene.btn.state == 0 then
				scene.btn.error = false
			end
		end,

		onBtnPress = function(pressed)
			if scene.btn.state == pd.kButtonA then
				showGameScreen()
			else
				scene.btn.error = true
			end
		end,

		onCrankDocked = function()
			scene.updateInstructions()
		end,

		onCrankUndocked = function()
			scene.updateInstructions()
		end,
	})
end

function showGameScreen()
	setSceneTo('game', {
		sprites = {
			sky = als:sprSky(),
			grass = als:sprGrass(),
			mower = als:sprMower(),
		},

		values = {
			mowDelay = 0,
			mowed = false,
		},

		onUpdate = function()
			if not als.grass.mowable then
				return
			end

			if als.motor.engaged then
				scene.values.mowDelay += 1

				if scene.values.mowDelay > 2 then
					scene.values.mowDelay = 0
					scene.values.mowed = true
				end
			end

			if not scene.values.mowed then
				return
			end

			-- mow the grass
			scene.sprites.grass:mow(
				als.mower.x,
				als.mower.y
			)

			-- update the mower's position
			scene.sprites.mower:mow()

			if als:lawnMowed() then
				-- completed
				als:stopMotor()
				scene.sprites.mower:remove()

				scene.sprites.wellMown = zx:sprite({
					str = 'well-mown',
					y = 9,
					centered = 1,
					ink = 'white',
					paper = 'black',
				})

				zx.beeper.stop()
				zx:beep(.5, 12)

				zx:pause(
					30,
					showCompletedScreen
				)
			elseif als:killed() then
				-- killed
				als:stopMotor()
				als.grass.mowable = false

				scene.sprites.mower.flashing = true
				scene.sprites.blood = als:sprBlood(showKilledScreen)
			end

			scene.values.mowed = false
		end,

		onBtnRelease = function(released)
			als.motor.engaged = (als.grass.mowable and scene.btn.state == pd.kButtonA)
		end,

		onBtnPress = function(pressed)
			als.motor.engaged = (als.grass.mowable and scene.btn.state == pd.kButtonA)
		end,

		onCrankChange = function(change, acceleratedChange)
			als.motor.engaged = (als.grass.mowable and change > getCrankiness())
			cheevos:earned('crank-to-mow')
		end,

		onCrankDocked = function()
			als.motor.engaged = false
		end,

		onCrankUndocked = function()
			als.motor.engaged = false
		end,

		afterSceneChange = function()
			als:rndExp()
			als:startMotor()
			als.grass.mowable = true
		end,
	})
end

function showKilledScreen()
	setSceneTo('killed', {
		sprites = {
			killed = zx:sprite({
				str = 'killed',
				y = 6.5,
				centered = 1,
			}),

			restart = zx:sprite({
				str = 'restart',
				y = 13.5,
				centered = 1,
			}),
		},

		background = .75,

		onBtnPress = function(pressed)
			if scene.btn.state == pd.kButtonA then
				showTitleScreen()
			end
		end,

		afterSceneChange = function()
			stats.deaths += 1

			als:setMenuImage(stats)

			cheevos:progressed(stats)
		end,
	})
end

function showCompletedScreen()
	setSceneTo('completed', {
		sprites = {
			restart = zx:sprite({
				str = 'restart',
				y = 13.5,
				centered = 1,
				ink = 'white',
			}),
		},

		timers = {
			scrollTimer = {
				duration = zx:getFrameMs(4),
				callback = function()
					scene.sprites.scrollingMessage:scroll(-1)
				end,
				settings = {
					repeats = true,
					discardOnCompletion = false,
				},
			},
		},

		background = 0,

		onBtnPress = function(pressed)
			if scene.btn.state == pd.kButtonA then
				showTitleScreen()
			end
		end,

		afterSceneChange = function()
			local msg =  math.random(1, 10)

			scene.sprites.scrollingMessage = als:scrollingMessage(
				msg,
				2,
				7,
				21
			),

			gfx.pushContext(backgroundImage)

			zx:ink('white')

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

			zx:ink('black')

			gfx.popContext()

			-- get a mow rating & update the stats
			local mowRating = als:getMowRating(msg)
			stats[mowRating] += 1

			als:setMenuImage(stats)

			-- update the achievements
			cheevos:earned('mow-rating-' .. msg)
			cheevos:progressed(stats)
		end,
	})
end

function showCreditsScreen()
	setSceneTo('credits', {
		sprites = {
			zx:sprite({
				str = 'credits-title',
				x = 1,
				y = 0.5,
				bordered = true,
				flashing = true,
				paper = 'black',
				ink = 'white',
			}),

			zx:sprite({
				str = 'credits',
				x = 1,
				y = 4.5,
			}),

			zx:sprite({
				str = 'return',
				y = 13.5,
				centered = 1,
			}),
		},

		onUpdate = function()
			if scene.btn.error then
				zx:beep(.5, 5)
			end
		end,

		onBtnRelease = function(released)
			if scene.btn.error and scene.btn.state == 0 then
				scene.btn.error = false
			end
		end,

		onBtnPress = function(pressed)
			if scene.btn.state == pd.kButtonB then
				showTitleScreen()
			else
				scene.btn.error = true
			end
		end,

		afterSceneChange = function()
			cheevos:earned('credits')
		end,
	})

end

----------------------------------------------------------------------------------------------------
-- SYSTEM
----------------------------------------------------------------------------------------------------

function getCrankiness()
	return 40 * (clamp(config.crankiness, 1, 4) / 4)
end

function addMenus()
	local menu = pd.getSystemMenu()

	menu:addCheckmarkMenuItem(
		gfx.getLocalizedText('menu-item-beeper'),
		config.beeper,
		function(value)
			config.beeper = value and 1 or 0
			zx.beeper.enabled(config.beeper)
		end
	)

	menu:addOptionsMenuItem(
		gfx.getLocalizedText('menu-item-crankiness'),
		{1, 2, 3, 4},
		config.crankiness,
		function(value)
			config.crankiness = tonumber(value) - 1
		end
	)

	if type(debugMode) == 'function' then
		menu:addCheckmarkMenuItem(
			gfx.getLocalizedText('menu-item-debug'),
			debugMode(),
			function(value)
				debugMode(value)
			end
		)
	end
end

scn.setRefreshRate(30)

function pd.update()
	spr.update()
	pd.timer.updateTimers()

	if type(scene.onUpdate) == 'function' then
		scene.onUpdate()
	end

	if type(debugMode) == 'function' and debugMode() then
		pd.drawFPS(385, 0)
	end
end

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
	cranked = updateSceneCranked,
})

----------------------------------------------------------------------------------------------------
-- INITIALISATION
----------------------------------------------------------------------------------------------------

loadConfig()
loadStats()
addMenus()

-- let's get this 80's mowing party started yo...
showTitleScreen()
