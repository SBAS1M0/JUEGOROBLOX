-- Panel de un stand de la sala: eliges qué cuadro exponer, le pones tu
-- precio (el juego te enseña el precio medio y cómo de rápido se venderá),
-- lo retiras o mejoras la calidad del stand.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Designs = require(Shared.Designs)
local Exhibition = require(Shared.Exhibition)

local Theme = require(script.Parent.Theme)
local DesignArt = require(script.Parent.DesignArt)

local StandPanel = {}

local C = Theme.Colors
local METER_MIN, METER_MAX = 0.5, 2
local TIER_COLORS = {
	Color3.fromRGB(214, 176, 128),
	Color3.fromRGB(44, 48, 56),
	Color3.fromRGB(232, 184, 80),
}

local app
local window
local refs = {}
local spot = nil
local selected = 1 -- índice del cuadro elegido en el almacén
local price = 0
local busy = false
local previewKey, storageKey = nil, nil -- evita redibujar si nada cambió

local function state()
	return app.state
end

local function entryOnStand()
	local s = state()
	for _, entry in ipairs(s and s.gallery or {}) do
		if entry.s == spot then
			return entry
		end
	end
	return nil
end

local function tierOf()
	local s = state()
	return s and s.stands and s.stands[spot] or 0
end

-- Cuadro que se está editando: el expuesto o el elegido del almacén.
local function currentPainting()
	local entry = entryOnStand()
	if entry then
		return entry, true
	end
	local s = state()
	return s and s.storage and s.storage[selected], false
end

local function marketOf(painting)
	return painting and Exhibition.marketPrice(painting.v, math.max(1, tierOf())) or 0
end

local function ratioToMeter(ratio)
	return math.clamp((ratio - METER_MIN) / (METER_MAX - METER_MIN), 0, 1)
end

-- Precio y medidor ---------------------------------------------------------------------------
local function refreshPrice()
	local painting = currentPainting()
	local market = marketOf(painting)
	refs.priceSection.Visible = painting ~= nil
	if not painting then
		return
	end
	price = Exhibition.clampPrice(price, market)
	local ratio = price / math.max(1, market)
	local band = Exhibition.band(ratio)
	refs.market.Text = "Precio medio: 💵 " .. Theme.formatNumber(market)
	refs.price.Text = "💵 " .. Theme.formatNumber(price)
	refs.percent.Text = math.floor(ratio * 100 + 0.5) .. "% del precio medio"
	refs.bandText.Text = band.text
	refs.bandText.TextColor3 = Theme.darker(band.color, 0.25)
	refs.marker.Position = UDim2.new(ratioToMeter(ratio), 0, 0.5, 0)
	refs.markerDot.BackgroundColor3 = band.color
	local interest = Exhibition.interest(ratio)
	refs.interest.Text = string.format("Interés de los visitantes: %d%%", math.floor(interest * 100 + 0.5))
	local onStand = entryOnStand()
	if onStand then
		refs.primary.SetText("💾 Guardar precio")
		refs.primary.SetEnabled(price ~= onStand.p)
	else
		refs.primary.SetText("🖼️ Exponer por 💵 " .. Theme.formatNumber(price))
		refs.primary.SetEnabled(true)
	end
end

local function setPrice(value)
	price = value
	refreshPrice()
end

-- Vista previa y calidad del stand --------------------------------------------------------------
local function refreshPreview()
	local painting = currentPainting()
	local design = painting and Designs.get(painting.d)
	local tier = tierOf()
	refs.artFrame.BackgroundColor3 = TIER_COLORS[math.clamp(tier, 1, 3)]
	local key = design and (painting.d .. painting.c .. (painting.st or 1)) or ""
	if key == previewKey then
		design = nil
	end
	previewKey = key
	if key == "" then
		design = nil
	end
	if design then
		refs.placeholder.Visible = false
		DesignArt.render(refs.art, design, {
			mode = "color",
			colors = Designs.decodeColors(painting.c),
			outlineThickness = 1.5,
		})
		refs.paintingName.Text = design.name
		refs.paintingStars.Text = string.rep("★", painting.st or 1) .. string.rep("☆", 3 - (painting.st or 1))
	elseif key == "" then
		local old = refs.art:FindFirstChild("Art")
		if old then
			old:Destroy()
		end
		refs.placeholder.Visible = true
		refs.paintingName.Text = "Stand vacío"
		refs.paintingStars.Text = ""
	end
	-- Calidad del stand y mejora.
	local def = Exhibition.Spots[spot]
	refs.tierName.Text = Exhibition.tierName(spot, tier)
	local bonus = Exhibition.tierBonus(tier)
	refs.tierBonus.Text = bonus > 0 and string.format("+%d%% de precio medio", math.floor(bonus * 100 + 0.5))
		or "Calidad básica"
	if tier >= Exhibition.MAX_TIER then
		refs.upgrade.SetText("✨ Calidad máxima")
		refs.upgrade.SetEnabled(false)
		refs.upgradeInfo.Text = "Este stand ya luce como en un museo."
	else
		local cost = Exhibition.upgradeCost(tier, def.room)
		local nextBonus = Exhibition.tierBonus(tier + 1)
		refs.upgrade.SetText("Mejorar · 💵 " .. Theme.formatNumber(cost))
		refs.upgrade.SetEnabled((state().coins or 0) >= cost)
		refs.upgradeInfo.Text = "→ "
			.. Exhibition.tierName(spot, tier + 1)
			.. string.format(" (+%d%%)", math.floor(nextBonus * 100 + 0.5))
	end
