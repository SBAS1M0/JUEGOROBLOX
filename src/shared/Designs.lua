-- Diseños que se pintan. Cada diseño está hecho de figuras (rectángulos
-- redondeados, círculos y píldoras) sobre un lienzo cuadrado de 0 a 1.
-- Cada figura pertenece a un "área"; antes de pintar se elige un color por área.
-- Las ilustraciones son dibujos de líneas (src/shared/Drawings, generados con
-- tools/dibujos/convertir.py): cada zona cerrada por las líneas es una figura.

local DrawingData = require(script.Parent.DrawingData)
local Drawings = script.Parent:WaitForChild("Drawings")

local Designs = {}

-- Niveles especiales: nombre y nivel que hay que tener abierto para verlos.
Designs.MAIN_LEVELS = 5
Designs.LevelInfo = {
	[6] = { name = "Ilustraciones", requires = 2 },
}

function Designs.levelName(level)
	local info = Designs.LevelInfo[level]
	return info and info.name or ("Nivel " .. level)
end

-- Figuras ---------------------------------------------------------------------------
-- r: redondeo de las esquinas (0 = recto, 0.5 = círculo / píldora).
local function R(area, x, y, w, h, rot, r)
	return { area = area, x = x, y = y, w = w, h = h, rot = rot or 0, r = r or 0 }
end
local function C(area, x, y, d)
	return R(area, x, y, d, d, 0, 0.5)
end
local function P(area, x, y, w, h, rot)
	return R(area, x, y, w, h, rot, 0.5)
end
-- Destello de 4 puntas.
local function Sparkle(area, x, y, s)
	return { P(area, x, y, s, s * 0.24), P(area, x, y, s * 0.24, s) }
end
-- Corazón: un rombo y dos círculos.
local function Heart(area, x, y, s)
	return {
		R(area, x, y + s * 0.1, s * 0.6, s * 0.6, 45, 0.12),
		C(area, x - s * 0.21, y - s * 0.1, s * 0.56),
		C(area, x + s * 0.21, y - s * 0.1, s * 0.56),
	}
end
local function Ring(area, count, cx, cy, radius, w, h, r)
	local list = {}
	for i = 0, count - 1 do
		local angle = i / count * 360
		local rad = math.rad(angle)
		table.insert(list, R(area, cx + math.cos(rad) * radius, cy + math.sin(rad) * radius, w, h, angle, r))
	end
	return list
end
local function Background(area)
	return R(area, 0.5, 0.5, 1, 1)
end

