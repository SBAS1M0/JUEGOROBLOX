-- Estudio de pintura. El dibujo aparece como un boceto numerado y se pinta
-- color por color, como en la vida real: eliges un bote de la paleta de
-- madera y las zonas de ese color se iluminan (más color, contorno que late y
-- su número destacado) mientras las demás se quedan casi en blanco. El pincel
-- solo deja pintura en esas zonas, con vetas como el óleo, y cada figura se
-- completa al cubrir casi toda su superficie. Cuanto más rápido, más estrellas.

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
local STROKE_STEP = 0.5 -- muestreo del trazo (en radios del pincel)
local MAX_SEGMENT = 0.25 -- largo máximo de un trazo dibujado (fracción del lienzo)
local MAX_STROKES = 500 -- trazos por figura (la pintura sigue contando después)
local WOOD_LIGHT = Color3.fromRGB(226, 186, 136)
local WOOD = Color3.fromRGB(200, 152, 102)
local WOOD_DARK = Color3.fromRGB(150, 106, 66)

local app
local gui, canvasFrame, overlay, catcher, cursor, cursorTip
local refs = {}
local current
local stroking = false
local pointer = nil
local lastBrush = nil
local tool = "brush"
local soundClock = 0
local confirmCancelUntil = 0
local finishing = false
local nagUntil = 0

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
			strokes = 0,
			cx = shape.x,
			cy = shape.y,
			area = shape.area,
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
				-- Figura diminuta: basta con pasar por su centro (o por un
				-- punto que seguro está dentro, en las ilustraciones).
				local spot = shape.label
				table.insert(info.points, { spot and spot.x or shape.x, spot and spot.y or shape.y, false })
			end
		end
		info.total = #info.points
		list[i] = info
	end
	return list
end

