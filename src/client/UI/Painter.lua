-- Estudio de pintura: el dibujo aparece como un boceto con los colores en tono
-- pálido y lo coloreas pasando el pincel. La pintura se queda justo donde
-- pasas (recortada a cada figura) y, cuando cubres casi toda una figura, esta
-- se completa con su color final. Cuanto más rápido terminas, más estrellas.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Config = require(Shared.Config)
local Designs = require(Shared.Designs)

local Theme = require(script.Parent.Theme)
local DesignArt = require(script.Parent.DesignArt)

local Painter = {}

local C = Theme.Colors
local COMPLETE_AT = 0.9 -- fracción de la figura cubierta para completarla
local DAB_SPACING = 0.5 -- distancia entre pinceladas (en radios)
local MAX_DABS = 380 -- pinceladas por figura (la pintura sigue contando después)
local WOOD = Color3.fromRGB(196, 140, 96)
local WOOD_DARK = Color3.fromRGB(150, 98, 64)

local app
local gui, canvasFrame, overlay, catcher, cursor, cursorIcon
local refs = {}
local current
local stroking = false
local pointer = nil
local lastBrush = nil
local tool = "brush"
local soundClock = 0
local confirmCancelUntil = 0
local finishing = false

-- Utilidades ----------------------------------------------------------------------------------
local function levels()
	return app.state and app.state.upgrades or {}
end

local function canvasPoint(position)
	local absPos = canvasFrame.AbsolutePosition
	local absSize = canvasFrame.AbsoluteSize
	if absSize.X <= 0 then
		return nil
	end
	return (position.X - absPos.X) / absSize.X, (position.Y - absPos.Y) / absSize.Y
end

-- Puntos de muestra de cada figura (solo donde la figura se ve): la figura se
-- completa cuando el pincel ha pasado cerca de casi todos.
local function buildSamples(design, radius)
	local spacing = radius * 1.2
	local list = {}
	for i, shape in ipairs(design.shapes) do
		local info = {
			points = {},
			painted = 0,
			total = 0,
			complete = false,
			dabs = 0,
			cx = shape.x,
			cy = shape.y,
			bound = 0.5 * math.sqrt(shape.w * shape.w + shape.h * shape.h),
		}
		if shape.visible > 0 then
			local nx = math.clamp(math.ceil(shape.w / spacing), 2, 40)
			local ny = math.clamp(math.ceil(shape.h / spacing), 2, 40)
			local rad = math.rad(shape.rot)
			local c, s = math.cos(rad), math.sin(rad)
			for gx = 1, nx do
				for gy = 1, ny do
					local lx = ((gx - 0.5) / nx - 0.5) * shape.w
					local ly = ((gy - 0.5) / ny - 0.5) * shape.h
					local x = shape.x + lx * c - ly * s
					local y = shape.y + lx * s + ly * c
					if x >= 0 and x <= 1 and y >= 0 and y <= 1 and Designs.shapeAt(design, x, y) == i then
						table.insert(info.points, { x, y, false })
					end
				end
			end
			if #info.points == 0 then
				-- Figura diminuta: basta con pasar por su centro.
				table.insert(info.points, { shape.x, shape.y, false })
			end
		end
		info.total = #info.points
		list[i] = info
	end
	return list
end

local function areaPercent(areaId)
	local total, done = 0, 0
	for i, shape in ipairs(current.design.shapes) do
		if shape.area == areaId and shape.visible > 0 then
			local info = current.samples[i]
			local p = info.complete and 1 or info.painted / math.max(info.total, 1)
			total += shape.visible
			done += shape.visible * p
		end
	end
	return total > 0 and done / total or 1
end

local function totalPercent()
	local total, done = 0, 0
	for i, shape in ipairs(current.design.shapes) do
		if shape.visible > 0 then
			local info = current.samples[i]
			local p = info.complete and 1 or info.painted / math.max(info.total, 1)
			total += shape.visible
			done += shape.visible * p
		end
	end
	return total > 0 and done / total or 1
end

local function isComplete()
	for _, info in ipairs(current.samples) do
		if not info.complete then
			return false
		end
	end
	return true
