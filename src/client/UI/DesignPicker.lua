-- Ventana "Elige un diseño": diseños por niveles, desbloqueos y maestría.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Designs = require(Shared.Designs)

local Theme = require(script.Parent.Theme)
local DesignArt = require(script.Parent.DesignArt)
local ImageArt = require(script.Parent.ImageArt)

local DesignPicker = {}

local C = Theme.Colors
local MEDALS = { bronce = "🥉", plata = "🥈", oro = "🥇" }

local app
local window
local cards = {}
local levelHeaders = {}
local detail = {}
local selectedId = "globo"
local busy = false

local function stateOf(design)
	local state = app.state
	if not state then
		return "closed"
	end
	if state.unlocked[design.id] then
		return "unlocked"
	end
	if Designs.isLevelOpen(design.level, state.made) then
		return "buyable"
	end
	return "closed"
end

local function averageValue(level)
	local total, count = 0, 0
	for _, design in ipairs(Designs.Levels[level]) do
		total += design.value
		count += 1
	end
	return math.floor(total / math.max(count, 1))
end

-- Tarjetas ------------------------------------------------------------------------------------
local function buildCard(design, parent)
	local holder, body = Theme.card({
		Name = design.id,
		Size = UDim2.fromOffset(146, 192),
		Radius = 14,
		LayoutOrder = design.index,
		Parent = parent,
	})
	local stroke = body:FindFirstChildOfClass("UIStroke")
	local button = Theme.new("TextButton", {
		Name = design.id,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 3,
		Parent = body,
	})
	local artBox = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(122, 122),
		BackgroundColor3 = C.PanelSoft,
		Parent = body,
	}, { Theme.corner(10) })
	local art = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = artBox }, {
		Theme.corner(10),
	})
	DesignArt.render(art, design, { mode = "color", outline = false })
	local lock = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.PanelSoft,
		BackgroundTransparency = 0.15,
		Visible = false,
		ZIndex = 2,
		Parent = artBox,
	}, { Theme.corner(10) })
	local lockIcon = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "🔒",
		Font = Theme.Fonts.Heavy,
		MaxTextSize = 30,
		ZIndex = 2,
		Parent = lock,
	})
	local name = Theme.label({
		Position = UDim2.fromOffset(6, 136),
		Size = UDim2.new(1, -12, 0, 22),
		Text = design.name,
		Font = Theme.Fonts.Bold,
		MaxTextSize = 16,
		Parent = body,
	})
	local footer = Theme.new("Frame", {
		Position = UDim2.fromOffset(10, 162),
		Size = UDim2.new(1, -20, 0, 22),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local medal = Theme.label({ Size = UDim2.fromOffset(22, 22), Text = "", MaxTextSize = 18, Parent = footer })
	local bar = Theme.progress({
		Position = UDim2.new(0, 26, 0.5, -4),
		Size = UDim2.new(1, -66, 0, 6),
		Gradient = "primary",
		Parent = footer,
	})
	local count = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 1),
		Size = UDim2.fromOffset(36, 20),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 13,
		Parent = footer,
	})
	local price, priceLabel = Theme.chip({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 161),
		Size = UDim2.fromOffset(110, 24),
		Color = C.PanelSoft,
		TextColor3 = C.Ink,
		Text = "",
		MaxTextSize = 14,
		Parent = body,
	})

	button.Activated:Connect(function()
		Theme.playSound("click", 1.2)
		selectedId = design.id
		DesignPicker.refresh()
	end)

	cards[design.id] = {
		holder = holder,
		body = body,
		stroke = stroke,
		art = art,
		lock = lock,
		lockIcon = lockIcon,
		name = name,
		footer = footer,
		medal = medal,
		bar = bar,
		count = count,
		price = price,
		priceLabel = priceLabel,
	}
end

