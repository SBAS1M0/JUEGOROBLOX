-- Lógica compartida para pedidos: objetivo de colores, validación y puntuación.
-- La usa el servidor (autoridad) y el cliente (pistas y vista previa).

local Config = require(script.Parent.Config)
local Palette = require(script.Parent.Palette)

local Scoring = {}

local OUTLINE = Palette.OUTLINE
local EMPTY = Palette.EMPTY

-- Color que espera el cliente en cada celda, o nil si el modo no exige uno.
function Scoring.targetString(order, template)
	if order.mode == "original" then
		return template.flat
	elseif order.mode == "remix" then
		local swapped = string.gsub(template.flat, order.swapFrom, order.swapTo)
		return swapped
	end
	return nil
end

-- Lienzo inicial: contornos fijos y el resto vacío.
function Scoring.blankCanvas(template)
	local blank = string.gsub(template.flat, "[^" .. OUTLINE .. "]", EMPTY)
	return blank
end

-- Comprueba que el lienzo recibido es válido para la plantilla.
function Scoring.isValidCanvas(cells, template)
	if type(cells) ~= "string" or #cells ~= Config.CELLS then
		return false
	end
	for i = 1, Config.CELLS do
		local key = string.sub(cells, i, i)
		local isOutline = string.sub(template.flat, i, i) == OUTLINE
		if isOutline then
			if key ~= OUTLINE then
				return false
			end
		elseif key ~= EMPTY and not Palette.isPaintKey(key) then
			return false
		end
	end
	return true
end

local function themeSet(themeId)
	local theme = Config.ThemeById[themeId]
	local set = {}
	if theme then
		for i = 1, #theme.keys do
			set[string.sub(theme.keys, i, i)] = true
		end
	end
	return set
end

function Scoring.starsFor(quality)
	local stars = 0
	for i, threshold in ipairs(Config.STAR_THRESHOLDS) do
		if quality >= threshold then
			stars = i
		end
	end
	return stars
end

-- Devuelve calidad (0..1), estrellas y estadísticas del lienzo.
function Scoring.evaluate(order, template, cells)
	local target = Scoring.targetString(order, template)
	local paintable, filled, matches, inTheme = 0, 0, 0, 0
	local distinct, distinctCount = {}, 0
	local allowed = order.mode == "tema" and themeSet(order.theme) or nil

	for i = 1, Config.CELLS do
		local base = string.sub(template.flat, i, i)
		if base ~= OUTLINE then
			paintable += 1
			local key = string.sub(cells, i, i)
			if key ~= EMPTY then
				filled += 1
				if not distinct[key] then
					distinct[key] = true
					distinctCount += 1
				end
				if target and string.sub(target, i, i) == key then
					matches += 1
				end
				if allowed and allowed[key] then
					inTheme += 1
				end
			end
		end
	end

	paintable = math.max(paintable, 1)
	local coverage = filled / paintable
	local quality

	if target then
		quality = matches / paintable
	elseif order.mode == "tema" then
		quality = coverage * (inTheme / math.max(filled, 1))
		if distinctCount < 2 then
			quality = math.min(quality, 0.79)
		end
	else
		local variety = ({ 0.55, 0.75, 0.9 })[distinctCount] or 1
		if distinctCount == 0 then
			variety = 0
		end
		quality = coverage * variety
	end

	quality = math.clamp(quality, 0, 1)
	return {
		quality = quality,
		stars = Scoring.starsFor(quality),
		coverage = coverage,
		colors = distinctCount,
	}
end

-- Texto que dice el cliente al hacer el pedido.
function Scoring.describe(order, template)
	if order.mode == "original" then
		return "Quiero «" .. template.name .. "» con sus colores originales."
	elseif order.mode == "remix" then
		local from = Palette.ByKey[order.swapFrom]
		local to = Palette.ByKey[order.swapTo]
		return "«"
			.. template.name
			.. "», pero cambia el "
			.. string.lower(from and from.name or "?")
			.. " por "
			.. string.lower(to and to.name or "?")
			.. "."
	elseif order.mode == "tema" then
		local theme = Config.ThemeById[order.theme]
		return "«" .. template.name .. "» pintado en " .. (theme and theme.name or "colores bonitos") .. "."
	end
	return "«" .. template.name .. "» como tú quieras. ¡Usa muchos colores!"
end

return Scoring
