-- Catálogo de pinturas. Las básicas son infinitas; el resto sale de la máquina
-- de colores con una rareza que multiplica el valor del cuadro.

local Colors = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Colors.Rarities = {
	{ id = "comun", name = "Común", finish = "Mate", mult = 1.1, weight = 58, color = rgb(150, 156, 172) },
	{ id = "pococomun", name = "Poco común", finish = "Satinado", mult = 1.3, weight = 26, color = rgb(52, 188, 116) },
	{ id = "raro", name = "Raro", finish = "Brillante", mult = 1.6, weight = 11, color = rgb(64, 140, 240) },
	{ id = "epico", name = "Épico", finish = "Degradado", mult = 2.2, weight = 4, color = rgb(150, 86, 240) },
	{
		id = "legendario",
		name = "Legendario",
		finish = "Metálico",
		mult = 3.5,
		weight = 0.9,
		color = rgb(250, 170, 30),
	},
	{ id = "mitico", name = "Mítico", finish = "Mágico", mult = 6, weight = 0.1, color = rgb(236, 64, 110) },
}
Colors.RarityById = {}
for index, rarity in ipairs(Colors.Rarities) do
	rarity.index = index
	Colors.RarityById[rarity.id] = rarity
end
Colors.BASIC_RARITY =
	{ id = "basico", name = "Básico", finish = "Mate", mult = 1, index = 0, color = rgb(190, 175, 165) }

