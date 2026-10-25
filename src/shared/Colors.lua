-- Catálogo de pinturas. Las básicas son infinitas; el resto sale de la máquina
-- de colores con una rareza que multiplica el valor del cuadro.

local Colors = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Colors.Rarities = {
	{ id = "comun", name = "Común", mult = 1.1, weight = 58, color = rgb(160, 160, 175) },
	{ id = "pococomun", name = "Poco común", mult = 1.3, weight = 26, color = rgb(70, 190, 110) },
	{ id = "raro", name = "Raro", mult = 1.6, weight = 11, color = rgb(70, 140, 250) },
	{ id = "epico", name = "Épico", mult = 2.2, weight = 4, color = rgb(160, 90, 250) },
	{ id = "legendario", name = "Legendario", mult = 3.5, weight = 0.9, color = rgb(250, 170, 30) },
	{ id = "mitico", name = "Mítico", mult = 6, weight = 0.1, color = rgb(255, 80, 170) },
}
Colors.RarityById = {}
for index, rarity in ipairs(Colors.Rarities) do
	rarity.index = index
	Colors.RarityById[rarity.id] = rarity
end
Colors.BASIC_RARITY = { id = "basico", name = "Básico", mult = 1, index = 0, color = rgb(190, 175, 165) }

-- color: un solo Color3. gradient: varios Color3 (se pinta con degradado).
Colors.List = {
	-- Básicos (infinitos)
	{ id = "blanco", name = "Blanco", basic = true, color = rgb(255, 255, 255) },
	{ id = "crema", name = "Crema", basic = true, color = rgb(255, 244, 222) },
	{ id = "gris", name = "Gris", basic = true, color = rgb(170, 172, 185) },
	{ id = "negro", name = "Carbón", basic = true, color = rgb(62, 54, 72) },
	{ id = "rojo", name = "Rojo", basic = true, color = rgb(238, 78, 86) },
	{ id = "naranja", name = "Naranja", basic = true, color = rgb(255, 156, 64) },
	{ id = "amarillo", name = "Amarillo", basic = true, color = rgb(255, 214, 80) },
	{ id = "durazno", name = "Durazno", basic = true, color = rgb(255, 205, 170) },
	{ id = "verde", name = "Verde", basic = true, color = rgb(110, 200, 100) },
	{ id = "verdeoscuro", name = "Verde pino", basic = true, color = rgb(52, 140, 92) },
	{ id = "celeste", name = "Celeste", basic = true, color = rgb(140, 210, 250) },
	{ id = "azul", name = "Azul", basic = true, color = rgb(70, 125, 230) },
	{ id = "marino", name = "Azul noche", basic = true, color = rgb(46, 54, 116) },
	{ id = "morado", name = "Morado", basic = true, color = rgb(160, 104, 226) },
	{ id = "rosa", name = "Rosa", basic = true, color = rgb(255, 150, 196) },
	{ id = "cafe", name = "Café", basic = true, color = rgb(150, 98, 64) },

	-- Común
	{ id = "coco", name = "Leche de coco", rarity = "comun", color = rgb(250, 246, 236) },
	{ id = "arena", name = "Arena", rarity = "comun", color = rgb(232, 210, 168) },
	{ id = "mentasuave", name = "Menta suave", rarity = "comun", color = rgb(184, 240, 214) },
	{ id = "cieloclaro", name = "Cielo claro", rarity = "comun", color = rgb(196, 230, 255) },
	{ id = "lavanda", name = "Lavanda", rarity = "comun", color = rgb(214, 198, 248) },
	{ id = "algodon", name = "Algodón rosa", rarity = "comun", color = rgb(255, 206, 226) },
	{ id = "limonada", name = "Limonada", rarity = "comun", color = rgb(255, 244, 150) },
	{ id = "mantequilla", name = "Mantequilla", rarity = "comun", color = rgb(255, 228, 160) },

	-- Poco común
	{ id = "coral", name = "Coral", rarity = "pococomun", color = rgb(255, 128, 110) },
	{ id = "pistacho", name = "Pistacho", rarity = "pococomun", color = rgb(196, 226, 140) },
	{ id = "turquesa", name = "Turquesa", rarity = "pococomun", color = rgb(64, 206, 196) },
	{ id = "mostaza", name = "Mostaza", rarity = "pococomun", color = rgb(222, 176, 40) },
	{ id = "ciruela", name = "Ciruela", rarity = "pococomun", color = rgb(140, 64, 120) },
	{ id = "terracota", name = "Terracota", rarity = "pococomun", color = rgb(204, 106, 72) },
	{ id = "salvia", name = "Salvia", rarity = "pococomun", color = rgb(150, 182, 150) },

	-- Raro
	{ id = "arandano", name = "Arándano negro", rarity = "raro", color = rgb(78, 66, 140) },
	{ id = "esmeralda", name = "Esmeralda", rarity = "raro", color = rgb(30, 170, 110) },
	{ id = "zafiro", name = "Zafiro", rarity = "raro", color = rgb(36, 84, 200) },
	{ id = "cereza", name = "Cereza", rarity = "raro", color = rgb(200, 30, 70) },
	{ id = "mandarina", name = "Mandarina", rarity = "raro", color = rgb(255, 120, 20) },
	{ id = "helecho", name = "Helecho dorado", rarity = "raro", color = rgb(140, 190, 60) },

	-- Épico
	{
		id = "lava",
		name = "Flujo de lava",
		rarity = "epico",
		gradient = { rgb(255, 210, 60), rgb(255, 90, 30), rgb(170, 20, 40) },
	},
	{
		id = "aurora",
		name = "Aurora boreal",
		rarity = "epico",
		gradient = { rgb(80, 240, 180), rgb(80, 160, 250), rgb(180, 100, 250) },
	},
	{
		id = "oceano",
		name = "Océano profundo",
		rarity = "epico",
		gradient = { rgb(60, 200, 240), rgb(30, 90, 200), rgb(20, 40, 110) },
	},
	{
		id = "cobre",
		name = "Hervidor de cobre",
		rarity = "epico",
		gradient = { rgb(250, 190, 140), rgb(200, 110, 60), rgb(140, 70, 40) },
	},

	-- Legendario
	{
		id = "oro",
		name = "Oro puro",
		rarity = "legendario",
		gradient = { rgb(255, 236, 140), rgb(240, 180, 40), rgb(255, 230, 120), rgb(200, 140, 20) },
	},
	{
		id = "plata",
		name = "Plata lunar",
		rarity = "legendario",
		gradient = { rgb(250, 252, 255), rgb(170, 180, 200), rgb(235, 240, 250), rgb(140, 150, 175) },
	},
	{
		id = "atardecer",
		name = "Atardecer",
		rarity = "legendario",
		gradient = { rgb(255, 220, 110), rgb(255, 130, 120), rgb(170, 90, 200) },
	},

	-- Mítico
	{
		id = "arcoiris",
		name = "Arcoíris",
		rarity = "mitico",
		gradient = {
			rgb(255, 90, 110),
			rgb(255, 180, 60),
			rgb(255, 235, 80),
			rgb(90, 220, 120),
			rgb(80, 160, 255),
			rgb(170, 100, 255),
		},
	},
	{
		id = "galaxia",
		name = "Galaxia",
		rarity = "mitico",
		gradient = { rgb(30, 20, 80), rgb(120, 50, 200), rgb(255, 110, 200), rgb(60, 40, 140) },
	},
}