end

local function elapsed()
	return os.clock() - current.started
end

local function refreshLabels()
	for areaId, slot in pairs(current.slots) do
		local p = areaPercent(areaId)
		slot.bar.Set(p)
		slot.check.Visible = p >= 0.999
	end
	local total = totalPercent()
	refs.percent.Text = math.floor(total * 100) .. "%"
	refs.progress.Set(total)
end

local function refreshTimer()
	if not current or current.done then
		return
	end
	local par = Config.parTime(current.design, levels())
	local t = elapsed()
	local stars = Config.starsFor(current.design, levels(), t)
	for i, star in ipairs(refs.stars) do
		star.TextColor3 = i <= stars and C.Gold or C.Border
	end
	refs.timerBar.Set(1 - math.clamp(t / (par * 2.5), 0, 1))
	refs.timerBar.SetGradient(stars >= 3 and "gold" or (stars == 2 and "orange" or "red"))
	refs.timerText.Text = string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
end

local function spawnParticle(x, y, color, burst)
	local dot = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(0.022, 0.022),
		BackgroundColor3 = color,
		ZIndex = 6,
		Parent = overlay,
	}, { Theme.round(), Theme.stroke(C.White, 1.5, 0.3) })
	local angle = math.random() * math.pi * 2
	local distance = (burst and 0.1 or 0.04) * (0.4 + math.random())
	Theme.tween(dot, 0.5, {
		Position = UDim2.fromScale(x + math.cos(angle) * distance, y + math.sin(angle) * distance),
		Size = UDim2.fromScale(0.004, 0.004),
		BackgroundTransparency = 1,
	})
	task.delay(0.55, function()
		dot:Destroy()
	end)
end

local function areaColor(shapeIndex)
	local shape = current.design.shapes[shapeIndex]
	return Colors.mainColor(current.colors[shape.area])
end

-- Pintar ---------------------------------------------------------------------------------------
local completeIfDone

local function completeShape(i, animate)
	local info = current.samples[i]
	if info.complete then
		return
	end
	info.complete = true
	current.art.complete(i, animate)
	if animate then
		local shape = current.design.shapes[i]
		for _ = 1, 6 do
			spawnParticle(shape.x, shape.y, areaColor(i), true)
		end
		Theme.playSound("success", 1.5 + math.random() * 0.3)
	end
	refreshLabels()
	completeIfDone()
end

-- Una pincelada en (x, y): pinta los puntos cercanos y deja la marca.
local function paintAt(x, y)
	local radius = current.radius
	local r2 = radius * radius
	local reach = radius * 1.25
	local reach2 = reach * reach
	local dabGap2 = (radius * DAB_SPACING) ^ 2
	local paintedAny = false
	for i, info in ipairs(current.samples) do
		if not info.complete and info.total > 0 then
			local dx, dy = x - info.cx, y - info.cy
			local limit = info.bound + reach
			if dx * dx + dy * dy <= limit * limit then
				local near, newly = false, 0
				for _, point in ipairs(info.points) do
					local px, py = point[1] - x, point[2] - y
					local d2 = px * px + py * py
					if d2 <= reach2 then
						near = true
						if d2 <= r2 and not point[3] then
							point[3] = true
							newly += 1
						end
					end
				end
				if near and info.dabs < MAX_DABS then
					local lx, ly = info.dabX, info.dabY
					if not lx or (lx - x) ^ 2 + (ly - y) ^ 2 >= dabGap2 then
						current.art.addDab(i, x, y, radius * 1.12)
						info.dabX, info.dabY = x, y
						info.dabs += 1
					end
				end
				if newly > 0 then
					paintedAny = true
					info.painted += newly
					if info.painted / info.total >= COMPLETE_AT then
						completeShape(i, true)
					end
				end
			end
		end
	end
	return paintedAny
end

