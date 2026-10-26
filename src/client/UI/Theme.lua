-- Sistema de diseño de la interfaz: colores, tipografías y componentes
-- (botones con relieve, tarjetas, ventanas, barras, insignias). Estilo de
-- "estudio de arte": crema, azul tinta y acentos turquesa, ámbar y coral.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Paleta "estudio": crema y azul tinta, con acentos turquesa, ámbar y coral.
Theme.Colors = {
	Bg = rgb(250, 246, 238),
	Panel = rgb(255, 255, 255),
	PanelSoft = rgb(247, 242, 233),
	Border = rgb(234, 225, 210),
	Ink = rgb(34, 42, 66),
	InkSoft = rgb(104, 110, 130),
	InkFaint = rgb(166, 168, 180),
	Navy = rgb(38, 50, 84),
	NavyDark = rgb(26, 35, 62),
	Primary = rgb(18, 168, 148),
	PrimaryDark = rgb(10, 128, 112),
	PrimaryLight = rgb(218, 246, 240),
	Pink = rgb(246, 112, 90),
	PinkLight = rgb(255, 232, 226),
	Coral = rgb(246, 112, 90),
	Mint = rgb(52, 188, 116),
	MintDark = rgb(28, 140, 82),
	MintLight = rgb(224, 247, 234),
	Gold = rgb(250, 176, 40),
	GoldDark = rgb(198, 124, 10),
	GoldLight = rgb(255, 244, 214),
	Red = rgb(236, 86, 76),
	RedLight = rgb(255, 230, 226),
	Orange = rgb(244, 140, 50),
	Blue = rgb(64, 140, 240),
	Purple = rgb(130, 96, 220),
	Shadow = rgb(20, 24, 40),
	White = rgb(255, 255, 255),
}
local C = Theme.Colors

-- Degradados de los botones y fichas (de arriba a abajo).
Theme.Gradients = {
	primary = { rgb(40, 196, 172), rgb(14, 156, 138) },
	mint = { rgb(84, 214, 140), rgb(40, 172, 104) },
	gold = { rgb(255, 204, 74), rgb(244, 160, 24) },
	red = { rgb(255, 136, 112), rgb(236, 92, 74) },
	coral = { rgb(255, 136, 112), rgb(236, 92, 74) },
	blue = { rgb(96, 166, 255), rgb(52, 124, 232) },
	purple = { rgb(156, 124, 240), rgb(118, 86, 212) },
	pink = { rgb(255, 136, 112), rgb(236, 92, 74) },
	orange = { rgb(255, 176, 86), rgb(240, 128, 40) },
	navy = { rgb(60, 76, 120), rgb(36, 48, 84) },
	dark = { rgb(60, 76, 120), rgb(36, 48, 84) },
	gray = { rgb(214, 212, 206), rgb(192, 190, 184) },
}

Theme.Fonts = {
	Display = Enum.Font.FredokaOne,
	Heavy = Enum.Font.BuilderSansExtraBold,
	Bold = Enum.Font.BuilderSansBold,
	Medium = Enum.Font.BuilderSansMedium,
	Body = Enum.Font.BuilderSans,
	Title = Enum.Font.FredokaOne,
}

local function darker(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.22)
end
Theme.darker = darker

-- Instancias ----------------------------------------------------------------------------------
function Theme.new(className, props, children)
	local instance = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Theme.corner(radius)
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function Theme.round()
	return Theme.new("UICorner", { CornerRadius = UDim.new(0.5, 0) })
end

