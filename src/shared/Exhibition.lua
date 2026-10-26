-- Sala de exposición: salas que se amplían, huecos donde se compran stands,
-- calidades de stand, precio medio de mercado y cómo deciden los compradores.

local Exhibition = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Salas ---------------------------------------------------------------------------------
-- La sala principal viene abierta; las demás se construyen con dinero cuando
-- ya tienes suficientes stands.
Exhibition.Rooms = {
	{ id = 1, name = "Sala principal", cost = 0, needStands = 0 },
	{ id = 2, name = "Sala del jardín", cost = 2500, needStands = 6 },
	{ id = 3, name = "Sala de los maestros", cost = 30000, needStands = 14 },
}

-- Huecos para stands (coordenadas del terreno). kind "floor": stand de pie;
-- kind "wall": marco en la pared. rot: giro en grados (0 = el cuadro mira a -Z).
Exhibition.Spots = {
	-- Sala principal
	{ room = 1, kind = "floor", x = -30, z = 5, rot = 0 },
	{ room = 1, kind = "floor", x = -14, z = 5, rot = 0 },
	{ room = 1, kind = "wall", x = -34, z = 16.6, rot = 0 },
	{ room = 1, kind = "wall", x = -10, z = 16.6, rot = 0 },
	{ room = 1, kind = "wall", x = -38.6, z = 9, rot = -90 },
	{ room = 1, kind = "wall", x = -38.6, z = -6, rot = -90 },
	{ room = 1, kind = "wall", x = -5.4, z = 11, rot = 90 },
	{ room = 1, kind = "wall", x = -5.4, z = 0, rot = 90 },
	-- Sala del jardín
	{ room = 2, kind = "floor", x = -28, z = 34, rot = 0 },
	{ room = 2, kind = "floor", x = -16, z = 34, rot = 0 },
	{ room = 2, kind = "wall", x = -29, z = 46.6, rot = 0 },
	{ room = 2, kind = "wall", x = -15, z = 46.6, rot = 0 },
	{ room = 2, kind = "wall", x = -38.6, z = 23, rot = -90 },
	{ room = 2, kind = "wall", x = -38.6, z = 42, rot = -90 },
	{ room = 2, kind = "wall", x = -5.4, z = 25, rot = 90 },
	{ room = 2, kind = "wall", x = -5.4, z = 42, rot = 90 },
	-- Sala de los maestros
	{ room = 3, kind = "floor", x = -55, z = 32, rot = -90 },
	{ room = 3, kind = "wall", x = -64, z = 46.6, rot = 0 },
	{ room = 3, kind = "wall", x = -55, z = 46.6, rot = 0 },
	{ room = 3, kind = "wall", x = -46, z = 46.6, rot = 0 },
	{ room = 3, kind = "wall", x = -69.6, z = 24, rot = -90 },
	{ room = 3, kind = "wall", x = -69.6, z = 36, rot = -90 },
	{ room = 3, kind = "wall", x = -58, z = 18.4, rot = 180 },
	{ room = 3, kind = "wall", x = -46, z = 18.4, rot = 180 },
}
Exhibition.SPOT_COUNT = #Exhibition.Spots

function Exhibition.roomOf(spot)
	local def = Exhibition.Spots[spot]
	return def and def.room or 1
end

-- Stands -----------------------------------------------------------------------------------
-- Tres calidades: cuanto mejor luce el cuadro, más pagan los visitantes.
Exhibition.Tiers = {
	{ id = 1, wall = "Marco sencillo", floor = "Caballete", bonus = 0 },
	{ id = 2, wall = "Marco de galería", floor = "Panel de galería", bonus = 0.15 },
	{ id = 3, wall = "Marco dorado", floor = "Vitrina de lujo", bonus = 0.35 },
}
Exhibition.MAX_TIER = #Exhibition.Tiers
Exhibition.FREE_STANDS = 1

function Exhibition.tierName(spot, tier)
	local def = Exhibition.Spots[spot]
	local info = Exhibition.Tiers[math.clamp(tier or 1, 1, Exhibition.MAX_TIER)]
	return def and def.kind == "wall" and info.wall or info.floor
