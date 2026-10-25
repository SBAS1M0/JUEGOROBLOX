-- Ajustes generales del juego: economía, mejoras, clientes y modos de pedido.

local Config = {}

Config.GRID = 16
Config.CELLS = Config.GRID * Config.GRID
Config.MAX_PLOTS = 6
Config.GALLERY_SIZE = 7

Config.START_COINS = 50
Config.AUTOSAVE_SECONDS = 90
Config.DAILY_COOLDOWN = 20 * 60 * 60

-- Paciencia: mientras pintas el pedido el cliente espera mucho más tranquilo.
Config.PAINTING_PATIENCE_RATE = 0.3
Config.BASE_SPAWN_INTERVAL = 13
Config.MIN_SPAWN_INTERVAL = 4
Config.BASE_QUEUE = 3
Config.MAX_QUEUE = 5

Config.VIP_MULTIPLIER = 2.5
Config.STREAK_BONUS = 0.05
Config.MAX_STREAK_BONUS = 0.5

-- Calidad mínima para cada estrella (0 a 1).
Config.STAR_THRESHOLDS = { 0.5, 0.8, 0.97 }
Config.STAR_PAY = { [0] = 0.25, [1] = 0.6, [2] = 0.85, [3] = 1.15 }

function Config.xpToNext(level)
	return math.floor(40 * level ^ 1.3)
end

-- Modos de pedido -------------------------------------------------------------
Config.Modes = {
	original = {
		name = "Original",
		icon = "🖼️",
		color = Color3.fromRGB(124, 92, 255),
		pay = 1,
		level = 1,
		weight = 5,
	},
	remix = {
		name = "Remix",
		icon = "🔀",
		color = Color3.fromRGB(255, 105, 180),
		pay = 1.25,
		level = 2,
		weight = 3,
	},
	tema = {
		name = "Temática",
		icon = "🎨",
		color = Color3.fromRGB(255, 160, 40),
		pay = 1.2,
		level = 3,
		weight = 3,
	},
	libre = {
		name = "Libre",
		icon = "✨",
		color = Color3.fromRGB(40, 190, 140),
		pay = 0.95,
		level = 1,
		weight = 2,
	},
}
Config.ModeOrder = { "original", "remix", "tema", "libre" }

Config.Themes = {
	{ id = "calidos", name = "colores cálidos", keys = "roytulmw" },
	{ id = "frios", name = "colores fríos", keys = "cbnpvdgsw" },
	{ id = "pastel", name = "tonos pastel", keys = "lstwcvy" },
	{ id = "noche", name = "una noche mágica", keys = "nbpsyaw" },
	{ id = "bosque", name = "tonos de bosque", keys = "gdvuyto" },
}
Config.ThemeById = {}
for _, theme in ipairs(Config.Themes) do
	Config.ThemeById[theme.id] = theme
end

-- Mejoras ---------------------------------------------------------------------
Config.Upgrades = {
	{
		id = "precio",
		name = "Precios de Artista",
		icon = "💰",
		desc = "Cada obra se vende más cara.",
		max = 15,
		cost = 60,
		growth = 1.42,
	},
	{
		id = "paciencia",
		name = "Sillones Cómodos",
		icon = "🛋️",
		desc = "Los clientes esperan más tiempo.",
		max = 10,
		cost = 80,
		growth = 1.5,
	},
	{
		id = "fama",
		name = "Fama de la Galería",
		icon = "⭐",
		desc = "Llegan clientes más rápido y caben más en la fila.",
		max = 10,
		cost = 120,
		growth = 1.55,
	},
	{
		id = "propinas",
		name = "Servicio Veloz",
		icon = "⚡",
		desc = "Propinas más grandes si entregas rápido.",
		max = 10,
		cost = 100,
		growth = 1.5,
	},
	{
		id = "vip",
		name = "Alfombra Roja",
		icon = "👑",
		desc = "Más clientes VIP que pagan x2.5.",
		max = 10,
		cost = 220,
		growth = 1.6,
	},
	{
		id = "pincel",
		name = "Pinceles Gruesos",
		icon = "🖌️",
		desc = "Desbloquea pinceles de 2x2 y 3x3.",
		max = 2,
		cost = 300,
		growth = 3,
	},
	{
		id = "decoracion",
		name = "Decoración",
		icon = "🪴",
		desc = "Embellece tu galería: +6% de pago por nivel.",
		max = 6,
		cost = 180,
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

-- Efectos de las mejoras (usados por servidor y cliente).
function Config.payMultiplier(levels)
	return (1 + 0.12 * (levels.precio or 0)) * (1 + 0.06 * (levels.decoracion or 0))
end

function Config.patienceMultiplier(levels)
	return 1 + 0.12 * (levels.paciencia or 0)
end

function Config.spawnInterval(levels)
	return math.max(Config.MIN_SPAWN_INTERVAL, Config.BASE_SPAWN_INTERVAL * 0.9 ^ (levels.fama or 0))
end

function Config.maxQueue(levels)
	return math.min(Config.MAX_QUEUE, Config.BASE_QUEUE + math.floor((levels.fama or 0) / 4))
end

function Config.tipMultiplier(levels)
	return 0.25 + 0.15 * (levels.propinas or 0)
end

function Config.vipChance(levels)
	return 0.04 + 0.03 * (levels.vip or 0)
end

function Config.brushSizes(levels)
	local sizes = { 1 }
	for i = 1, levels.pincel or 0 do
		table.insert(sizes, i + 1)
	end
	return sizes
end

-- Clientes ----------------------------------------------------------------------
Config.CustomerNames = {
	"Lucía",
	"Mateo",
	"Sofía",
	"Diego",
	"Valentina",
	"Leo",
	"Camila",
	"Hugo",
	"Martina",
	"Bruno",
	"Isabella",
	"Thiago",
	"Emma",
	"Gael",
	"Olivia",
	"Nico",
	"Abril",
	"Tomás",
	"Zoe",
	"Iker",
	"Renata",
	"Dante",
	"Mía",
	"Lautaro",
}

Config.CustomerColors = {
	Color3.fromRGB(255, 170, 170),
	Color3.fromRGB(255, 205, 140),
	Color3.fromRGB(255, 236, 140),
	Color3.fromRGB(170, 230, 160),
	Color3.fromRGB(150, 210, 255),
	Color3.fromRGB(200, 170, 255),
	Color3.fromRGB(255, 170, 220),
	Color3.fromRGB(160, 235, 220),
}

Config.HappyLines = {
	"¡Es una obra maestra! 😍",
	"¡Me encanta! ❤️",
	"¡Wow, qué talento! ✨",
	"¡Perfecto, volveré pronto! 😄",
	"¡La colgaré en mi sala! 🖼️",
}
Config.OkLines = { "Está bonito 🙂", "No está mal 👍", "Gracias, me sirve 😊" }
Config.SadLines = { "Mmm... no es lo que pedí 😕", "Esperaba algo mejor 😐" }
Config.AngryLines = { "¡Me cansé de esperar! 😤", "¡Qué lento! 😠", "Me voy a otra galería 🙄" }

return Config
