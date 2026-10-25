-- Estudio de pintura: el diseño aparece en líneas y cada figura se rellena con
-- el color de su área mientras pasas el pincel por encima.

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
local current -- { design, colors, art, progress, areaLabels, done }
local stroking = false
local pointer = nil
local tool = "brush"
local particleClock = 0
local soundClock = 0
local confirmCancelUntil = 0
local finishing = false

-- Utilidades ----------------------------------------------------------------------------
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

local function refreshLabels()
	for areaId, label in pairs(current.areaLabels) do
		local p = areaPercent(areaId)
		local area = current.design.areaById[areaId]
		if p >= 0.999 then
			label.Text = area.name .. "\n✔ 100%"
			label.TextColor3 = C.PrimaryDark
		else
			label.Text = area.name .. "\n" .. math.floor(p * 100) .. "%"
			label.TextColor3 = C.Ink
		end
	end
	local total = totalPercent()
	refs.title.Text = current.design.name .. " · " .. math.floor(total * 100) .. "%"
	refs.progressFill.Size = UDim2.fromScale(total, 1)
end

-- Partículas --------------------------------------------------------------------------------
local function spawnParticle(x, y, color, burst)
	local dot = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(0.018, 0.018),
		BackgroundColor3 = color,
		ZIndex = 6,
		Parent = particles,
	}, { Theme.corner(50) })
	local angle = math.random() * math.pi * 2
	local distance = (burst and 0.08 or 0.035) * (0.4 + math.random())
	Theme.tween(dot, 0.45, {
		Position = UDim2.fromScale(x + math.cos(angle) * distance, y + math.sin(angle) * distance),
		Size = UDim2.fromScale(0.004, 0.004),
		BackgroundTransparency = 1,
	})
	task.delay(0.5, function()
		dot:Destroy()
	end)
end

-- Pintar ------------------------------------------------------------------------------------
local function setShapeProgress(i, p)
	current.progress[i] = p
	current.art.setProgress(i, p)
end

local function areaColor(shapeIndex)
	local shape = current.design.shapes[shapeIndex]
	return Colors.mainColor(current.colors[shape.area])
end