function Theme.stroke(color, thickness, transparency)
	return Theme.new("UIStroke", {
		Color = color or C.Border,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.textStroke(color, thickness, transparency)
	return Theme.new("UIStroke", {
		Color = color or C.Ink,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Theme.padding(all, horizontal)
	local v = UDim.new(0, all)
	local h = UDim.new(0, horizontal or all)
	return Theme.new("UIPadding", { PaddingTop = v, PaddingBottom = v, PaddingLeft = h, PaddingRight = h })
end

function Theme.gradient(a, b, rotation)
	if type(a) == "string" then
		local pair = Theme.Gradients[a]
		return Theme.new("UIGradient", { Color = ColorSequence.new(pair[1], pair[2]), Rotation = b or 90 })
	end
	return Theme.new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90 })
end

function Theme.list(direction, padding, hAlign, vAlign)
	return Theme.new("UIListLayout", {
		FillDirection = direction == "h" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- Texto con tamaño automático y límite de tamaño.
function Theme.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Bold,
		TextColor3 = C.Ink,
		TextScaled = true,
		TextWrapped = true,
		Text = "",
	}
	for key, value in pairs(props) do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local label = Theme.new("TextLabel", defaults)
	if label.TextScaled then
		Theme.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 32, Parent = label })
	end
	return label
end

-- Tarjeta blanca con sombra suave. Devuelve el contenedor y el cuerpo.
function Theme.card(props)
	local holder = Theme.new("Frame", {
		Name = props.Name or "Card",
		Size = props.Size or UDim2.fromOffset(200, 100),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	local radius = props.Radius or 16
	Theme.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, props.ShadowOffset or 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = props.ShadowTransparency or 0.88,
		Parent = holder,
	}, { Theme.corner(radius) })
	local body = Theme.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = props.Color or C.Panel,
		BackgroundTransparency = props.Transparency or 0,
		Parent = holder,
	}, { Theme.corner(radius) })
	if props.Stroke ~= false then
		Theme.stroke(props.StrokeColor or C.Border, props.StrokeThickness or 1.5).Parent = body
	end
	return holder, body
end

-- Botones con relieve: una cara con degradado sobre un "labio" más oscuro que
-- se hunde al pulsar. Variant: primary, mint, gold, coral, blue, navy, ghost.
function Theme.button(props)
	local variant = props.Variant or (props.Soft and "ghost") or "primary"
	local radius = props.Radius or 14
	local depth = props.Depth or 4
	local holder = Theme.new("Frame", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 48),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local lip = Theme.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, depth),
		Size = UDim2.new(1, 0, 1, -depth),
		BackgroundColor3 = C.Navy,
		ZIndex = holder.ZIndex,
		Parent = holder,
	}, { Theme.corner(radius) })
	local button = Theme.new("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -depth),
		BackgroundColor3 = C.White,
		AutoButtonColor = false,
		Font = props.Font or Theme.Fonts.Heavy,
		Text = props.Text or "",
		TextColor3 = C.White,
		TextScaled = true,
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	}, {
		Theme.corner(radius),
		Theme.new("UIPadding", {
			PaddingTop = UDim.new(0.2, 0),
			PaddingBottom = UDim.new(0.2, 0),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Theme.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 22 }),
	})
	local gradient = Theme.new("UIGradient", { Rotation = 90, Parent = button })
	local border = Theme.stroke(C.Border, 0)
	border.Parent = button
	local textStroke = Theme.textStroke(C.Shadow, 1.2, 0.8)
	textStroke.Parent = button

	local enabled = true
	local function paint()
		local v = enabled and variant or "gray"
		if v == "ghost" then
			gradient.Color = ColorSequence.new(C.White, C.PanelSoft)
			lip.BackgroundColor3 = C.Border
			button.TextColor3 = props.TextColor or C.Ink
			border.Color = props.Color or C.Border
			border.Thickness = 1.5
			textStroke.Transparency = 1
		else
			local pair = Theme.Gradients[v] or Theme.Gradients.primary
			gradient.Color = ColorSequence.new(pair[1], pair[2])
			lip.BackgroundColor3 = darker(pair[2], 0.25)
			button.TextColor3 = C.White
			border.Thickness = 0
			textStroke.Transparency = v == "gray" and 1 or 0.8
		end
		button.TextTransparency = enabled and 0 or 0.15
	end
	paint()

	local function press(down)
		button.Position = UDim2.fromOffset(0, down and depth - 1 or 0)
	end
	local scale = Theme.new("UIScale", { Name = "Interact", Parent = holder })
	button.MouseEnter:Connect(function()
		if enabled then
			Theme.tween(scale, 0.12, { Scale = 1.03 })
		end
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
		press(false)
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			press(true)
		end
	end)
	button.MouseButton1Up:Connect(function()
		press(false)
	end)

	local api = { Holder = holder, Button = button, Shadow = lip }
	function api.SetEnabled(value)
		enabled = value
		button.Active = value
		paint()
	end
	function api.SetVariant(newVariant)
		variant = newVariant
		paint()
	end
	function api.SetText(text)
		button.Text = text
	end
	if props.OnClick then
		button.Activated:Connect(function()
			if enabled then
				Theme.playSound("click")
				props.OnClick()
			end
		end)
	end
	return api