end

-- Lista de cuadros del almacén -----------------------------------------------------------------------
local function refreshStorage()
	local onStand = entryOnStand()
	local storage = state().storage or {}
	local key = (onStand and "on" or "off") .. selected .. ":" .. tierOf()
	for _, painting in ipairs(storage) do
		key ..= "|" .. painting.d .. painting.c .. painting.v
	end
	if key == storageKey then
		return
	end
	storageKey = key
	for _, child in ipairs(refs.storageList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	refs.storageSection.Visible = onStand == nil
	refs.manage.Visible = onStand ~= nil
	refs.empty.Visible = onStand == nil and #storage == 0
	refs.priceTitle.Text = onStand and "Precio del cuadro" or "2. Ponle tu precio"
	if onStand then
		return
	end
	if selected > #storage then
		selected = 1
	end
	for i, painting in ipairs(storage) do
		local design = Designs.get(painting.d)
		local card = Theme.new("TextButton", {
			Name = "Stored" .. i,
			Size = UDim2.fromOffset(96, 112),
			BackgroundColor3 = C.Panel,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = i,
			Parent = refs.storageList,
		}, { Theme.corner(12), Theme.stroke(i == selected and C.Primary or C.Border, i == selected and 3 or 1.5) })
		local box = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = C.White,
			Parent = card,
		}, { Theme.corner(4), Theme.stroke(C.Navy, 2) })
		if design then
			DesignArt.render(
				box,
				design,
				{ mode = "color", colors = Designs.decodeColors(painting.c), outline = false }
			)
		end
		Theme.label({
			Position = UDim2.fromOffset(4, 84),
			Size = UDim2.new(1, -8, 0, 20),
			Text = "💵 " .. Theme.formatNumber(Exhibition.marketPrice(painting.v, math.max(1, tierOf()))),
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Ink,
			MaxTextSize = 15,
			Parent = card,
		})
		card.Activated:Connect(function()
			if selected ~= i then
				selected = i
				Theme.playSound("click", 1.2)
				price = Exhibition.marketPrice(painting.v, math.max(1, tierOf()))
				refreshStorage()
				refreshPreview()
				refreshPrice()
			end
		end)
	end
end

function StandPanel.refresh()
	if not (window and spot and window.Holder.Visible and state()) then
		return
	end
	if tierOf() == 0 then
		StandPanel.close()
		return
	end
	local def = Exhibition.Spots[spot]
	local room = Exhibition.Rooms[def.room]
	window.Title.Text = "Stand " .. spot .. " · " .. Exhibition.tierName(spot, tierOf())
	window.Subtitle.Text = (room and room.name or "") .. " · Tienes 💵 " .. Theme.formatNumber(state().coins)
	refreshStorage()
	refreshPreview()
	refreshPrice()
end

-- Acciones -----------------------------------------------------------------------------------------
local function invoke(action, a, b)
	if busy then
		return false
	end
	busy = true
	local ok, success, message = pcall(function()
		return app.remotes.StandAction:InvokeServer(action, spot, a, b)
	end)
	busy = false
	if ok and success then
		return true, message
	end
	app.notify(ok and message or "No se pudo hacer.", "error")
	return false
end

local function primaryAction()
	local onStand = entryOnStand()
	if onStand then
		local ok, message = invoke("price", price)
		if ok then
			Theme.playSound("success", 1.3)
			app.notify(message, "success")
		end
		return
	end
	local ok, message = invoke("exhibit", selected, price)
	if ok then
		Theme.playSound("success", 1.1)
		app.notify(message, "success")
		StandPanel.close()
	end
end

-- Construcción ---------------------------------------------------------------------------------------
local function sectionTitle(parent, text, y)
	return Theme.label({
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 24),
		Text = text,
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 19,
		Parent = parent,
	})
end