-- Pinta a lo largo del trazo para que los movimientos rápidos no dejen huecos.
local function strokeTo(x, y)
	local step = current.radius * DAB_SPACING
	local fromX, fromY = x, y
	if lastBrush then
		fromX, fromY = lastBrush[1], lastBrush[2]
	end
	local distance = math.sqrt((x - fromX) ^ 2 + (y - fromY) ^ 2)
	local steps = math.clamp(math.ceil(distance / step), 1, 60)
	local painted = false
	for k = 1, steps do
		local t = k / steps
		if paintAt(fromX + (x - fromX) * t, fromY + (y - fromY) * t) then
			painted = true
		end
	end
	lastBrush = { x, y }
	return painted
end

local function bucket(x, y)
	local index = Designs.shapeAt(current.design, x, y)
	local info = index and current.samples[index]
	if not info or info.complete then
		return
	end
	current.art.flood(index, x, y, 0.3)
	info.painted = info.total
	Theme.playSound("whoosh", 1.3)
	for _ = 1, 8 do
		spawnParticle(x, y, areaColor(index), true)
	end
	task.delay(0.28, function()
		if current and current.samples[index] == info then
			completeShape(index, true)
		end
	end)
end

function completeIfDone()
	if not current.done and isComplete() then
		current.done = true
		current.finishedAt = elapsed()
		stroking = false
		refreshLabels()
		task.delay(0.6, function()
			if current and current.done then
				Painter.showComplete()
			end
		end)
	end
end

local function updateCursor()
	if not pointer or not current or current.done then
		cursor.Visible = false
		return
	end
	local x, y = canvasPoint(pointer)
	if not x or x < 0 or y < 0 or x > 1 or y > 1 then
		cursor.Visible = false
		for _, slot in pairs(current.slots) do
			slot.stroke.Color = C.Border
		end
		return
	end
	local radius = tool == "bucket" and 0.03 or current.radius
	cursor.Visible = true
	cursor.Position = UDim2.fromScale(x, y)
	cursor.Size = UDim2.fromScale(radius * 2, radius * 2)
	cursorIcon.Text = tool == "bucket" and "🪣" or "🖌️"
	local index = Designs.shapeAt(current.design, x, y)
	local color = index and areaColor(index) or C.InkSoft
	cursor.BackgroundColor3 = color
	refs.cursorStroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.3)
	local areaId = index and current.design.shapes[index].area
	for id, slot in pairs(current.slots) do
		slot.stroke.Color = id == areaId and C.Primary or C.Border
		slot.stroke.Thickness = id == areaId and 3 or 1.5
	end
end

local function onStep(dt)
	if not current then
		return
	end
	updateCursor()
	current.timerClock = (current.timerClock or 0) + dt
	if current.timerClock > 0.2 then
		current.timerClock = 0
		refreshTimer()
	end
	if stroking and pointer and not current.done and tool == "brush" then
		local x, y = canvasPoint(pointer)
		if x and x >= -0.1 and y >= -0.1 and x <= 1.1 and y <= 1.1 then
			if strokeTo(x, y) then
				current.labelClock = (current.labelClock or 0) + dt
				if current.labelClock > 0.1 then
					current.labelClock = 0
					refreshLabels()
				end
				soundClock += dt
				if soundClock > 0.16 then
					soundClock = 0
					Theme.playSound("paint", 0.9 + math.random() * 0.3)
				end
			end
		else
			lastBrush = nil
		end
	end
end

-- Interfaz ---------------------------------------------------------------------------------------
local function setTool(name)
	tool = name
	refs.brushButton.SetVariant(name == "brush" and "primary" or "ghost")
	refs.bucketButton.SetVariant(name == "bucket" and "primary" or "ghost")
end