-- Diseños -----------------------------------------------------------------------------
-- value: precio base de venta. price: lo que cuesta desbloquearlo.
Designs.List = {
	-- Nivel 1 ------------------------------------------------------------------------
	{
		id = "globo",
		name = "Globo Rojo",
		level = 1,
		value = 30,
		price = 0,
		areas = {
			{ id = "cielo", name = "Cielo", default = "celeste" },
			{ id = "nubes", name = "Nubes", default = "blanco" },
			{ id = "cuerda", name = "Cuerda", default = "cafe" },
			{ id = "globo", name = "Globo", default = "rojo" },
			{ id = "brillo", name = "Brillo", default = "rosa" },
		},
		shapes = {
			Background("cielo"),
			C("nubes", 0.18, 0.76, 0.2),
			C("nubes", 0.3, 0.71, 0.24),
			C("nubes", 0.42, 0.77, 0.18),
			P("nubes", 0.3, 0.81, 0.42, 0.11),
			C("nubes", 0.78, 0.24, 0.15),
			C("nubes", 0.87, 0.27, 0.12),
			P("nubes", 0.81, 0.3, 0.26, 0.08),
			R("cuerda", 0.52, 0.77, 0.014, 0.28, -6),
			P("globo", 0.5, 0.4, 0.42, 0.5),
			R("globo", 0.5, 0.655, 0.07, 0.07, 45, 0.15),
			P("brillo", 0.39, 0.3, 0.07, 0.15, 25),
		},
	},
	{
		id = "sol",
		name = "Sol Feliz",
		level = 1,
		value = 35,
		price = 60,
		areas = {
			{ id = "cielo", name = "Cielo", default = "celeste" },
			{ id = "rayos", name = "Rayos", default = "naranja" },
			{ id = "sol", name = "Sol", default = "amarillo" },
			{ id = "cara", name = "Carita", default = "cafe" },
			{ id = "mejillas", name = "Mejillas", default = "rosa" },
		},
		shapes = {
			Background("cielo"),
			Ring("rayos", 10, 0.5, 0.5, 0.31, 0.15, 0.07, 0.5),
			C("sol", 0.5, 0.5, 0.46),
			C("cara", 0.41, 0.46, 0.055),
			C("cara", 0.59, 0.46, 0.055),
			P("cara", 0.5, 0.59, 0.12, 0.045),
			C("mejillas", 0.35, 0.56, 0.08),
			C("mejillas", 0.65, 0.56, 0.08),
		},
	},
	{
		id = "taza",
		name = "Taza de Té",
		level = 1,
		value = 40,
		price = 110,
		areas = {
			{ id = "pared", name = "Pared", default = "durazno" },
			{ id = "mesa", name = "Mesa", default = "cafe" },
			{ id = "plato", name = "Plato", default = "celeste" },
			{ id = "taza", name = "Taza", default = "blanco" },
			{ id = "corazon", name = "Corazón", default = "rosa" },
			{ id = "vapor", name = "Vapor", default = "crema" },
		},
		shapes = {
			Background("pared"),
			R("mesa", 0.5, 0.88, 1, 0.24),
			C("taza", 0.7, 0.56, 0.2),
			C("pared", 0.7, 0.56, 0.1),
			P("plato", 0.47, 0.79, 0.62, 0.09),
			R("taza", 0.47, 0.59, 0.4, 0.36, 0, 0.28),
			P("taza", 0.47, 0.42, 0.44, 0.06),
			Heart("corazon", 0.47, 0.6, 0.15),
			P("vapor", 0.38, 0.25, 0.05, 0.14, 15),
			P("vapor", 0.48, 0.2, 0.05, 0.16, -10),
			P("vapor", 0.58, 0.26, 0.05, 0.13, 15),
		},
	},
	{
		id = "gatito",
		name = "Gatito",
		level = 1,
		value = 45,
		price = 170,
		areas = {
			{ id = "fondo", name = "Fondo", default = "verde" },
			{ id = "pelaje", name = "Pelaje", default = "naranja" },
			{ id = "orejas", name = "Orejas y nariz", default = "rosa" },
			{ id = "hocico", name = "Hocico", default = "blanco" },
			{ id = "ojos", name = "Ojos", default = "negro" },
		},
		shapes = {
			Background("fondo"),
			R("pelaje", 0.3, 0.32, 0.22, 0.22, 45, 0.12),
			R("pelaje", 0.7, 0.32, 0.22, 0.22, 45, 0.12),
			R("orejas", 0.3, 0.34, 0.11, 0.11, 45, 0.15),
			R("orejas", 0.7, 0.34, 0.11, 0.11, 45, 0.15),
			P("pelaje", 0.5, 0.57, 0.64, 0.5),
			P("hocico", 0.44, 0.67, 0.17, 0.13),
			P("hocico", 0.56, 0.67, 0.17, 0.13),
			C("ojos", 0.37, 0.52, 0.085),
			C("ojos", 0.63, 0.52, 0.085),
			R("orejas", 0.5, 0.61, 0.06, 0.06, 45, 0.25),
		},
	},

	-- Nivel 2 ------------------------------------------------------------------------
	{
		id = "hongo",
		name = "Hongo Mágico",
		level = 2,
		value = 110,
		price = 450,
		areas = {
			{ id = "fondo", name = "Cielo", default = "celeste" },
			{ id = "pasto", name = "Pasto", default = "verde" },
			{ id = "tallo", name = "Tallo", default = "crema" },
			{ id = "ojos", name = "Ojitos", default = "negro" },
			{ id = "sombrero", name = "Sombrero", default = "rojo" },
			{ id = "manchas", name = "Manchas", default = "blanco" },
		},
		shapes = {
			Background("fondo"),
			P("pasto", 0.5, 0.96, 1.3, 0.3),
			R("tallo", 0.5, 0.7, 0.28, 0.32, 0, 0.3),
			C("ojos", 0.44, 0.72, 0.04),
			C("ojos", 0.56, 0.72, 0.04),
			P("sombrero", 0.5, 0.42, 0.74, 0.44),
			C("manchas", 0.37, 0.33, 0.1),
			C("manchas", 0.6, 0.29, 0.08),
			C("manchas", 0.69, 0.45, 0.07),
			C("manchas", 0.47, 0.5, 0.06),
			C("manchas", 0.27, 0.48, 0.06),
		},
	},
	{
		id = "perrito",
		name = "Perrito Corgi",
		level = 2,
		value = 120,
		price = 600,
		areas = {
			{ id = "fondo", name = "Fondo", default = "amarillo" },
			{ id = "pelaje", name = "Pelaje", default = "naranja" },
			{ id = "orejas", name = "Orejas", default = "rosa" },
			{ id = "blanco", name = "Hocico", default = "blanco" },
			{ id = "ojos", name = "Ojos y nariz", default = "negro" },
			{ id = "lengua", name = "Lengua", default = "rojo" },
		},
		shapes = {
			Background("fondo"),
			R("pelaje", 0.29, 0.28, 0.25, 0.25, 45, 0.15),
			R("pelaje", 0.71, 0.28, 0.25, 0.25, 45, 0.15),
			R("orejas", 0.29, 0.31, 0.12, 0.12, 45, 0.2),
			R("orejas", 0.71, 0.31, 0.12, 0.12, 45, 0.2),
			P("pelaje", 0.5, 0.58, 0.66, 0.54),
			P("blanco", 0.5, 0.45, 0.11, 0.32),
			P("blanco", 0.5, 0.7, 0.38, 0.26),
			C("ojos", 0.36, 0.53, 0.075),
			C("ojos", 0.64, 0.53, 0.075),
			P("ojos", 0.5, 0.62, 0.11, 0.07),
			P("lengua", 0.5, 0.75, 0.07, 0.07),
		},
	},
	{
		id = "helado",
		name = "Helado Triple",
		level = 2,
		value = 130,
		price = 750,
		areas = {
			{ id = "fondo", name = "Fondo", default = "rosa" },
			{ id = "cono", name = "Cono", default = "durazno" },
			{ id = "bola1", name = "Bola izquierda", default = "verde" },
			{ id = "bola2", name = "Bola derecha", default = "celeste" },
			{ id = "bola3", name = "Bola de arriba", default = "crema" },
			{ id = "cereza", name = "Cereza", default = "rojo" },
		},
		shapes = {
			Background("fondo"),
			Sparkle("bola3", 0.15, 0.2, 0.09),
			Sparkle("bola3", 0.85, 0.72, 0.08),
			R("cono", 0.5, 0.67, 0.34, 0.34, 45, 0.06),
			C("bola1", 0.37, 0.47, 0.28),
			C("bola2", 0.63, 0.47, 0.28),
			C("bola3", 0.5, 0.31, 0.3),
			R("cereza", 0.53, 0.09, 0.012, 0.08, 20),
			C("cereza", 0.5, 0.14, 0.09),
		},
	},
	{
		id = "planeta",
		name = "Planeta Anillado",
		level = 2,
		value = 140,
		price = 900,
		areas = {
			{ id = "espacio", name = "Espacio", default = "marino" },
			{ id = "estrellas", name = "Estrellas", default = "amarillo" },
			{ id = "anillo", name = "Anillo", default = "naranja" },
			{ id = "planeta", name = "Planeta", default = "morado" },
			{ id = "franja", name = "Franja", default = "rosa" },
			{ id = "luna", name = "Luna", default = "gris" },
		},
		shapes = {
			Background("espacio"),
			Sparkle("estrellas", 0.15, 0.18, 0.1),
			Sparkle("estrellas", 0.84, 0.82, 0.08),
			Sparkle("estrellas", 0.2, 0.84, 0.06),
			Sparkle("estrellas", 0.62, 0.12, 0.06),
			P("anillo", 0.5, 0.53, 0.84, 0.15, -15),
			C("planeta", 0.5, 0.53, 0.42),
			P("franja", 0.5, 0.47, 0.36, 0.06, -15),
			P("franja", 0.52, 0.6, 0.3, 0.04, -15),
			C("luna", 0.82, 0.23, 0.13),
		},
	},

	-- Nivel 3 ------------------------------------------------------------------------
	{
		id = "estrella",
		name = "Estrella Fugaz",
		level = 3,
		value = 380,
		price = 2500,
		areas = {
			{ id = "noche", name = "Noche", default = "marino" },
			{ id = "estela1", name = "Estela larga", default = "celeste" },
			{ id = "estela2", name = "Estela media", default = "rosa" },
			{ id = "estela3", name = "Estela corta", default = "amarillo" },
			{ id = "estrella", name = "Estrella", default = "amarillo" },
			{ id = "brillos", name = "Brillos", default = "blanco" },
		},
		shapes = {
			Background("noche"),
			Sparkle("brillos", 0.18, 0.18, 0.08),
			Sparkle("brillos", 0.85, 0.75, 0.1),
			Sparkle("brillos", 0.3, 0.42, 0.06),
			Sparkle("brillos", 0.72, 0.9, 0.06),
			Sparkle("brillos", 0.1, 0.6, 0.07),
			P("estela1", 0.4, 0.62, 0.62, 0.06, -45),
			P("estela2", 0.45, 0.53, 0.5, 0.05, -45),
			P("estela3", 0.36, 0.53, 0.44, 0.045, -45),
			P("estrella", 0.66, 0.34, 0.42, 0.07),
			P("estrella", 0.66, 0.34, 0.07, 0.42),
			P("estrella", 0.66, 0.34, 0.2, 0.05, 45),
			P("estrella", 0.66, 0.34, 0.2, 0.05, -45),
			C("estrella", 0.66, 0.34, 0.08),
		},
	},
	{
		id = "koi",
		name = "Pez Koi",
		level = 3,
		value = 420,
		price = 3000,
		areas = {
			{ id = "agua", name = "Agua", default = "azul" },
			{ id = "aletas", name = "Aletas", default = "rojo" },
			{ id = "cuerpo", name = "Cuerpo", default = "naranja" },
			{ id = "manchas", name = "Manchas", default = "blanco" },
			{ id = "ojo", name = "Ojo", default = "negro" },
			{ id = "burbujas", name = "Burbujas", default = "celeste" },
		},
		shapes = {
			Background("agua"),
			R("aletas", 0.25, 0.5, 0.22, 0.22, 45, 0.15),
			P("aletas", 0.5, 0.33, 0.2, 0.09, -30),
			P("aletas", 0.5, 0.67, 0.2, 0.09, 30),
			P("cuerpo", 0.56, 0.5, 0.52, 0.3),
			P("manchas", 0.5, 0.44, 0.11, 0.07),
			P("manchas", 0.63, 0.57, 0.13, 0.07),
			C("manchas", 0.42, 0.55, 0.05),
			C("ojo", 0.73, 0.46, 0.05),
			C("burbujas", 0.86, 0.3, 0.06),
			C("burbujas", 0.9, 0.19, 0.04),
			C("burbujas", 0.83, 0.1, 0.05),
			C("burbujas", 0.15, 0.85, 0.05),
		},
	},
	{
		id = "casita",
		name = "Casita de Campo",
		level = 3,
		value = 460,
		price = 3500,
		areas = {
			{ id = "cielo", name = "Cielo", default = "celeste" },
			{ id = "sol", name = "Sol", default = "amarillo" },
			{ id = "pasto", name = "Pasto", default = "verde" },
			{ id = "techo", name = "Techo", default = "rojo" },
			{ id = "paredes", name = "Paredes", default = "crema" },
			{ id = "puerta", name = "Puerta", default = "cafe" },
			{ id = "ventanas", name = "Ventanas", default = "celeste" },
		},
		shapes = {
			Background("cielo"),
			C("sol", 0.84, 0.16, 0.17),
			R("pasto", 0.5, 0.91, 1, 0.18),
			R("techo", 0.67, 0.3, 0.07, 0.14),
			R("techo", 0.5, 0.48, 0.42, 0.42, 45, 0.05),
			R("paredes", 0.5, 0.67, 0.5, 0.32),
			R("puerta", 0.5, 0.74, 0.11, 0.18, 0, 0.25),
			R("ventanas", 0.34, 0.63, 0.1, 0.1, 0, 0.15),
			R("ventanas", 0.66, 0.63, 0.1, 0.1, 0, 0.15),
		},
	},
	{
		id = "flor",
		name = "Flor en Maceta",
		level = 3,
		value = 500,
		price = 4000,
		areas = {
			{ id = "fondo", name = "Fondo", default = "crema" },
			{ id = "tallo", name = "Tallo", default = "verde" },
			{ id = "hojas", name = "Hojas", default = "verdeoscuro" },
			{ id = "maceta", name = "Maceta", default = "naranja" },
			{ id = "petalos", name = "Pétalos", default = "rosa" },
			{ id = "centro", name = "Centro", default = "amarillo" },
		},
		shapes = {
			Background("fondo"),
			R("tallo", 0.5, 0.6, 0.04, 0.36),
			P("hojas", 0.41, 0.62, 0.17, 0.07, -30),
			P("hojas", 0.59, 0.7, 0.17, 0.07, 30),
			R("maceta", 0.5, 0.86, 0.32, 0.18, 0, 0.18),
			P("maceta", 0.5, 0.77, 0.4, 0.06),
			Ring("petalos", 6, 0.5, 0.32, 0.13, 0.2, 0.12, 0.5),
			C("centro", 0.5, 0.32, 0.14),
		},
	},

	-- Nivel 4 ------------------------------------------------------------------------
	{
		id = "cristal",
		name = "Bola de Cristal",
		level = 4,
		value = 1200,
		price = 10000,
		areas = {
			{ id = "fondo", name = "Fondo", default = "crema" },
			{ id = "marco", name = "Arco", default = "rosa" },
			{ id = "noche", name = "Noche", default = "marino" },
			{ id = "estrellas", name = "Estrellas", default = "amarillo" },
			{ id = "esfera", name = "Esfera", default = "morado" },
			{ id = "luna", name = "Media luna", default = "amarillo" },
			{ id = "soporte", name = "Soporte", default = "cafe" },
			{ id = "velas", name = "Velas", default = "blanco" },
			{ id = "llamas", name = "Llamas", default = "naranja" },
			{ id = "mantel", name = "Mantel", default = "rojo" },
		},
		shapes = {
			Background("fondo"),
			R("marco", 0.5, 0.5, 0.72, 0.84, 0, 0.5),
			R("marco", 0.5, 0.78, 0.72, 0.28),
			R("noche", 0.5, 0.51, 0.6, 0.76, 0, 0.5),
			R("noche", 0.5, 0.77, 0.6, 0.24),
			Sparkle("estrellas", 0.3, 0.27, 0.08),
			Sparkle("estrellas", 0.7, 0.27, 0.08),
			Sparkle("estrellas", 0.26, 0.48, 0.07),
			Sparkle("estrellas", 0.74, 0.48, 0.07),
			C("esfera", 0.5, 0.49, 0.36),
			C("luna", 0.55, 0.42, 0.12),
			C("esfera", 0.585, 0.395, 0.1),
			Sparkle("estrellas", 0.42, 0.56, 0.06),
			P("soporte", 0.5, 0.69, 0.24, 0.06),
			R("soporte", 0.5, 0.74, 0.08, 0.06),
			P("soporte", 0.5, 0.79, 0.3, 0.05),
			R("velas", 0.27, 0.75, 0.07, 0.13, 0, 0.12),
			R("velas", 0.73, 0.75, 0.07, 0.13, 0, 0.12),
			P("llamas", 0.27, 0.645, 0.045, 0.075),
			P("llamas", 0.73, 0.645, 0.045, 0.075),
			R("mantel", 0.5, 0.86, 0.6, 0.06),
		},
	},
	{
		id = "tetera",
		name = "Tetera Acogedora",
		level = 4,
		value = 1350,
		price = 12000,
		areas = {
			{ id = "fondo", name = "Fondo", default = "celeste" },
			{ id = "mesa", name = "Mesa", default = "cafe" },
			{ id = "tetera", name = "Tetera", default = "rosa" },
			{ id = "tapa", name = "Tapa", default = "blanco" },
			{ id = "corazones", name = "Corazones", default = "rojo" },
			{ id = "vapor", name = "Vapor", default = "blanco" },
		},
		shapes = {
			Background("fondo"),
			R("mesa", 0.5, 0.9, 1, 0.2),
			C("tetera", 0.75, 0.57, 0.22),
			C("fondo", 0.75, 0.57, 0.12),
			P("tetera", 0.25, 0.52, 0.24, 0.08, -35),
			P("tetera", 0.5, 0.62, 0.52, 0.42),
			P("tapa", 0.5, 0.42, 0.32, 0.09),
			C("tapa", 0.5, 0.35, 0.06),
			Heart("corazones", 0.5, 0.63, 0.13),
			Heart("corazones", 0.18, 0.2, 0.09),
			Heart("corazones", 0.83, 0.2, 0.09),
			P("vapor", 0.45, 0.24, 0.045, 0.12, 15),
			P("vapor", 0.55, 0.21, 0.045, 0.13, -10),
		},
	},
	{
		id = "ovillo",
		name = "Gato y Ovillo",
		level = 4,
		value = 1500,
		price = 14000,
		areas = {
			{ id = "fondo", name = "Fondo", default = "morado" },
			{ id = "suelo", name = "Suelo", default = "cafe" },
			{ id = "gato", name = "Gato", default = "gris" },
			{ id = "panza", name = "Panza", default = "blanco" },
			{ id = "orejas", name = "Orejas y nariz", default = "rosa" },
			{ id = "ojos", name = "Ojos", default = "negro" },
			{ id = "ovillo", name = "Ovillo", default = "azul" },
			{ id = "hilo", name = "Hilo", default = "celeste" },
		},
		shapes = {
			Background("fondo"),
			R("suelo", 0.5, 0.91, 1, 0.18),
			P("gato", 0.77, 0.6, 0.3, 0.08, -55),
			P("gato", 0.57, 0.7, 0.42, 0.34),
			P("panza", 0.5, 0.74, 0.2, 0.22),
			R("gato", 0.32, 0.31, 0.15, 0.15, 45, 0.12),
			R("gato", 0.54, 0.31, 0.15, 0.15, 45, 0.12),
			C("gato", 0.43, 0.43, 0.33),
			R("orejas", 0.32, 0.33, 0.07, 0.07, 45, 0.15),
			R("orejas", 0.54, 0.33, 0.07, 0.07, 45, 0.15),
			C("ojos", 0.37, 0.43, 0.05),
			C("ojos", 0.49, 0.43, 0.05),
			R("orejas", 0.43, 0.49, 0.04, 0.04, 45, 0.25),
			C("ovillo", 0.2, 0.78, 0.21),
			R("hilo", 0.2, 0.78, 0.18, 0.014, 30),
			R("hilo", 0.2, 0.78, 0.18, 0.014, -30),
			R("hilo", 0.2, 0.78, 0.014, 0.18),
			R("hilo", 0.34, 0.87, 0.2, 0.014, 12),
		},
	},
	{
		id = "castillo",
		name = "Castillo Encantado",
		level = 4,
		value = 1700,
		price = 16000,
		areas = {
			{ id = "cielo", name = "Cielo", default = "celeste" },
			{ id = "pasto", name = "Pasto", default = "verde" },
			{ id = "techos", name = "Techos", default = "morado" },
			{ id = "banderas", name = "Banderas", default = "rojo" },
			{ id = "muros", name = "Muros", default = "gris" },
			{ id = "puerta", name = "Puerta", default = "cafe" },
			{ id = "ventanas", name = "Ventanas", default = "amarillo" },
		},
		shapes = {
			Background("cielo"),
			R("pasto", 0.5, 0.92, 1, 0.16),
			R("banderas", 0.22, 0.17, 0.012, 0.12),
			R("banderas", 0.255, 0.135, 0.06, 0.04),
			R("banderas", 0.78, 0.17, 0.012, 0.12),
			R("banderas", 0.815, 0.135, 0.06, 0.04),
			R("techos", 0.22, 0.34, 0.16, 0.16, 45, 0.05),
			R("techos", 0.78, 0.34, 0.16, 0.16, 45, 0.05),
			R("muros", 0.22, 0.6, 0.17, 0.5),
			R("muros", 0.78, 0.6, 0.17, 0.5),
			R("muros", 0.32, 0.4, 0.06, 0.06),
			R("muros", 0.44, 0.4, 0.06, 0.06),
			R("muros", 0.56, 0.4, 0.06, 0.06),
			R("muros", 0.68, 0.4, 0.06, 0.06),
			R("muros", 0.5, 0.64, 0.44, 0.44),
			R("puerta", 0.5, 0.76, 0.14, 0.2, 0, 0.4),
			R("ventanas", 0.22, 0.54, 0.05, 0.09, 0, 0.5),
			R("ventanas", 0.78, 0.54, 0.05, 0.09, 0, 0.5),
			R("ventanas", 0.39, 0.56, 0.06, 0.09, 0, 0.5),
			R("ventanas", 0.61, 0.56, 0.06, 0.09, 0, 0.5),
		},
	},

	-- Nivel 5 ------------------------------------------------------------------------
	{
		id = "ballena",
		name = "Ballena Feliz",
		level = 5,
		value = 4200,
		price = 45000,
		areas = {
			{ id = "mar", name = "Mar", default = "celeste" },
			{ id = "olas", name = "Olas", default = "azul" },
			{ id = "chorro", name = "Chorro", default = "blanco" },
			{ id = "ballena", name = "Ballena", default = "marino" },
			{ id = "panza", name = "Panza", default = "crema" },
			{ id = "ojo", name = "Ojo", default = "negro" },
			{ id = "mejillas", name = "Mejillas", default = "rosa" },
		},
		shapes = {
			Background("mar"),
			P("chorro", 0.45, 0.22, 0.05, 0.16),
			P("chorro", 0.39, 0.16, 0.05, 0.11, -35),
			P("chorro", 0.51, 0.16, 0.05, 0.11, 35),
			C("chorro", 0.33, 0.11, 0.05),
			C("chorro", 0.57, 0.11, 0.05),
			R("ballena", 0.85, 0.46, 0.17, 0.17, 45, 0.2),
			P("ballena", 0.75, 0.53, 0.2, 0.08, -25),
			P("ballena", 0.47, 0.52, 0.62, 0.36),
			P("panza", 0.43, 0.61, 0.46, 0.14),
			P("ballena", 0.48, 0.72, 0.16, 0.06, 25),
			C("ojo", 0.3, 0.47, 0.055),
			C("mejillas", 0.27, 0.55, 0.06),
			C("olas", 0.1, 0.96, 0.24),
			C("olas", 0.3, 0.98, 0.24),
			C("olas", 0.5, 0.96, 0.24),
			C("olas", 0.7, 0.98, 0.24),
			C("olas", 0.9, 0.96, 0.24),
		},
	},
	{
		id = "pastel",
		name = "Pastel de Fiesta",
		level = 5,
		value = 4600,
		price = 50000,
		areas = {
			{ id = "fondo", name = "Fondo", default = "morado" },
			{ id = "confeti", name = "Confeti", default = "amarillo" },
			{ id = "plato", name = "Plato", default = "blanco" },
			{ id = "bizcocho", name = "Bizcocho", default = "durazno" },
			{ id = "crema", name = "Crema", default = "rosa" },
			{ id = "fresas", name = "Fresas", default = "rojo" },
			{ id = "velas", name = "Velas", default = "celeste" },
			{ id = "llamas", name = "Llamas", default = "naranja" },
		},
		shapes = {
			Background("fondo"),
			Sparkle("confeti", 0.13, 0.17, 0.08),
			Sparkle("confeti", 0.87, 0.2, 0.08),
			Sparkle("confeti", 0.1, 0.62, 0.06),
			Sparkle("confeti", 0.9, 0.6, 0.06),
			C("confeti", 0.22, 0.36, 0.035),
			C("confeti", 0.8, 0.4, 0.035),
			P("plato", 0.5, 0.86, 0.78, 0.08),
			R("bizcocho", 0.5, 0.72, 0.62, 0.22, 0, 0.08),
			R("bizcocho", 0.5, 0.5, 0.48, 0.2, 0, 0.08),
			P("crema", 0.5, 0.61, 0.66, 0.06),
			P("crema", 0.5, 0.4, 0.52, 0.06),
			C("crema", 0.3, 0.645, 0.05),
			C("crema", 0.5, 0.645, 0.05),
			C("crema", 0.7, 0.645, 0.05),
			C("fresas", 0.36, 0.36, 0.07),
			C("fresas", 0.64, 0.36, 0.07),
			R("velas", 0.42, 0.29, 0.035, 0.12, 0, 0.2),
			R("velas", 0.5, 0.28, 0.035, 0.14, 0, 0.2),
			R("velas", 0.58, 0.29, 0.035, 0.12, 0, 0.2),
			P("llamas", 0.42, 0.205, 0.03, 0.05),
			P("llamas", 0.5, 0.185, 0.03, 0.05),
			P("llamas", 0.58, 0.205, 0.03, 0.05),
		},
	},
	{
		id = "arcoiris",
		name = "Arcoíris",
		level = 5,
		value = 5200,
		price = 55000,
		areas = {
			{ id = "cielo", name = "Cielo", default = "celeste" },
			{ id = "banda1", name = "Banda roja", default = "rojo" },
			{ id = "banda2", name = "Banda naranja", default = "naranja" },
			{ id = "banda3", name = "Banda amarilla", default = "amarillo" },
			{ id = "banda4", name = "Banda verde", default = "verde" },
			{ id = "banda5", name = "Banda azul", default = "azul" },
			{ id = "nubes", name = "Nubes", default = "blanco" },
			{ id = "sol", name = "Sol", default = "amarillo" },
		},
		shapes = {
			Background("cielo"),
			C("sol", 0.86, 0.14, 0.14),
			C("banda1", 0.5, 0.78, 0.92),
			C("banda2", 0.5, 0.78, 0.8),
			C("banda3", 0.5, 0.78, 0.68),
			C("banda4", 0.5, 0.78, 0.56),
			C("banda5", 0.5, 0.78, 0.44),
			C("cielo", 0.5, 0.78, 0.32),
			R("cielo", 0.5, 0.94, 1, 0.32),
			C("nubes", 0.12, 0.76, 0.16),
			C("nubes", 0.22, 0.73, 0.19),
			C("nubes", 0.32, 0.78, 0.14),
			P("nubes", 0.21, 0.81, 0.36, 0.1),
			C("nubes", 0.7, 0.76, 0.15),
			C("nubes", 0.8, 0.72, 0.19),
			C("nubes", 0.9, 0.77, 0.15),
			P("nubes", 0.8, 0.81, 0.36, 0.1),
		},
	},
	{
		id = "faro",
		name = "Faro Nocturno",
		level = 5,
		value = 6000,
		price = 60000,
		areas = {
			{ id = "noche", name = "Noche", default = "marino" },
			{ id = "estrellas", name = "Estrellas", default = "amarillo" },
			{ id = "luz", name = "Haz de luz", default = "amarillo" },
			{ id = "mar", name = "Mar", default = "azul" },
			{ id = "rocas", name = "Rocas", default = "gris" },
			{ id = "faro", name = "Faro", default = "blanco" },
			{ id = "rayas", name = "Rayas", default = "rojo" },
			{ id = "lampara", name = "Lámpara", default = "naranja" },
		},
		shapes = {
			Background("noche"),
			Sparkle("estrellas", 0.12, 0.15, 0.07),
			Sparkle("estrellas", 0.3, 0.08, 0.05),
			Sparkle("estrellas", 0.85, 0.42, 0.06),
			Sparkle("estrellas", 0.1, 0.45, 0.05),
			C("estrellas", 0.82, 0.12, 0.12),
			C("noche", 0.85, 0.1, 0.1),
			P("luz", 0.3, 0.26, 0.42, 0.07, 12),
			P("luz", 0.72, 0.26, 0.42, 0.07, -12),
			R("mar", 0.5, 0.88, 1, 0.24),
			P("rocas", 0.5, 0.84, 0.5, 0.14),
			C("rocas", 0.32, 0.8, 0.14),
			C("rocas", 0.66, 0.81, 0.12),
			R("faro", 0.5, 0.56, 0.18, 0.46, 0, 0.1),
			R("rayas", 0.5, 0.46, 0.18, 0.06),
			R("rayas", 0.5, 0.6, 0.18, 0.06),
			R("rayas", 0.5, 0.74, 0.18, 0.06),
			R("faro", 0.5, 0.31, 0.24, 0.04),
			R("lampara", 0.5, 0.26, 0.12, 0.08, 0, 0.2),
			R("rayas", 0.5, 0.2, 0.18, 0.05, 0, 0.5),
		},
	},

	-- Ilustraciones (dibujos de líneas) --------------------------------------------------
	{
		id = "chica",
		name = "Chica tímida",
		level = 6,
		value = 520,
		price = 1500,
		drawing = require(Drawings:WaitForChild("chica")),
	},
}