-- Dónde va el número de cada figura: el punto visible más alejado de sus
-- bordes (así no tapa detalles y siempre queda dentro de la zona).
local LABEL_GRID = 48
local labelCache = {}
local function labelSpots(design)
	if labelCache[design.id] then
		return labelCache[design.id]
	end
	-- Las ilustraciones traen el sitio del número calculado al convertirlas.
	if design.kind == "image" then
		local spots = {}
		for i, shape in ipairs(design.shapes) do
			spots[i] = shape.label
		end
		labelCache[design.id] = spots
		return spots
	end
	local n = LABEL_GRID
	local owner = {}
	for gy = 0, n - 1 do
		for gx = 0, n - 1 do
			owner[gy * n + gx] = Designs.shapeAt(design, (gx + 0.5) / n, (gy + 0.5) / n) or 0
		end
	end
	local spots = {}
	for i in ipairs(design.shapes) do
		-- Distancia (en celdas) al borde más cercano de la figura.
		local dist = {}
		local queue = {}
		for gy = 0, n - 1 do
			for gx = 0, n - 1 do
				local index = gy * n + gx
				if owner[index] ~= i then
					dist[index] = 0
					table.insert(queue, index)
				elseif gx == 0 or gy == 0 or gx == n - 1 or gy == n - 1 then
					dist[index] = 1
					table.insert(queue, index)
				end
			end
		end
		local head = 1
		while head <= #queue do
			local index = queue[head]
			head += 1
			local gx, gy = index % n, index // n
			local d = dist[index] + 1
			for _, offset in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local nx, ny = gx + offset[1], gy + offset[2]
				if nx >= 0 and ny >= 0 and nx < n and ny < n then
					local other = ny * n + nx
					if dist[other] == nil then
						dist[other] = d
						table.insert(queue, other)
					end
				end
			end
		end
		local best, bestIndex = 0, nil
		for index, d in pairs(dist) do
			if owner[index] == i and d > best then
				best, bestIndex = d, index
			end
		end
		if bestIndex then
			spots[i] = { x = (bestIndex % n + 0.5) / n, y = (bestIndex // n + 0.5) / n, r = best / n }
		end
	end
	labelCache[design.id] = spots
	return spots
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

local function areaName(areaId)
	local area = current.design.areaById[areaId]
	return area and area.name or ""
end

local function areaMain(areaId)
	return Colors.mainColor(current.colors[areaId])
end

-- Bocadillo de ayuda sobre la paleta (o el lienzo).
local function coach(text)
	refs.coach.Visible = text ~= nil
	if text then
		refs.coachText.Text = text
	end
end

local function refreshCoach()
	local text = nil
	if current and not current.done then
		if not current.activeArea then
			text = "👇 Elige un color de la paleta para empezar"
		elseif areaPercent(current.activeArea) >= 0.999 then
			text = "✔ ¡" .. areaName(current.activeArea) .. " listo! Elige otro color"
		elseif app.state and app.state.tutorial == 3 and totalPercent() < 0.08 then
			text = "🖌️ Pasa el pincel por las zonas marcadas de " .. areaName(current.activeArea)
		end
	end
	coach(text)
end

local function refreshLabels()
	for areaId, slot in pairs(current.slots) do
		local p = areaPercent(areaId)
		slot.bar.Set(p)
		slot.check.Visible = p >= 0.999
		local active = areaId == current.activeArea
		slot.ring.Thickness = active and 4 or 0
		slot.blob.Position = UDim2.new(0.5, 0, 0, active and 2 or 8)
	end
	local total = totalPercent()
	refs.percent.Text = math.floor(total * 100) .. "%"
	refs.progress.Set(total)
	refreshCoach()
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

local function nag(text)
	if os.clock() > nagUntil then
		nagUntil = os.clock() + 2.5
		app.notify(text, "info")
		Theme.pop(refs.paletteBody, 0.94)
	end
end

-- Pintar ---------------------------------------------------------------------------------------
local completeIfDone
local buildLabels

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
			spawnParticle(shape.x, shape.y, areaMain(shape.area), true)
		end
		Theme.playSound("success", 1.5 + math.random() * 0.3)
	end
	refreshLabels()
	completeIfDone()
end

-- Cubre los puntos cercanos a (x, y) en las figuras del color elegido y
-- devuelve qué figuras tocó el pincel.
local function coverAt(x, y, touched)
	local radius = current.radius
	local r2 = radius * radius
	local reach = radius * 1.25
	local reach2 = reach * reach
	local painted = false
	for i, info in ipairs(current.samples) do
		if info.area == current.activeArea and not info.complete and info.total > 0 then
			local dx, dy = x - info.cx, y - info.cy
			local limit = info.bound + reach
			if dx * dx + dy * dy <= limit * limit then
				local newly = 0
				for _, point in ipairs(info.points) do
					local px, py = point[1] - x, point[2] - y
					local d2 = px * px + py * py
					if d2 <= reach2 then
						touched[i] = true
						if d2 <= r2 and not point[3] then
							point[3] = true
							newly += 1
						end
					end
				end
				if newly > 0 then
					painted = true
					info.painted += newly
				end
			end
		end
	end
	return painted
end

-- Un tramo de pincelada desde el punto anterior hasta (x, y).
local function strokeTo(x, y)
	local radius = current.radius
	local fromX, fromY = x, y
	if lastBrush then
		fromX, fromY = lastBrush[1], lastBrush[2]
	end
	local distance = math.sqrt((x - fromX) ^ 2 + (y - fromY) ^ 2)
	if lastBrush and distance < radius * 0.25 then
		return false
	end
	local steps = math.clamp(math.ceil(distance / (radius * STROKE_STEP)), 1, 80)
	local touched = {}
	local painted = false
	for k = 1, steps do
		local t = k / steps
		if coverAt(fromX + (x - fromX) * t, fromY + (y - fromY) * t, touched) then
			painted = true
		end
	end
	-- Dibuja el trazo en cada figura tocada (el CanvasGroup lo recorta).
	local pieces = math.max(1, math.ceil(distance / MAX_SEGMENT))
	local tint = areaMain(current.activeArea):Lerp(
		math.random() < 0.5 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0),
		math.random() * 0.07
	)
	for i in pairs(touched) do
		local info = current.samples[i]
		if info.strokes < MAX_STROKES then
			for k = 1, pieces do
				local a, b = (k - 1) / pieces, k / pieces
				current.art.addStroke(
					i,
					fromX + (x - fromX) * a,
					fromY + (y - fromY) * a,
					fromX + (x - fromX) * b,
					fromY + (y - fromY) * b,
					radius,
					tint
				)
				info.strokes += 1
			end
		end
	end
	for i in pairs(touched) do
		local info = current.samples[i]
		if not info.complete and info.painted / info.total >= COMPLETE_AT then
			completeShape(i, true)
		end
	end
	if painted then
		current.lastProgress = os.clock()
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
	if info.area ~= current.activeArea then
		nag("Esa zona va de otro color: elige «" .. areaName(info.area) .. "» en la paleta")
		return
	end
	current.art.flood(index, x, y, 0.3)
	info.painted = info.total
	current.lastProgress = os.clock()
	Theme.playSound("whoosh", 1.3)
	for _ = 1, 8 do
		spawnParticle(x, y, areaMain(info.area), true)
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

local function selectArea(areaId)
	if not current or current.done then
		return
	end
	current.activeArea = areaId
	current.art.setFocus(areaId)
	current.lastProgress = os.clock()
	current.flashAt = os.clock()
	lastBrush = nil
	Theme.playSound("click", 1.25)
	refreshLabels()
	local slot = current.slots[areaId]
	if slot then
		Theme.pop(slot.blob, 0.8)
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
		return
	end
	local radius = tool == "bucket" and 0.03 or current.radius
	cursor.Visible = true
	cursor.Position = UDim2.fromScale(x, y)
	cursor.Size = UDim2.fromScale(radius * 2, radius * 2)
	local color = current.activeArea and areaMain(current.activeArea) or C.InkFaint
	cursor.BackgroundColor3 = color
	cursor.BackgroundTransparency = current.activeArea and 0.35 or 0.7
	refs.cursorStroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.35)
	cursorTip.Text = tool == "bucket" and "🪣" or "🖌️"