local function buildTopBar(parent)
	refs.exit = Theme.button({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(118, 42),
		Text = "✕ Salir",
		Variant = "ghost",
		Color = C.Red,
		TextColor = C.Red,
		MaxTextSize = 20,
		Parent = parent,
		OnClick = function()
			Painter.requestCancel()
		end,
	})
	refs.title = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.5, 0, 0, 34),
		Text = "",
		Font = Theme.Fonts.Display,
		MaxTextSize = 30,
		Parent = parent,
	})
	local row = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(300, 18),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	refs.progress = Theme.progress({
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, -56, 0, 10),
		Gradient = "mint",
		Parent = row,
	})
	refs.percent = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(48, 18),
		Text = "0%",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.MintDark,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 16,
		Parent = row,
	})

	-- Estrellas y cronómetro.
	local holder, body = Theme.card({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(176, 44),
		Radius = 22,
		Parent = parent,
	})
	refs.timerCard = holder
	refs.stars = {}
	for i = 1, 3 do
		refs.stars[i] = Theme.label({
			Position = UDim2.fromOffset(12 + (i - 1) * 24, 6),
			Size = UDim2.fromOffset(24, 26),
			Text = "★",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Gold,
			MaxTextSize = 24,
			Parent = body,
		})
	end
	refs.timerText = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 7),
		Size = UDim2.fromOffset(60, 24),
		Text = "0:00",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 19,
		Parent = body,
	})
	refs.timerBar = Theme.progress({
		Position = UDim2.new(0, 14, 1, -9),
		Size = UDim2.new(1, -28, 0, 4),
		Gradient = "gold",
		Parent = body,
	})
end

local function buildCanvas(parent)
	local area = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.new(1, -40, 1, -74 - 132),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	-- Bastidor de madera con paspartú blanco.
	local board = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = area,
	}, { Theme.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	refs.board = board
	Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.8,
		Parent = board,
	}, { Theme.corner(18) })
	local frame = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		Parent = board,
	}, { Theme.corner(18), Theme.gradient(WOOD, WOOD_DARK, 90) })
	local mat = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		BackgroundColor3 = Color3.fromRGB(253, 251, 246),
		Parent = frame,
	}, { Theme.corner(10) })
	canvasFrame = Theme.new("Frame", {
		Name = "Canvas",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = C.White,
		ClipsDescendants = true,
		Parent = mat,
	}, { Theme.corner(6) })
	overlay = Theme.new("Frame", {
		Name = "Overlay",
		Position = canvasFrame.Position,
		Size = canvasFrame.Size,
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = mat,
	})
	cursor = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.1, 0.1),
		BackgroundTransparency = 0.55,
		Visible = false,
		ZIndex = 8,
		Parent = overlay,
	}, { Theme.round() })
	refs.cursorStroke = Theme.stroke(C.Ink, 2.5)
	refs.cursorStroke.Parent = cursor
	cursorIcon = Theme.label({
		Position = UDim2.fromScale(0.75, -0.75),
		Size = UDim2.fromOffset(26, 26),
		Text = "🖌️",
		MaxTextSize = 24,
		ZIndex = 9,
		Parent = cursor,
	})
	catcher = Theme.new("TextButton", {
		Name = "PaintInput",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 10,
		Parent = overlay,
	})
	catcher.InputBegan:Connect(function(input)
		if not current or current.done then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pointer = input.Position
			lastBrush = nil
			if tool == "bucket" then
				local x, y = canvasPoint(pointer)
				if x then
					bucket(x, y)
				end
			else
				stroking = true
			end
		end
	end)
end

