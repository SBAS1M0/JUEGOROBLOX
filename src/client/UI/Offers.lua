-- Ofertas de la caja: cuando un visitante quiere un cuadro y tu precio le
-- parece alto, te hace una oferta. Puedes aceptarla, pedirle un poco más o
-- rechazarla. Las tarjetas se ven también mientras pintas.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Designs = require(Shared.Designs)
local Exhibition = require(Shared.Exhibition)

local Theme = require(script.Parent.Theme)
local DesignArt = require(script.Parent.DesignArt)

local Offers = {}

local C = Theme.Colors
local CARD_WIDTH = 340
local CARD_HEIGHT = 214

local app
local holder
local cards = {}

local function closeCard(id, text)
	local card = cards[id]
	if not card then
		return
	end
	cards[id] = nil
	card.closing = true
	if text then
		card.status.Text = text
	end
	task.delay(text and 1.2 or 0.2, function()
		Theme.tween(card.scale, 0.2, { Scale = 0.6 })
		task.wait(0.2)
		card.holder:Destroy()
	end)
end

local function respond(id, action)
	local card = cards[id]
	if not card or card.answered then
		return
	end
	card.answered = true
	for _, button in ipairs(card.buttons) do
		button.SetEnabled(false)
	end
	card.status.Text = action == "accept" and "✔ Aceptada"
		or (action == "counter" and "↔ Pediste 💵" .. Theme.formatNumber(card.data.counter) or "✖ Rechazada")
	app.remotes.RespondOffer:FireServer(id, action)
end