-- Geometría ---------------------------------------------------------------------------
-- ¿El punto (x, y) del lienzo cae dentro de la figura? (rectángulo redondeado rotado)
function Designs.contains(shape, x, y)
	local dx, dy = x - shape.x, y - shape.y
	local rad = math.rad(shape.rot)
	local c, s = math.cos(rad), math.sin(rad)
	local lx = math.abs(dx * c + dy * s)
	local ly = math.abs(-dx * s + dy * c)
	local hw, hh = shape.w / 2, shape.h / 2
	if lx > hw or ly > hh then
		return false
	end
	local rr = shape.r * math.min(shape.w, shape.h)
	local qx, qy = lx - (hw - rr), ly - (hh - rr)
	if qx <= 0 or qy <= 0 then
		return true
	end
	return qx * qx + qy * qy <= rr * rr
end

-- Índice de la figura visible (la de más arriba) en ese punto.
function Designs.shapeAt(design, x, y)
	if design.drawing then
		return DrawingData.labelAt(design.drawing, x, y)
	end
	local shapes = design.shapes
	for i = #shapes, 1, -1 do
		if Designs.contains(shapes[i], x, y) then
			return i
		end
	end
	return nil
end

local SAMPLES = 40

-- Preparación ---------------------------------------------------------------------------
Designs.ById = {}
Designs.Levels = {}
-- Ilustración: las áreas vienen del dibujo y cada zona es una figura.
local function prepareDrawing(design)
	local drawing = design.drawing
	design.kind = "image"
	design.areas = {}
	design.areaById = {}
	for areaIndex, area in ipairs(drawing.areas) do
		local copy = { id = area.id, name = area.name, default = area.default, index = areaIndex, weight = 0 }
		design.areas[areaIndex] = copy
		design.areaById[area.id] = copy
	end
	design.shapes = {}
	for i, region in ipairs(drawing.regions) do
		local area = design.areaById[region.a]
		assert(area, "Área desconocida " .. tostring(region.a) .. " en " .. design.id)
		design.shapes[i] = {
			area = region.a,
			x = region.x,
			y = region.y,
			w = region.w,
			h = region.h,
			rot = 0,
			r = 0,
			visible = region.v,
			label = { x = region.lx, y = region.ly, r = region.lr },
		}
		area.weight += region.v
	end
