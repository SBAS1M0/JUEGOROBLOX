-- Ilustraciones (dibujos de líneas) pintadas píxel a píxel en una
-- EditableImage. Tiene la misma interfaz que DesignArt: en modo "color" dibuja
-- el cuadro terminado; en modo "paint" el boceto, los trazos del pincel (que
-- nunca se salen de la zona) y el resaltado de las zonas del color elegido.

local AssetService = game:GetService("AssetService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Designs = require(Shared.Designs)
local DrawingData = require(Shared.DrawingData)

local ImageArt = {}

local WHITE = Color3.new(1, 1, 1)
local UNPAINTED_LIGHT = Color3.fromRGB(196, 200, 210)
local FAINT = Color3.fromRGB(244, 244, 246)
local HINT = Color3.fromRGB(250, 176, 40)
local INK_R, INK_G, INK_B = 34, 34, 44
local OPAQUE = 4278190080 -- alfa 255 en el byte alto
local GRADIENT_COS, GRADIENT_SIN = math.cos(math.rad(35)), math.sin(math.rad(35))

local supported = nil

local function createImage(size)
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
	end)
	return ok and image or nil
end

-- ¿Puede este dispositivo dibujar ilustraciones?
function ImageArt.supported()
	if supported == nil then
		local image = createImage(4)
		supported = image ~= nil
		if image then
			image:Destroy()
		end
	end
	return supported
end

local function pack(r, g, b)
	return math.floor(r) + math.floor(g) * 256 + math.floor(b) * 65536
end

local function packColor(color)
	return pack(color.R * 255 + 0.5, color.G * 255 + 0.5, color.B * 255 + 0.5)
end

-- Paradas del acabado en números (0-255) para mezclar rápido.
local function numericStops(colorId)
	local list = {}
	for _, stop in ipairs(Colors.stops(colorId)) do
		local c = stop[2]
		table.insert(list, { stop[1], c.R * 255, c.G * 255, c.B * 255 })
	end
	return list
end

