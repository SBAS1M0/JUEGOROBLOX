-- Ventana "Elige tus colores": un color por área antes de empezar a pintar.
-- Los colores raros multiplican el valor del cuadro.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)
local DesignArt = require(script.Parent.DesignArt)

local ColorPicker = {}

local C = Theme.Colors

local app
local window
local refs = {}
local design
local choices = {}
local selectedArea
local preview
local areaRows = {}
local remembered = {}
local busy = false

local function owned(colorId)
	local entry = Colors.ById[colorId]
	if entry and entry.basic then
		return math.huge
	end
	return app.state and app.state.paints[colorId] or 0
end

-- Unidades libres de un color sin contar el área seleccionada.
local function remaining(colorId, exceptArea)
	local used = 0
	for areaId, chosen in pairs(choices) do
		if chosen == colorId and areaId ~= exceptArea then
			used += 1
		end
	end
	return owned(colorId) - used
end

local function colorRarityText(colorId)
	local entry = Colors.ById[colorId]
	local rarity = Colors.rarityOf(entry)
	return rarity.name .. " x" .. string.format("%.1f", rarity.mult), rarity.color
end

local function updateValue()
	if not design then
		return
	end
	local state = app.state
	local mult = Config.colorMultiplier(design, choices)
	local value = Config.paintingValue(design, choices, state.upgrades, state.made[design.id] or 0)
	refs.value.Text = string.format("Valor del cuadro x%.2f  ·  💵 %s", mult, Theme.formatNumber(value))
	preview.setColors(choices)
end

local function refreshAreas()
	for _, row in pairs(areaRows) do
		local areaId = row.area.id
		local selected = areaId == selectedArea
		row.frame.BackgroundColor3 = selected and C.YellowSoft or C.Panel
		row.stroke.Thickness = selected and 2.5 or 0
		DesignArt.swatch(row.swatch, choices[areaId])
		local entry = Colors.ById[choices[areaId]]
		row.colorName.Text = entry and entry.name or ""
		local _, rarityColor = colorRarityText(choices[areaId])
		row.colorName.TextColor3 = entry and entry.basic and C.InkSoft or rarityColor
	end
end

local function sortedColors()
	local list = {}
	for _, entry in ipairs(Colors.List) do
		if not entry.basic and owned(entry.id) > 0 then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = Colors.rarityOf(a).index, Colors.rarityOf(b).index
		if ra ~= rb then
			return ra > rb
		end
		return a.index < b.index
	end)
	for _, entry in ipairs(Colors.List) do
		if entry.basic then
			table.insert(list, entry)
		end
	end
	return list
end

local function refreshColors()
	local area = design.areaById[selectedArea]
	refs.colorsTitle.Text = "Pintura para «" .. area.name .. "»"
	for _, child in ipairs(refs.grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, entry in ipairs(sortedColors()) do
		local free = remaining(entry.id, selectedArea)
		local selected = choices[selectedArea] == entry.id
		local cell = Theme.new("TextButton", {
			Name = entry.id,
			BackgroundColor3 = selected and C.YellowSoft or C.Panel,
			BackgroundTransparency = selected and 0 or 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = order,
			Parent = refs.grid,
		}, { Theme.corner(14) })
		Theme.stroke(C.Yellow, selected and 2.5 or 0).Parent = cell
		local swatch = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(60, 60),
			Parent = cell,
		}, { Theme.corner(30) })
		DesignArt.swatch(swatch, entry.id)
		local rarityText, rarityColor = colorRarityText(entry.id)
		Theme.stroke(entry.basic and Color3.fromRGB(235, 225, 215) or rarityColor, 3).Parent = swatch
		Theme.label({
			Size = UDim2.new(1, -6, 0, 20),
			Position = UDim2.fromOffset(3, 70),
			Text = entry.name,
			MaxTextSize = 18,
			Parent = cell,
		})
		Theme.label({
			Size = UDim2.new(1, -6, 0, 16),
			Position = UDim2.fromOffset(3, 90),
			Text = entry.basic and "Básico · ∞" or (rarityText .. " · x" .. owned(entry.id)),
			TextColor3 = entry.basic and C.InkSoft or rarityColor,
			MaxTextSize = 15,
			Parent = cell,
		})
		if free <= 0 and not selected then
			cell.BackgroundTransparency = 1
			swatch.BackgroundTransparency = 0.6
		end
		cell.Activated:Connect(function()
			if remaining(entry.id, selectedArea) <= 0 then
				app.notify("Ya usaste todo tu «" .. entry.name .. "» 🎨", "error")
				return
			end
			Theme.playSound("click", 1.2)
			choices[selectedArea] = entry.id
			-- Pasa a la siguiente área automáticamente.
			local index = design.areaById[selectedArea].index
			local nextArea = design.areas[index + 1]
			if nextArea then
				selectedArea = nextArea.id
			end
			refreshAreas()
			refreshColors()
			updateValue()
		end)
	end