Colors.ById = {}
Colors.ByRarity = {}
for index, entry in ipairs(Colors.List) do
	entry.index = index
	Colors.ById[entry.id] = entry
	if entry.rarity then
		Colors.ByRarity[entry.rarity] = Colors.ByRarity[entry.rarity] or {}
		table.insert(Colors.ByRarity[entry.rarity], entry)
	end
end

function Colors.rarityOf(entry)
	if not entry or entry.basic then
		return Colors.BASIC_RARITY
	end
	return Colors.RarityById[entry.rarity]
end

function Colors.multiplier(id)
	local entry = Colors.ById[id]
	return entry and Colors.rarityOf(entry).mult or 1
end

-- Color "principal" (para bordes, partículas, etc.).
function Colors.mainColor(id)
	local entry = Colors.ById[id]
	if not entry then
		return rgb(255, 255, 255)
	end
	if entry.gradient then
		return entry.gradient[math.ceil(#entry.gradient / 2)]
	end
	return entry.color
end

-- ColorSequence para UIGradient (blanco si es color liso).
function Colors.sequence(id)
	local entry = Colors.ById[id]
	if entry and entry.gradient then
		local keypoints = {}
		local count = #entry.gradient
		for i, color in ipairs(entry.gradient) do
			table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (count - 1), color))
		end
		return ColorSequence.new(keypoints)
	end
	return ColorSequence.new(Color3.new(1, 1, 1))
end

-- Tirada de la máquina: suerte > 1 favorece las rarezas altas.
function Colors.roll(luck, random)
	local total = 0
	local weights = {}
	for i, rarity in ipairs(Colors.Rarities) do
		local weight = rarity.weight * luck ^ (i - 1)
		weights[i] = weight
		total += weight
	end
	local pick = random:NextNumber() * total
	local chosen = Colors.Rarities[1]
	for i, rarity in ipairs(Colors.Rarities) do
		pick -= weights[i]
		if pick <= 0 then
			chosen = rarity
			break
		end
	end
	local options = Colors.ByRarity[chosen.id]
	return options[random:NextInteger(1, #options)]
end

-- Probabilidad (0..1) de cada rareza con una suerte dada.
function Colors.chances(luck)
	local total = 0
	local weights = {}
	for i, rarity in ipairs(Colors.Rarities) do
		weights[i] = rarity.weight * luck ^ (i - 1)
		total += weights[i]
	end
	local result = {}
	for i, rarity in ipairs(Colors.Rarities) do
		result[rarity.id] = weights[i] / total
	end
	return result
end

return Colors