-- Bandeja inferior con un bote de pintura por área.
local function buildTray(parent)
	local holder, body = Theme.card({
		Name = "Tray",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(500, 108),
		Radius = 24,
		Parent = parent,
	})
	refs.tray = holder
	refs.slots = Theme.new("Frame", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 1, -16),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Theme.list("h", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	refs.tools = Theme.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(52, 92),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Theme.list("v", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	refs.brushButton = Theme.button({
		Size = UDim2.fromOffset(48, 42),
		Text = "🖌️",
		LayoutOrder = 1,
		Radius = 14,
		MaxTextSize = 22,
		Parent = refs.tools,
		OnClick = function()
			setTool("brush")
		end,
	})
	refs.bucketButton = Theme.button({
		Size = UDim2.fromOffset(48, 42),
		Text = "🪣",
		Variant = "ghost",
		LayoutOrder = 2,
		Radius = 14,
		MaxTextSize = 22,
		Parent = refs.tools,
		OnClick = function()
			setTool("bucket")
		end,
	})
end

local function fillTray(design, colors)
	for _, child in ipairs(refs.slots:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	current.slots = {}
	for i, areaDef in ipairs(design.areas) do
		local slotHolder, slot = Theme.card({
			Size = UDim2.fromOffset(84, 90),
			Radius = 18,
			Color = C.PanelSoft,
			LayoutOrder = i,
			Parent = refs.slots,
		})
		slotHolder:FindFirstChild("Shadow").Visible = false
		local swatch = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(42, 42),
			Parent = slot,
		}, { Theme.round(), Theme.stroke(C.White, 3) })
		DesignArt.swatch(swatch, colors[areaDef.id])
		local check = Theme.label({
			Size = UDim2.fromScale(1, 1),
			Text = "✔",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.White,
			MaxTextSize = 22,
			Visible = false,
			Parent = swatch,
		})
		Theme.textStroke(C.Shadow, 1.5, 0.4).Parent = check
		Theme.label({
			Position = UDim2.fromOffset(4, 54),
			Size = UDim2.new(1, -8, 0, 16),
			Text = areaDef.name,
			Font = Theme.Fonts.Bold,
			TextColor3 = C.Ink,
			MaxTextSize = 14,
			Parent = slot,
		})
		local bar = Theme.progress({
			Position = UDim2.new(0, 10, 0, 74),
			Size = UDim2.new(1, -20, 0, 6),
			Gradient = "mint",
			Parent = slot,
		})
		current.slots[areaDef.id] = { bar = bar, check = check, stroke = slot:FindFirstChildOfClass("UIStroke") }
	end
	local hasBucket = Config.hasBucket(levels())
	refs.tools.Visible = hasBucket
	refs.slots.Size = UDim2.new(1, hasBucket and -86 or -20, 1, -16)
	local width = 20 + #design.areas * 92 - 8 + (hasBucket and 66 or 0)
	refs.tray.Size = UDim2.fromOffset(math.max(width, 200), 108)
end

-- Ventana de cuadro terminado.
local function buildComplete()
	refs.done = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	local wrapper = Theme.new("Frame", {
		Name = "Wrapper",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 40),
		Size = UDim2.fromOffset(460, 590),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = refs.done,
	})
	refs.doneWrapper = wrapper
	local panelCard, panel = Theme.card({
		Size = UDim2.fromScale(1, 1),
		Radius = 28,
		ShadowTransparency = 0.55,
		ShadowOffset = 10,
		StrokeColor = C.White,
		StrokeThickness = 3,
		Parent = wrapper,
	})
	refs.donePanelCard = panelCard
	local band = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 116),
		BackgroundColor3 = C.White,
		Parent = panel,
	}, { Theme.corner(28), Theme.gradient("primary", 0) })
	local title = Theme.label({
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -40, 0, 42),
		Text = "¡Cuadro terminado!",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		MaxTextSize = 36,
		Parent = band,
	})
	Theme.textStroke(C.Shadow, 2, 0.7).Parent = title
	refs.doneStars = {}
	for i = 1, 3 do
		local star = Theme.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (i - 2) * 62, 0, i == 2 and 82 or 88),
			Size = UDim2.fromOffset(i == 2 and 60 or 50, i == 2 and 60 or 50),
			Text = "★",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Gold,
			MaxTextSize = 58,
			Parent = band,
		})
		Theme.textStroke(C.GoldDark, 2.5).Parent = star
		refs.doneStars[i] = star
	end
	local artBox = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(212, 212),
		BackgroundColor3 = C.White,
		Parent = panel,
	}, { Theme.corner(10), Theme.stroke(C.Gold, 8) })
	refs.doneArt = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = artBox },
		{ Theme.corner(10) }
	)
	refs.doneValue = Theme.label({
		Position = UDim2.fromOffset(20, 356),
		Size = UDim2.new(1, -40, 0, 36),
		Text = "",
		Font = Theme.Fonts.Display,
		TextColor3 = C.MintDark,
		MaxTextSize = 32,
		Parent = panel,
	})
	refs.doneBreakdown = Theme.label({
		Position = UDim2.fromOffset(20, 392),
		Size = UDim2.new(1, -40, 0, 22),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 16,
		Parent = panel,
	})
	refs.doneInfo = Theme.label({
		Position = UDim2.fromOffset(20, 416),
		Size = UDim2.new(1, -40, 0, 22),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 16,
		Parent = panel,
	})
	refs.exhibit = Theme.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 450),
		Size = UDim2.new(1, -60, 0, 58),
		Text = "",
		Variant = "mint",
		Radius = 18,
		Parent = panel,
		OnClick = function()
			Painter.finish("galeria")
		end,
	})
	refs.sell = Theme.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 520),
		Size = UDim2.new(1, -60, 0, 50),
		Text = "",
		Variant = "ghost",
		Color = C.Gold,
		Radius = 18,
		Parent = panel,
		OnClick = function()
			Painter.finish("vender")
		end,
	})