end

-- Ficha cuadrada del menú lateral (icono + texto) con relieve e insignia.
function Theme.tile(props)
	local pair = Theme.Gradients[props.Gradient or "navy"] or Theme.Gradients.navy
	local holder = Theme.new("Frame", {
		Name = props.Name or "Tile",
		Size = props.Size or UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Theme.new("Frame", {
		Name = "Lip",
		Size = UDim2.new(1, 0, 1, -4),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = darker(pair[2], 0.3),
		Parent = holder,
	}, { Theme.corner(16) })
	local face = Theme.new("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -4),
		BackgroundColor3 = C.White,
		AutoButtonColor = false,
		Text = "",
		Parent = holder,
	}, {
		Theme.corner(16),
		Theme.gradient(pair[1], pair[2], 90),
		Theme.stroke(C.White, 1.5, 0.55),
	})
	Theme.label({
		Name = "Icon",
		Size = UDim2.new(1, 0, 0.56, 0),
		Position = UDim2.fromScale(0, 0.06),
		Text = props.Icon,
		Font = Theme.Fonts.Bold,
		MaxTextSize = props.IconSize or 28,
		Parent = face,
	})
	local caption = Theme.label({
		Name = "Caption",
		Size = UDim2.new(1, -6, 0.26, 0),
		Position = UDim2.new(0, 3, 0.64, 0),
		Text = props.Text,
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		MaxTextSize = 13,
		Parent = face,
	})
	Theme.textStroke(C.Shadow, 1.2, 0.6).Parent = caption
	local badge = Theme.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = C.Red,
		Visible = false,
		ZIndex = 5,
		Parent = holder,
	}, { Theme.round(), Theme.stroke(C.White, 2) })
	local badgeText = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		MaxTextSize = 12,
		ZIndex = 6,
		Parent = badge,
	})
	local ring = Theme.stroke(C.White, 0)
	ring.Parent = face
	local scale = Theme.new("UIScale", { Name = "Interact", Parent = holder })
	face.MouseEnter:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.06 })
	end)
	face.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
		face.Position = UDim2.new()
	end)
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, 3)
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	if props.OnClick then
		face.Activated:Connect(function()
			Theme.playSound("click")
			props.OnClick()
		end)
	end
	local api = { Holder = holder, Button = face, Caption = caption }
	function api.SetBadge(value)
		if value == nil or value == false or value == 0 then
			badge.Visible = false
		else
			badge.Visible = true
			badgeText.Text = value == true and "!" or tostring(value)
		end
	end
	function api.SetActive(active)
		ring.Thickness = active and 3 or 0
		ring.Color = C.White
	end
	return api
end

-- Barra de progreso con degradado.
function Theme.progress(props)
	local track = Theme.new("Frame", {
		Name = props.Name or "Progress",
		Size = props.Size or UDim2.new(1, 0, 0, 10),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = props.TrackColor or rgb(236, 229, 216),
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, { Theme.round() })
	local fill = Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.White,
		ZIndex = track.ZIndex,
		Parent = track,
	}, { Theme.round() })
	local fillGradient = Theme.gradient(props.Gradient or "primary", 0)
	fillGradient.Parent = fill
	local api = { Frame = track, Fill = fill }
	function api.Set(fraction, animate)
		fraction = math.clamp(fraction or 0, 0, 1)
		local target = UDim2.fromScale(fraction, 1)
		if animate then
			Theme.tween(fill, 0.35, { Size = target })
		else
			fill.Size = target
		end
		fill.Visible = fraction > 0.001
	end
	function api.SetGradient(name)
		local pair = Theme.Gradients[name]
		fillGradient.Color = ColorSequence.new(pair[1], pair[2])
	end
	return api