local function buildLeft(body)
	local _, card = Theme.card({
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(276, 476),
		Radius = 18,
		Parent = body,
	})
	refs.artFrame = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(222, 222),
		BackgroundColor3 = TIER_COLORS[1],
		Parent = card,
	}, { Theme.corner(6) })
	refs.art = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		BackgroundColor3 = Color3.fromRGB(252, 248, 240),
		Parent = refs.artFrame,
	})
	refs.placeholder = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "🖼️\nStand vacío",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkFaint,
		MaxTextSize = 22,
		Parent = refs.art,
	})
	refs.paintingName = Theme.label({
		Position = UDim2.fromOffset(14, 248),
		Size = UDim2.new(1, -28, 0, 28),
		Text = "",
		Font = Theme.Fonts.Display,
		MaxTextSize = 24,
		Parent = card,
	})
	refs.paintingStars = Theme.label({
		Position = UDim2.fromOffset(14, 276),
		Size = UDim2.new(1, -28, 0, 22),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.Gold,
		MaxTextSize = 20,
		Parent = card,
	})
	-- Calidad del stand.
	local quality = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 308),
		Size = UDim2.new(1, -24, 0, 152),
		BackgroundColor3 = C.PanelSoft,
		Parent = card,
	}, { Theme.corner(14) })
	Theme.label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "CALIDAD DEL STAND",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 12,
		Parent = quality,
	})
	refs.tierName = Theme.label({
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 22),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = quality,
	})
	refs.tierBonus = Theme.label({
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.PrimaryDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = quality,
	})
	refs.upgrade = Theme.button({
		Position = UDim2.fromOffset(10, 72),
		Size = UDim2.new(1, -20, 0, 40),
		Text = "",
		Variant = "gold",
		Radius = 12,
		MaxTextSize = 17,
		Parent = quality,
		OnClick = function()
			local ok, message = invoke("upgrade")
			if ok then
				Theme.playSound("success", 1.2)
				app.notify(message, "success")
				app.celebrate()
			end
		end,
	})
	refs.upgradeInfo = Theme.label({
		Position = UDim2.fromOffset(12, 122),
		Size = UDim2.new(1, -24, 0, 18),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 13,
		Parent = quality,
	})
end