end

local function buildUI()
	gui = Theme.new("ScreenGui", {
		Name = "Painter",
		ResetOnSpawn = false,
		DisplayOrder = 15,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- Fondo de estudio que tapa también la barra superior de Roblox.
	local background = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundColor3 = C.White,
		Parent = gui,
	}, { Theme.gradient(Color3.fromRGB(252, 248, 242), Color3.fromRGB(238, 230, 250), 90) })
	local root = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		Parent = background,
	})
	buildTopBar(root)
	buildCanvas(root)
	buildTray(root)
	buildComplete()
end

local function updateScales()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local scale = math.clamp(math.min((viewport.X - 20) / 460, (viewport.Y - 70) / 590), 0.45, 1.1)
	local uiScale = refs.doneWrapper:FindFirstChild("ViewportScale")
		or Theme.new("UIScale", { Name = "ViewportScale", Parent = refs.doneWrapper })
	uiScale.Scale = scale
	local hudScale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.6, 1)
	for _, frame in ipairs({ refs.timerCard, refs.tray }) do
		local s = frame:FindFirstChild("ViewportScale")
			or Theme.new("UIScale", { Name = "ViewportScale", Parent = frame })
		s.Scale = hudScale
	end
end

local function bindInput()
	UserInputService.InputChanged:Connect(function(input)
		if not current then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pointer = input.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			stroking = false
			lastBrush = nil
			if current then
				refreshLabels()
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not current then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			setTool("brush")
		elseif input.KeyCode == Enum.KeyCode.F and Config.hasBucket(levels()) then
			setTool("bucket")
		end
	end)
	RunService.RenderStepped:Connect(onStep)
end

