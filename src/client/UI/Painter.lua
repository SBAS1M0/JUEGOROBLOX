-- Estudio de pintura: el diseño aparece en líneas y cada figura se rellena con
-- el color de su área mientras pasas el pincel. Cuanto más rápido terminas,
-- más estrellas (y más valor) consigue el cuadro.

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
local SAMPLE_RING = 6

local app
local gui, root, canvasFrame, catcher, cursor, particles
local refs = {}
local current
local stroking = false
local pointer = nil
local tool = "brush"
local particleClock = 0
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

local function areaPercent(areaId)
	local total, done = 0, 0
	for i, shape in ipairs(current.design.shapes) do
		if shape.area == areaId then
			total += shape.visible
			done += shape.visible * current.progress[i]
		end
	end
	return total > 0 and done / total or 1
end

local function totalPercent()
	local total, done = 0, 0
	for i, shape in ipairs(current.design.shapes) do
		total += shape.visible
		done += shape.visible * current.progress[i]
	end
	return total > 0 and done / total or 1
end

local function isComplete()
	for i in ipairs(current.design.shapes) do
		if current.progress[i] < 1 then
			return false
		end
	end
	return true
end

local function elapsed()
	return os.clock() - current.started
end

local function currentStars()
	return Config.starsFor(current.design, levels(), elapsed())
end

local function refreshLabels()
	for areaId, row in pairs(current.areaRows) do
		local p = areaPercent(areaId)
		row.bar.Set(p)
		if p >= 0.999 then
			row.percent.Text = "✔"
			row.percent.TextColor3 = C.MintDark
		else
			row.percent.Text = math.floor(p * 100) .. "%"
			row.percent.TextColor3 = C.InkSoft
		end
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
	local limit = par * 2.5
	refs.timerBar.Set(1 - math.clamp(t / limit, 0, 1))
	local stars = currentStars()
	for i, star in ipairs(refs.stars) do
		star.TextColor3 = i <= stars and C.Gold or C.Border
	end
	refs.timerBar.SetGradient(stars >= 3 and "gold" or (stars == 2 and "orange" or "red"))
	refs.timerText.Text = string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
end

-- Partículas -----------------------------------------------------------------------------------
local function spawnParticle(x, y, color, burst)
	local dot = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(0.02, 0.02),
		BackgroundColor3 = color,
		ZIndex = 6,
		Parent = particles,
	}, { Theme.round() })
	local angle = math.random() * math.pi * 2
	local distance = (burst and 0.09 or 0.035) * (0.4 + math.random())
	Theme.tween(dot, 0.45, {
		Position = UDim2.fromScale(x + math.cos(angle) * distance, y + math.sin(angle) * distance),
		Size = UDim2.fromScale(0.004, 0.004),
		BackgroundTransparency = 1,
	})
	task.delay(0.5, function()
		dot:Destroy()
	end)
end

-- Pintar ---------------------------------------------------------------------------------------
local function setShapeProgress(i, p)
	current.progress[i] = p
	current.art.setProgress(i, p)
end

local function areaColor(shapeIndex)
	local shape = current.design.shapes[shapeIndex]
	return Colors.mainColor(current.colors[shape.area])
end

-- El relleno empieza en el lado por el que entró el pincel.
local function aimFill(index, x, y)
	if current.progress[index] > 0 then
		return
	end
	local shape = current.design.shapes[index]
	local dx, dy = shape.x - x, shape.y - y
	if dx * dx + dy * dy > 0.0001 then
		current.art.setFillDirection(index, math.deg(math.atan2(dy, dx)) - shape.rot)
	end
end

local function completeIfDone()
	if not current.done and isComplete() then
		current.done = true
		current.finishedAt = elapsed()
		stroking = false
		refreshLabels()
		task.delay(0.4, function()
			if current and current.done then
				Painter.showComplete()
			end
		end)
	end
end

