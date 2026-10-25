-- Ajustes generales: economía, mejoras, maestría y visitantes.

local Colors = require(script.Parent.Colors)

local Config = {}

Config.MAX_PLOTS = 12
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
		id = "auto",
		name = "Auto-Rolling",
		icon = "🤖",
		desc = "La máquina tira colores sola mientras pintas.",
		max = 1,
		cost = 1200,
		growth = 1,
	},
	{
		id = "pincel",
		name = "Pincel grande",
		icon = "🖌️",
		desc = "Trazo más ancho: coloreas mucho más rápido.",
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
	return math.max(0.6, 2.5 * 0.86 ^ (levels.velocidad or 0))
end

-- Las tiradas automáticas van algo más lentas que las manuales.
function Config.autoRollInterval(levels)
	return Config.rollInterval(levels) * 1.6
end

function Config.hasAutoRoll(levels)
	return (levels.auto or 0) >= 1
end

function Config.luck(levels)
	return 1 + 0.1 * (levels.suerte or 0)
end

-- Radio del pincel (en fracción del lienzo).
function Config.brushRadius(levels)
	return 0.05 + 0.009 * (levels.pincel or 0)
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

-- Estrellas por rapidez ---------------------------------------------------------------------
Config.STAR_BONUS = { [1] = 0, [2] = 0.1, [3] = 0.25 }

-- Tiempo "ideal" para pintar un diseño con tus mejoras.
-- Tiempo de referencia para las estrellas: lo que tarda alguien que pasa el
-- pincel a buen ritmo por toda la superficie visible del dibujo.
local SWEEP_SPEED = 0.9
function Config.parTime(design, levels)
	if Config.hasBucket(levels) then
		return 3 + #design.shapes * 0.45
	end
	local width = 2 * Config.brushRadius(levels)
	local total = 2
	for _, shape in ipairs(design.shapes) do
		if shape.visible > 0 then
			total += 0.3 + shape.visible / (width * SWEEP_SPEED)
		end
	end
	return total
end

function Config.starsFor(design, levels, elapsed)
	local par = Config.parTime(design, levels)
	if elapsed <= par * 1.5 then
		return 3
	elseif elapsed <= par * 2.5 then
		return 2
	end
	return 1
end

function Config.paintingValue(design, colors, levels, made, stars)
	local tier = Config.masteryFor(made)
	local mastery = 1 + (tier and tier.bonus or 0)
	local starBonus = 1 + (Config.STAR_BONUS[stars or 1] or 0)
	return math.floor(
		design.value * Config.colorMultiplier(design, colors) * mastery * Config.payMultiplier(levels) * starBonus
	)
end

-- Tiempo mínimo que el servidor exige para aceptar un cuadro (anti-trampas).
-- Mínimo humanamente posible (antitrampas): barrer muy rápido y sin repasar.
function Config.minPaintTime(design, levels)
	if Config.hasBucket(levels) then
		return #design.shapes * 0.08
	end
	local width = 2 * Config.brushRadius(levels)
	local area = 0
	for _, shape in ipairs(design.shapes) do
		area += shape.visible
	end
	return area * 0.85 / (width * 3.5)
end

-- Coleccionistas VIP: a veces llega uno que paga el doble.
Config.VIP_MULTIPLIER = 2
function Config.vipChance(levels)
	return 0.06 + 0.02 * (levels.fama or 0)
end

-- Misiones diarias -------------------------------------------------------------------------
Config.QuestTypes = {
	{ id = "pintar", text = "Pinta %d cuadros", one = "Pinta 1 cuadro", icon = "🎨", goals = { 2, 3, 5 } },
	{
		id = "vender",
		text = "Vende %d cuadros a visitantes",
		one = "Vende 1 cuadro a un visitante",
		icon = "🖼️",
		goals = { 1, 2, 4 },
	},
	{ id = "tirar", text = "Tira %d colores en la máquina", icon = "🎲", goals = { 15, 30, 50 } },
	{
		id = "raro",
		text = "Consigue %d colores Raros o mejores",
		one = "Consigue 1 color Raro o mejor",
		icon = "💎",
		goals = { 1, 3, 5 },
	},
	{
		id = "estrellas",
		text = "Termina %d cuadros con 3 estrellas",
		one = "Termina 1 cuadro con 3 estrellas",
		icon = "⭐",
		goals = { 1, 2, 3 },
	},
	{ id = "ganar", text = "Gana %d monedas", icon = "💵", goals = { 150, 400, 900 }, scale = true },
}
Config.QuestById = {}
for _, quest in ipairs(Config.QuestTypes) do
	Config.QuestById[quest.id] = quest
end
Config.QUESTS_PER_DAY = 3

-- Las metas de monedas y las recompensas crecen con tu nivel de diseños.
function Config.questScale(openLevel)
	return 1.8 ^ ((openLevel or 1) - 1)
end

function Config.questText(quest)
	local def = Config.QuestById[quest.id]
	if not def then
		return "?"
	end
	if quest.goal == 1 and def.one then
		return def.one
	end
	return string.format(def.text, quest.goal)
end

-- Tutorial ---------------------------------------------------------------------------------
Config.Tutorial = {
	{ text = "Ve a la máquina de colores y tira 3 veces", target = "machine", goal = 3 },
	{ text = "Ve a la mesa de dibujo y empieza un cuadro", target = "easel", goal = 1 },
	{ text = "Colorea el dibujo pasando el pincel", target = nil, goal = 1 },
	{ text = "Expón tu cuadro en la galería", target = nil, goal = 1 },
	{ text = "Espera a que un visitante compre tu cuadro", target = "gallery", goal = 1 },
}
Config.TUTORIAL_REWARD = 150

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
