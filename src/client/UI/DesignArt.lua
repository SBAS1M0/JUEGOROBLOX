-- Dibuja un diseño (figuras) dentro de un Frame cuadrado.
-- mode = "color": cuadro terminado. mode = "lineart": líneas para colorear,
-- cada figura se va rellenando de abajo arriba con setProgress.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Designs = require(Shared.Designs)

local DesignArt = {}

local LINE_COLOR = Color3.fromRGB(236, 150, 186)

local function applyColor(frame, gradient, colorId)
	local entry = Colors.ById[colorId]
	if entry and entry.gradient then
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		gradient.Color = Colors.sequence(colorId)
	else
		frame.BackgroundColor3 = entry and entry.color or Color3.new(1, 1, 1)
		gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
	end
end

local function revealSequence(p)
	if p >= 1 then
		return NumberSequence.new(0)
	end
	if p <= 0 then
		return NumberSequence.new(1)
	end
	local edge = math.min(p + 0.05, 1)
	if edge >= 1 then
		return NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(p, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(p, 0),
		NumberSequenceKeypoint.new(edge, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
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
		if shape.r > 0 then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(shape.r, 0)
			corner.Parent = base
		end

		local entry = { shape = shape, base = base }
		if mode == "lineart" then
			base.BackgroundColor3 = Color3.new(1, 1, 1)
			local line = Instance.new("UIStroke")
			line.Color = LINE_COLOR
			line.Thickness = stroke
			line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			line.Parent = base

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.fromScale(1, 1)
			fill.BorderSizePixel = 0
			fill.ZIndex = zindex
			if shape.r > 0 then
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(shape.r, 0)
				corner.Parent = fill
			end
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = -90
			gradient.Transparency = revealSequence(0)
			gradient.Parent = fill
			applyColor(fill, gradient, colors[shape.area])
			fill.Parent = base
			entry.fill = fill
			entry.gradient = gradient
			entry.progress = 0
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

	function handle.setProgress(i, p)
		local entry = handle.shapes[i]
		if entry and entry.gradient and entry.fill then
			entry.progress = p
			entry.gradient.Transparency = revealSequence(p)
		end
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
