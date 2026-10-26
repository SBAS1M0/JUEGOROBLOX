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

-- Unidades libres de un color sin contar el área indicada.
local function remaining(colorId, exceptArea)
	local used = 0
	for areaId, chosen in pairs(choices) do
		if chosen == colorId and areaId ~= exceptArea then
			used += 1
		end
	end
	return owned(colorId) - used
end

local function rarityInfo(colorId)
	local entry = Colors.ById[colorId]
	local rarity = Colors.rarityOf(entry)
	return rarity, string.format("%s x%.1f", rarity.name, rarity.mult)
end

local function updateValue()
	if not design then
		return
	end
	local state = app.state
	local mult = Config.colorMultiplier(design, choices)
	local value = Config.paintingValue(design, choices, state.upgrades, state.made[design.id] or 0, 1)
	refs.multiplier.Text = string.format("x%.2f", mult)
	refs.value.Text = "💵 "
		.. Theme.formatNumber(value)
		.. "  (hasta "
		.. Theme.formatNumber(math.floor(value * (1 + Config.STAR_BONUS[3])))
		.. " con ⭐⭐⭐)"
	refs.multBar.Set(math.clamp((mult - 1) / 5, 0, 1), true)
	preview.setColors(choices)
end

local function refreshAreas()
	for _, row in pairs(areaRows) do
		local areaId = row.area.id
		local selected = areaId == selectedArea
		row.stroke.Color = selected and C.Primary or C.Border
		row.stroke.Thickness = selected and 2 or 1
		DesignArt.swatch(row.swatch, choices[areaId])
		local entry = Colors.ById[choices[areaId]]
		local rarity = rarityInfo(choices[areaId])
		row.colorName.Text = entry and entry.name or ""
		row.colorName.TextColor3 = entry and entry.basic and C.InkSoft or rarity.color:Lerp(C.Ink, 0.25)
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
		local rarity, rarityLabel = rarityInfo(entry.id)
		local holder, body = Theme.card({
			Name = entry.id,
			Size = UDim2.fromOffset(112, 128),
			Radius = 12,
			LayoutOrder = order,
			StrokeColor = selected and C.Primary or C.Border,
			StrokeThickness = selected and 2 or 1,
			Parent = refs.grid,
		})
		local cell = Theme.new("TextButton", {
			Name = entry.id,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 3,
			Parent = body,
		})
		local swatch = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(58, 58),
			Parent = body,
		}, { Theme.round() })
		DesignArt.swatch(swatch, entry.id)
		Theme.stroke(entry.basic and C.Border or rarity.color, 2.5).Parent = swatch
		Theme.label({
			Position = UDim2.fromOffset(4, 72),
			Size = UDim2.new(1, -8, 0, 18),
			Text = entry.name,
			Font = Theme.Fonts.Bold,
			MaxTextSize = 15,
			Parent = body,
		})
		Theme.chip({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 94),
			Size = UDim2.new(1, -12, 0, 22),
			Color = C.PanelSoft,
			TextColor3 = entry.basic and C.InkSoft or rarity.color:Lerp(C.Ink, 0.3),
			Text = entry.basic and "Básico · ∞" or (rarityLabel .. " · " .. owned(entry.id)),
			MaxTextSize = 12,
			Parent = body,
		})
		if free <= 0 and not selected then
			body.BackgroundTransparency = 0.4
			swatch.BackgroundTransparency = 0.6
		end
		cell.Activated:Connect(function()
			if remaining(entry.id, selectedArea) <= 0 then
				app.notify("Ya usaste todo tu «" .. entry.name .. "» 🎨", "error")
				return
			end
			Theme.playSound("click", 1.2)
			choices[selectedArea] = entry.id
			local index = design.areaById[selectedArea].index
			local nextArea = design.areas[index + 1]
			if nextArea then
				selectedArea = nextArea.id
			end
			refreshAreas()
			refreshColors()
			updateValue()
		end)
		holder.Name = entry.id
	end
end

-- Asigna los colores más valiosos a las áreas más grandes.
local function autoPick()
	local areas = {}
	for _, area in ipairs(design.areas) do
		table.insert(areas, area)
		choices[area.id] = area.default
	end
	table.sort(areas, function(a, b)
		return a.weight > b.weight
	end)
	local pool = {}
	for _, entry in ipairs(Colors.List) do
		if not entry.basic then
			for _ = 1, owned(entry.id) do
				table.insert(pool, entry)
			end
		end
	end
	table.sort(pool, function(a, b)
		return Colors.rarityOf(a).mult > Colors.rarityOf(b).mult
	end)
	for i, area in ipairs(areas) do
		local entry = pool[i]
		if entry and Colors.rarityOf(entry).mult > 1 then
			choices[area.id] = entry.id
		end
	end
	refreshAreas()
	refreshColors()
	updateValue()
	Theme.playSound("success", 1.3)
