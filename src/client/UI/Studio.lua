-- Estudio de pintura: el jugador pinta sobre la plantilla del pedido.
-- Herramientas: pincel (con tamaños), cubeta de relleno por zonas, borrador,
-- deshacer y limpiar. En los modos Original y Remix se ven los números guía.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Scoring = require(Shared.Scoring)
local Templates = require(Shared.Templates)

local Theme = require(script.Parent.Theme)
local PixelArt = require(script.Parent.PixelArt)

local Studio = {}

local C = Theme.Colors
local GRID = Config.GRID
local EMPTY = Palette.EMPTY
local OUTLINE = Palette.OUTLINE
local MAX_UNDO = 40
local GRID_LINE = Color3.fromRGB(226, 218, 236)

local app
local gui, panel
local canvasFrame, catcher
local cellFrames, numberLabels = {}, {}
local paletteButtons = {}
local toolButtons = {}
local sizeButtons = {}
local sizeLocked = {}
local refs = {}

local current = nil -- pedido abierto
local cells = {}
local undoStack = {}
local selectedKey = "r"
local tool = "brush"
local brushSize = 1
local stroking = false
local lastCell = nil
local submitting = false
local confirmUntil = 0
local drafts = {}

-- Utilidades de lienzo ------------------------------------------------------------
local function index(col, row)
	return row * GRID + col + 1
end

local function templateKey(i)
	return string.sub(current.template.flat, i, i)
end

local function targetKey(i)
	if current.target then
		return string.sub(current.target, i, i)
	end
	return nil
end

local function cellColor(i)
	local key = cells[i]
	if key == OUTLINE then
		return Palette.OutlineColor
	end
	if key == EMPTY then
		local target = targetKey(i)
		if current.hints and target == selectedKey and tool ~= "eraser" then
			return Palette.EmptyColor:Lerp(Palette.colorOf(selectedKey), 0.28)
		end
		return Palette.EmptyColor
	end
	return Palette.colorOf(key)
end

local function refreshCell(i)
	local frame = cellFrames[i]
	if not frame then
		return
	end
	frame.BackgroundColor3 = cellColor(i)
	local label = numberLabels[i]
	if label then
		label.Visible = current.hints and cells[i] == EMPTY
	end
end

local function refreshAll()
	for i = 1, Config.CELLS do
		refreshCell(i)
	end
end

local function updateProgress()
	local paintable, filled = 0, 0
	for i = 1, Config.CELLS do
		if templateKey(i) ~= OUTLINE then
			paintable += 1
			if cells[i] ~= EMPTY then
				filled += 1
			end
		end
	end
	local fraction = filled / math.max(paintable, 1)
	refs.progressFill.Size = UDim2.fromScale(fraction, 1)
	refs.progressText.Text = "Progreso " .. math.floor(fraction * 100 + 0.5) .. "%"
	refs.submit.SetBaseColor(fraction >= 0.999 and C.Green or C.Primary)
	return fraction
end

local function snapshot()
	return table.concat(cells)
end

local function pushUndo()
	table.insert(undoStack, snapshot())
	if #undoStack > MAX_UNDO then
		table.remove(undoStack, 1)
	end
end

local function loadSnapshot(str)
	for i = 1, Config.CELLS do
		cells[i] = string.sub(str, i, i)
	end
	refreshAll()
	updateProgress()
end

local function paintCell(col, row, key)
	if col < 0 or row < 0 or col >= GRID or row >= GRID then
		return false
	end
	local i = index(col, row)
	if templateKey(i) == OUTLINE or cells[i] == key then
		return false
	end
	cells[i] = key
	refreshCell(i)
	return true
end

local function paintBrush(col, row)
	local key = tool == "eraser" and EMPTY or selectedKey
	local offset = math.floor((brushSize - 1) / 2)
	local changed = false
	for dy = 0, brushSize - 1 do
		for dx = 0, brushSize - 1 do
			if paintCell(col + dx - offset, row + dy - offset, key) then
				changed = true
			end
		end
	end
	return changed