end

-- Etiqueta en forma de píldora.
function Theme.chip(props)
	local chip = Theme.new("Frame", {
		Name = props.Name or "Chip",
		Size = props.Size or UDim2.fromOffset(100, 26),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = props.Color or C.PrimaryLight,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, { Theme.round() })
	local label = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = props.Text or "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = props.TextColor or props.TextColor3 or C.PrimaryDark,
		MaxTextSize = props.MaxTextSize or 15,
		ZIndex = chip.ZIndex,
		Parent = chip,
	})
	Theme.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0.15, 0),
		PaddingBottom = UDim.new(0.15, 0),
		Parent = label,
	})
	return chip, label
end

-- Ventana modal: cabecera azul tinta con icono y título, cuerpo crema -----------------------
function Theme.window(props)
	local holder = Theme.new("Frame", {
		Name = props.Name or "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = props.Parent,
	})
	local dim = Theme.new("TextButton", {
		Name = "Dim",
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		Parent = holder,
	})
	local wrapper = Theme.new("Frame", {
		Name = "Wrapper",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromOffset(900, 560),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local panelCard, panel = Theme.card({
		Name = "PanelCard",
		Size = UDim2.fromScale(1, 1),
		Radius = 22,
		Color = C.Bg,
		ShadowOffset = 8,
		ShadowTransparency = 0.7,
		StrokeColor = C.Navy,
		StrokeThickness = 3,
		Parent = wrapper,
	})
	panel.Name = "Panel"
	local header = Theme.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = C.White,
		Parent = panel,
	}, { Theme.corner(22), Theme.gradient(Theme.Gradients.navy[1], Theme.Gradients.navy[2], 90) })
	-- Tapa las esquinas inferiores redondeadas de la cabecera.
	Theme.new("Frame", {
		Position = UDim2.new(0, 0, 1, -22),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Parent = header,
	}, { Theme.gradient(Theme.Gradients.navy[1]:Lerp(Theme.Gradients.navy[2], 0.7), Theme.Gradients.navy[2], 90) })
	local accent = Theme.Gradients[props.Accent or "primary"] or Theme.Gradients.primary
	local badge = Theme.new("Frame", {
		Name = "IconBadge",
		Position = UDim2.fromOffset(18, 13),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = C.White,
		Visible = props.Icon ~= nil,
		Parent = header,
	}, { Theme.corner(14), Theme.gradient(accent[1], accent[2], 90), Theme.stroke(C.White, 2, 0.5) })
	Theme.label({ Size = UDim2.fromScale(1, 1), Text = props.Icon or "", MaxTextSize = 28, Parent = badge })
	local textX = props.Icon and 78 or 24
	local title = Theme.label({
		Name = "Title",
		Size = UDim2.new(1, -textX - 80, 0, 32),
		Position = UDim2.fromOffset(textX, 10),
		Text = props.Title or "",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		Parent = header,
	})
	local subtitle = Theme.label({
		Name = "Subtitle",
		Size = UDim2.new(1, -textX - 80, 0, 18),
		Position = UDim2.fromOffset(textX, 44),
		Text = props.Subtitle or "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.White,
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = header,
	})
	Theme.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0, 40),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = darker(C.Coral, 0.3),
		Parent = header,
	}, { Theme.round() })
	local close = Theme.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0, 37),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = C.White,
		Font = Theme.Fonts.Heavy,
		Text = "✕",
		TextScaled = true,
		TextColor3 = C.White,
		AutoButtonColor = true,
		Parent = header,
	}, { Theme.round(), Theme.padding(11), Theme.gradient(Theme.Gradients.coral[1], Theme.Gradients.coral[2], 90) })
	local body = Theme.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 1, -74),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	local api = {
		Holder = holder,
		Panel = panel,
		Body = body,
		Header = header,
		Wrapper = wrapper,
		Title = title,
		Subtitle = subtitle,
		Close = close,
	}
	function api.Open()
		holder.Visible = true
		dim.BackgroundTransparency = 1
		Theme.tween(dim, 0.2, { BackgroundTransparency = 0.5 })
		Theme.pop(panelCard, 0.9)
		Theme.playSound("whoosh", 1.1)
	end
	function api.Close()
		holder.Visible = false
	end
	local function requestClose()
		Theme.playSound("click")
		if props.OnClose then
			props.OnClose()
		else
			api.Close()
		end
	end
	close.Activated:Connect(requestClose)
	if not props.Modal then
		dim.Activated:Connect(requestClose)
	end
	local function updateScale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local size = wrapper.Size
		local viewport = camera.ViewportSize
		local scale = math.min((viewport.X - 24) / size.X.Offset, (viewport.Y - 70) / size.Y.Offset)
		local uiScale = wrapper:FindFirstChild("ViewportScale")
			or Theme.new("UIScale", { Name = "ViewportScale", Parent = wrapper })
		uiScale.Scale = math.clamp(scale, 0.4, 1.1)
	end
	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	api.UpdateScale = updateScale
	return api