-- color: un solo Color3. gradient: varios Color3 (se pinta con degradado).
-- Los nombres y tonos están pensados para combinar bien entre sí.
Colors.List = {
	-- Básicos (infinitos)
	{ id = "blanco", name = "Blanco", basic = true, color = rgb(255, 255, 255) },
	{ id = "crema", name = "Crema", basic = true, color = rgb(255, 243, 220) },
	{ id = "gris", name = "Gris", basic = true, color = rgb(168, 172, 186) },
	{ id = "negro", name = "Carbón", basic = true, color = rgb(54, 52, 68) },
	{ id = "rojo", name = "Rojo", basic = true, color = rgb(236, 70, 80) },
	{ id = "naranja", name = "Naranja", basic = true, color = rgb(255, 148, 56) },
	{ id = "amarillo", name = "Amarillo", basic = true, color = rgb(255, 210, 66) },
	{ id = "durazno", name = "Durazno", basic = true, color = rgb(255, 200, 164) },
	{ id = "verde", name = "Verde", basic = true, color = rgb(100, 196, 92) },
	{ id = "verdeoscuro", name = "Verde pino", basic = true, color = rgb(42, 132, 88) },
	{ id = "celeste", name = "Celeste", basic = true, color = rgb(126, 204, 250) },
	{ id = "azul", name = "Azul", basic = true, color = rgb(60, 118, 228) },
	{ id = "marino", name = "Azul noche", basic = true, color = rgb(40, 50, 112) },
	{ id = "morado", name = "Morado", basic = true, color = rgb(150, 96, 222) },
	{ id = "rosa", name = "Rosa", basic = true, color = rgb(255, 138, 190) },
	{ id = "cafe", name = "Café", basic = true, color = rgb(146, 94, 62) },

	-- Común: pasteles suaves (acabado mate)
	{ id = "coco", name = "Leche de coco", rarity = "comun", color = rgb(250, 246, 236) },
	{ id = "arena", name = "Arena", rarity = "comun", color = rgb(234, 212, 170) },
	{ id = "mentasuave", name = "Menta suave", rarity = "comun", color = rgb(178, 238, 210) },
	{ id = "cieloclaro", name = "Cielo claro", rarity = "comun", color = rgb(190, 228, 255) },
	{ id = "lavanda", name = "Lavanda", rarity = "comun", color = rgb(212, 196, 250) },
	{ id = "algodon", name = "Algodón rosa", rarity = "comun", color = rgb(255, 204, 226) },
	{ id = "limonada", name = "Limonada", rarity = "comun", color = rgb(255, 242, 140) },
	{ id = "mantequilla", name = "Mantequilla", rarity = "comun", color = rgb(255, 226, 156) },
	{ id = "melocoton", name = "Melocotón", rarity = "comun", color = rgb(255, 186, 150) },
	{ id = "niebla", name = "Niebla", rarity = "comun", color = rgb(204, 214, 228) },

	-- Poco común: colores vivos (acabado satinado)
	{ id = "coral", name = "Coral", rarity = "pococomun", color = rgb(255, 122, 104) },
	{ id = "pistacho", name = "Pistacho", rarity = "pococomun", color = rgb(190, 224, 128) },
	{ id = "turquesa", name = "Turquesa", rarity = "pococomun", color = rgb(48, 204, 192) },
	{ id = "mostaza", name = "Mostaza", rarity = "pococomun", color = rgb(226, 174, 32) },
	{ id = "ciruela", name = "Ciruela", rarity = "pococomun", color = rgb(140, 58, 120) },
	{ id = "terracota", name = "Terracota", rarity = "pococomun", color = rgb(206, 100, 66) },
	{ id = "salvia", name = "Salvia", rarity = "pococomun", color = rgb(142, 180, 146) },
	{ id = "frambuesa", name = "Frambuesa", rarity = "pococomun", color = rgb(228, 56, 120) },
	{ id = "petroleo", name = "Azul petróleo", rarity = "pococomun", color = rgb(22, 112, 130) },

	-- Raro: tonos joya (acabado brillante)
	{ id = "arandano", name = "Arándano negro", rarity = "raro", color = rgb(74, 60, 142) },
	{ id = "esmeralda", name = "Esmeralda", rarity = "raro", color = rgb(16, 170, 108) },
	{ id = "zafiro", name = "Zafiro", rarity = "raro", color = rgb(30, 80, 204) },
	{ id = "cereza", name = "Cereza", rarity = "raro", color = rgb(204, 24, 66) },
	{ id = "mandarina", name = "Mandarina", rarity = "raro", color = rgb(255, 118, 14) },
	{ id = "helecho", name = "Helecho dorado", rarity = "raro", color = rgb(136, 190, 50) },
	{ id = "amatista", name = "Amatista", rarity = "raro", color = rgb(150, 70, 214) },
	{ id = "cobalto", name = "Cobalto eléctrico", rarity = "raro", color = rgb(0, 132, 255) },

	-- Épico: degradados
	{
		id = "lava",
		name = "Flujo de lava",
		rarity = "epico",
		gradient = { rgb(255, 214, 70), rgb(255, 96, 30), rgb(178, 18, 44) },
	},
	{
		id = "aurora",
		name = "Aurora boreal",
		rarity = "epico",
		gradient = { rgb(80, 244, 180), rgb(70, 160, 252), rgb(182, 96, 252) },
	},
	{
		id = "oceano",
		name = "Océano profundo",
		rarity = "epico",
		gradient = { rgb(70, 214, 244), rgb(30, 96, 206), rgb(18, 36, 110) },
	},
	{
		id = "cobre",
		name = "Hervidor de cobre",
		rarity = "epico",
		gradient = { rgb(252, 196, 146), rgb(206, 112, 58), rgb(140, 66, 36) },
	},
	{
		id = "sakura",
		name = "Flor de cerezo",
		rarity = "epico",
		gradient = { rgb(255, 228, 238), rgb(255, 156, 196), rgb(226, 84, 150) },
	},
	{
		id = "selva",
		name = "Selva tropical",
		rarity = "epico",
		gradient = { rgb(196, 244, 96), rgb(40, 176, 96), rgb(8, 92, 74) },
	},
	{
		id = "golosina",
		name = "Algodón de azúcar",
		rarity = "epico",
		gradient = { rgb(255, 184, 222), rgb(204, 180, 255), rgb(150, 220, 255) },
	},

	-- Legendario: metálicos con destello
	{
		id = "oro",
		name = "Oro puro",
		rarity = "legendario",
		gradient = { rgb(255, 240, 150), rgb(240, 180, 40), rgb(255, 234, 128), rgb(196, 136, 16) },
	},
	{
		id = "plata",
		name = "Plata lunar",
		rarity = "legendario",
		gradient = { rgb(252, 253, 255), rgb(168, 178, 200), rgb(236, 240, 250), rgb(136, 146, 172) },
	},
	{
		id = "atardecer",
		name = "Atardecer",
		rarity = "legendario",
		gradient = { rgb(255, 222, 110), rgb(255, 128, 118), rgb(168, 86, 200) },
	},
	{
		id = "rosaoro",
		name = "Oro rosa",
		rarity = "legendario",
		gradient = { rgb(255, 222, 210), rgb(232, 148, 138), rgb(255, 228, 214), rgb(186, 104, 104) },
	},
	{
		id = "nacar",
		name = "Nácar",
		rarity = "legendario",
		gradient = { rgb(255, 252, 246), rgb(224, 214, 255), rgb(212, 255, 242), rgb(255, 226, 240) },
	},

	-- Mítico: colores mágicos que se mueven
	{
		id = "arcoiris",
		name = "Arcoíris",
		rarity = "mitico",
		gradient = {
			rgb(255, 84, 108),
			rgb(255, 176, 56),
			rgb(255, 234, 76),
			rgb(84, 220, 120),
			rgb(76, 158, 255),
			rgb(168, 98, 255),
		},
	},
	{
		id = "galaxia",
		name = "Galaxia",
		rarity = "mitico",
		gradient = { rgb(26, 18, 80), rgb(118, 48, 204), rgb(255, 108, 204), rgb(56, 38, 144) },
	},
	{
		id = "fenix",
		name = "Fuego de fénix",
		rarity = "mitico",
		gradient = { rgb(255, 244, 130), rgb(255, 146, 36), rgb(234, 40, 60), rgb(150, 18, 96) },
	},
	{
		id = "holograma",
		name = "Holograma",
		rarity = "mitico",
		gradient = { rgb(120, 255, 240), rgb(255, 120, 236), rgb(255, 246, 120), rgb(120, 200, 255) },
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

function Colors.finishOf(id)
	local entry = Colors.ById[id]
	return Colors.rarityOf(entry).finish
end

local WHITE = rgb(255, 255, 255)
local BLACK = rgb(0, 0, 0)

-- Cómo se pinta un color según su acabado. Devuelve el color de fondo, el
-- degradado (UIGradient) y la animación: "shine" (destello metálico que
-- recorre la figura) o "spin" (los colores giran).
function Colors.look(id)
	local entry = Colors.ById[id]
	if not entry then
		return WHITE, ColorSequence.new(WHITE), nil
	end
	if entry.gradient then
		local animation = entry.rarity == "mitico" and "spin" or (entry.rarity == "legendario" and "shine" or nil)
		return WHITE, Colors.sequence(id), animation
	end
	local c = entry.color
	if entry.rarity == "raro" then
		-- Esmalte: reflejo marcado arriba y sombra abajo.
		return WHITE,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, c:Lerp(WHITE, 0.5)),
				ColorSequenceKeypoint.new(0.2, c:Lerp(WHITE, 0.12)),
				ColorSequenceKeypoint.new(0.55, c),
				ColorSequenceKeypoint.new(1, c:Lerp(BLACK, 0.2)),
			}),
			nil
	elseif entry.rarity == "pococomun" then
		-- Satinado: un brillo suave.
		return WHITE,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, c:Lerp(WHITE, 0.2)),
				ColorSequenceKeypoint.new(0.6, c),
				ColorSequenceKeypoint.new(1, c:Lerp(BLACK, 0.08)),
			}),
			nil
	end
	return c, ColorSequence.new(WHITE), nil
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