end

-- Rellena la zona de la plantilla (misma letra) que tenga el mismo color actual.
local function floodFill(col, row)
	local start = index(col, row)
	local zone = templateKey(start)
	if zone == OUTLINE then
		return false
	end
	local from = cells[start]
	local to = selectedKey
	if from == to then
		return false
	end
	local queue = { { col, row } }
	local seen = { [start] = true }
	local head = 1
	while head <= #queue do
		local c, r = queue[head][1], queue[head][2]
		head += 1
		local i = index(c, r)
		cells[i] = to
		refreshCell(i)
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nc, nr = c + d[1], r + d[2]
			if nc >= 0 and nr >= 0 and nc < GRID and nr < GRID then
				local ni = index(nc, nr)
				if not seen[ni] and templateKey(ni) == zone and cells[ni] == from then
					seen[ni] = true
					table.insert(queue, { nc, nr })
				end
			end
		end
	end
	return true
end

local function cellAt(position)
	local absPos = canvasFrame.AbsolutePosition
	local absSize = canvasFrame.AbsoluteSize
	if absSize.X <= 0 or absSize.Y <= 0 then
		return nil
	end
	local col = math.floor((position.X - absPos.X) / absSize.X * GRID)
	local row = math.floor((position.Y - absPos.Y) / absSize.Y * GRID)
	if col < 0 or row < 0 or col >= GRID or row >= GRID then
		return nil
	end
	return col, row
end

local function strokeTo(col, row)
	if not lastCell then
		paintBrush(col, row)
	else
		-- Interpola para que los trazos rápidos no dejen huecos.
		local c0, r0 = lastCell[1], lastCell[2]
		local steps = math.max(math.abs(col - c0), math.abs(row - r0))
		for s = 1, steps do
			local t = s / steps
			paintBrush(math.floor(c0 + (col - c0) * t + 0.5), math.floor(r0 + (row - r0) * t + 0.5))
		end
	end
	lastCell = { col, row }
end

local function onPress(position)
	if not current or submitting then
		return
	end
	local col, row = cellAt(position)
	if not col then
		return
	end
	pushUndo()
	if tool == "fill" then
		if floodFill(col, row) then
			Theme.playSound("whoosh", 1.3)
			updateProgress()
		else
			table.remove(undoStack)
		end
		return
	end
	stroking = true
	lastCell = nil
	strokeTo(col, row)
	Theme.playSound("paint", 0.9 + math.random() * 0.3)
	updateProgress()
end

-- Selección de herramientas ---------------------------------------------------------
local function refreshTools()
	for key, button in pairs(paletteButtons) do
		local selected = (key == selectedKey and tool ~= "eraser") or (key == EMPTY and tool == "eraser")
		button.stroke.Thickness = selected and 4 or 0
		button.check.Visible = selected
	end
	for name, button in pairs(toolButtons) do
		button.SetBaseColor(name == tool and C.Pink or C.Primary)
	end
	for size, button in pairs(sizeButtons) do
		if sizeLocked[size] then
			button.SetEnabled(false)
		else
			button.SetBaseColor((size == brushSize and tool ~= "fill") and C.Pink or Color3.fromRGB(150, 130, 200))
		end
	end
	if refs.colorName then
		if tool == "eraser" then
			refs.colorName.Text = "Borrador"
		else
			local entry = Palette.ByKey[selectedKey]
			refs.colorName.Text = entry and (entry.index .. " · " .. entry.name) or ""
		end
	end
	if current then
		refreshAll()
	end
end

local function selectColor(key)
	if key == EMPTY then
		tool = "eraser"
	else
		selectedKey = key
		if tool == "eraser" then
			tool = "brush"
		end
	end
	refreshTools()
end

local function setTool(name)
	tool = name
	refreshTools()
end