local function completeIfDone()
	if not current.done and isComplete() then
		current.done = true
		stroking = false
		refreshLabels()
		task.delay(0.35, function()
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
		local time = Designs.shapeTime(current.design.shapes[index])
		-- Basta con rozar una figura para pintarla; cubrirla entera va más rápido.
		local coverage = 0.6 + 0.4 * count / #samples
		local amount = dt * speed * coverage * 1.15 / math.max(time, 0.05)
		setShapeProgress(index, math.min(1, current.progress[index] + amount))
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
	local radius = tool == "bucket" and 0.02 or Config.brushRadius(levels())
	cursor.Visible = true
	cursor.Position = UDim2.fromScale(x, y)
	cursor.Size = UDim2.fromScale(radius * 2.4, radius * 2.4)
	local index = Designs.shapeAt(current.design, x, y)
	cursor.BackgroundColor3 = index and areaColor(index) or Color3.new(1, 1, 1)
end

local function onStep(dt)
	if not current then
		return
	end
	updateCursor()
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

-- Interfaz ---------------------------------------------------------------------------------
local function setTool(name)
	tool = name
	refs.brushButton.SetBaseColor(name == "brush" and C.Mint or Color3.fromRGB(220, 210, 200))
	refs.bucketButton.SetBaseColor(name == "bucket" and C.Mint or Color3.fromRGB(220, 210, 200))
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
	-- Se extiende hacia arriba para tapar también la barra superior de Roblox.
	root = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundColor3 = C.Background,
		Parent = gui,
	})
	root = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		Parent = root,
	})

	-- Barra superior.
	refs.exit = Theme.button({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(140, 46),
		Text = "✕ Salir",
		Soft = true,
		Color = C.Red,
		Parent = root,
		OnClick = function()
			Painter.requestCancel()
		end,
	})
	refs.title = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0.5, 0, 0, 40),
		Text = "",
		MaxTextSize = 36,
		Parent = root,
	})
	local barBack = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(0.3, 0, 0, 10),
		BackgroundColor3 = Color3.fromRGB(240, 234, 226),
		Parent = root,
	}, { Theme.corner(5) })
	refs.progressFill = Theme.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Mint,
		Parent = barBack,
	}, { Theme.corner(5) })

	refs.brushButton = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -170, 0, 12),
		Size = UDim2.fromOffset(140, 46),
		Text = "🖌️ Pincel",
		Color = C.Mint,
		Parent = root,
		OnClick = function()
			setTool("brush")
		end,
	})
	refs.bucketButton = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(140, 46),
		Text = "🪣 Cubeta",
		Color = Color3.fromRGB(220, 210, 200),
		Parent = root,
		OnClick = function()
			if Config.hasBucket(levels()) then
				setTool("bucket")
			else
				app.notify("Compra la mejora «Cubeta mágica» 🪣", "info")
			end
		end,
	})

	-- Lienzo.
	local canvasHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(0.6, 0, 1, -150),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = root,
	}, {
		Theme.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Theme.corner(18),
		Theme.stroke(Color3.fromRGB(240, 230, 220), 4),
	})
	canvasFrame = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = canvasHolder,
	}, { Theme.corner(18) })
	particles = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = canvasHolder,
	})
	cursor = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.07, 0.07),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 8,
		Parent = canvasHolder,
	}, { Theme.corner(50), Theme.stroke(C.Ink, 2) })
	catcher = Theme.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 9,
		Parent = canvasHolder,
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

	-- Columnas de áreas a los lados del lienzo.
	refs.left = Theme.new("Frame", {
		Position = UDim2.new(0, 16, 0, 80),
		Size = UDim2.new(0.18, 0, 1, -100),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Theme.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	refs.right = Theme.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 80),
		Size = UDim2.new(0.18, 0, 1, -100),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Theme.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	refs.value = Theme.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(0.5, 0, 0, 28),
		Text = "",
		TextColor3 = C.PrimaryDark,
		MaxTextSize = 24,
		Parent = root,
	})

	-- Ventana de cuadro terminado.
	refs.done = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	local wrapper = Theme.new("Frame", {
		Name = "Wrapper",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 560),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = refs.done,
	})
	refs.donePanel = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Background,
		ZIndex = 20,
		Parent = wrapper,
	}, { Theme.corner(28), Theme.stroke(Color3.fromRGB(240, 230, 220), 3) })
	Theme.label({
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 50),
		Text = "✨ ¡Cuadro terminado! ✨",
		MaxTextSize = 40,
		ZIndex = 21,
		Parent = refs.donePanel,
	})
	local artBox = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.fromOffset(240, 240),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 21,
		Parent = refs.donePanel,
	}, { Theme.corner(12), Theme.stroke(C.Gold, 8) })
	refs.doneArt = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 21, Parent = artBox },
		{
			Theme.corner(12),
		}
	)
	refs.doneValue = Theme.label({
		Position = UDim2.fromOffset(20, 324),
		Size = UDim2.new(1, -40, 0, 34),
		Text = "",
		TextColor3 = C.PrimaryDark,
		MaxTextSize = 30,
		ZIndex = 21,
		Parent = refs.donePanel,
	})
	refs.doneInfo = Theme.label({
		Position = UDim2.fromOffset(20, 358),
		Size = UDim2.new(1, -40, 0, 26),
		Text = "",
		TextColor3 = C.InkSoft,
		MaxTextSize = 19,
		ZIndex = 21,
		Parent = refs.donePanel,
	})
	refs.exhibit = Theme.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 396),
		Size = UDim2.new(1, -60, 0, 60),
		Text = "",
		Color = C.Mint,
		ZIndex = 21,
		Parent = refs.donePanel,
		OnClick = function()
			Painter.finish("galeria")
		end,
	})
	refs.sell = Theme.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 470),
		Size = UDim2.new(1, -60, 0, 56),
		Text = "",
		Soft = true,
		Color = C.Gold,
		ZIndex = 21,
		Parent = refs.donePanel,
		OnClick = function()
			Painter.finish("vender")
		end,
	})
	refs.doneWrapper = wrapper