local function brush(x, y, dt)
	local radius = Config.brushRadius(levels())
	local speed = Config.brushSpeed(levels())
	local hits = {}
	local samples = { { x, y } }
	for k = 0, SAMPLE_RING - 1 do
		local angle = k / SAMPLE_RING * math.pi * 2
		table.insert(samples, { x + math.cos(angle) * radius, y + math.sin(angle) * radius })
	end
	for _, point in ipairs(samples) do
		local index = Designs.shapeAt(current.design, point[1], point[2])
		if index and current.progress[index] < 1 then
			hits[index] = (hits[index] or 0) + 1
		end
	end
	local painted = nil
	for index, count in pairs(hits) do
		aimFill(index, x, y)
		local time = Designs.shapeTime(current.design.shapes[index])
		-- Basta con rozar una figura para pintarla; cubrirla entera va más rápido.
		local coverage = 0.6 + 0.4 * count / #samples
		local amount = dt * speed * coverage * 1.15 / math.max(time, 0.05)
		setShapeProgress(index, math.min(1, current.progress[index] + amount))
		if current.progress[index] >= 1 then
			for _ = 1, 4 do
				spawnParticle(x, y, areaColor(index), true)
			end
		end
		painted = index
	end
	if painted then
		particleClock += dt
		if particleClock > 0.05 then
			particleClock = 0
			spawnParticle(x, y, areaColor(painted), false)
		end
		soundClock += dt
		if soundClock > 0.18 then
			soundClock = 0
			Theme.playSound("paint", 0.9 + math.random() * 0.3)
		end
	end
	return painted ~= nil
end

local function bucket(x, y)
	local index = Designs.shapeAt(current.design, x, y)
	if index and current.progress[index] < 1 then
		aimFill(index, x, y)
		setShapeProgress(index, 1)
		for _ = 1, 10 do
			spawnParticle(x, y, areaColor(index), true)
		end
		Theme.playSound("whoosh", 1.3)
		refreshLabels()
		completeIfDone()
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
	local radius = tool == "bucket" and 0.025 or Config.brushRadius(levels())
	cursor.Visible = true
	cursor.Position = UDim2.fromScale(x, y)
	cursor.Size = UDim2.fromScale(radius * 2.4, radius * 2.4)
	local index = Designs.shapeAt(current.design, x, y)
	cursor.BackgroundColor3 = index and areaColor(index) or C.White
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
		if x and x >= -0.05 and y >= -0.05 and x <= 1.05 and y <= 1.05 then
			if brush(x, y, math.min(dt, 0.1)) then
				current.labelClock = (current.labelClock or 0) + dt
				if current.labelClock > 0.1 then
					current.labelClock = 0
					refreshLabels()
				end
				completeIfDone()
			end
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
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(130, 46),
		Text = "✕ Salir",
		Variant = "ghost",
		Color = C.Red,
		TextColor = C.Red,
		Parent = parent,
		OnClick = function()
			Painter.requestCancel()
		end,
	})
	refs.title = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.44, 0, 0, 38),
		Text = "",
		Font = Theme.Fonts.Display,
		MaxTextSize = 34,
		Parent = parent,
	})
	refs.progress = Theme.progress({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, -24, 0, 52),
		Size = UDim2.new(0.28, 0, 0, 12),
		Gradient = "mint",
		Parent = parent,
	})
	refs.percent = Theme.label({
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0.64, -16, 0, 46),
		Size = UDim2.fromOffset(60, 24),
		Text = "0%",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.MintDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = parent,
	})
	refs.brushButton = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -168, 0, 14),
		Size = UDim2.fromOffset(140, 46),
		Text = "🖌️ Pincel",
		Parent = parent,
		OnClick = function()
			setTool("brush")
		end,
	})
	refs.bucketButton = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 14),
		Size = UDim2.fromOffset(140, 46),
		Text = "🪣 Cubeta",
		Variant = "ghost",
		Parent = parent,
		OnClick = function()
			if Config.hasBucket(levels()) then
				setTool("bucket")
			else
				app.notify("🔒 Compra la mejora «Cubeta mágica» 🪣", "info")
			end
		end,
	})
end