end

-- Resaltado: las zonas del color elegido laten siempre (más fuerte al
-- elegirlo y si llevas un rato sin avanzar) y sus números se agrandan.
-- Sin color elegido, brilla la paleta.
local function updateHints()
	local now = os.clock()
	local idle = not current.done and now - (current.lastProgress or now) > 2.5
	refs.paletteGlow.Thickness = (not current.done and not current.activeArea) and (2 + 2 * math.abs(math.sin(now * 4)))
		or 0
	local alpha = 0
	if current.activeArea and not current.done then
		local wave = 0.5 + 0.5 * math.sin(now * 5)
		alpha = idle and wave or wave * 0.45
		local flash = 1 - (now - (current.flashAt or 0)) / 0.9
		if flash > 0 then
			alpha = math.max(alpha, flash * (0.5 + 0.5 * math.sin(now * 18)))
		end
	end
	for i, info in ipairs(current.samples) do
		local active = not info.complete and info.area == current.activeArea
		current.art.setHint(i, active and alpha or 0)
	end
	for _, label in ipairs(current.labels or {}) do
		local info = current.samples[label.index]
		local active = not current.done and info.area == current.activeArea
		if info.complete then
			label.frame.Visible = false
		else
			label.frame.Visible = true
			label.frame.BackgroundTransparency = active and 0 or 1
			label.text.TextColor3 = active and C.Ink or C.InkFaint
			label.text.TextTransparency = (current.activeArea == nil or active) and 0 or 0.35
			label.ring.Thickness = active and 2.5 or 0
			label.scale.Scale = active and (1.1 + alpha * 0.2) or 0.8
		end
	end
end