-- Construcción de la interfaz ---------------------------------------------------------
local function buildCanvas(parent)
	canvasFrame = Theme.new("Frame", {
		Name = "Canvas",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GRID_LINE,
		BorderSizePixel = 0,
		Parent = parent,
	})
	for row = 0, GRID - 1 do
		for col = 0, GRID - 1 do
			local i = index(col, row)
			local cell = Theme.new("Frame", {
				Name = "C" .. i,
				Position = UDim2.new(col / GRID, 0, row / GRID, 0),
				Size = UDim2.new(1 / GRID, -1, 1 / GRID, -1),
				BackgroundColor3 = Palette.EmptyColor,
				BorderSizePixel = 0,
				Parent = canvasFrame,
			})
			cellFrames[i] = cell
			numberLabels[i] = Theme.new("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = Theme.Fonts.Bold,
				TextScaled = true,
				TextColor3 = Color3.fromRGB(170, 160, 190),
				Text = "",
				Visible = false,
				Parent = cell,
			}, {
				Theme.new("UITextSizeConstraint", { MaxTextSize = 14 }),
				Theme.new("UIPadding", {
					PaddingTop = UDim.new(0.2, 0),
					PaddingBottom = UDim.new(0.2, 0),
				}),
			})
		end
	end
	catcher = Theme.new("TextButton", {
		Name = "Input",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = canvasFrame,
	})
	catcher.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			onPress(input.Position)
		end
	end)
end

