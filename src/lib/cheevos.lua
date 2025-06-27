local pd <const> = playdate
local gfx <const> = pd.graphics

import '../vendor/PlaydateSquad/pd-achievements/achievements/achievements'

class('cheevos', {
	types = {
		'total',
		'good',
		'bad',
		'deaths',
	},

	targets = {
		16,
		128,
		1982,
		9999,
		10000,
	},

	earnables = {
		'chose-broken-mower',
		'chose-working-mower',
		'crank-to-mow',
		'mow-rating-1',
		'mow-rating-2',
		'mow-rating-3',
		'mow-rating-4',
		'mow-rating-5',
		'mow-rating-6',
		'mow-rating-7',
		'mow-rating-8',
		'mow-rating-9',
		'mow-rating-10',
		'scoreborked',
		'credits',
	}
}).extends()

function cheevos:init()
	cheevos.super.init(self)

	local items = self:generateData()

	achievements.initialize({
		cardPath = pd.metadata.imagePath .. '/banner',
		iconPath = pd.metadata.imagePath .. '/icon',
		achievements = items,
		keyed = self:generateKeyed(items),
	}, {
		forceSaveOnGrantOrRevoke = true,
		generateGrantedFromShared = true,
		preventDebug = true,
	})
end

function cheevos:generateData()
	data = {}

	for v = 1, #self.targets do
		for k = 1, #self.types do
			local type = self.types[k]
			local value = self.targets[v]
			local handle = type .. '-' .. value

			table.insert(
				data,
				{
					id = handle,
					name = gfx.getLocalizedText('achievement-name-' .. handle),
					description = gfx.getLocalizedText('achievement-desc-' .. handle),
					isSecret = ternary(value > 9999),
					progressMax = value,
					progressIsPercentage = true,
					scoreValue = 1,
				}
			)
		end
	end

	for k = 1, #self.earnables do
		local handle = self.earnables[k]

		table.insert(
			data,
			{
				id = handle,
				name = gfx.getLocalizedText('achievement-name-' .. handle),
				description = gfx.getLocalizedText('achievement-desc-' .. handle),
				isSecret = true,
				scoreValue = 0,
			}
		)
	end

	return data
end

function cheevos:generateKeyed(values)
	local keyed = {}

	for i = 1, #values do
		table.insert(
			keyed,
			values[i].id
		)
	end

	return keyed
end

function cheevos:progressed(stats)
	local total = stats.good + stats.bad + stats.deaths
	local type
	local value
	local achievementProgress

	for v = 1, #self.targets do
		for k = 1, #self.types do
			local type = self.types[k]
			local value = self.targets[v]
			local handle = type .. '-' .. value

			achievements.advanceTo(
				handle,
				ternary(
					type == 'total',
					total,
					stats[type]
				)
			)
		end
	end

	if (stats.good > 9999 and stats.bad > 9999 and stats.deaths > 9999) then
		self:earned('scoreborked')
	end

	achievements:save()
end

function cheevos:earned(handle)
	if not achievements.isGranted(handle) then
		achievements.grant(handle)
	end
end
