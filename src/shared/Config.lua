-- Ajustes generales: economía, mejoras, maestría y visitantes.

local Designs = require(script.Parent.Designs)
local Colors = require(script.Parent.Colors)

local Config = {}

Config.MAX_PLOTS = 6
Config.GALLERY_SIZE = 7
Config.START_COINS = 25
Config.AUTOSAVE_SECONDS = 90
Config.DAILY_COOLDOWN = 20 * 60 * 60
Config.MAX_PAINT_STACK = 999

-- Vender en la galería (a un visitante) paga más que vender al instante.
Config.GALLERY_BONUS = 1.25
Config.QUICK_SELL = 1

-- Maestría por diseño: cuantas más veces lo pintas, más vale.
Config.Mastery = {
	{ id = "bronce", name = "Bronce", made = 3, bonus = 0.05, color = Color3.fromRGB(220, 140, 70) },
	{ id = "plata", name = "Plata", made = 8, bonus = 0.1, color = Color3.fromRGB(170, 180, 210) },
	{ id = "oro", name = "Oro", made = 20, bonus = 0.2, color = Color3.fromRGB(255, 200, 40) },
}

function Config.masteryFor(made)
	local current, nextTier = nil, Config.Mastery[1]
	for i, tier in ipairs(Config.Mastery) do
		if (made or 0) >= tier.made then
			current = tier
			nextTier = Config.Mastery[i + 1]
		end
	end
	return current, nextTier
end

-- Mejoras ------------------------------------------------------------------------------
Config.Upgrades = {
	{
		id = "suerte",
		name = "Suerte de la máquina",
		icon = "🍀",
		desc = "Más colores raros al tirar.",
		max = 12,
		cost = 80,
		growth = 1.55,
	},
	{
		id = "velocidad",
		name = "Máquina veloz",
		icon = "⚙️",
		desc = "La máquina tira colores más rápido.",
		max = 10,
		cost = 60,
		growth = 1.5,
	},
	{
		id = "pincel",
		name = "Pincel grande",
		icon = "🖌️",
		desc = "Pintas más rápido y con trazo más ancho.",
		max = 8,
		cost = 90,
		growth = 1.6,
	},
	{
		id = "cubeta",
		name = "Cubeta mágica",
		icon = "🪣",
		desc = "Rellena una figura entera con un toque.",
		max = 1,
		cost = 2500,
		growth = 1,
	},
	{
		id = "precio",
		name = "Precios de artista",
		icon = "💰",
		desc = "Tus cuadros se venden más caros.",
		max = 15,
		cost = 120,
		growth = 1.45,
	},
	{
		id = "fama",
		name = "Fama",
		icon = "⭐",
		desc = "Llegan visitantes a comprar más seguido.",
		max = 10,
		cost = 150,
		growth = 1.55,
	},
	{
		id = "paredes",
		name = "Más paredes",
		icon = "🖼️",
		desc = "Más cuadros expuestos a la venta.",
		max = 4,
		cost = 300,
		growth = 2.2,
	},
	{
		id = "decoracion",
		name = "Decoración",
		icon = "🪴",
		desc = "Embellece tu galería: +6% de valor por nivel.",
		max = 6,
		cost = 250,
		growth = 1.9,
	},
}
Config.UpgradeById = {}
for _, upgrade in ipairs(Config.Upgrades) do
	Config.UpgradeById[upgrade.id] = upgrade
end

function Config.upgradeCost(id, currentLevel)
	local upgrade = Config.UpgradeById[id]
	return math.floor(upgrade.cost * upgrade.growth ^ currentLevel)
end

function Config.rollInterval(levels)
	return math.max(0.8, 4 * 0.86 ^ (levels.velocidad or 0))
end

function Config.luck(levels)
	return 1 + 0.1 * (levels.suerte or 0)
end

function Config.brushSpeed(levels)
	return 1 + 0.3 * (levels.pincel or 0)
end

function Config.brushRadius(levels)
	return 0.035 + 0.008 * (levels.pincel or 0)
end

function Config.hasBucket(levels)
	return (levels.cubeta or 0) >= 1
end

function Config.payMultiplier(levels)
	return (1 + 0.1 * (levels.precio or 0)) * (1 + 0.06 * (levels.decoracion or 0))
end

function Config.buyerInterval(levels)
	return math.max(5, 18 * 0.88 ^ (levels.fama or 0))
end

function Config.maxBuyers(levels)
	return math.min(4, 2 + math.floor((levels.fama or 0) / 4))
end

function Config.gallerySlots(levels)
	return math.min(Config.GALLERY_SIZE, 3 + (levels.paredes or 0))
end

-- Valor de un cuadro ---------------------------------------------------------------------
-- Cada área pesa según su tamaño (raíz para que las áreas pequeñas también cuenten).
function Config.colorMultiplier(design, colors)
	local total, weighted = 0, 0
	for _, area in ipairs(design.areas) do
		local weight = math.sqrt(area.weight)
		total += weight
		weighted += weight * Colors.multiplier(colors[area.id])
	end
	return total > 0 and weighted / total or 1
end

function Config.paintingValue(design, colors, levels, made)
	local tier = Config.masteryFor(made)
	local mastery = 1 + (tier and tier.bonus or 0)
	return math.floor(design.value * Config.colorMultiplier(design, colors) * mastery * Config.payMultiplier(levels))
end

-- Tiempo mínimo que el servidor exige para aceptar un cuadro (anti-trampas).
function Config.minPaintTime(design, levels)
	if Config.hasBucket(levels) then
		return #design.shapes * 0.08
	end
	return Designs.totalTime(design) / Config.brushSpeed(levels) * 0.45
end

-- Visitantes -----------------------------------------------------------------------------
-- Si no se pueden cargar avatares de amigos se usan estos usuarios conocidos.
Config.FALLBACK_AVATARS = { 1, 156, 261, 2, 3 }

Config.BuyerLines = {
	"¡Qué belleza! Me lo llevo 😍",
	"¡Justo lo que buscaba! 💖",
	"¡Esto va en mi sala! 🖼️",
	"¡Wow, qué colores! ✨",
	"¡Lo compro ya mismo! 💰",
}

return Config