local function buildPalette(parent)
	local grid = Theme.new("Frame", {
		Name = "Palette",
		Size = UDim2.fromScale(1, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Theme.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 1 / 6, -6),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local entries = {}
	for _, entry in ipairs(Palette.List) do
		table.insert(entries, entry)
	end
	table.insert(entries, { key = EMPTY, name = "Borrador", color = Color3.fromRGB(255, 255, 255), index = 99 })

	for order, entry in ipairs(entries) do
		local button = Theme.new("TextButton", {
			Name = entry.key,
			BackgroundColor3 = entry.color,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = order,
			Parent = grid,
		}, { Theme.corner(10) })
		local stroke = Theme.stroke(C.Ink, 0)
		stroke.Parent = button
		Theme.stroke(Color3.fromRGB(0, 0, 0), 1, 0.85).Parent = button
		local isLight = entry.color.R * 0.3 + entry.color.G * 0.59 + entry.color.B * 0.11 > 0.6
		Theme.label({
			Size = UDim2.fromScale(1, 1),
			Text = entry.key == EMPTY and "🧽" or tostring(entry.index),
			Font = Theme.Fonts.Title,
			TextColor3 = isLight and C.Ink or Color3.new(1, 1, 1),
			MaxTextSize = 22,
			Parent = button,
		}, nil)
		local check = Theme.new("Frame", {
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.new(1, -6, 0, -6),
			BackgroundColor3 = C.Pink,
			Visible = false,
			ZIndex = 3,
			Parent = button,
		}, { Theme.corner(6), Theme.stroke(Color3.new(1, 1, 1), 2) })
		button.Activated:Connect(function()
			Theme.playSound("click", 1.2)
			selectColor(entry.key)
		end)
		paletteButtons[entry.key] = { stroke = stroke, check = check }
	end
end

local function buildUI()
	gui = Theme.new("ScreenGui", {
		Name = "Studio",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 10,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = gui,
	})
	panel = Theme.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.97, 0.94),
		BackgroundColor3 = C.Background,
		Parent = gui,
	}, {
		Theme.corner(22),
		Theme.stroke(C.Ink, 4),
		Theme.new("UIAspectRatioConstraint", { AspectRatio = 1.62 }),
		Theme.new("UISizeConstraint", { MaxSize = Vector2.new(1240, 766) }),
	})

	-- Cabecera.
	local header = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.11),
		BackgroundColor3 = C.Primary,
		Parent = panel,
	}, {
		Theme.corner(22),
		Theme.gradient(Color3.fromRGB(150, 120, 255), Color3.fromRGB(255, 120, 190), 0),
	})
	Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0.4, 0),
		Position = UDim2.fromScale(0, 0.6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = header,
	}, { Theme.gradient(Color3.fromRGB(150, 120, 255), Color3.fromRGB(255, 120, 190), 0) })
	Theme.label({
		Size = UDim2.fromScale(0.4, 0.7),
		Position = UDim2.fromScale(0.02, 0.15),
		Text = "🎨 Estudio de Pintura",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = header,
	}, nil)
		:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize =
		34
	Theme.textStroke(C.PrimaryDark, 2).Parent = header:FindFirstChildOfClass("TextLabel")

	refs.patienceBack = Theme.new("Frame", {
		Size = UDim2.fromScale(0.3, 0.26),
		Position = UDim2.fromScale(0.52, 0.37),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.4,
		Parent = header,
	}, { Theme.corner(10) })
	refs.patienceFill = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Green,
		Parent = refs.patienceBack,
	}, { Theme.corner(10) })
	Theme.label({
		Size = UDim2.fromScale(0.1, 0.6),
		Position = UDim2.fromScale(0.42, 0.2),
		Text = "⏳",
		Parent = header,
	})

	Theme.button({
		Size = UDim2.fromScale(0.06, 0.7),
		Position = UDim2.fromScale(0.925, 0.12),
		Text = "✕",
		Color = C.Red,
		Radius = 12,
		Parent = header,
		OnClick = function()
			Studio.close(true)
		end,
	})

	-- Columna izquierda: el pedido.
	local left = Theme.new("Frame", {
		Size = UDim2.fromScale(0.24, 0.84),
		Position = UDim2.fromScale(0.015, 0.135),
		BackgroundColor3 = C.Panel,
		Parent = panel,
	}, { Theme.corner(18), Theme.stroke(C.Ink, 2, 0.8), Theme.padding(10) })

	refs.customer = Theme.label({
		Size = UDim2.fromScale(1, 0.08),
		Text = "Pedido",
		Parent = left,
	})
	refs.modeBadge = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.07),
		Position = UDim2.fromScale(0, 0.09),
		BackgroundColor3 = C.Primary,
		Parent = left,
	}, { Theme.corner(10) })
	refs.modeText = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		Parent = refs.modeBadge,
	})
	Theme.new(
		"UIPadding",
		{ PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0), Parent = refs.modeText }
	)

	refs.request = Theme.label({
		Size = UDim2.fromScale(1, 0.17),
		Position = UDim2.fromScale(0, 0.17),
		Text = "",
		Font = Theme.Fonts.Body,
		TextWrapped = true,
		TextColor3 = C.InkSoft,
		MaxTextSize = 18,
		Parent = left,
	})

	local previewHolder = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.42),
		Position = UDim2.fromScale(0, 0.35),
		BackgroundTransparency = 1,
		Parent = left,
	})
	refs.preview = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.EmptyColor,
		Parent = previewHolder,
	}, {
		Theme.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Theme.stroke(C.Gold, 4),
	})
	refs.previewTag = Theme.label({
		Size = UDim2.fromScale(0.9, 0.16),
		Position = UDim2.fromScale(0.05, 0.82),
		Text = "Referencia",
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = refs.preview,
	})
	Theme.textStroke(C.Ink, 2).Parent = refs.previewTag

	refs.swatches = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.07),
		Position = UDim2.fromScale(0, 0.78),
		BackgroundTransparency = 1,
		Parent = left,
	}, {
		Theme.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
		}),
	})

	refs.reward = Theme.label({
		Size = UDim2.fromScale(1, 0.07),
		Position = UDim2.fromScale(0, 0.86),
		Text = "",
		TextColor3 = C.GoldDark,
		Parent = left,
	})
	local progressBack = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.06),
		Position = UDim2.fromScale(0, 0.94),
		BackgroundColor3 = Color3.fromRGB(234, 228, 244),
		Parent = left,
	}, { Theme.corner(8) })
	refs.progressFill = Theme.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Primary,
		Parent = progressBack,
	}, { Theme.corner(8), Theme.gradient(Color3.fromRGB(150, 120, 255), Color3.fromRGB(255, 120, 190), 0) })
	refs.progressText = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "Progreso 0%",
		TextColor3 = C.Ink,
		ZIndex = 3,
		Parent = progressBack,
	})

	-- Centro: lienzo cuadrado.
	local canvasHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromScale(0.47, 0.84),
		Position = UDim2.fromScale(0.5, 0.135),
		BackgroundColor3 = Color3.fromRGB(120, 80, 50),
		Parent = panel,
	}, {
		Theme.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Theme.corner(10),
		Theme.stroke(Color3.fromRGB(90, 60, 36), 3),
		Theme.padding(10),
	})
	buildCanvas(canvasHolder)

	-- Columna derecha: paleta y herramientas.
	local right = Theme.new("Frame", {
		Size = UDim2.fromScale(0.24, 0.84),
		Position = UDim2.fromScale(0.745, 0.135),
		BackgroundColor3 = C.Panel,
		Parent = panel,
	}, { Theme.corner(18), Theme.stroke(C.Ink, 2, 0.8), Theme.padding(10) })

	refs.colorName = Theme.label({
		Size = UDim2.fromScale(1, 0.06),
		Text = "",
		Parent = right,
	})
	local paletteHolder = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.5),
		Position = UDim2.fromScale(0, 0.07),
		BackgroundTransparency = 1,
		Parent = right,
	})
	buildPalette(paletteHolder)
	paletteHolder.Palette.Size = UDim2.fromScale(1, 1)

	local toolsRow = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.1),
		Position = UDim2.fromScale(0, 0.59),
		BackgroundTransparency = 1,
		Parent = right,
	})
	toolButtons.brush = Theme.button({
		Size = UDim2.new(0.5, -4, 1, -4),
		Text = "🖌️ Pincel",
		Parent = toolsRow,
		OnClick = function()
			setTool("brush")
		end,
	})
	toolButtons.fill = Theme.button({
		Size = UDim2.new(0.5, -4, 1, -4),
		Position = UDim2.new(0.5, 4, 0, 0),
		Text = "🪣 Cubeta",
		Parent = toolsRow,
		OnClick = function()
			setTool("fill")
		end,
	})

	refs.sizeRow = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.08),
		Position = UDim2.fromScale(0, 0.71),
		BackgroundTransparency = 1,
		Parent = right,
	})
	for size = 1, 3 do
		sizeButtons[size] = Theme.button({
			Size = UDim2.new(1 / 3, -4, 1, -4),
			Position = UDim2.new((size - 1) / 3, 2, 0, 0),
			Text = size .. "x" .. size,
			Color = Color3.fromRGB(150, 130, 200),
			Parent = refs.sizeRow,
			OnClick = function()
				brushSize = size
				if tool == "fill" then
					tool = "brush"
				end
				refreshTools()
			end,
		})
	end

	local actionRow = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.08),
		Position = UDim2.fromScale(0, 0.8),
		BackgroundTransparency = 1,
		Parent = right,
	})
	Theme.button({
		Size = UDim2.new(0.5, -4, 1, -4),
		Text = "↩️ Deshacer",
		Color = C.Orange,
		Parent = actionRow,
		OnClick = function()
			Studio.undo()
		end,
	})
	Theme.button({
		Size = UDim2.new(0.5, -4, 1, -4),
		Position = UDim2.new(0.5, 4, 0, 0),
		Text = "🗑️ Limpiar",
		Color = Color3.fromRGB(150, 140, 170),
		Parent = actionRow,
		OnClick = function()
			if not current then
				return
			end
			pushUndo()
			loadSnapshot(Scoring.blankCanvas(current.template))
			Theme.playSound("whoosh", 0.8)
		end,
	})

	refs.submit = Theme.button({
		Size = UDim2.new(1, 0, 0.1, -4),
		Position = UDim2.fromScale(0, 0.9),
		Text = "✅ Entregar obra",
		Color = C.Primary,
		Parent = right,
		OnClick = function()
			Studio.submit()
		end,
	})