end

local function build(parent)
	-- Izquierda: vista previa y áreas.
	local previewBox = Theme.new("Frame", {
		Position = UDim2.fromOffset(60, 98),
		Size = UDim2.fromOffset(240, 240),
		BackgroundColor3 = C.Panel,
		Parent = parent,
	}, { Theme.corner(18), Theme.stroke(Color3.fromRGB(240, 230, 220), 3) })
	refs.previewBox = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = previewBox },
		{
			Theme.corner(18),
		}
	)
	refs.areas = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(24, 352),
		Size = UDim2.new(0, 316, 1, -372),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.InkSoft,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new(
			"UIPadding",
			{ PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 10) }
		),
	})

	-- Derecha: colores.
	refs.colorsTitle = Theme.label({
		Position = UDim2.fromOffset(372, 100),
		Size = UDim2.new(1, -400, 0, 30),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = parent,
	})
	refs.grid = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(366, 136),
		Size = UDim2.new(1, -390, 1, -236),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.InkSoft,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		Theme.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(112, 112),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	refs.value = Theme.label({
		Position = UDim2.new(0, 372, 1, -78),
		Size = UDim2.new(1, -640, 0, 56),
		Text = "",
		TextColor3 = C.PrimaryDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = parent,
	})
	refs.continue = Theme.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -22),
		Size = UDim2.fromOffset(220, 56),
		Text = "Continuar",
		Soft = true,
		Color = C.Mint,
		Parent = parent,
		OnClick = function()
			ColorPicker.confirm()
		end,
	})
end

function ColorPicker.open(newDesign)
	design = newDesign
	choices = {}
	local saved = remembered[design.id] or {}
	for _, area in ipairs(design.areas) do
		local colorId = saved[area.id]
		if not colorId or owned(colorId) <= 0 then
			colorId = area.default
		end
		choices[area.id] = colorId
	end
	-- Si guardamos más usos de un color de los que hay, volvemos al básico.
	for _, area in ipairs(design.areas) do
		if remaining(choices[area.id], nil) < 0 then
			choices[area.id] = area.default
		end
	end
	selectedArea = design.areas[1].id

	window.Title.Text = "Elige tus colores · " .. design.name
	window.Subtitle.Text = "Este cuadro tiene "
		.. #design.areas
		.. " áreas. Cada área toma el color de su pintura: ¡los colores raros valen más!"
	preview = DesignArt.render(refs.previewBox, design, { mode = "color", colors = choices, outline = false })

	for _, row in pairs(areaRows) do
		row.frame:Destroy()
	end
	areaRows = {}
	for _, area in ipairs(design.areas) do
		local frame = Theme.new("TextButton", {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = C.Panel,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = area.index,
			Parent = refs.areas,
		}, { Theme.corner(12) })
		local stroke = Theme.stroke(C.Yellow, 0)
		stroke.Parent = frame
		local swatch = Theme.new("Frame", {
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(30, 30),
			Parent = frame,
		}, { Theme.corner(15), Theme.stroke(Color3.fromRGB(235, 225, 215), 2) })
		Theme.label({
			Position = UDim2.fromOffset(50, 6),
			Size = UDim2.new(0.5, -40, 1, -12),
			Text = area.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 21,
			Parent = frame,
		})
		local colorName = Theme.label({
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0.5, -10, 1, -16),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 17,
			Parent = frame,
		})
		frame.Activated:Connect(function()
			Theme.playSound("click", 1.1)
			selectedArea = area.id
			refreshAreas()
			refreshColors()
		end)
		areaRows[area.id] = { area = area, frame = frame, stroke = stroke, swatch = swatch, colorName = colorName }
	end

	refreshAreas()
	refreshColors()
	updateValue()
	window.Open()
end

function ColorPicker.refresh()
	if design and window.Holder.Visible then
		refreshColors()
		updateValue()
	end
end

function ColorPicker.confirm()
	if busy or not design then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return app.remotes.StartPainting:InvokeServer(design.id, choices)
	end)
	busy = false
	if ok and success then
		remembered[design.id] = table.clone(choices)
		window.Close()
		app.openPainter(design, choices)
	else
		app.notify(ok and message or "No se pudo empezar.", "error")
	end
end

function ColorPicker.init(appRef)
	app = appRef
	local gui = Theme.new("ScreenGui", {
		Name = "ColorPicker",
		ResetOnSpawn = false,
		DisplayOrder = 13,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	window = Theme.window({
		Name = "Window",
		Parent = gui,
		Size = UDim2.fromOffset(1000, 640),
		Title = "Elige tus colores",
	})
	build(window.Panel)
end

return ColorPicker