local function buildRight(body)
	local column = Theme.new("Frame", {
		Position = UDim2.fromOffset(316, 14),
		Size = UDim2.new(1, -334, 1, -28),
		BackgroundTransparency = 1,
		Parent = body,
	})
	-- 1. Elegir cuadro del almacén.
	refs.storageSection = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		Parent = column,
	})
	sectionTitle(refs.storageSection, "1. Elige un cuadro de tu almacén", 0)
	refs.storageList = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.InkFaint,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = refs.storageSection,
	}, { Theme.list("h", 8), Theme.padding(2) })
	refs.empty = Theme.label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 60),
		Text = "No tienes cuadros terminados.\nPinta uno en la mesa de dibujo del taller 🎨",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 18,
		Visible = false,
		Parent = refs.storageSection,
	})
	-- Gestión del cuadro expuesto.
	refs.manage = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = column,
	})
	sectionTitle(refs.manage, "Cuadro a la venta", 0)
	Theme.label({
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 60),
		Text = "Los visitantes que se interesen irán a la caja: te pagarán tu precio o te harán una oferta.",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = refs.manage,
	})
	refs.takeDown = Theme.button({
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.fromOffset(210, 44),
		Text = "↩ Retirar cuadro",
		Variant = "ghost",
		TextColor = C.Red,
		Radius = 12,
		MaxTextSize = 17,
		Parent = refs.manage,
		OnClick = function()
			local ok, message = invoke("takedown")
			if ok then
				app.notify(message, "info")
				StandPanel.close()
			end
		end,
	})

	-- 2. Precio.
	refs.priceSection = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 160),
		Size = UDim2.new(1, 0, 0, 300),
		BackgroundTransparency = 1,
		Parent = column,
	})
	refs.priceTitle = sectionTitle(refs.priceSection, "2. Ponle tu precio", 0)
	refs.market = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(230, 26),
		BackgroundColor3 = C.PrimaryLight,
		BackgroundTransparency = 0,
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.PrimaryDark,
		MaxTextSize = 16,
		Parent = refs.priceSection,
	})
	Theme.round().Parent = refs.market
	local _, priceCard = Theme.card({
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 76),
		Radius = 16,
		Parent = refs.priceSection,
	})
	local function stepButton(text, x, anchor, sign)
		Theme.button({
			AnchorPoint = Vector2.new(anchor, 0.5),
			Position = UDim2.new(x, anchor == 0 and 10 or -10, 0.5, 0),
			Size = UDim2.fromOffset(56, 52),
			Text = text,
			Variant = "navy",
			Radius = 14,
			MaxTextSize = 28,
			Parent = priceCard,
			OnClick = function()
				local painting = currentPainting()
				setPrice(price + sign * Exhibition.priceStep(marketOf(painting)))
			end,
		})
	end
	stepButton("−", 0, 0, -1)
	stepButton("+", 1, 1, 1)
	refs.price = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(1, -150, 0, 42),
		Text = "",
		Font = Theme.Fonts.Display,
		TextColor3 = C.Ink,
		MaxTextSize = 38,
		Parent = priceCard,
	})
	refs.percent = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.new(1, -150, 0, 18),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 14,
		Parent = priceCard,
	})
	-- Atajos de precio.
	local presets = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = refs.priceSection,
	}, { Theme.list("h", 8) })
	for i, preset in ipairs({
		{ "Rápido −15%", 0.85 },
		{ "Precio medio", 1 },
		{ "+25%", 1.25 },
		{ "+50%", 1.5 },
	}) do
		Theme.button({
			Size = UDim2.new(0.25, -6, 1, 0),
			Text = preset[1],
			Variant = "ghost",
			Radius = 12,
			Depth = 3,
			MaxTextSize = 15,
			LayoutOrder = i,
			Parent = presets,
			OnClick = function()
				setPrice(Exhibition.roundPrice(marketOf(currentPainting()) * preset[2]))
			end,
		})
	end
	-- Medidor: de ganga a carísimo.
	local meter = Theme.new("Frame", {
		Position = UDim2.fromOffset(4, 176),
		Size = UDim2.new(1, -8, 0, 14),
		BackgroundTransparency = 1,
		Parent = refs.priceSection,
	})
	local from = METER_MIN
	for i, band in ipairs(Exhibition.PriceBands) do
		local to = math.min(band.max, METER_MAX)
		local a, b = ratioToMeter(from), ratioToMeter(to)
		Theme.new("Frame", {
			Position = UDim2.fromScale(a, 0),
			Size = UDim2.new(b - a, i < #Exhibition.PriceBands and -2 or 0, 1, 0),
			BackgroundColor3 = band.color,
			Parent = meter,
		}, { Theme.corner(5) })
		from = to
	end
	refs.marker = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.33, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = meter,
	})
	refs.markerDot = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Primary,
		ZIndex = 3,
		Parent = refs.marker,
	}, { Theme.round(), Theme.stroke(C.White, 4) })
	Theme.label({
		Position = UDim2.fromOffset(0, 196),
		Size = UDim2.new(0.5, 0, 0, 16),
		Text = "Ganga",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkFaint,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = refs.priceSection,
	})
	Theme.label({
		Position = UDim2.new(0.5, 0, 0, 196),
		Size = UDim2.new(0.5, 0, 0, 16),
		Text = "Carísimo",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkFaint,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 13,
		Parent = refs.priceSection,
	})
	refs.bandText = Theme.label({
		Position = UDim2.fromOffset(0, 214),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		Font = Theme.Fonts.Heavy,
		MaxTextSize = 18,
		Parent = refs.priceSection,
	})
	refs.interest = Theme.label({
		Position = UDim2.fromOffset(0, 236),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 14,
		Parent = refs.priceSection,
	})
	refs.primary = Theme.button({
		Position = UDim2.fromOffset(0, 258),
		Size = UDim2.new(1, 0, 0, 52),
		Text = "",
		Variant = "primary",
		Radius = 14,
		MaxTextSize = 21,
		Parent = refs.priceSection,
		OnClick = primaryAction,
	})
end

-- API ------------------------------------------------------------------------------------------------
function StandPanel.open(index)
	local s = state()
	if not (window and s and Exhibition.Spots[index]) then
		return
	end
	spot = index
	selected = 1
	previewKey, storageKey = nil, nil
	local painting = currentPainting()
	local onStand = entryOnStand()
	price = onStand and onStand.p or marketOf(painting)
	window.Open()
	StandPanel.refresh()
end

function StandPanel.close()
	if window then
		window.Close()
	end
	spot = nil
end

function StandPanel.isOpen()
	return window ~= nil and window.Holder.Visible
end

function StandPanel.init(appRef)
	app = appRef
	local gui = Theme.new("ScreenGui", {
		Name = "StandPanel",
		ResetOnSpawn = false,
		DisplayOrder = 14,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	window = Theme.window({
		Name = "Window",
		Parent = gui,
		Size = UDim2.fromOffset(860, 580),
		Title = "Stand",
		Icon = "🖼️",
		Accent = "gold",
		OnClose = StandPanel.close,
	})
	buildLeft(window.Body)
	buildRight(window.Body)
end

return StandPanel