local function buildCard(data)
	local cardHolder, body = Theme.card({
		Name = "Offer" .. data.id,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		Radius = 18,
		Color = C.Bg,
		StrokeColor = data.vip and C.Gold or C.Navy,
		StrokeThickness = data.vip and 3 or 2,
		ShadowTransparency = 0.7,
		LayoutOrder = data.id,
		Parent = holder,
	})
	local scale = Theme.new("UIScale", { Name = "PopScale", Parent = cardHolder })
	-- Cabecera con el visitante.
	local header = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = C.White,
		Parent = body,
	}, {
		Theme.corner(18),
		Theme.gradient(
			data.vip and Theme.Gradients.gold[1] or Theme.Gradients.navy[1],
			data.vip and Theme.Gradients.gold[2] or Theme.Gradients.navy[2],
			90
		),
	})
	Theme.new("Frame", {
		Position = UDim2.new(0, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = data.vip and Theme.Gradients.gold[2] or Theme.Gradients.navy[2],
		BorderSizePixel = 0,
		Parent = header,
	})
	Theme.new("ImageLabel", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = C.PanelSoft,
		Image = data.userId and ("rbxthumb://type=AvatarHeadShot&id=" .. data.userId .. "&w=150&h=150") or "",
		Parent = header,
	}, { Theme.round(), Theme.stroke(C.White, 2) })
	Theme.label({
		Position = UDim2.fromOffset(56, 6),
		Size = UDim2.new(1, -66, 0, 22),
		Text = (data.vip and "👑 " or "") .. tostring(data.buyer) .. " está en la caja",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = header,
	})
	Theme.label({
		Position = UDim2.fromOffset(56, 27),
		Size = UDim2.new(1, -66, 0, 16),
		Text = data.final and "Te hace su ÚLTIMA oferta" or "Te hace una oferta por tu cuadro",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.White,
		TextTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = header,
	})
	-- Cuadro y cifras.
	local art = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(70, 70),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.corner(4), Theme.stroke(C.Navy, 3) })
	local design = Designs.get(data.designId or "")
	if design then
		DesignArt.render(art, design, { mode = "color", colors = Designs.decodeColors(data.colors), outline = false })
	end
	Theme.label({
		Position = UDim2.fromOffset(94, 58),
		Size = UDim2.new(1, -104, 0, 20),
		Text = design and ("«" .. design.name .. "»") or "",
		Font = Theme.Fonts.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = body,
	})
	Theme.label({
		Position = UDim2.fromOffset(94, 78),
		Size = UDim2.new(1, -104, 0, 18),
		Text = "Tu precio 💵 " .. Theme.formatNumber(data.price) .. "  ·  Medio 💵 " .. Theme.formatNumber(
			data.market
		),
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = body,
	})
	local ratio = data.offer / math.max(1, data.price)
	Theme.label({
		Position = UDim2.fromOffset(94, 98),
		Size = UDim2.fromOffset(150, 32),
		Text = "💵 " .. Theme.formatNumber(data.offer),
		Font = Theme.Fonts.Display,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		Parent = body,
	})
	Theme.chip({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 104),
		Size = UDim2.fromOffset(70, 26),
		Text = math.floor(ratio * 100 + 0.5) .. "%",
		Color = ratio >= Exhibition.CASHIER_ACCEPT and C.MintLight or C.GoldLight,
		TextColor3 = ratio >= Exhibition.CASHIER_ACCEPT and C.MintDark or C.GoldDark,
		MaxTextSize = 15,
		Parent = body,
	})
	-- Botones.
	local row = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 140),
		Size = UDim2.new(1, -24, 0, 42),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Theme.list("h", 8) })
	local buttons = {}
	table.insert(
		buttons,
		Theme.button({
			Size = UDim2.new(data.final and 0.6 or 0.36, -6, 1, 0),
			Text = "✔ Aceptar",
			Variant = "mint",
			Radius = 12,
			MaxTextSize = 17,
			LayoutOrder = 1,
			Parent = row,
			OnClick = function()
				respond(data.id, "accept")
			end,
		})
	)
	if not data.final then
		table.insert(
			buttons,
			Theme.button({
				Size = UDim2.new(0.4, -6, 1, 0),
				Text = "Pedir 💵" .. Theme.formatNumber(data.counter),
				Variant = "gold",
				Radius = 12,
				MaxTextSize = 16,
				LayoutOrder = 2,
				Parent = row,
				OnClick = function()
					respond(data.id, "counter")
				end,
			})
		)
	end
	table.insert(
		buttons,
		Theme.button({
			Size = UDim2.new(data.final and 0.4 or 0.24, -6, 1, 0),
			Text = "✖ No",
			Variant = "ghost",
			TextColor = C.Red,
			Radius = 12,
			MaxTextSize = 16,
			LayoutOrder = 3,
			Parent = row,
			OnClick = function()
				respond(data.id, "reject")
			end,
		})
	)
	local status = Theme.label({
		Position = UDim2.fromOffset(12, 186),
		Size = UDim2.new(1, -24, 0, 14),
		Text = data.cashier and "Si no respondes, tu cajero decide por ti" or "Si no respondes, se irá sin comprar",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 12,
		Parent = body,
	})
	local timer = Theme.progress({
		Position = UDim2.new(0, 14, 1, -8),
		Size = UDim2.new(1, -28, 0, 4),
		Gradient = data.vip and "gold" or "primary",
		Parent = body,
	})
	timer.Set(1)
	local card = {
		holder = cardHolder,
		scale = scale,
		status = status,
		buttons = buttons,
		data = data,
		started = os.clock(),
		timer = timer,
	}
	Theme.pop(cardHolder, 0.7)
	return card
end

function Offers.show(data)
	if type(data) ~= "table" or not data.id then
		return
	end
	cards[data.id] = buildCard(data)
	Theme.playSound("success", 1.7)
	-- El temporizador se vacía hasta que el visitante se cansa.
	task.spawn(function()
		local card = cards[data.id]
		while card and cards[data.id] == card do
			local left = 1 - (os.clock() - card.started) / math.max(1, data.time or 20)
			card.timer.Set(left)
			task.wait(0.1)
		end
	end)
end

function Offers.closed(id)
	local card = cards[id]
	if card then
		closeCard(id, not card.answered and "⏳ Se acabó el tiempo" or nil)
	end
end

function Offers.init(appRef)
	app = appRef
	local gui = Theme.new("ScreenGui", {
		Name = "Offers",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	holder = Theme.new("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 84),
		Size = UDim2.fromOffset(CARD_WIDTH, 600),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.list("v", 10, Enum.HorizontalAlignment.Right) })
	local function updateScale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local scale = holder:FindFirstChild("ViewportScale")
			or Theme.new("UIScale", { Name = "ViewportScale", Parent = holder })
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.6, 1)
	end
	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return Offers