local function onStep(dt)
	if not current then
		return
	end
	updateCursor()
	updateHints()
	current.timerClock = (current.timerClock or 0) + dt
	if current.timerClock > 0.2 then
		current.timerClock = 0
		refreshTimer()
	end
	if stroking and pointer and not current.done and tool == "brush" then
		local x, y = canvasPoint(pointer)
		if x and x >= -0.1 and y >= -0.1 and x <= 1.1 and y <= 1.1 then
			if not current.activeArea then
				nag("🎨 Primero elige un color de la paleta")
				return
			end
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
		Size = UDim2.fromOffset(124, 46),
		Text = "✕ Salir",
		Variant = "ghost",
		MaxTextSize = 19,
		Parent = parent,
		OnClick = function()
			Painter.requestCancel()
		end,
	})
	local _, titleBody = Theme.card({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(360, 62),
		Radius = 18,
		Parent = parent,
	})
	refs.title = Theme.label({
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -32, 0, 30),
		Text = "",
		Font = Theme.Fonts.Display,
		MaxTextSize = 26,
		Parent = titleBody,
	})
	refs.progress = Theme.progress({
		Position = UDim2.fromOffset(18, 42),
		Size = UDim2.new(1, -86, 0, 10),
		Gradient = "primary",
		Parent = titleBody,
	})
	refs.percent = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 36),
		Size = UDim2.fromOffset(52, 20),
		Text = "0%",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.PrimaryDark,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 17,
		Parent = titleBody,
	})

	-- Estrellas y cronómetro.
	local holder, body = Theme.card({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(184, 50),
		Radius = 18,
		Parent = parent,
	})
	refs.timerCard = holder
	refs.stars = {}
	for i = 1, 3 do
		refs.stars[i] = Theme.label({
			Position = UDim2.fromOffset(12 + (i - 1) * 26, 6),
			Size = UDim2.fromOffset(26, 28),
			Text = "★",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Gold,
			MaxTextSize = 26,
			Parent = body,
		})
	end
	refs.timerText = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(64, 26),
		Text = "0:00",
		Font = Theme.Fonts.Display,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 22,
		Parent = body,
	})
	refs.timerBar = Theme.progress({
		Position = UDim2.new(0, 14, 1, -11),
		Size = UDim2.new(1, -28, 0, 5),
		Gradient = "gold",
		Parent = body,
	})
end