end

function Exhibition.tierBonus(tier)
	local info = Exhibition.Tiers[tier or 1]
	return info and info.bonus or 0
end

function Exhibition.countStands(stands)
	local owned = 0
	for _, tier in ipairs(stands or {}) do
		if tier > 0 then
			owned += 1
		end
	end
	return owned
end

-- Precio del siguiente stand (el primero es gratis).
function Exhibition.standCost(owned)
	if owned < Exhibition.FREE_STANDS then
		return 0
	end
	return math.floor(50 * 1.42 ^ (owned - Exhibition.FREE_STANDS) / 5 + 0.5) * 5
end

-- Mejorar un stand de la calidad tier a la siguiente.
function Exhibition.upgradeCost(tier, room)
	local base = tier <= 1 and 250 or 1500
	return math.floor(base * 3 ^ ((room or 1) - 1))
end

-- Precios ------------------------------------------------------------------------------------
-- Redondeo amable: de 5 en 5 a partir de 50.
function Exhibition.roundPrice(amount)
	amount = math.max(1, amount)
	if amount >= 50 then
		return math.floor(amount / 5 + 0.5) * 5
	end
	return math.floor(amount + 0.5)
end

-- Precio medio: lo que suele pagar un visitante por el cuadro en ese stand.
function Exhibition.marketPrice(value, tier)
	return Exhibition.roundPrice(value * (1 + Exhibition.tierBonus(tier)))
end

Exhibition.PRICE_MIN = 0.5
Exhibition.PRICE_MAX = 3

function Exhibition.clampPrice(price, market)
	local low = Exhibition.roundPrice(market * Exhibition.PRICE_MIN)
	local high = Exhibition.roundPrice(market * Exhibition.PRICE_MAX)
	price = tonumber(price) or market
	if price ~= price then
		price = market
	end
	return math.clamp(math.floor(price), low, high)
end

-- Paso de los botones − / + del precio.
function Exhibition.priceStep(market)
	return math.max(1, Exhibition.roundPrice(market * 0.05))
end

-- Probabilidad de que a un visitante le interese el cuadro según lo caro
-- que esté (ratio = precio / precio medio).
function Exhibition.interest(ratio)
	return math.clamp(1.55 - 0.72 * ratio, 0.08, 1)
end

Exhibition.PriceBands = {
	{ max = 0.86, short = "Ganga", text = "Ganga: se venderá volando", color = rgb(52, 188, 116) },
	{ max = 1.1, short = "Precio justo", text = "Precio justo: se venderá pronto", color = rgb(18, 168, 148) },
	{ max = 1.35, short = "Algo caro", text = "Algo caro: te harán ofertas", color = rgb(250, 176, 40) },
	{ max = 1.7, short = "Caro", text = "Caro: pocos visitantes se animarán", color = rgb(244, 140, 50) },
	{ max = math.huge, short = "Carísimo", text = "Carísimo: casi nadie lo comprará", color = rgb(236, 86, 76) },
}

function Exhibition.band(ratio)
	for _, band in ipairs(Exhibition.PriceBands) do
		if ratio <= band.max then
			return band
		end
	end
	return Exhibition.PriceBands[#Exhibition.PriceBands]
end

-- Lo máximo que está dispuesto a pagar un visitante (los VIP, mucho más).
function Exhibition.budget(market, vip, random)
	if vip then
		return market * random:NextNumber(1.7, 2.3)
	end
	return market * random:NextNumber(0.85, 1.3)
end

-- Contraoferta: a medio camino entre su oferta y tu precio.
function Exhibition.counterPrice(offer, price)
	return Exhibition.roundPrice((offer + price) / 2)
end

-- Segundos para responder a una oferta en la caja.
Exhibition.OFFER_TIME = 20
-- Con la mejora Cajero, las ofertas sin respuesta se aceptan si llegan a esto.
Exhibition.CASHIER_ACCEPT = 0.85
Exhibition.CASHIER_TIME = 8

return Exhibition