end

-- Mayúsculas que respetan tildes y eñes (string.upper solo cambia ASCII).
local ACCENTS =
	{ ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
function Theme.upper(text)
	local result = string.upper(text)
	for lower, upper in pairs(ACCENTS) do
		result = string.gsub(result, lower, upper)
	end
	return result
end

-- Animaciones ---------------------------------------------------------------------------------
function Theme.tween(instance, time, props, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- Igual que pop pero para tarjetas (cuerpo y sombra crecen juntos).
function Theme.popCard(holder, scale)
	for _, name in ipairs({ "Body", "Shadow" }) do
		local part = holder:FindFirstChild(name)
		if part then
			Theme.pop(part, scale)
		end
	end
end

function Theme.pop(guiObject, scale)
	local uiScale = guiObject:FindFirstChild("PopScale")
	if not uiScale then
		uiScale = Theme.new("UIScale", { Name = "PopScale", Parent = guiObject })
	end
	uiScale.Scale = scale or 0.6
	Theme.tween(uiScale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Formato ---------------------------------------------------------------------------------------
local function trimZero(text)
	local cleaned = string.gsub(text, "%.0$", "")
	return cleaned
end

function Theme.formatNumber(n)
	n = math.floor(n or 0)
	local abs = math.abs(n)
	if abs >= 1e9 then
		return trimZero(string.format("%.1f", n / 1e9)) .. "B"
	elseif abs >= 1e6 then
		return trimZero(string.format("%.1f", n / 1e6)) .. "M"
	elseif abs >= 1e4 then
		return trimZero(string.format("%.1f", n / 1e3)) .. "K"
	end
	local formatted = tostring(n)
	while true do
		local replaced, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return formatted
end

function Theme.formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor(seconds % 3600 / 60)
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm %02ds", m, seconds % 60)
end

-- Sonidos ---------------------------------------------------------------------------------------
-- Sonidos incluidos en el cliente de Roblox (no requieren subir audio).
local SOUND_IDS = {
	click = "rbxasset://sounds/button.wav",
	paint = "rbxasset://sounds/clickfast.wav",
	success = "rbxasset://sounds/electronicpingshort.wav",
	whoosh = "rbxasset://sounds/swoosh.wav",
}
local SOUND_VOLUME = { click = 0.35, paint = 0.12, success = 0.55, whoosh = 0.35 }
local soundCache = {}
Theme.soundsEnabled = true

function Theme.playSound(name, pitch)
	if not Theme.soundsEnabled then
		return
	end
	local id = SOUND_IDS[name]
	if not id then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = SOUND_VOLUME[name] or 0.5
		sound.Parent = SoundService
		soundCache[name] = sound
	end
	sound.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(sound)
end

return Theme