end

local function build(parent)
	-- Izquierda: vista previa y áreas.
	local _, left = Theme.card({
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.new(0, 330, 1, -28),
		Radius = 16,
		Parent = parent,
	})
	local previewBox = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(200, 200),
		BackgroundColor3 = C.White,
		Parent = left,
	}, { Theme.corner(12), Theme.stroke(C.Border, 1) })
	refs.previewBox = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = previewBox },
		{
			Theme.corner(12),
		}
	)
	refs.areas = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 224),
		Size = UDim2.new(1, -20, 1, -234),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.InkFaint,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = left,
	}, {
		Theme.list("v", 6),
		Theme.new("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 6),
		}),
	})

	-- Derecha: colores.
	refs.colorsTitle = Theme.label({
		Position = UDim2.fromOffset(366, 12),
		Size = UDim2.new(1, -600, 0, 32),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 21,
		Parent = parent,
	})
	Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 10),
		Size = UDim2.fromOffset(210, 40),
		Text = "✨ Mejores colores",
		Variant = "ghost",
		TextColor = C.Primary,
		MaxTextSize = 17,
		Parent = parent,
		OnClick = function()
			autoPick()
		end,
	})
	refs.grid = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(360, 56),
		Size = UDim2.new(1, -378, 1, -160),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.InkFaint,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		Theme.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(112, 128),
			CellPadding = UDim2.fromOffset(10, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Theme.new(
			"UIPadding",
			{ PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }
		),
	})

	-- Barra inferior con el valor.
	local _, footer = Theme.card({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 360, 1, -14),
		Size = UDim2.new(1, -378, 0, 84),
		Radius = 16,
		Parent = parent,
	})
	Theme.label({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(170, 18),
		Text = "Valor del cuadro",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = footer,
	})
	refs.multiplier = Theme.label({
		Position = UDim2.fromOffset(16, 28),
		Size = UDim2.fromOffset(110, 40),
		Text = "x1.00",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		Parent = footer,
	})
	refs.value = Theme.label({
		Position = UDim2.fromOffset(130, 32),
		Size = UDim2.new(1, -390, 0, 24),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.MintDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = footer,
	})
	refs.multBar = Theme.progress({
		Position = UDim2.fromOffset(130, 60),
		Size = UDim2.new(1, -390, 0, 6),
		Gradient = "primary",
		Parent = footer,
	})
	refs.continue = Theme.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(210, 50),
		Text = "Empezar a pintar",
		Variant = "primary",
		Radius = 12,
		Parent = footer,
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
	for _, area in ipairs(design.areas) do
		if remaining(choices[area.id], nil) < 0 then
			choices[area.id] = area.default
		end
	end
	selectedArea = design.areas[1].id

	window.Title.Text = "Elige tus colores · " .. design.name
	window.Subtitle.Text = "Un color para cada una de sus " .. #design.areas .. " zonas. Los colores raros valen más."
	preview = DesignArt.render(refs.previewBox, design, { mode = "color", colors = choices, outline = false })

	for _, row in pairs(areaRows) do
		row.holder:Destroy()
	end
	areaRows = {}
	for _, area in ipairs(design.areas) do
		local holder, body = Theme.card({
			Size = UDim2.new(1, 0, 0, 48),
			Radius = 12,
			LayoutOrder = area.index,
			Parent = refs.areas,
		})
		local button = Theme.new("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 3,
			Parent = body,
		})
		local swatch = Theme.new("Frame", {
			Position = UDim2.fromOffset(10, 9),
			Size = UDim2.fromOffset(30, 30),
			Parent = body,
		}, { Theme.round(), Theme.stroke(C.Border, 1) })
		Theme.label({
			Position = UDim2.fromOffset(48, 6),
			Size = UDim2.new(0.5, -40, 1, -12),
			Text = area.name,
			Font = Theme.Fonts.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 17,
			Parent = body,
		})
		local colorName = Theme.label({
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0.5, -12, 1, -16),
			Text = "",
			Font = Theme.Fonts.Heavy,
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 14,
			Parent = body,
		})
		button.Activated:Connect(function()
			Theme.playSound("click", 1.1)
			selectedArea = area.id
			refreshAreas()
			refreshColors()
		end)
		areaRows[area.id] = {
			area = area,
			holder = holder,
			body = body,
			stroke = body:FindFirstChildOfClass("UIStroke"),
			swatch = swatch,
			colorName = colorName,
		}
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
		Size = UDim2.fromOffset(1010, 650),
		Title = "Elige tus colores",
		Icon = "🎨",
		Accent = "coral",
	})
	build(window.Body)
end

return ColorPicker
