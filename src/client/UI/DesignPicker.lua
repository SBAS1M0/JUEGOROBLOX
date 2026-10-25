-- Ventana "Elige un diseño": diseños por niveles, desbloqueos y maestría.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Designs = require(Shared.Designs)

local Theme = require(script.Parent.Theme)
local DesignArt = require(script.Parent.DesignArt)

local DesignPicker = {}

local C = Theme.Colors
local MEDALS = { bronce = "🥉", plata = "🥈", oro = "🥇" }

local app
local window
local list
local cards = {}
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

local function masteryText(made)
	local tier, nextTier = Config.masteryFor(made)
	local medal = tier and MEDALS[tier.id] or "⚪"
	return medal, tier, nextTier
end

local function averageValue(level)
	local total, count = 0, 0
	for _, design in ipairs(Designs.Levels[level]) do
		total += design.value
		count += 1
	end
	return math.floor(total / math.max(count, 1))
end

-- Tarjetas ----------------------------------------------------------------------------------
local function buildCard(design, parent)
	local card = Theme.new("TextButton", {
		Name = design.id,
		Size = UDim2.fromOffset(138, 176),
		BackgroundColor3 = C.Panel,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = design.index,
		Parent = parent,
	}, { Theme.corner(18) })
	local stroke = Theme.stroke(C.Yellow, 0)
	stroke.Parent = card
	local artBox = Theme.new("Frame", {
		Size = UDim2.fromOffset(104, 104),
		Position = UDim2.fromOffset(17, 10),
		BackgroundColor3 = C.PanelSoft,
		Parent = card,
	}, { Theme.corner(16) })
	local art = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = artBox,
	}, { Theme.corner(16) })
	DesignArt.render(art, design, { mode = "color", outline = false })
	local mystery = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "?",
		TextColor3 = C.InkSoft,
		MaxTextSize = 64,
		Visible = false,
		Parent = artBox,
	})
	local name = Theme.label({
		Size = UDim2.new(1, -10, 0, 24),
		Position = UDim2.fromOffset(5, 118),
		Text = design.name,
		MaxTextSize = 21,
		Parent = card,
	})
	local footer = Theme.new("Frame", {
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 144),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local medal = Theme.label({ Size = UDim2.fromOffset(24, 24), Text = "⚪", MaxTextSize = 20, Parent = footer })
	local barBack = Theme.new("Frame", {
		Size = UDim2.new(1, -66, 0, 8),
		Position = UDim2.new(0, 28, 0.5, -4),
		BackgroundColor3 = Color3.fromRGB(240, 234, 226),
		Parent = footer,
	}, { Theme.corner(4) })
	local bar = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Yellow, Parent = barBack },
		{ Theme.corner(4) }
	)
	local count = Theme.label({
		Size = UDim2.fromOffset(36, 24),
		Position = UDim2.new(1, -36, 0, 0),
		Text = "",
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 16,
		Parent = footer,
	})
	local price = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 142),
		Size = UDim2.fromOffset(96, 28),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = card,
	}, { Theme.corner(14), Theme.stroke(C.MintSoft, 2) })
	local priceLabel = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = C.PrimaryDark,
		MaxTextSize = 18,
		Parent = price,
	})

	card.Activated:Connect(function()
		Theme.playSound("click", 1.2)
		selectedId = design.id
		DesignPicker.refresh()
	end)

	cards[design.id] = {
		card = card,
		stroke = stroke,
		art = art,
		mystery = mystery,
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
	list = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(24, 100),
		Size = UDim2.new(0, 630, 1, -120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.InkSoft,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new(
			"UIPadding",
			{ PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 12) }
		),
	})
	for level = 1, Designs.MAX_LEVEL do
		local header = Theme.new("Frame", {
			Name = "Header" .. level,
			Size = UDim2.new(1, -16, 0, 34),
			BackgroundTransparency = 1,
			LayoutOrder = level * 2 - 1,
			Parent = list,
		})
		Theme.label({
			Size = UDim2.fromOffset(110, 34),
			Text = "Nivel " .. level,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 28,
			Parent = header,
		})
		Theme.label({
			Size = UDim2.fromOffset(240, 34),
			Position = UDim2.fromOffset(100, 0),
			Text = "💵 Se vende por ~" .. Theme.formatNumber(averageValue(level)),
			TextColor3 = C.PrimaryDark,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 20,
			Parent = header,
		})
		local grid = Theme.new("Frame", {
			Name = "Level" .. level,
			Size = UDim2.new(1, -16, 0, 184),
			BackgroundTransparency = 1,
			LayoutOrder = level * 2,
			Parent = list,
		}, {
			Theme.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(138, 176),
				CellPadding = UDim2.fromOffset(16, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for _, design in ipairs(Designs.Levels[level]) do
			buildCard(design, grid)
		end
	end
end

-- Panel de detalle ---------------------------------------------------------------------------
local function buildDetail(parent)
	local panel = Theme.new("Frame", {
		Position = UDim2.new(1, -324, 0, 100),
		Size = UDim2.new(0, 300, 1, -120),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local artBox = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(170, 170),
		BackgroundColor3 = C.PanelSoft,
		Parent = panel,
	}, { Theme.corner(22), Theme.stroke(Color3.fromRGB(240, 230, 220), 3) })
	detail.art = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = artBox },
		{ Theme.corner(22) }
	)
	detail.mystery = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "?",
		TextColor3 = C.InkSoft,
		MaxTextSize = 90,
		Parent = artBox,
	})
	detail.value = Theme.label({
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 176),
		Text = "",
		TextColor3 = C.PrimaryDark,
		MaxTextSize = 21,
		Parent = panel,
	})
	detail.name = Theme.label({
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 204),
		Text = "",
		MaxTextSize = 34,
		Parent = panel,
	})
	detail.info = Theme.label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 244),
		Text = "",
		TextColor3 = C.InkSoft,
		MaxTextSize = 18,
		Parent = panel,
	})
	detail.medal = Theme.label({
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.fromOffset(0, 276),
		Text = "⚪",
		MaxTextSize = 44,
		Parent = panel,
	})
	detail.tier = Theme.label({
		Size = UDim2.new(1, -64, 0, 28),
		Position = UDim2.fromOffset(62, 276),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = panel,
	})
	detail.tierBonus = Theme.label({
		Size = UDim2.new(1, -64, 0, 22),
		Position = UDim2.fromOffset(62, 304),
		Text = "",
		TextColor3 = C.PrimaryDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = panel,
	})
	local barBack = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.fromOffset(0, 340),
		BackgroundColor3 = Color3.fromRGB(240, 234, 226),
		Parent = panel,
	}, { Theme.corner(6) })
	detail.bar = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Yellow, Parent = barBack },
		{ Theme.corner(6) }
	)
	detail.progress = Theme.label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 356),
		Text = "",
		TextColor3 = C.InkSoft,
		MaxTextSize = 17,
		Parent = panel,
	})
	detail.tiers = Theme.label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 380),
		Text = "🥉 +5%   🥈 +10%   🥇 +20%",
		TextColor3 = C.Ink,
		MaxTextSize = 18,
		Parent = panel,
	})
	detail.button = Theme.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -10, 0, 56),
		Text = "Empezar a pintar",
		Soft = true,
		Color = C.Mint,
		Parent = panel,
		OnClick = function()
			DesignPicker.action()
		end,
	})
