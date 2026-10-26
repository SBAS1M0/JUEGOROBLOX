-- Dibuja un diseño (figuras) dentro de un Frame cuadrado.
-- mode = "color": cuadro terminado.
-- mode = "paint": boceto para colorear. Cada figura se ve en un tono pálido de
-- su color con línea de lápiz; las pinceladas (addDab) se recortan a la forma
-- de la figura con un CanvasGroup y, al completarla, el color final aparece.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Designs = require(Shared.Designs)

local DesignArt = {}

local WHITE = Color3.new(1, 1, 1)
local SKETCH_LINE = Color3.fromRGB(150, 156, 170)
local UNPAINTED_LIGHT = Color3.fromRGB(196, 200, 210)
local HINT_LINE = Color3.fromRGB(40, 104, 232)
local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function applyColor(frame, gradient, colorId)
	local entry = Colors.ById[colorId]
	if entry and entry.gradient then
		frame.BackgroundColor3 = WHITE
		gradient.Color = Colors.sequence(colorId)
	else
		frame.BackgroundColor3 = entry and entry.color or WHITE
		gradient.Color = ColorSequence.new(WHITE)
	end
end

local function addCorner(frame, shape)
	if shape.r > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(shape.r, 0)
		corner.Parent = frame
	end
end

-- Punto del lienzo (0..1) en coordenadas locales de la figura (0..1).
function DesignArt.toLocal(shape, x, y)
	local dx, dy = x - shape.x, y - shape.y
	local rad = math.rad(shape.rot)
	local c, s = math.cos(rad), math.sin(rad)
	local lx = dx * c + dy * s
	local ly = -dx * s + dy * c
	return lx / shape.w + 0.5, ly / shape.h + 0.5
end