-- Tirada de la máquina: suerte > 1 favorece las rarezas altas. Con minIndex
-- solo pueden salir rarezas de ese nivel o mejores (tirada garantizada).
function Colors.roll(luck, random, minIndex)
	minIndex = minIndex or 1
	local total = 0
	local weights = {}
	for i, rarity in ipairs(Colors.Rarities) do
		local weight = i >= minIndex and rarity.weight * luck ^ (i - 1) or 0
		weights[i] = weight
		total += weight
	end
	local pick = random:NextNumber() * total
	local chosen = Colors.Rarities[minIndex]
	for i, rarity in ipairs(Colors.Rarities) do
		if weights[i] > 0 then
			pick -= weights[i]
			if pick <= 0 then
				chosen = rarity
				break
			end
		end
	end
	local options = Colors.ByRarity[chosen.id]
	return options[random:NextInteger(1, #options)]
end

-- Mezclador: varios colores de una rareza se convierten en uno de la rareza
-- siguiente. Cuántos hacen falta según la rareza de partida.
Colors.MixCost = { comun = 3, pococomun = 3, raro = 4, epico = 4, legendario = 5 }

-- Color que sale de una mezcla (la mitad de las veces, uno que aún no tienes).
function Colors.mix(rarityId, random, discovered)
	local rarity = Colors.RarityById[rarityId]
	local nextRarity = rarity and Colors.Rarities[rarity.index + 1]
	if not nextRarity then
		return nil
	end
	local options = Colors.ByRarity[nextRarity.id]
	local fresh = {}
	for _, entry in ipairs(options) do
		if not (discovered and discovered[entry.id]) then
			table.insert(fresh, entry)
		end
	end
	if #fresh > 0 and random:NextNumber() < 0.5 then
		return fresh[random:NextInteger(1, #fresh)]
	end
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