end

-- Lógica ------------------------------------------------------------------------------------
function DesignPicker.refresh()
	if not (window and window.Holder.Visible and app.state) then
		return
	end
	local state = app.state
	for _, design in ipairs(Designs.List) do
		local card = cards[design.id]
		local status = stateOf(design)
		local made = state.made[design.id] or 0
		card.stroke.Thickness = design.id == selectedId and 3 or 0
		card.card.BackgroundColor3 = design.id == selectedId and C.YellowSoft or C.Panel
		card.art.Visible = status ~= "closed"
		card.mystery.Visible = status == "closed"
		card.footer.Visible = status == "unlocked"
		card.price.Visible = status ~= "unlocked"
		if status == "buyable" then
			card.priceLabel.Text = "💵 " .. Theme.formatNumber(design.price)
		elseif status == "closed" then
			card.priceLabel.Text = "🔒 " .. Theme.formatNumber(design.price)
		end
		local medal, _, nextTier = masteryText(made)
		card.medal.Text = medal
		local goal = nextTier and nextTier.made or made
		card.bar.Size = UDim2.fromScale(math.clamp(made / math.max(goal, 1), 0, 1), 1)
		card.count.Text = nextTier and (made .. "/" .. goal) or tostring(made)
		card.name.TextTransparency = status == "closed" and 0.5 or 0
	end

	local design = Designs.get(selectedId) or Designs.List[1]
	local status = stateOf(design)
	local made = state.made[design.id] or 0
	DesignArt.render(detail.art, design, { mode = "color", outline = false })
	detail.art.Visible = status ~= "closed"
	detail.mystery.Visible = status == "closed"
	local value = Config.paintingValue(design, Designs.defaultColors(design), state.upgrades, made)
	detail.value.Text = "💵 Se vende por ~" .. Theme.formatNumber(value)
	detail.name.Text = status == "closed" and "???" or design.name
	detail.info.Text = "Nivel "
		.. design.level
		.. " · "
		.. #design.areas
		.. " colores · "
		.. #design.shapes
		.. " figuras"
	local medal, tier, nextTier = masteryText(made)
	detail.medal.Text = medal
	detail.tier.Text = tier and ("Maestría de " .. tier.name) or "Sin maestría aún"
	detail.tierBonus.Text = tier and ("Se vende por +" .. math.floor(tier.bonus * 100 + 0.5) .. "%")
		or "Píntalo varias veces para ganar medallas"
	if nextTier then
		detail.bar.Size = UDim2.fromScale(math.clamp(made / nextTier.made, 0, 1), 1)
		detail.progress.Text = made .. " de " .. nextTier.made .. " para " .. nextTier.name
	else
		detail.bar.Size = UDim2.fromScale(1, 1)
		detail.progress.Text = "¡Maestría máxima! (" .. made .. " pintados)"
	end

	if status == "unlocked" then
		detail.button.Button.Text = "🎨 Empezar a pintar"
		detail.button.SetBaseColor(C.Mint)
		detail.button.SetEnabled(not state.painting)
	elseif status == "buyable" then
		detail.button.Button.Text = "Desbloquear · 💵 " .. Theme.formatNumber(design.price)
		detail.button.SetBaseColor(C.Gold)
		detail.button.SetEnabled(state.coins >= design.price)
	else
		detail.button.Button.Text = "🔒 Pinta todo el nivel " .. (design.level - 1)
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
		app.notify("Ya tienes un cuadro empezado 🎨", "info")
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
		Size = UDim2.fromOffset(1000, 640),
		Title = "Elige un diseño",
		Subtitle = "Pinta todos los diseños de un nivel para abrir el siguiente. Los niveles altos se venden más caros.",
	})
	buildList(window.Panel)
	buildDetail(window.Panel)
end

return DesignPicker
