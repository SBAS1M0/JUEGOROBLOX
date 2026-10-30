-- Descomprime los dibujos de líneas (src/shared/Drawings) la primera vez que se
-- necesitan: la zona de cada píxel y la oscuridad de la línea, en buffers.

local DrawingData = {}

local cache = {}

-- base64 -> buffer
local B64 = {}
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do
		B64[string.byte(alphabet, i)] = i - 1
	end
end

local function decodeBase64(text)
	local length = #text
	local padding = 0
	if string.sub(text, -2) == "==" then
		padding = 2
	elseif string.sub(text, -1) == "=" then
		padding = 1
	end
	local out = buffer.create(length // 4 * 3 - padding)
	local o = 0
	for i = 1, length, 4 do
		local a, b, c, d = string.byte(text, i, i + 3)
		local n = B64[a] * 262144 + B64[b] * 4096 + (B64[c] or 0) * 64 + (B64[d] or 0)
		buffer.writeu8(out, o, n // 65536)
		if c ~= 61 then
			buffer.writeu8(out, o + 1, n // 256 % 256)
		end
		if d ~= 61 then
			buffer.writeu8(out, o + 2, n % 256)
		end
		o += 3
	end
	return out
end

local function readVarint(data, position)
	local value, shift = 0, 1
	while true do
		local byte = buffer.readu8(data, position)
		position += 1
		value += (byte % 128) * shift
		if byte < 128 then
			return value, position
		end
		shift *= 128
	end
end

-- Zona de cada píxel: (zona, largo) repetido.
local function decodeLabels(text, total)
	local data = decodeBase64(text)
	local out = buffer.create(total)
	local position, o = 0, 0
	local size = buffer.len(data)
	while position < size do
		local value = buffer.readu8(data, position)
		local run
		run, position = readVarint(data, position + 1)
		buffer.fill(out, o, value, run)
		o += run
	end
	return out
end

-- Oscuridad de la línea: un byte con valor (4 bits) y largo (4 bits, 15 = sigue).
local function decodeAlpha(text, total)
	local data = decodeBase64(text)
	local out = buffer.create(total)
	local position, o = 0, 0
	local size = buffer.len(data)
	while position < size do
		local byte = buffer.readu8(data, position)
		position += 1
		local value, run = byte // 16, byte % 16
		if run == 15 then
			local extra
			extra, position = readVarint(data, position)
			run += extra
		end
		if value > 0 then
			buffer.fill(out, o, value, run)
		end
		o += run
	end
	return out
end

function DrawingData.get(drawing)
	local decoded = cache[drawing]
	if decoded then
		return decoded
	end
	local size = drawing.size
	decoded = {
		size = size,
		labels = decodeLabels(drawing.labels, size * size),
		alpha = decodeAlpha(drawing.alpha, size * size),
	}
	cache[drawing] = decoded
	return decoded
end

-- Píxeles de cada zona (índices del buffer), para rellenarla de golpe.
function DrawingData.pixels(drawing)
	local decoded = DrawingData.get(drawing)
	if decoded.pixels then
		return decoded.pixels
	end
	local lists = {}
	for i = 1, #drawing.regions do
		lists[i] = {}
	end
	local labels = decoded.labels
	for index = 0, decoded.size * decoded.size - 1 do
		local label = buffer.readu8(labels, index)
		if label > 0 then
			local list = lists[label]
			list[#list + 1] = index
		end
	end
	decoded.pixels = lists
	return lists
end

-- Zona en un punto del lienzo (0..1), o nil sobre un detalle blanco.
function DrawingData.labelAt(drawing, x, y)
	local decoded = DrawingData.get(drawing)
	local size = decoded.size
	local px = math.clamp(math.floor(x * size), 0, size - 1)
	local py = math.clamp(math.floor(y * size), 0, size - 1)
	local label = buffer.readu8(decoded.labels, py * size + px)
	return label > 0 and label or nil
end

return DrawingData