-- Color final (empaquetado) de una zona en el píxel (x, y) del lienzo de lado n.
local function finalColor(fill, x, y, n)
	local stops = fill.stops
	if #stops == 1 then
		return fill.flat
	end
	local u, v = (x + 0.5) / n - fill.x0, (y + 0.5) / n - fill.y0
	local t = math.clamp((u * GRADIENT_COS + v * GRADIENT_SIN) / fill.span, 0, 1)
	for k = 2, #stops do
		local b = stops[k]
		if t <= b[1] then
			local a = stops[k - 1]
			local f = (t - a[1]) / math.max(b[1] - a[1], 1e-6)
			return pack(a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, a[4] + (b[4] - a[4]) * f)
		end
	end
	local last = stops[#stops]
	return pack(last[2], last[3], last[4])
end

local function makeFill(colorId, shape)
	local stops = numericStops(colorId)
	local first = stops[1]
	return {
		stops = stops,
		flat = pack(first[2], first[3], first[4]),
		x0 = shape.x - shape.w / 2,
		y0 = shape.y - shape.h / 2,
		span = math.max(shape.w * GRADIENT_COS + shape.h * GRADIENT_SIN, 1e-3),
	}
end

local function noop() end

function ImageArt.render(container, design, opts)
	opts = opts or {}
	local old = container:FindFirstChild("Art")
	if old then
		old:Destroy()
	end
	local mode = opts.mode or "color"
	local drawing = design.drawing
	local zindex = opts.zindex or container.ZIndex
	local colors = Designs.defaultColors(design)
	for areaId, colorId in pairs(opts.colors or {}) do
		if Colors.ById[colorId] then
			colors[areaId] = colorId
		end
	end

	local holder = Instance.new("Frame")
	holder.Name = "Art"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = zindex

	local handle = {
		holder = holder,
		design = design,
		flood = noop,
		complete = noop,
		addStroke = noop,
		setFocus = noop,
		setHint = noop,
		setColors = noop,
	}

	local data = DrawingData.get(drawing)
	local n = data.size
	local size = mode == "paint" and n or math.min(n, opts.resolution or 256)
	local image = createImage(size)
	if not image then
		-- Sin EditableImage (memoria agotada o dispositivo antiguo): aviso sencillo.
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(250, 246, 238)
		label.Text = "🎨"
		label.TextScaled = true
		label.ZIndex = zindex
		label.Parent = holder
		holder.Parent = container
		return handle
	end
	local view = Instance.new("ImageLabel")
	view.Name = "Image"
	view.Size = UDim2.fromScale(1, 1)
	view.BackgroundTransparency = 1
	view.ZIndex = zindex
	view.ImageContent = Content.fromObject(image)
	view.Parent = holder
	-- La imagen se libera al quitar el dibujo.
	holder.AncestryChanged:Connect(function(_, parent)
		if parent == nil and image then
			image:Destroy()
			image = nil
		end
	end)

	local labels, alpha = data.labels, data.alpha
	local shapes = design.shapes
	local pixels = buffer.create(size * size * 4)
	local fills = {}
	local function setColors(newColors)
		for i, shape in ipairs(shapes) do
			fills[i] = makeFill(newColors[shape.area] or colors[shape.area], shape)
		end
	end
	setColors(colors)

	-- Escribe un píxel mezclando el relleno con la línea (a: 0-15).
	local function put(offset, color, a)
		local r, g, b = color % 256, color // 256 % 256, color // 65536
		if a > 0 then
			local k = a / 15
			r += (INK_R - r) * k
			g += (INK_G - g) * k
			b += (INK_B - b) * k
		end
		buffer.writeu32(pixels, offset, pack(r, g, b) + OPAQUE)
	end

	-- Modo color: el cuadro terminado (reducido si hace falta) -----------------------------
	if mode ~= "paint" then
		local step = n / size
		local block = math.max(1, math.ceil(step))
		local white = pack(255, 255, 255)
		local function drawAll()
			for sy = 0, size - 1 do
				local cy = math.floor((sy + 0.5) * step)
				local y0 = math.floor(sy * step)
				for sx = 0, size - 1 do
					local cx = math.floor((sx + 0.5) * step)
					local x0 = math.floor(sx * step)
					local label = buffer.readu8(labels, cy * n + cx)
					-- La línea más oscura del bloque, para que no desaparezca al reducir.
					local a = 0
					for by = y0, math.min(y0 + block - 1, n - 1) do
						for bx = x0, math.min(x0 + block - 1, n - 1) do
							local value = buffer.readu8(alpha, by * n + bx)
							if value > a then
								a = value
							end
						end
					end
					local color = label > 0 and finalColor(fills[label], cx, cy, n) or white
					put((sy * size + sx) * 4, color, a)
				end
			end
			image:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(size, size), pixels)
		end
		drawAll()
		function handle.setColors(newColors)
			if image then
				setColors(newColors)
				drawAll()
			end
		end
		holder.Parent = container
		return handle
	end

	-- Modo pintura ------------------------------------------------------------------------------
	local state = buffer.create(n * n) -- 0 boceto, 1 trazo, 2 terminado
	local paint = buffer.create(n * n * 4) -- color del trazo o final de cada píxel
	local base = {} -- color del boceto de cada zona (según el resaltado)
	local tones = {}
	local done = {}
	local hinted = {}
	local focus = nil
	local white = pack(255, 255, 255)
	for i, shape in ipairs(shapes) do
		local main = Colors.mainColor(colors[shape.area])
		local light = 0.299 * main.R + 0.587 * main.G + 0.114 * main.B
		local pale = light > 0.8 and main:Lerp(UNPAINTED_LIGHT, 0.6) or main:Lerp(WHITE, 0.78)
		local vivid = light > 0.8 and main:Lerp(UNPAINTED_LIGHT, 0.75) or main:Lerp(WHITE, 0.5)
		tones[i] = {
			pale = packColor(pale),
			vivid = packColor(vivid),
			faint = packColor(pale:Lerp(FAINT, 0.7)),
			hint = packColor(vivid:Lerp(HINT, 0.45)),
		}
		base[i] = tones[i].pale
	end

	local function compose(index)
		local label = buffer.readu8(labels, index)
		local color
		if label == 0 then
			color = white
		elseif buffer.readu8(state, index) == 0 then
			color = base[label]
		else
			color = buffer.readu32(paint, index * 4)
		end
		put(index * 4, color, buffer.readu8(alpha, index))
	end

	-- Solo se manda a la imagen la parte que cambió.
	local dirty = nil
	local scheduled = false
	local function flush()
		scheduled = false
		if not dirty or not image then
			return
		end
		local x0, y0, x1, y1 = dirty[1], dirty[2], dirty[3], dirty[4]
		dirty = nil
		local w, h = x1 - x0 + 1, y1 - y0 + 1
		if w == n and h == n then
			image:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(n, n), pixels)
			return
		end
		local part = buffer.create(w * h * 4)
		for row = 0, h - 1 do
			buffer.copy(part, row * w * 4, pixels, ((y0 + row) * n + x0) * 4, w * 4)
		end
		image:WritePixelsBuffer(Vector2.new(x0, y0), Vector2.new(w, h), part)
	end
	local function markDirty(x0, y0, x1, y1)
		x0, y0 = math.clamp(math.floor(x0), 0, n - 1), math.clamp(math.floor(y0), 0, n - 1)
		x1, y1 = math.clamp(math.ceil(x1), 0, n - 1), math.clamp(math.ceil(y1), 0, n - 1)
		if dirty then
			dirty = {
				math.min(dirty[1], x0),
				math.min(dirty[2], y0),
				math.max(dirty[3], x1),
				math.max(dirty[4], y1),
			}
		else
			dirty = { x0, y0, x1, y1 }
		end
		if not scheduled then
			scheduled = true
			task.defer(flush)
		end
	end
	local function markShape(i)
		local shape = shapes[i]
		markDirty(
			(shape.x - shape.w / 2) * n - 1,
			(shape.y - shape.h / 2) * n - 1,
			(shape.x + shape.w / 2) * n + 1,
			(shape.y + shape.h / 2) * n + 1
		)
	end
	local function redrawRegion(i)
		for _, index in ipairs(DrawingData.pixels(drawing)[i]) do
			if buffer.readu8(state, index) == 0 then
				compose(index)
			end
		end
		markShape(i)
	end
	local function redrawAll()
		for index = 0, n * n - 1 do
			compose(index)
		end
		markDirty(0, 0, n - 1, n - 1)
	end
	redrawAll()
	flush()

	-- La zona queda con su color final (y su acabado).
	function handle.complete(i)
		if done[i] then
			return
		end
		done[i] = true
		local fill = fills[i]
		for _, index in ipairs(DrawingData.pixels(drawing)[i]) do
			buffer.writeu32(paint, index * 4, finalColor(fill, index % n, index // n, n))
			buffer.writeu8(state, index, 2)
			compose(index)
		end
		markShape(i)
	end

	-- Trazo de pincel de (x1, y1) a (x2, y2) con grosor 2·radius: solo pinta
	-- los píxeles de la zona i.
	function handle.addStroke(i, x1, y1, x2, y2, radius, color)
		if done[i] then
			return
		end
		local ax, ay, bx, by = x1 * n, y1 * n, x2 * n, y2 * n
		local r = radius * n
		local r2 = r * r
		local minX, maxX =
			math.max(0, math.floor(math.min(ax, bx) - r)), math.min(n - 1, math.ceil(math.max(ax, bx) + r))
		local minY, maxY =
			math.max(0, math.floor(math.min(ay, by) - r)), math.min(n - 1, math.ceil(math.max(ay, by) + r))
		local dx, dy = bx - ax, by - ay
		local length2 = dx * dx + dy * dy
		local packed = packColor(color or Colors.mainColor(colors[shapes[i].area]))
		for py = minY, maxY do
			local row = py * n
			for px = minX, maxX do
				local index = row + px
				if buffer.readu8(labels, index) == i and buffer.readu8(state, index) ~= 2 then
					local cx, cy = px + 0.5, py + 0.5
					local t = 0
					if length2 > 0 then
						t = math.clamp(((cx - ax) * dx + (cy - ay) * dy) / length2, 0, 1)
					end
					local qx, qy = ax + t * dx - cx, ay + t * dy - cy
					if qx * qx + qy * qy <= r2 then
						buffer.writeu32(paint, index * 4, packed)
						buffer.writeu8(state, index, 1)
						compose(index)
					end
				end
			end
		end
		markDirty(minX, minY, maxX, maxY)
	end

	-- Resalta las zonas del color elegido y deja las demás casi en blanco.
	function handle.setFocus(areaId)
		focus = areaId
		for i, shape in ipairs(shapes) do
			local tone = tones[i]
			if areaId == nil then
				base[i] = tone.pale
			else
				base[i] = shape.area == areaId and tone.vivid or tone.faint
			end
			hinted[i] = false
		end
		redrawAll()
	end

	-- Latido: las zonas que faltan del color elegido se encienden (alpha > 0.6).
	function handle.setHint(i, value)
		local on = value > 0.6 and not done[i]
		if on == (hinted[i] == true) then
			return
		end
		hinted[i] = on
		local tone = tones[i]
		if on then
			base[i] = tone.hint
		elseif focus == nil then
			base[i] = tone.pale
		else
			base[i] = shapes[i].area == focus and tone.vivid or tone.faint
		end
		redrawRegion(i)
	end

	holder.Parent = container
	return handle
end

return ImageArt
