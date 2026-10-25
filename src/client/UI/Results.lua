-- Pantalla de resultados tras entregar una obra (estrellas, monedas, confeti)
-- y la ventana de ayuda.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local PixelArt = require(script.Parent.PixelArt)

local Results = {}

local C = Theme.Colors
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 140),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(140, 110, 255),
	Color3.fromRGB(80, 220, 140),
}

local gui
local refs = {}
local queue = {}
local showing = false

local function confetti(amount)
	local holder = refs.confetti
	local random = Random.new()
	for _ = 1, amount do
		local piece = Theme.new("Frame", {
			Size = UDim2.fromOffset(random:NextInteger(8, 14), random:NextInteger(12, 20)),
			Position = UDim2.new(random:NextNumber(0.1, 0.9), 0, -0.05, 0),
			Rotation = random:NextInteger(0, 360),
			BackgroundColor3 = CONFETTI_COLORS[random:NextInteger(1, #CONFETTI_COLORS)],
			BorderSizePixel = 0,
			Parent = holder,
		}, { Theme.corner(3) })
		local duration = random:NextNumber(1.6, 2.8)
		Theme.tween(piece, duration, {
			Position = UDim2.new(piece.Position.X.Scale + random:NextNumber(-0.15, 0.15), 0, 1.05, 0),
			Rotation = piece.Rotation + random:NextInteger(-540, 540),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

local function row(parent, order, icon, text, color)
	local frame = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = C.PanelSoft,
		LayoutOrder = order,
		Parent = parent,
	}, { Theme.corner(10) })
	Theme.label({
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		Text = icon .. "  " .. text,
		TextColor3 = color or C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = frame,
	})
	frame.Visible = false
	return frame
end

local function buildModal(name)
	local holder = Theme.new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Theme.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Parent = holder,
	})
	-- El "Wrapper" lleva la escala por pantalla y la tarjeta la animación de entrada.
	local wrapper = Theme.new("Frame", {
		Name = "Wrapper",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 600),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local card = Theme.new("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Background,
		Parent = wrapper,
	}, {
		Theme.corner(26),
		Theme.stroke(C.Ink, 4),
	})
	return holder, card, wrapper
end

local function buildResults()
	local holder, card = buildModal("Results")
	refs.holder = holder
	refs.card = card

	refs.title = Theme.label({
		Size = UDim2.new(1, -40, 0, 46),
		Position = UDim2.fromOffset(20, 14),
		Text = "¡Obra entregada!",
		TextColor3 = C.Primary,
		MaxTextSize = 40,
		Parent = card,
	})
	Theme.textStroke(Color3.new(1, 1, 1), 3).Parent = refs.title

	local starRow = Theme.new("Frame", {
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.fromOffset(20, 62),
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		Theme.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
	refs.stars = {}
	for i = 1, 3 do
		local star = Theme.label({
			Size = UDim2.fromOffset(i == 2 and 74 or 62, i == 2 and 74 or 62),
			Text = "★",
			TextColor3 = Color3.fromRGB(220, 214, 230),
			MaxTextSize = 80,
			LayoutOrder = i,
			Parent = starRow,
		})
		Theme.textStroke(C.Ink, 3).Parent = star
		refs.stars[i] = star
	end

	refs.art = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = card,
	}, { Theme.stroke(C.Gold, 6), Theme.corner(4) })

	refs.line = Theme.label({
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.fromOffset(20, 302),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 20,
		Parent = card,
	})

	refs.rows = Theme.new("Frame", {
		Size = UDim2.new(1, -60, 0, 180),
		Position = UDim2.fromOffset(30, 338),
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	refs.continue = Theme.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(220, 56),
		Text = "¡Genial!",
		Color = C.Green,
		Parent = card,
		OnClick = function()
			Results.hide()
		end,
	})

	refs.confetti = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 20,
		Parent = gui,
	})
end