local function buildTimer(parent)
	local holder, body = Theme.card({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(330, 40),
		Radius = 20,
		Parent = parent,
	})
	refs.timerCard = holder
	refs.stars = {}
	for i = 1, 3 do
		refs.stars[i] = Theme.label({
			Position = UDim2.fromOffset(10 + (i - 1) * 26, 6),
			Size = UDim2.fromOffset(26, 28),
			Text = "★",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Gold,
			MaxTextSize = 26,
			Parent = body,
		})
	end
	refs.timerBar = Theme.progress({
		Position = UDim2.fromOffset(96, 15),
		Size = UDim2.new(1, -170, 0, 10),
		Gradient = "gold",
		Parent = body,
	})
	refs.timerText = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(56, 24),
		Text = "0:00",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 18,
		Parent = body,
	})
end

local function buildCanvas(parent)
	local canvasCard = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 46),
		Size = UDim2.new(0.56, 0, 1, -196),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Theme.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local _, canvasBody = Theme.card({
		Size = UDim2.fromScale(1, 1),
		Radius = 22,
		ShadowOffset = 8,
		ShadowTransparency = 0.8,
		StrokeColor = C.White,
		StrokeThickness = 6,
		Parent = canvasCard,
	})
	canvasFrame = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = canvasBody,
	}, { Theme.corner(22) })
	particles = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = canvasBody,
	})
	cursor = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.07, 0.07),
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 8,
		Parent = canvasBody,
	}, { Theme.round(), Theme.stroke(C.Ink, 2.5) })
	catcher = Theme.new("TextButton", {
		Name = "PaintInput",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 9,
		Parent = canvasBody,
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

local function buildColumns(parent)
	for _, side in ipairs({ "left", "right" }) do
		local column = Theme.new("Frame", {
			Name = side,
			AnchorPoint = Vector2.new(side == "left" and 0 or 1, 0.5),
			Position = UDim2.new(side == "left" and 0 or 1, side == "left" and 18 or -18, 0.5, 46),
			Size = UDim2.new(0.19, 0, 1, -200),
			BackgroundTransparency = 1,
			Parent = parent,
		}, { Theme.list("v", 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
		refs[side] = column
	end
end

local function buildValue(parent)
	local holder, body = Theme.card({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(420, 38),
		Radius = 19,
		Parent = parent,
	})
	refs.valueCard = holder
	refs.value = Theme.label({
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.MintDark,
		MaxTextSize = 19,
		Parent = body,
	})
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
		Position = UDim2.new(0.5, 0, 0.5, 16),
		Size = UDim2.fromOffset(480, 610),
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
	refs.donePanel = panel
	refs.donePanelCard = panelCard
	local band = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = C.White,
		Parent = panel,
	}, { Theme.corner(28), Theme.gradient("primary", 0) })
	local title = Theme.label({
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -40, 0, 44),
		Text = "¡Cuadro terminado!",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		MaxTextSize = 38,
		Parent = band,
	})
	Theme.textStroke(C.Shadow, 2, 0.7).Parent = title
	refs.doneStars = {}
	for i = 1, 3 do
		local star = Theme.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (i - 2) * 64, 0, i == 2 and 84 or 90),
			Size = UDim2.fromOffset(i == 2 and 62 or 52, i == 2 and 62 or 52),
			Text = "★",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Gold,
			MaxTextSize = 60,
			Parent = band,
		})
		Theme.textStroke(C.GoldDark, 2.5).Parent = star
		refs.doneStars[i] = star
	end
	local artBox = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 136),
		Size = UDim2.fromOffset(220, 220),
		BackgroundColor3 = C.White,
		Parent = panel,
	}, { Theme.corner(10), Theme.stroke(C.Gold, 8) })
	refs.doneArt = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = artBox },
		{ Theme.corner(10) }
	)
	refs.doneValue = Theme.label({
		Position = UDim2.fromOffset(20, 366),
		Size = UDim2.new(1, -40, 0, 36),
		Text = "",
		Font = Theme.Fonts.Display,
		TextColor3 = C.MintDark,
		MaxTextSize = 32,
		Parent = panel,
	})
	refs.doneBreakdown = Theme.label({
		Position = UDim2.fromOffset(20, 402),
		Size = UDim2.new(1, -40, 0, 22),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 16,
		Parent = panel,
	})
	refs.doneInfo = Theme.label({
		Position = UDim2.fromOffset(20, 426),
		Size = UDim2.new(1, -40, 0, 22),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 16,
		Parent = panel,
	})
	refs.exhibit = Theme.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 460),
		Size = UDim2.new(1, -60, 0, 62),
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
		Position = UDim2.new(0.5, 0, 0, 534),
		Size = UDim2.new(1, -60, 0, 54),
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
	-- Fondo que tapa también la barra superior de Roblox.
	local background = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundColor3 = C.White,
		Parent = gui,
	}, { Theme.gradient(Color3.fromRGB(250, 247, 255), Color3.fromRGB(236, 230, 252), 90) })
	root = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		Parent = background,
	})
	buildTopBar(root)
	buildTimer(root)
	buildCanvas(root)
	buildColumns(root)
	buildValue(root)
	buildComplete()