end

-- Diseño de figuras: aplana las compuestas y calcula la parte visible de cada una.
local function prepareShapes(design)
	-- Aplana las figuras compuestas (destellos, corazones, anillos).
	local flat = {}
	for _, item in ipairs(design.shapes) do
		if item.area then
			table.insert(flat, item)
		else
			for _, shape in ipairs(item) do
				table.insert(flat, shape)
			end
		end
	end
	design.shapes = flat
	design.areaById = {}
	for areaIndex, area in ipairs(design.areas) do
		area.index = areaIndex
		area.weight = 0
		design.areaById[area.id] = area
	end
	-- Parte visible de cada figura (muestreo del lienzo).
	local counts = {}
	for gx = 0, SAMPLES - 1 do
		for gy = 0, SAMPLES - 1 do
			local hit = Designs.shapeAt(design, (gx + 0.5) / SAMPLES, (gy + 0.5) / SAMPLES)
			if hit then
				counts[hit] = (counts[hit] or 0) + 1
			end
		end
	end
	for i, shape in ipairs(flat) do
		local area = design.areaById[shape.area]
		assert(area, "Área desconocida " .. tostring(shape.area) .. " en " .. design.id)
		shape.visible = (counts[i] or 0) / (SAMPLES * SAMPLES)
		area.weight += shape.visible
	end