local function buildCanvas(parent)
	local area = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82),
		Size = UDim2.new(1, -40, 1, -82 - 206),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	-- Lienzo sobre un bastidor de madera.
	local board = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = area,
	}, { Theme.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	refs.board = board
	Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.8,
		Parent = board,
	}, { Theme.corner(12) })
	local frame = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		Parent = board,
	}, { Theme.corner(12), Theme.gradient(WOOD_LIGHT, WOOD, 90), Theme.stroke(WOOD_DARK, 2) })
	local mat = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		BackgroundColor3 = Color3.fromRGB(253, 251, 246),
		Parent = frame,
	}, { Theme.corner(4) })
	canvasFrame = Theme.new("Frame", {
		Name = "Canvas",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundColor3 = C.White,
		ClipsDescendants = true,
		Parent = mat,
	})
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
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 8,
		Parent = overlay,
	}, { Theme.round() })
	refs.cursorStroke = Theme.stroke(C.Ink, 2.5)
	refs.cursorStroke.Parent = cursor
	cursorTip = Theme.label({
		Position = UDim2.fromScale(0.72, -0.85),
		Size = UDim2.fromOffset(28, 28),
		Text = "🖌️",
		MaxTextSize = 26,
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
			if not current.activeArea then
				nag("🎨 Primero elige un color de la paleta")
				return
			end
			if tool == "bucket" then
				local x, y = canvasPoint(pointer)
				if x then
					bucket(x, y)
				end
			else
				stroking = true
				local x, y = canvasPoint(pointer)
				if x then
					strokeTo(x, y)
				end
			end
		end
	end)
end

-- Números sobre el boceto: cada zona lleva el número de su color en la paleta.
function buildLabels(design, colors)
	for _, label in ipairs(current.labels or {}) do
		label.frame:Destroy()
	end
	current.labels = {}
	local numberOf = {}
	for i, areaDef in ipairs(design.areas) do
		numberOf[areaDef.id] = i
	end
	for i, spot in pairs(labelSpots(design)) do
		local info = current.samples[i]
		if spot.r >= 0.03 and not info.complete then
			local area = design.shapes[i].area
			local size = math.clamp(spot.r * 1.3, 0.042, 0.075)
			local frame = Theme.new("Frame", {
				Name = "Number" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(spot.x, spot.y),
				Size = UDim2.fromScale(size, size),
				BackgroundColor3 = C.White,
				BackgroundTransparency = 1,
				ZIndex = 7,
				Parent = overlay,
			}, { Theme.round() })
			local ring = Theme.stroke(Colors.mainColor(colors[area]):Lerp(Color3.new(0, 0, 0), 0.3), 0)
			ring.Parent = frame
			local text = Theme.label({
				Size = UDim2.fromScale(1, 1),
				Text = tostring(numberOf[area] or ""),
				Font = Theme.Fonts.Heavy,
				TextColor3 = C.InkFaint,
				MaxTextSize = 30,
				ZIndex = 7,
				Parent = frame,
			})
			local scale = Theme.new("UIScale", { Scale = 0.8, Parent = frame })
			table.insert(current.labels, { index = i, frame = frame, text = text, ring = ring, scale = scale })
		end
	end
end

-- Paleta de pintor de madera con un bote de pintura por color.
local function buildPalette(parent)
	local holder = Theme.new("Frame", {
		Name = "Palette",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(520, 132),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Theme.corner(48) })
	refs.palette = holder
	Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.82,
		Parent = holder,
	}, { Theme.corner(48) })
	local body = Theme.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		Parent = holder,
	}, { Theme.corner(48), Theme.gradient(WOOD_LIGHT, WOOD, 90), Theme.stroke(WOOD_DARK, 2.5) })
	refs.paletteBody = body
	refs.paletteGlow = Theme.stroke(C.Gold, 0)
	refs.paletteGlow.Parent = holder
	-- Agujero para el pulgar.
	Theme.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.fromOffset(26, 34),
		BackgroundColor3 = WOOD_DARK,
		BackgroundTransparency = 0.25,
		Parent = body,
	}, { Theme.round() })
	refs.slots = Theme.new("Frame", {
		Position = UDim2.fromOffset(56, 0),
		Size = UDim2.new(1, -70, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Theme.list("h", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	refs.tools = Theme.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(52, 104),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Theme.list("v", 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	refs.brushButton = Theme.button({
		Size = UDim2.fromOffset(50, 48),
		Text = "🖌️",
		LayoutOrder = 1,
		Radius = 14,
		MaxTextSize = 24,
		Parent = refs.tools,
		OnClick = function()
			setTool("brush")
		end,
	})
	refs.bucketButton = Theme.button({
		Size = UDim2.fromOffset(50, 48),
		Text = "🪣",
		Variant = "ghost",
		LayoutOrder = 2,
		Radius = 14,
		MaxTextSize = 24,
		Parent = refs.tools,
		OnClick = function()
			setTool("bucket")
		end,
	})

	-- Bocadillo de ayuda encima de la paleta.
	local coachCard, coachBody = Theme.card({
		Name = "Coach",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -10),
		Size = UDim2.fromOffset(420, 42),
		Radius = 21,
		Color = C.Navy,
		Stroke = false,
		Visible = false,
		Parent = holder,
	})
	refs.coach = coachCard
	refs.coachText = Theme.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 1, -12),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.White,
		MaxTextSize = 17,
		Parent = coachBody,
	})
end

local function fillPalette(design, colors)
	for _, child in ipairs(refs.slots:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	current.slots = {}
	for i, areaDef in ipairs(design.areas) do
		local slot = Theme.new("Frame", {
			Name = "Slot" .. i,
			Size = UDim2.fromOffset(80, 116),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = refs.slots,
		})
		-- Gota de pintura con brillo.
		local blob = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(56, 56),
			Parent = slot,
		}, { Theme.round(), Theme.stroke(Theme.darker(WOOD_DARK, 0.1), 2) })
		DesignArt.swatch(blob, colors[areaDef.id])
		Theme.new("Frame", {
			Position = UDim2.fromScale(0.22, 0.16),
			Size = UDim2.fromScale(0.3, 0.2),
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.45,
			Rotation = -25,
			Parent = blob,
		}, { Theme.round() })
		local ring = Theme.stroke(C.White, 0)
		ring.Parent = blob
		local number = Theme.label({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, -4, 1, 4),
			Size = UDim2.fromOffset(22, 22),
			Text = tostring(i),
			Font = Theme.Fonts.Heavy,
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0,
			TextColor3 = C.Ink,
			MaxTextSize = 14,
			Parent = blob,
		})
		Theme.round().Parent = number
		Theme.stroke(WOOD_DARK, 1.5).Parent = number
		local check = Theme.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -4),
			Size = UDim2.fromOffset(22, 22),
			Text = "✔",
			Font = Theme.Fonts.Heavy,
			BackgroundColor3 = C.Mint,
			BackgroundTransparency = 0,
			TextColor3 = C.White,
			MaxTextSize = 14,
			Visible = false,
			Parent = blob,
		})
		Theme.round().Parent = check
		Theme.stroke(C.White, 2).Parent = check
		local label = Theme.label({
			Position = UDim2.fromOffset(0, 70),
			Size = UDim2.new(1, 0, 0, 18),
			Text = areaDef.name,
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.White,
			MaxTextSize = 14,
			Parent = slot,
		})
		Theme.textStroke(WOOD_DARK:Lerp(Color3.new(0, 0, 0), 0.4), 1.5, 0.1).Parent = label
		local bar = Theme.progress({
			Position = UDim2.new(0, 10, 0, 94),
			Size = UDim2.new(1, -20, 0, 7),
			Gradient = "mint",
			TrackColor = WOOD_DARK,
			Parent = slot,
		})
		local pick = Theme.new("TextButton", {
			Name = "Paint_" .. areaDef.id,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 4,
			Parent = slot,
		})
		pick.Activated:Connect(function()
			selectArea(areaDef.id)
		end)
		current.slots[areaDef.id] = { bar = bar, check = check, ring = ring, blob = blob }
	end
	local hasBucket = Config.hasBucket(levels())
	refs.tools.Visible = hasBucket
	refs.slots.Size = UDim2.new(1, hasBucket and -136 or -70, 1, 0)
	local width = 56 + #design.areas * 86 + (hasBucket and 82 or 18)
	refs.palette.Size = UDim2.fromOffset(math.max(width, 280), 132)
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
		Position = UDim2.new(0.5, 0, 0.5, 20),
		Size = UDim2.fromOffset(460, 590),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = refs.done,
	})
	refs.doneWrapper = wrapper
	local panelCard, panel = Theme.card({
		Size = UDim2.fromScale(1, 1),
		Radius = 24,
		Color = C.Bg,
		ShadowTransparency = 0.6,
		ShadowOffset = 8,
		StrokeColor = C.Navy,
		StrokeThickness = 3,
		Parent = wrapper,
	})
	refs.donePanelCard = panelCard
	local band = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 118),
		BackgroundColor3 = C.White,
		Parent = panel,
	}, { Theme.corner(24), Theme.gradient(Theme.Gradients.navy[1], Theme.Gradients.navy[2], 90) })
	Theme.label({
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -40, 0, 40),
		Text = "¡Cuadro terminado!",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		MaxTextSize = 34,
		Parent = band,
	})
	refs.doneStars = {}
	for i = 1, 3 do
		local star = Theme.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (i - 2) * 62, 0, i == 2 and 82 or 88),
			Size = UDim2.fromOffset(i == 2 and 58 or 48, i == 2 and 58 or 48),
			Text = "★",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Gold,
			MaxTextSize = 56,
			Parent = band,
		})
		Theme.textStroke(C.GoldDark, 2).Parent = star
		refs.doneStars[i] = star
	end
	local artBox = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 134),
		Size = UDim2.fromOffset(206, 206),
		BackgroundColor3 = C.White,
		Parent = panel,
	}, { Theme.corner(4), Theme.stroke(C.Navy, 7) })
	refs.doneArt = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = artBox },
		{ Theme.corner(4) }
	)
	refs.doneValue = Theme.label({
		Position = UDim2.fromOffset(20, 352),
		Size = UDim2.new(1, -40, 0, 36),
		Text = "",
		Font = Theme.Fonts.Display,
		TextColor3 = C.Ink,
		MaxTextSize = 32,
		Parent = panel,
	})
	refs.doneBreakdown = Theme.label({
		Position = UDim2.fromOffset(20, 390),
		Size = UDim2.new(1, -40, 0, 20),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 15,
		Parent = panel,
	})
	refs.doneInfo = Theme.label({
		Position = UDim2.fromOffset(24, 414),
		Size = UDim2.new(1, -48, 0, 38),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.PrimaryDark,
		MaxTextSize = 15,
		Parent = panel,
	})
	refs.carry = Theme.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 460),
		Size = UDim2.new(1, -60, 0, 60),
		Text = "🖼️ Llevar a la sala",
		Variant = "primary",
		Radius = 16,
		MaxTextSize = 24,
		Parent = panel,
		OnClick = function()
			Painter.finish(false)
		end,
	})
	refs.another = Theme.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 528),
		Size = UDim2.new(1, -60, 0, 48),
		Text = "🎨 Guardarlo y pintar otro",
		Variant = "ghost",
		Radius = 14,
		MaxTextSize = 19,
		Parent = panel,
		OnClick = function()
			Painter.finish(true)
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
	-- Fondo de estudio (pared crema) que tapa también la barra de Roblox.
	local background = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundColor3 = C.White,
		Parent = gui,
	}, { Theme.gradient(Color3.fromRGB(246, 238, 224), Color3.fromRGB(226, 214, 196), 90) })
	local root = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		Parent = background,
	})
	buildTopBar(root)
	buildCanvas(root)
	buildPalette(root)
	buildComplete()