end

local function updateScales()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local scale = math.clamp(math.min((viewport.X - 20) / 480, (viewport.Y - 70) / 610), 0.45, 1.1)
	local uiScale = refs.doneWrapper:FindFirstChild("ViewportScale")
		or Theme.new("UIScale", { Name = "ViewportScale", Parent = refs.doneWrapper })
	uiScale.Scale = scale
	local hudScale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.6, 1)
	for _, frame in ipairs({ refs.timerCard, refs.valueCard }) do
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
	current = {
		design = design,
		colors = colors,
		progress = {},
		areaRows = {},
		done = false,
		started = os.clock(),
	}
	current.art = DesignArt.render(canvasFrame, design, { mode = "lineart", colors = colors, stroke = 2.5 })
	for i, shape in ipairs(design.shapes) do
		-- Las figuras completamente tapadas ya cuentan como pintadas.
		setShapeProgress(i, shape.visible <= 0 and 1 or 0)
	end
	for _, column in ipairs({ refs.left, refs.right }) do
		for _, child in ipairs(column:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	local half = math.ceil(#design.areas / 2)
	for i, area in ipairs(design.areas) do
		local column = i <= half and refs.left or refs.right
		local _, body = Theme.card({
			Size = UDim2.new(1, 0, 0, 62),
			Radius = 16,
			LayoutOrder = i,
			Parent = column,
		})
		local swatch = Theme.new("Frame", {
			Position = UDim2.fromOffset(10, 11),
			Size = UDim2.fromOffset(40, 40),
			Parent = body,
		}, { Theme.round(), Theme.stroke(C.Border, 2.5) })
		DesignArt.swatch(swatch, colors[area.id])
		Theme.label({
			Position = UDim2.fromOffset(58, 8),
			Size = UDim2.new(1, -110, 0, 24),
			Text = area.name,
			Font = Theme.Fonts.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 19,
			Parent = body,
		})
		local percent = Theme.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 8),
			Size = UDim2.fromOffset(46, 24),
			Text = "0%",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.InkSoft,
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 17,
			Parent = body,
		})
		local bar = Theme.progress({
			Position = UDim2.fromOffset(58, 38),
			Size = UDim2.new(1, -70, 0, 10),
			Gradient = "mint",
			Parent = body,
		})
		current.areaRows[area.id] = { percent = percent, bar = bar }
	end
	refs.title.Text = design.name
	local made = app.state and app.state.made[design.id] or 0
	local base = Config.paintingValue(design, colors, levels(), made, 1)
	refs.value.Text = string.format(
		"💵 %s  ·  Colores x%.2f  ·  ⭐⭐⭐ +%d%%",
		Theme.formatNumber(base),
		Config.colorMultiplier(design, colors),
		math.floor(Config.STAR_BONUS[3] * 100)
	)
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
		refs.exit.SetText("¿Salir? Toca otra vez")
		task.delay(3, function()
			refs.exit.SetText("✕ Salir")
		end)
		app.notify("Si sales pierdes este cuadro (te devolvemos las pinturas).", "info")
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