end

-- Entrada global (arrastrar el pincel y atajos de teclado) --------------------------
local function bindInput()
	UserInputService.InputChanged:Connect(function(input)
		if not (stroking and current) then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local col, row = cellAt(input.Position)
			if col then
				strokeTo(col, row)
				updateProgress()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			stroking = false
			lastCell = nil
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not current then
			return
		end
		local code = input.KeyCode
		if code == Enum.KeyCode.B then
			setTool("brush")
		elseif code == Enum.KeyCode.F or code == Enum.KeyCode.G then
			setTool("fill")
		elseif code == Enum.KeyCode.X then
			selectColor(EMPTY)
		elseif code == Enum.KeyCode.Z then
			Studio.undo()
		elseif code == Enum.KeyCode.Return then
			Studio.submit()
		end
	end)
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

-- API ----------------------------------------------------------------------------------
function Studio.init(appRef)
	app = appRef
	buildUI()
	refreshTools()
end

function Studio.isOpen()
	return current ~= nil
end

function Studio.undo()
	if not current or #undoStack == 0 then
		return
	end
	loadSnapshot(table.remove(undoStack))
	Theme.playSound("click", 0.8)
end

local opening = false

function Studio.open(model)
	if current or submitting or opening then
		return
	end
	local orderId = model:GetAttribute("OrderId")
	local template = Templates.get(model:GetAttribute("TemplateId"))
	if not (orderId and template) then
		return
	end
	opening = true
	local ok, accepted = pcall(function()
		return app.remotes.StartPainting:InvokeServer(orderId)
	end)
	opening = false
	if not (ok and accepted) then
		app.notify("Ese cliente ya no está esperando.", "error")
		return
	end

	local order = {
		mode = model:GetAttribute("Mode"),
		swapFrom = model:GetAttribute("SwapFrom"),
		swapTo = model:GetAttribute("SwapTo"),
		theme = model:GetAttribute("Theme"),
	}
	local target = Scoring.targetString(order, template)
	current = {
		id = orderId,
		model = model,
		template = template,
		order = order,
		target = target,
		hints = target ~= nil,
	}

	-- Números guía.
	for i = 1, Config.CELLS do
		local label = numberLabels[i]
		local key = target and string.sub(target, i, i)
		local entry = key and Palette.ByKey[key]
		label.Text = entry and tostring(entry.index) or ""
	end

	-- Cargar borrador previo o lienzo en blanco.
	undoStack = {}
	loadSnapshot(drafts[orderId] or Scoring.blankCanvas(template))

	-- Panel del pedido.
	local mode = Config.Modes[order.mode] or Config.Modes.original
	local vip = model:GetAttribute("VIP")
	refs.customer.Text = (vip and "👑 " or "") .. "Pedido de " .. tostring(model:GetAttribute("CustomerName"))
	refs.modeBadge.BackgroundColor3 = mode.color
	refs.modeText.Text = mode.icon .. " Modo " .. mode.name .. (vip and " · VIP" or "")
	refs.request.Text = Scoring.describe(order, template)
	refs.reward.Text = "💰 Hasta "
		.. Theme.formatNumber(math.floor((model:GetAttribute("Reward") or 0) * Config.STAR_PAY[3]))
		.. " + propina"
	PixelArt.render(refs.preview, target or Scoring.blankCanvas(template))
	refs.previewTag.Text = target and "Referencia" or (order.mode == "tema" and "¡Tú eliges!" or "¡Libre!")

	for _, child in ipairs(refs.swatches:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if order.mode == "tema" then
		local theme = Config.ThemeById[order.theme]
		if theme then
			for i = 1, #theme.keys do
				Theme.new("Frame", {
					Size = UDim2.new(0, 22, 1, 0),
					BackgroundColor3 = Palette.colorOf(string.sub(theme.keys, i, i)),
					Parent = refs.swatches,
				}, { Theme.corner(6), Theme.stroke(C.Ink, 1, 0.6) })
			end
		end
	end

	-- Pinceles desbloqueados.
	local sizes = Config.brushSizes(app.state and app.state.upgrades or {})
	local unlocked = {}
	for _, size in ipairs(sizes) do
		unlocked[size] = true
	end
	for size, button in pairs(sizeButtons) do
		sizeLocked[size] = not unlocked[size]
		button.SetEnabled(unlocked[size] == true)
		button.Button.Text = unlocked[size] and (size .. "x" .. size) or "🔒"
	end
	if not unlocked[brushSize] then
		brushSize = 1
	end
	tool = target and "fill" or "brush"
	if target then
		-- Empieza con el color de la zona más grande para ir directo al grano.
		local counts, best, bestKey = {}, 0, selectedKey
		for i = 1, #target do
			local key = string.sub(target, i, i)
			if key ~= OUTLINE then
				counts[key] = (counts[key] or 0) + 1
				if counts[key] > best then
					best, bestKey = counts[key], key
				end
			end
		end
		selectedKey = bestKey
	end
	refreshTools()

	-- Vigilar al cliente.
	local function watch()
		if not current or current.model ~= model then
			return
		end
		local max = model:GetAttribute("MaxPatience") or 1
		local fraction = math.clamp((model:GetAttribute("Patience") or 0) / math.max(max, 1), 0, 1)
		refs.patienceFill.Size = UDim2.fromScale(fraction, 1)
		refs.patienceFill.BackgroundColor3 = app.patienceColor(fraction)
		if model:GetAttribute("State") ~= "waiting" and not submitting then
			app.notify((model:GetAttribute("CustomerName") or "El cliente") .. " se fue sin esperar 😢", "error")
			Studio.close(false)
		end
	end
	current.attrConnection = model.AttributeChanged:Connect(watch)
	current.ancestryConnection = model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and current and current.model == model and not submitting then
			Studio.close(false)
		end
	end)
	watch()

	ProximityPromptService.Enabled = false
	setControlsEnabled(false)
	gui.Enabled = true
	Theme.pop(panel, 0.85)
	Theme.playSound("whoosh")
