-- Paleta de colores del estudio. El orden define el número que se ve en el lienzo.

local Palette = {}

Palette.OUTLINE = "k"
Palette.EMPTY = "."
Palette.OutlineColor = Color3.fromRGB(45, 34, 58)
Palette.EmptyColor = Color3.fromRGB(252, 248, 240)

Palette.List = {
	{ key = "w", name = "Blanco", color = Color3.fromRGB(255, 255, 255) },
	{ key = "s", name = "Lavanda", color = Color3.fromRGB(214, 204, 245) },
	{ key = "a", name = "Gris", color = Color3.fromRGB(150, 156, 175) },
	{ key = "r", name = "Rojo", color = Color3.fromRGB(236, 72, 80) },
	{ key = "o", name = "Naranja", color = Color3.fromRGB(255, 152, 56) },
	{ key = "y", name = "Amarillo", color = Color3.fromRGB(255, 216, 72) },
	{ key = "t", name = "Durazno", color = Color3.fromRGB(247, 204, 164) },
	{ key = "u", name = "Café", color = Color3.fromRGB(150, 96, 60) },
	{ key = "l", name = "Rosa pastel", color = Color3.fromRGB(255, 204, 220) },
	{ key = "m", name = "Rosa", color = Color3.fromRGB(255, 120, 184) },
	{ key = "p", name = "Morado", color = Color3.fromRGB(156, 96, 224) },
	{ key = "n", name = "Azul noche", color = Color3.fromRGB(44, 52, 120) },
	{ key = "b", name = "Azul", color = Color3.fromRGB(64, 124, 236) },
	{ key = "c", name = "Celeste", color = Color3.fromRGB(130, 210, 250) },
	{ key = "v", name = "Menta", color = Color3.fromRGB(170, 238, 206) },
	{ key = "g", name = "Verde", color = Color3.fromRGB(104, 204, 96) },
	{ key = "d", name = "Verde bosque", color = Color3.fromRGB(40, 140, 84) },
}

Palette.ByKey = {}
for index, entry in ipairs(Palette.List) do
	entry.index = index
	Palette.ByKey[entry.key] = entry
end

-- Color3 para cualquier carácter del lienzo (incluye contorno y vacío).
function Palette.colorOf(key)
	if key == Palette.OUTLINE then
		return Palette.OutlineColor
	end
	local entry = Palette.ByKey[key]
	if entry then
		return entry.color
	end
	return Palette.EmptyColor
end

function Palette.isPaintKey(key)
	return Palette.ByKey[key] ~= nil
end

return Palette