end

local function updateScales()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local scale = math.clamp(math.min((viewport.X - 20) / 460, (viewport.Y - 100) / 600), 0.45, 1.1)
	local uiScale = refs.doneWrapper:FindFirstChild("ViewportScale")
		or Theme.new("UIScale", { Name = "ViewportScale", Parent = refs.doneWrapper })
	uiScale.Scale = scale
	local hudScale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.6, 1)
	for _, frame in ipairs({ refs.timerCard, refs.palette }) do
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
		-- Teclas 1-9 para elegir color.
		if input.KeyCode then
			local digit = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
			local areaDef = digit >= 1 and digit <= 9 and current.design.areas[digit]
			if areaDef then
				selectArea(areaDef.id)
			end
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
		lastProgress = os.clock(),
		activeArea = nil,
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
	buildLabels(design, colors)
	fillPalette(design, colors)
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
	local price = math.floor(value * Config.GALLERY_BONUS)
	local tier = Config.masteryFor(made)
	DesignArt.render(refs.doneArt, design, { mode = "color", colors = current.colors, outline = false })
	refs.doneValue.Text = "Precio medio: 💵 " .. Theme.formatNumber(price)
	refs.doneBreakdown.Text = string.format(
		"Colores x%.2f  ·  Estrellas +%d%%  ·  Maestría +%d%%",
		Config.colorMultiplier(design, current.colors),
		math.floor(Config.STAR_BONUS[stars] * 100),
		math.floor((tier and tier.bonus or 0) * 100)
	)
	refs.doneInfo.Text =
		"Llévalo a un stand de la sala y ponle tu precio: los visitantes te harán ofertas en la caja."
	local stored = state and state.storage and #state.storage or 0
	refs.another.SetEnabled(stored + 1 < Config.STORAGE_SIZE)
	for _, star in ipairs(refs.doneStars) do
		star.TextColor3 = C.NavyDark
		star.TextTransparency = 0.3
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

-- Entrega el cuadro: va al almacén y lo llevas a la espalda hasta exponerlo.
function Painter.finish(paintAnother)
	if finishing or not current then
		return
	end
	finishing = true
	local result
	for _ = 1, 30 do
		local ok, response = pcall(function()
			return app.remotes.FinishPainting:InvokeServer()
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
	local design = Designs.get(result.designId)
	Painter.close()
	if result.freeStands then
		app.notify(
			"🖼️ Llevas «" .. (design and design.name or "tu cuadro") .. "»: exponlo en un stand libre de la sala",
			"success"
		)
	else
		app.notify("Todos tus stands están ocupados: compra otro stand en la sala (＋).", "info")
	end
	if result.mastery then
		app.notify("🏅 ¡Maestría de " .. result.mastery .. " en este diseño!", "gold")
	end
	if result.newLevel then
		app.notify("🔓 ¡Nivel " .. result.newLevel .. " de diseños desbloqueado!", "gold")
		app.celebrate()
	end
	if paintAnother then
		task.defer(app.openDesigns)
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