local function setControlsEnabled(enabled)
	pcall(function()
		local playerModule = require(Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule", 2))
		local controls = playerModule:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

-- API --------------------------------------------------------------------------------------------
function Painter.open(design, colors)
	local radius = Config.brushRadius(levels())
	current = {
		design = design,
		colors = colors,
		radius = radius,
		samples = buildSamples(design, radius),
		slots = {},
		done = false,
		started = os.clock(),
	}
	stroking = false
	lastBrush = nil
	current.art = DesignArt.render(canvasFrame, design, { mode = "paint", colors = colors, stroke = 2 })
	for i, info in ipairs(current.samples) do
		-- Las figuras completamente tapadas ya cuentan como pintadas.
		if info.total == 0 then
			info.complete = true
			current.art.complete(i, false)
		end
	end
	fillTray(design, colors)
	refs.title.Text = design.name
	refs.done.Visible = false
	setTool(tool == "bucket" and Config.hasBucket(levels()) and "bucket" or "brush")
	refreshLabels()
	refreshTimer()
	updateScales()
	gui.Enabled = true
	ProximityPromptService.Enabled = false
	setControlsEnabled(false)
	app.setHudVisible(false)
	Theme.playSound("whoosh")
	completeIfDone()
end

function Painter.isOpen()
	return current ~= nil
end

function Painter.close()
	current = nil
	stroking = false
	gui.Enabled = false
	refs.done.Visible = false
	ProximityPromptService.Enabled = true
	setControlsEnabled(true)
	app.setHudVisible(true)
end

function Painter.requestCancel()
	if not current then
		return
	end
	if os.clock() > confirmCancelUntil then
		confirmCancelUntil = os.clock() + 3
		refs.exit.SetText("¿Salir?")
		task.delay(3, function()
			refs.exit.SetText("✕ Salir")
		end)
		app.notify("Toca otra vez para salir (te devolvemos las pinturas).", "info")
		return
	end
	confirmCancelUntil = 0
	refs.exit.SetText("✕ Salir")
	app.remotes.CancelPainting:FireServer()
	Painter.close()
end

function Painter.showComplete()
	local state = app.state
	local design = current.design
	local stars = Config.starsFor(design, levels(), current.finishedAt or elapsed())
	current.stars = stars
	local made = state and state.made[design.id] or 0
	local value = Config.paintingValue(design, current.colors, levels(), made, stars)
	current.value = value
	local tier = Config.masteryFor(made)
	DesignArt.render(refs.doneArt, design, { mode = "color", colors = current.colors, outline = false })
	refs.doneValue.Text = "💵 Vale " .. Theme.formatNumber(value)
	refs.doneBreakdown.Text = string.format(
		"Colores x%.2f  ·  Estrellas +%d%%  ·  Maestría +%d%%",
		Config.colorMultiplier(design, current.colors),
		math.floor(Config.STAR_BONUS[stars] * 100),
		math.floor((tier and tier.bonus or 0) * 100)
	)
	local free = state and (state.slots - state.displayed) or 0
	refs.doneInfo.Text = free > 0 and ("Huecos libres en tu galería: " .. free)
		or "Tu galería está llena: compra «Más paredes» 🖼️"
	refs.exhibit.SetText(
		"🖼️ Exponer · un visitante pagará 💵 " .. Theme.formatNumber(math.floor(value * Config.GALLERY_BONUS))
	)
	refs.exhibit.SetEnabled(free > 0)
	refs.sell.SetText("💰 Vender ya · 💵 " .. Theme.formatNumber(value))
	for _, star in ipairs(refs.doneStars) do
		star.TextColor3 = C.White
		star.TextTransparency = 0.6
	end
	updateScales()
	refs.done.Visible = true
	Theme.pop(refs.donePanelCard, 0.6)
	Theme.playSound("success", 1)
	task.spawn(function()
		task.wait(0.35)
		for i = 1, stars do
			local star = refs.doneStars[i]
			if not star.Parent then
				return
			end
			star.TextColor3 = C.Gold
			star.TextTransparency = 0
			Theme.pop(star, 1.8)
			Theme.playSound("success", 0.9 + i * 0.15)
			task.wait(0.28)
		end
		if stars >= 3 then
			app.celebrate()
		end
	end)
end

function Painter.finish(choice)
	if finishing or not current then
		return
	end
	finishing = true
	local result
	for _ = 1, 30 do
		local ok, response = pcall(function()
			return app.remotes.FinishPainting:InvokeServer(choice)
		end)
		result = ok and response or nil
		if result and not result.ok and result.reason == "¡Aún no está terminado!" then
			task.wait(1)
		else
			break
		end
	end
	finishing = false
	if not (result and result.ok) then
		app.notify(result and result.reason or "No se pudo terminar el cuadro.", "error")
		return
	end
	Painter.close()
	local stars = string.rep("⭐", result.stars or 1)
	if result.displayed then
		app.notify(
			stars .. " ¡Expuesto! Un visitante lo comprará por 💵" .. Theme.formatNumber(result.price),
			"success"
		)
	else
		app.notify(stars .. " ¡Vendido por 💵" .. Theme.formatNumber(result.price) .. "!", "gold")
	end
	if result.mastery then
		app.notify("🏅 ¡Maestría de " .. result.mastery .. " en este diseño!", "gold")
	end
	if result.newLevel then
		app.notify("🔓 ¡Nivel " .. result.newLevel .. " de diseños desbloqueado!", "gold")
		app.celebrate()
	end
end

function Painter.init(appRef)
	app = appRef
	buildUI()
	bindInput()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
	end
end

return Painter