local function buildList(parent)
	local list = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.new(0, 668, 1, -28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.InkFaint,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		Theme.list("v", 10),
		Theme.new("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 14),
		}),
	})
	for level = 1, Designs.MAX_LEVEL do
		local header = Theme.new("Frame", {
			Name = "Header" .. level,
			Size = UDim2.new(1, -10, 0, 36),
			BackgroundTransparency = 1,
			LayoutOrder = (Designs.LevelInfo[level] and -level or level) * 2 - 1,
			Parent = list,
		})
		local title = Theme.label({
			Position = UDim2.fromOffset(2, 6),
			Size = UDim2.fromOffset(Designs.LevelInfo[level] and 190 or 112, 26),
			Text = Designs.levelName(level),
			Font = Theme.Fonts.Heavy,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 20,
			Parent = header,
		})
		local info = Theme.label({
			Position = UDim2.fromOffset(Designs.LevelInfo[level] and 198 or 120, 9),
			Size = UDim2.new(1, -128, 0, 20),
			Text = "Se venden por ~💵" .. Theme.formatNumber(averageValue(level)),
			Font = Theme.Fonts.Medium,
			TextColor3 = C.InkSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = header,
		})
		levelHeaders[level] = { title = title, info = info }
		local grid = Theme.new("Frame", {
			Name = "Level" .. level,
			Size = UDim2.new(1, -10, 0, 204),
			BackgroundTransparency = 1,
			LayoutOrder = (Designs.LevelInfo[level] and -level or level) * 2,
			Parent = list,
		}, {
			Theme.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(146, 192),
				CellPadding = UDim2.fromOffset(12, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for _, design in ipairs(Designs.Levels[level]) do
			buildCard(design, grid)
		end
	end
end

-- Panel de detalle ------------------------------------------------------------------------------
local function buildDetail(parent)
	local _, panel = Theme.card({
		Position = UDim2.new(1, -306, 0, 14),
		Size = UDim2.new(0, 288, 1, -28),
		Radius = 16,
		Parent = parent,
	})
	local artBox = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(176, 176),
		BackgroundColor3 = C.PanelSoft,
		Parent = panel,
	}, { Theme.corner(12), Theme.stroke(C.Border, 1) })
	detail.art = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = artBox }, {
		Theme.corner(12),
	})
	detail.lock = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "🔒",
		Font = Theme.Fonts.Heavy,
		BackgroundColor3 = C.PanelSoft,
		BackgroundTransparency = 0.15,
		MaxTextSize = 40,
		Visible = false,
		Parent = artBox,
	})
	Theme.corner(12).Parent = detail.lock
	detail.name = Theme.label({
		Position = UDim2.fromOffset(12, 200),
		Size = UDim2.new(1, -24, 0, 34),
		Text = "",
		Font = Theme.Fonts.Heavy,
		MaxTextSize = 24,
		Parent = panel,
	})
	detail.value = Theme.label({
		Position = UDim2.fromOffset(12, 234),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.MintDark,
		MaxTextSize = 17,
		Parent = panel,
	})
	detail.info = Theme.label({
		Position = UDim2.fromOffset(12, 258),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 15,
		Parent = panel,
	})
	local masteryBox = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 286),
		Size = UDim2.new(1, -24, 0, 92),
		BackgroundColor3 = C.PanelSoft,
		Parent = panel,
	}, { Theme.corner(12) })
	detail.medal = Theme.label({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(40, 40),
		Text = "",
		MaxTextSize = 34,
		Parent = masteryBox,
	})
	detail.tier = Theme.label({
		Position = UDim2.fromOffset(54, 8),
		Size = UDim2.new(1, -62, 0, 22),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = masteryBox,
	})
	detail.tierBonus = Theme.label({
		Position = UDim2.fromOffset(54, 30),
		Size = UDim2.new(1, -62, 0, 18),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = masteryBox,
	})
	detail.bar = Theme.progress({
		Position = UDim2.fromOffset(10, 56),
		Size = UDim2.new(1, -20, 0, 6),
		Gradient = "primary",
		Parent = masteryBox,
	})
	detail.progress = Theme.label({
		Position = UDim2.fromOffset(10, 68),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 13,
		Parent = masteryBox,
	})
	detail.tiers = Theme.label({
		Position = UDim2.fromOffset(12, 384),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "🥉 3 → +5%   🥈 8 → +10%   🥇 20 → +20%",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 14,
		Parent = panel,
	})
	detail.button = Theme.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -28, 0, 50),
		Text = "Empezar a pintar",
		Variant = "primary",
		Radius = 12,
		Parent = panel,
		OnClick = function()
			DesignPicker.action()
		end,
	})
end