end

local function updateDoneScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local scale = math.clamp(math.min((viewport.X - 20) / 460, (viewport.Y - 80) / 560), 0.45, 1.1)
	local uiScale = refs.doneWrapper:FindFirstChild("ViewportScale")
		or Theme.new("UIScale", { Name = "ViewportScale", Parent = refs.doneWrapper })
	uiScale.Scale = scale
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

-- API -----------------------------------------------------------------------------------------
function Painter.open(design, colors)
	current = {
		design = design,
		colors = colors,
		progress = {},
		areaLabels = {},
		done = false,
	}
	current.art = DesignArt.render(canvasFrame, design, { mode = "lineart", colors = colors, stroke = 2 })
	for i, shape in ipairs(design.shapes) do
		-- Las figuras completamente tapadas ya cuentan como pintadas.
		local initial = shape.visible <= 0 and 1 or 0
		setShapeProgress(i, initial)
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
		local row = Theme.new("Frame", {
			Size = UDim2.new(1, 0, 0, 58),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = column,
		})
		local swatch = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			Parent = row,
		}, { Theme.corner(13), Theme.stroke(Color3.fromRGB(235, 225, 215), 2) })
		DesignArt.swatch(swatch, colors[area.id])
		current.areaLabels[area.id] = Theme.label({
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -34, 1, 0),
			Text = area.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			Parent = row,
		})
	end
	local value = Config.paintingValue(design, colors, levels(), app.state and app.state.made[design.id] or 0)
	refs.value.Text =
		string.format("Valor x%.2f · 💵 %s", Config.colorMultiplier(design, colors), Theme.formatNumber(value))
	current.value = value
	refs.done.Visible = false
	setTool(tool == "bucket" and Config.hasBucket(levels()) and "bucket" or "brush")
	refreshLabels()
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
		refs.exit.Button.Text = "¿Salir? Toca otra vez"
		task.delay(3, function()
			refs.exit.Button.Text = "✕ Salir"
		end)
		app.notify("Si sales pierdes este cuadro (te devolvemos las pinturas).", "info")
		return
	end
	confirmCancelUntil = 0
	refs.exit.Button.Text = "✕ Salir"
	app.remotes.CancelPainting:FireServer()
	Painter.close()
end

function Painter.showComplete()
	local state = app.state
	DesignArt.render(refs.doneArt, current.design, { mode = "color", colors = current.colors, outline = false })
	local value = current.value
	local galleryPrice = math.floor(value * Config.GALLERY_BONUS)
	refs.doneValue.Text = "💵 Vale " .. Theme.formatNumber(value)
	local free = state and (state.slots - state.displayed) or 0
	refs.doneInfo.Text = free > 0 and ("Huecos libres en tu galería: " .. free)
		or "Tu galería está llena: compra «Más paredes» 🖼️"
	refs.exhibit.Button.Text = "🖼️ Exponer en la galería · 💵 " .. Theme.formatNumber(galleryPrice)
	refs.exhibit.SetEnabled(free > 0)
	refs.sell.Button.Text = "💰 Vender ya · 💵 " .. Theme.formatNumber(value)
	updateDoneScale()
	refs.done.Visible = true
	Theme.pop(refs.donePanel, 0.6)
	Theme.playSound("success", 1)
	app.celebrate()
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
	if result.displayed then
		app.notify(
			"🖼️ ¡Tu cuadro está en la galería! Un visitante lo comprará por 💵" .. result.price,
			"success"
		)
	else
		app.notify("💰 ¡Vendido por 💵" .. result.price .. "!", "gold")
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
end

return Painter