end

function Studio.close(sendStop)
	if not current then
		gui.Enabled = false
		return
	end
	local closing = current
	drafts[closing.id] = snapshot()
	if closing.attrConnection then
		closing.attrConnection:Disconnect()
	end
	if closing.ancestryConnection then
		closing.ancestryConnection:Disconnect()
	end
	if sendStop then
		app.remotes.StopPainting:FireServer(closing.id)
	end
	current = nil
	stroking = false
	lastCell = nil
	gui.Enabled = false
	ProximityPromptService.Enabled = true
	setControlsEnabled(true)
end

function Studio.submit()
	if not current or submitting then
		return
	end
	local fraction = updateProgress()
	if fraction < 0.9 and os.clock() > confirmUntil then
		confirmUntil = os.clock() + 3
		refs.submit.Button.Text = "¿Entregar incompleta?"
		task.delay(3, function()
			if refs.submit.Button.Text == "¿Entregar incompleta?" then
				refs.submit.Button.Text = "✅ Entregar obra"
			end
		end)
		return
	end
	confirmUntil = 0
	refs.submit.Button.Text = "✅ Entregar obra"

	submitting = true
	local order = current
	local art = snapshot()
	local ok, result = pcall(function()
		return app.remotes.SubmitPainting:InvokeServer(order.id, art)
	end)
	submitting = false

	if not ok or type(result) ~= "table" then
		app.notify("No se pudo entregar. Inténtalo otra vez.", "error")
		return
	end
	if not result.ok then
		app.notify(result.reason or "No se pudo entregar.", "error")
		if current == order and not (order.model.Parent and order.model:GetAttribute("State") == "waiting") then
			Studio.close(false)
		end
		return
	end
	drafts[order.id] = nil
	if current == order then
		Studio.close(false)
	end
	drafts[order.id] = nil
	app.showResults(result, order.template, art)
end

function Studio.start()
	bindInput()
end

return Studio