function DesignArt.render(container, design, opts)
	opts = opts or {}
	local old = container:FindFirstChild("Art")
	if old then
		old:Destroy()
	end
	local mode = opts.mode or "color"
	local colors = opts.colors or Designs.defaultColors(design)
	local zindex = opts.zindex or container.ZIndex
	local stroke = opts.stroke or 2

	local holder = Instance.new("Frame")
	holder.Name = "Art"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	holder.ZIndex = zindex

	local handle = { shapes = {}, design = design, holder = holder }

	for i, shape in ipairs(design.shapes) do
		local base = Instance.new("Frame")
		base.Name = "S" .. i
		base.AnchorPoint = Vector2.new(0.5, 0.5)
		base.Position = UDim2.fromScale(shape.x, shape.y)
		base.Size = UDim2.fromScale(shape.w, shape.h)
		base.Rotation = shape.rot
		base.BorderSizePixel = 0
		base.ZIndex = zindex
		addCorner(base, shape)

		local entry = { shape = shape, base = base, done = false }
		if mode == "paint" then
			local main = Colors.mainColor(colors[shape.area])
			entry.main = main
			-- Tono pálido del color final; los colores muy claros se ven en gris
			-- para que se note qué falta por pintar.
			local light = 0.299 * main.R + 0.587 * main.G + 0.114 * main.B
			base.BackgroundColor3 = light > 0.8 and main:Lerp(UNPAINTED_LIGHT, 0.6) or main:Lerp(WHITE, 0.78)
			local line = Instance.new("UIStroke")
			line.Color = SKETCH_LINE
			line.Thickness = stroke
			line.Transparency = 0.1
			line.Parent = base
			entry.line = line

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.fromScale(1, 1)
			fill.BorderSizePixel = 0
			fill.BackgroundTransparency = 1
			fill.ZIndex = zindex + 2
			addCorner(fill, shape)
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 35
			gradient.Parent = fill
			applyColor(fill, gradient, colors[shape.area])
			fill.Parent = base
			entry.fill = fill
			entry.gradient = gradient
		else
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 35
			gradient.Parent = base
			applyColor(base, gradient, colors[shape.area])
			entry.gradient = gradient
			if opts.outline ~= false then
				local line = Instance.new("UIStroke")
				line.Color = Colors.mainColor(colors[shape.area]):Lerp(Color3.new(0, 0, 0), 0.25)
				line.Thickness = opts.outlineThickness or 1
				line.Transparency = 0.55
				line.Parent = base
			end
		end
		base.Parent = holder
		handle.shapes[i] = entry
	end

	-- Capa de pintura recortada a la forma de la figura.
	local function paintLayer(entry)
		if entry.group then
			return entry.group
		end
		local group = Instance.new("CanvasGroup")
		group.Name = "Paint"
		group.Size = UDim2.fromScale(1, 1)
		group.BackgroundTransparency = 1
		group.ZIndex = zindex + 1
		addCorner(group, entry.shape)
		group.Parent = entry.base
		entry.group = group
		return group
	end

	-- Pincelada redonda de radio `radius` (en fracción del lienzo) en (x, y).
	function handle.addDab(i, x, y, radius)
		local entry = handle.shapes[i]
		if not entry or entry.done or mode ~= "paint" then
			return
		end
		local shape = entry.shape
		local u, v = DesignArt.toLocal(shape, x, y)
		local dab = Instance.new("Frame")
		dab.AnchorPoint = Vector2.new(0.5, 0.5)
		dab.Position = UDim2.fromScale(u, v)
		dab.Size = UDim2.fromScale(2 * radius / shape.w, 2 * radius / shape.h)
		dab.BackgroundColor3 = entry.main
		dab.BorderSizePixel = 0
		dab.ZIndex = zindex + 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = dab
		dab.Parent = paintLayer(entry)
	end

	-- Relleno de cubeta: una mancha que crece desde (x, y) hasta cubrir la figura.
	function handle.flood(i, x, y, duration)
		local entry = handle.shapes[i]
		if not entry or entry.done or mode ~= "paint" then
			return
		end
		local shape = entry.shape
		local u, v = DesignArt.toLocal(shape, x, y)
		local dab = Instance.new("Frame")
		dab.AnchorPoint = Vector2.new(0.5, 0.5)
		dab.Position = UDim2.fromScale(u, v)
		dab.Size = UDim2.fromScale(0, 0)
		dab.BackgroundColor3 = entry.main
		dab.BorderSizePixel = 0
		dab.ZIndex = zindex + 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = dab
		dab.Parent = paintLayer(entry)
		local reach = 2.2 * math.sqrt(shape.w * shape.w + shape.h * shape.h)
		TweenService:Create(
			dab,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(reach / shape.w, reach / shape.h) }
		):Play()
	end

	-- La figura queda pintada con su color final (con o sin animación).
	function handle.complete(i, animate)
		local entry = handle.shapes[i]
		if not entry or entry.done then
			return
		end
		entry.done = true
		if mode ~= "paint" then
			return
		end
		local finalLine = entry.main:Lerp(Color3.new(0, 0, 0), 0.25)
		if animate then
			TweenService:Create(entry.fill, FADE, { BackgroundTransparency = 0 }):Play()
			TweenService:Create(entry.line, FADE, { Color = finalLine, Transparency = 0.55 }):Play()
			local group = entry.group
			if group then
				task.delay(0.3, function()
					group:Destroy()
				end)
			end
		else
			entry.fill.BackgroundTransparency = 0
			entry.line.Color = finalLine
			entry.line.Transparency = 0.55
			if entry.group then
				entry.group:Destroy()
			end
		end
		entry.group = nil
	end

	-- Pista: resalta el contorno de una figura sin pintar (alpha 0..1).
	function handle.setHint(i, alpha)
		local entry = handle.shapes[i]
		if not entry or entry.done or not entry.line then
			return
		end
		entry.line.Color = SKETCH_LINE:Lerp(HINT_LINE, alpha)
		entry.line.Thickness = stroke + alpha * 1.5
		entry.line.Transparency = 0.1 * (1 - alpha)
	end

	function handle.setColors(newColors)
		colors = newColors
		for _, entry in ipairs(handle.shapes) do
			local target = entry.fill or entry.base
			applyColor(target, entry.gradient, newColors[entry.shape.area])
		end
	end

	holder.Parent = container
	return handle
end

-- Muestra de color redonda (soporta degradados).
function DesignArt.swatch(frame, colorId)
	local gradient = frame:FindFirstChild("SwatchGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Name = "SwatchGradient"
		gradient.Rotation = 35
		gradient.Parent = frame
	end
	applyColor(frame, gradient, colorId)
end

return DesignArt