end

for index, design in ipairs(Designs.List) do
	design.index = index
	if design.drawing then
		prepareDrawing(design)
	else
		prepareShapes(design)
	end
	for _, area in ipairs(design.areas) do
		assert(area.weight > 0, "El área " .. area.id .. " de " .. design.id .. " no se ve")
	end
	Designs.ById[design.id] = design
	Designs.Levels[design.level] = Designs.Levels[design.level] or {}
	table.insert(Designs.Levels[design.level], design)
end
Designs.MAX_LEVEL = #Designs.Levels

function Designs.get(id)
	return Designs.ById[id]
end

-- Segundos de pincel que necesita una figura (las grandes tardan más).
-- Las figuras tapadas del todo no hace falta pintarlas.
-- ¿Está abierto el nivel? (todos los diseños del nivel anterior pintados).
function Designs.isLevelOpen(level, made)
	if level <= 1 then
		return true
	end
	local info = Designs.LevelInfo[level]
	if info then
		return Designs.isLevelOpen(info.requires, made)
	end
	local previous = Designs.Levels[level - 1]
	if not previous then
		return false
	end
	for _, design in ipairs(previous) do
		if (made[design.id] or 0) < 1 then
			return false
		end
	end
	return Designs.isLevelOpen(level - 1, made)
end

-- Colores por defecto de un diseño (para miniaturas).
function Designs.defaultColors(design)
	local colors = {}
	for _, area in ipairs(design.areas) do
		colors[area.id] = area.default
	end
	return colors
end

-- "area:color,area:color" <-> tabla
function Designs.encodeColors(colors)
	local parts = {}
	for areaId, colorId in pairs(colors) do
		table.insert(parts, areaId .. ":" .. colorId)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

function Designs.decodeColors(str)
	local colors = {}
	if type(str) == "string" then
		for areaId, colorId in string.gmatch(str, "([%w_]+):([%w_]+)") do
			colors[areaId] = colorId
		end
	end
	return colors
end

return Designs