local function buildLevelUp()
	local holder, card, wrapper = buildModal("LevelUp")
	wrapper.Size = UDim2.fromOffset(420, 340)
	refs.levelHolder = holder
	refs.levelCard = card
	local banner = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundColor3 = C.Gold,
		Parent = card,
	}, { Theme.corner(26), Theme.gradient(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 150, 60), 0) })
	refs.levelTitle = Theme.label({
		Size = UDim2.new(1, -20, 1, -16),
		Position = UDim2.fromOffset(10, 8),
		Text = "¡NIVEL 2!",
		TextColor3 = Color3.new(1, 1, 1),
		MaxTextSize = 56,
		Parent = banner,
	})
	Theme.textStroke(C.GoldDark, 3).Parent = refs.levelTitle
	refs.levelText = Theme.label({
		Size = UDim2.new(1, -40, 0, 150),
		Position = UDim2.fromOffset(20, 104),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextWrapped = true,
		TextColor3 = C.Ink,
		MaxTextSize = 22,
		Parent = card,
	})
	Theme.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(220, 56),
		Text = "¡A pintar!",
		Color = C.Primary,
		Parent = card,
		OnClick = function()
			refs.levelHolder.Visible = false
			Results.next()
		end,
	})
end

local HELP_TEXT = table.concat({
	"1️⃣  Los clientes entran a tu galería con un pedido.",
	"2️⃣  Pulsa «Pintar» en la lista o acércate y pulsa E.",
	"3️⃣  Pinta sobre la imagen: usa la 🪣 cubeta para rellenar zonas y el 🖌️ pincel para detalles.",
	"4️⃣  En modo Original y Remix los números te dicen qué color va en cada casilla.",
	"5️⃣  ¡Entrega rápido! Más estrellas y más paciencia restante = más monedas y propinas.",
	"6️⃣  Compra mejoras 🛒, sube de nivel ⭐ y desbloquea nuevas obras.",
	"",
	"Atajos: B pincel · F cubeta · X borrador · Z deshacer · Enter entregar",
}, "\n")

local function buildHelp()
	local holder, card, wrapper = buildModal("Help")
	wrapper.Size = UDim2.fromOffset(560, 470)
	refs.helpHolder = holder
	refs.helpCard = card
	local title = Theme.label({
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.fromOffset(20, 16),
		Text = "🎨 ¿Cómo se juega?",
		TextColor3 = C.Primary,
		MaxTextSize = 40,
		Parent = card,
	})
	Theme.textStroke(Color3.new(1, 1, 1), 2).Parent = title
	Theme.label({
		Size = UDim2.new(1, -50, 0, 300),
		Position = UDim2.fromOffset(25, 76),
		Text = HELP_TEXT,
		Font = Theme.Fonts.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.Ink,
		MaxTextSize = 20,
		Parent = card,
	})
	Theme.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(220, 56),
		Text = "¡Entendido!",
		Color = C.Green,
		Parent = card,
		OnClick = function()
			refs.helpHolder.Visible = false
		end,
	})
end