-- Lógica ---------------------------------------------------------------------------------------------
function DesignPicker.refresh()
	if not (window and window.Holder.Visible and app.state) then
		return
	end
	local state = app.state
	for level, header in pairs(levelHeaders) do
		local open = Designs.isLevelOpen(level, state.made)
		header.title.TextColor3 = open and C.Ink or C.InkFaint
		header.title.Text = (open and "" or "🔒 ") .. Designs.levelName(level)
	end
	for _, design in ipairs(Designs.List) do
		local card = cards[design.id]
		local status = stateOf(design)
		local made = state.made[design.id] or 0
		local selected = design.id == selectedId
		card.stroke.Color = selected and C.Primary or C.Border
		card.stroke.Thickness = selected and 2 or 1
		card.art.Visible = status ~= "closed"
		card.lock.Visible = status ~= "unlocked"
		card.lockIcon.Text = status == "closed" and "🔒" or "🛒"
		card.footer.Visible = status == "unlocked"
		card.price.Visible = status ~= "unlocked"
		card.priceLabel.Text = (status == "closed" and "🔒 " or "💵 ") .. Theme.formatNumber(design.price)
		card.name.Text = status == "closed" and "???" or design.name
		card.name.TextColor3 = status == "closed" and C.InkFaint or C.Ink
		local tier, nextTier = Config.masteryFor(made)
		card.medal.Text = tier and MEDALS[tier.id] or "⚪"
		local goal = nextTier and nextTier.made or made
		card.bar.Set(made / math.max(goal, 1))
		card.count.Text = nextTier and (made .. "/" .. goal) or tostring(made)
	end

	local design = Designs.get(selectedId) or Designs.List[1]
	local status = stateOf(design)
	local made = state.made[design.id] or 0
	-- Solo se redibuja al cambiar de diseño (las ilustraciones pesan más).
	if detail.shownId ~= design.id then
		detail.shownId = design.id
		DesignArt.render(detail.art, design, { mode = "color", outline = false })
	end
	detail.art.Visible = status ~= "closed"
	detail.lock.Visible = status == "closed"
	local value = Config.paintingValue(design, Designs.defaultColors(design), state.upgrades, made, 3)
	detail.value.Text = "💵 Hasta ~" .. Theme.formatNumber(value) .. " con colores básicos"
	detail.name.Text = status == "closed" and "???" or design.name
	detail.info.Text = Designs.levelName(design.level)
		.. "  ·  "
		.. #design.areas
		.. " colores  ·  "
		.. #design.shapes
		.. (design.kind == "image" and " zonas" or " figuras")
	local tier, nextTier = Config.masteryFor(made)
	detail.medal.Text = tier and MEDALS[tier.id] or "⚪"
	detail.tier.Text = tier and ("Maestría de " .. tier.name) or "Sin maestría aún"
	detail.tierBonus.Text = tier and ("Se vende un " .. math.floor(tier.bonus * 100 + 0.5) .. "% más caro")
		or "Píntalo varias veces para ganar medallas"
	if nextTier then
		detail.bar.Set(made / nextTier.made)
		detail.progress.Text = made .. " de " .. nextTier.made .. " para " .. nextTier.name
	else
		detail.bar.Set(1)
		detail.progress.Text = "¡Maestría máxima! (" .. made .. " pintados)"
	end

	if design.kind == "image" and not ImageArt.supported() then
		-- Sin EditableImage no se puede pintar una ilustración en este dispositivo.
		detail.button.SetText("No disponible en este dispositivo")
		detail.button.SetVariant("primary")
		detail.button.SetEnabled(false)
	elseif status == "unlocked" then
		detail.button.SetText(state.painting and "Tienes un cuadro empezado" or "Empezar a pintar")
		detail.button.SetVariant("primary")
		detail.button.SetEnabled(not state.painting)
	elseif status == "buyable" then
		detail.button.SetText("Desbloquear · 💵 " .. Theme.formatNumber(design.price))
		detail.button.SetVariant("gold")
		detail.button.SetEnabled(state.coins >= design.price)
	else
		local info = Designs.LevelInfo[design.level]
		detail.button.SetText("Pinta todo el nivel " .. ((info and info.requires or design.level) - 1))
		detail.button.SetEnabled(false)
	end
end

function DesignPicker.action()
	if busy then
		return
	end
	local design = Designs.get(selectedId)
	local status = stateOf(design)
	if status == "unlocked" then
		window.Close()
		app.openColorPicker(design)
	elseif status == "buyable" then
		busy = true
		local ok, success, message = pcall(function()
			return app.remotes.UnlockDesign:InvokeServer(design.id)
		end)
		busy = false
		if ok and success then
			Theme.playSound("success", 1.1)
			app.notify("🔓 " .. message, "success")
			app.celebrate()
		else
			app.notify(ok and message or "No se pudo desbloquear.", "error")
		end
		DesignPicker.refresh()
	end
end

function DesignPicker.open()
	if app.state and app.state.painting then
		app.resumePainting()
		return
	end
	window.Open()
	DesignPicker.refresh()
end

function DesignPicker.isOpen()
	return window.Holder.Visible
end

function DesignPicker.init(appRef)
	app = appRef
	local gui = Theme.new("ScreenGui", {
		Name = "DesignPicker",
		ResetOnSpawn = false,
		DisplayOrder = 12,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	window = Theme.window({
		Name = "Window",
		Parent = gui,
		Size = UDim2.fromOffset(1010, 650),
		Title = "Elige un diseño",
		Icon = "🖌️",
		Accent = "primary",
		Subtitle = "Pinta todos los diseños de un nivel para abrir el siguiente.",
	})
	buildList(window.Body)
	buildDetail(window.Body)
end

return DesignPicker