-- Muestra los resultados uno a uno (por si llegan varios seguidos).
function Results.next()
	if showing then
		return
	end
	local item = table.remove(queue, 1)
	if not item then
		return
	end
	showing = true
	if item.kind == "level" then
		refs.levelTitle.Text = "¡NIVEL " .. item.level .. "!"
		local lines = { "¡Tu galería es cada vez más famosa! 🌟" }
		for _, name in ipairs(item.unlocked) do
			table.insert(lines, "🖼️ Nueva obra: " .. name)
		end
		for _, name in ipairs(item.modes) do
			table.insert(lines, "✨ Nuevo modo de pedido: " .. name)
		end
		refs.levelText.Text = table.concat(lines, "\n")
		refs.levelHolder.Visible = true
		Theme.pop(refs.levelCard, 0.5)
		Theme.playSound("success", 0.8)
		confetti(70)
		showing = false
		return
	end

	local result = item.result
	refs.holder.Visible = true
	Theme.pop(refs.card, 0.6)
	PixelArt.render(refs.art, item.art)
	refs.line.Text = "«" .. result.line .. "»"
	local titles =
		{ [0] = "Hmm... no le gustó", [1] = "¡Obra entregada!", [2] = "¡Muy bien hecho!", [3] = "¡OBRA MAESTRA!" }
	refs.title.Text = titles[result.stars] or "¡Obra entregada!"
	refs.title.TextColor3 = result.stars >= 3 and C.Gold or (result.stars == 0 and C.Red or C.Primary)

	for _, child in ipairs(refs.rows:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local rows = {
		row(
			refs.rows,
			1,
			"💰",
			"Pago: " .. Theme.formatNumber(result.payment) .. (result.vip and "  (VIP 👑)" or ""),
			C.GoldDark
		),
	}
	if result.tip > 0 then
		table.insert(
			rows,
			row(refs.rows, 2, "⚡", "Propina por rapidez: " .. Theme.formatNumber(result.tip), C.Orange)
		)
	end
	if result.streak > 1 then
		table.insert(
			rows,
			row(
				refs.rows,
				3,
				"🔥",
				"Racha x" .. result.streak .. "  (+" .. math.floor(result.streakBonus * 100 + 0.5) .. "%)",
				C.Red
			)
		)
	end
	table.insert(
		rows,
		row(
			refs.rows,
			4,
			"⭐",
			"+" .. result.xp .. " XP  ·  Precisión " .. math.floor(result.quality * 100 + 0.5) .. "%",
			C.Primary
		)
	)

	for _, star in ipairs(refs.stars) do
		star.TextColor3 = Color3.fromRGB(220, 214, 230)
	end
	refs.continue.Holder.Visible = false
	task.spawn(function()
		task.wait(0.35)
		for i = 1, result.stars do
			local star = refs.stars[i]
			star.TextColor3 = C.Gold
			Theme.pop(star, 1.8)
			Theme.playSound("success", 0.9 + i * 0.15)
			task.wait(0.32)
		end
		for _, frame in ipairs(rows) do
			frame.Visible = true
			Theme.pop(frame, 0.8)
			Theme.playSound("click", 1.3)
			task.wait(0.15)
		end
		if result.stars >= 3 then
			confetti(90)
		elseif result.stars == 2 then
			confetti(30)
		end
		refs.continue.Holder.Visible = true
		Theme.pop(refs.continue.Holder, 0.6)
	end)
end

function Results.hide()
	refs.holder.Visible = false
	showing = false
	Results.next()
end

function Results.show(result, template, art)
	table.insert(queue, { kind = "result", result = result, template = template, art = art })
	if result.levelUp then
		table.insert(queue, {
			kind = "level",
			level = result.levelUp,
			unlocked = result.unlocked or {},
			modes = result.newModes or {},
		})
	end
	Results.next()
end

function Results.showHelp()
	refs.helpHolder.Visible = true
	Theme.pop(refs.helpCard, 0.7)
end

function Results.init()
	gui = Theme.new("ScreenGui", {
		Name = "Results",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	buildResults()
	buildLevelUp()
	buildHelp()

	-- Ajusta las ventanas a pantallas pequeñas.
	local function updateScale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		for _, holder in ipairs({ refs.holder, refs.levelHolder, refs.helpHolder }) do
			local wrapper = holder:FindFirstChild("Wrapper")
			local size = wrapper.Size
			local scale = math.min((viewport.X - 20) / size.X.Offset, (viewport.Y - 80) / size.Y.Offset)
			local uiScale = wrapper:FindFirstChild("ViewportScale")
				or Theme.new("UIScale", { Name = "ViewportScale", Parent = wrapper })
			uiScale.Scale = math.clamp(scale, 0.45, 1.15)
		end
	end
	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return Results
