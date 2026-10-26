-- Sistema de diseño de la interfaz: colores, tipografías y componentes
-- (botones, tarjetas, ventanas, barras, insignias). Estilo minimalista:
-- colores planos, sombras suaves y un único color de acento.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Paleta neutra con un solo color de acento (azul). Pensada para todo el
-- público: fondos claros, texto oscuro y colores planos.
Theme.Colors = {
	Bg = rgb(244, 245, 247),
	Panel = rgb(255, 255, 255),
	PanelSoft = rgb(242, 243, 246),
	Border = rgb(225, 228, 234),
	Ink = rgb(26, 30, 38),
	InkSoft = rgb(96, 104, 118),
	InkFaint = rgb(156, 163, 175),
	Primary = rgb(40, 104, 232),
	PrimaryDark = rgb(28, 80, 196),
	PrimaryLight = rgb(232, 239, 253),
	Pink = rgb(40, 104, 232),
	PinkLight = rgb(232, 239, 253),
	Mint = rgb(26, 160, 108),
	MintDark = rgb(16, 128, 84),
	MintLight = rgb(225, 245, 236),
	Gold = rgb(240, 168, 32),
	GoldDark = rgb(170, 108, 0),
	GoldLight = rgb(253, 245, 225),
	Red = rgb(220, 64, 64),
	RedLight = rgb(252, 232, 232),
	Orange = rgb(234, 126, 40),
	Blue = rgb(40, 104, 232),
	Purple = rgb(112, 90, 214),
	Shadow = rgb(14, 18, 28),
	White = rgb(255, 255, 255),
}
local C = Theme.Colors

-- Colores de relleno (casi planos: el degradado es apenas perceptible).
Theme.Gradients = {
	primary = { rgb(48, 112, 240), rgb(36, 98, 226) },
	mint = { rgb(32, 170, 116), rgb(24, 154, 104) },
	gold = { rgb(244, 176, 44), rgb(234, 160, 28) },
	red = { rgb(228, 74, 74), rgb(212, 58, 58) },
	blue = { rgb(48, 112, 240), rgb(36, 98, 226) },
	purple = { rgb(122, 100, 222), rgb(108, 86, 208) },
	pink = { rgb(48, 112, 240), rgb(36, 98, 226) },
	orange = { rgb(240, 138, 52), rgb(228, 122, 38) },
	dark = { rgb(44, 50, 62), rgb(32, 37, 48) },
	gray = { rgb(228, 231, 236), rgb(220, 224, 230) },
}

Theme.Fonts = {
	Display = Enum.Font.BuilderSansExtraBold,
	Heavy = Enum.Font.BuilderSansExtraBold,
	Bold = Enum.Font.BuilderSansBold,
	Medium = Enum.Font.BuilderSansMedium,
	Body = Enum.Font.BuilderSans,
	Title = Enum.Font.BuilderSansExtraBold,
}

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

-- Tarjeta blanca con sombra muy suave. Devuelve el contenedor y el cuerpo.
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
	local radius = props.Radius or 14
	Theme.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, props.ShadowOffset or 3),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = props.ShadowTransparency or 0.93,
		Parent = holder,
	}, { Theme.corner(radius) })
	local body = Theme.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = props.Color or C.Panel,
		Parent = holder,
	}, { Theme.corner(radius) })
	if props.Stroke ~= false then
		Theme.stroke(props.StrokeColor or C.Border, props.StrokeThickness or 1).Parent = body
	end
	return holder, body
end

-- Botones -------------------------------------------------------------------------------------
-- Variant: primary, mint, gold, red, dark, ghost (blanco con borde).
function Theme.button(props)
	local variant = props.Variant or (props.Soft and "ghost") or "primary"
	local radius = props.Radius or 12
	local holder = Theme.new("Frame", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local shadow = Theme.new("Frame", {
		Name = "Shadow",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 2),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.9,
		ZIndex = holder.ZIndex,
		Parent = holder,
	}, { Theme.corner(radius) })
	local button = Theme.new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		AutoButtonColor = false,
		Font = props.Font or Theme.Fonts.Bold,
		Text = props.Text or "",
		TextColor3 = C.White,
		TextScaled = true,
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	}, {
		Theme.corner(radius),
		Theme.new("UIPadding", {
			PaddingTop = UDim.new(0.22, 0),
			PaddingBottom = UDim.new(0.22, 0),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Theme.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 20 }),
	})
	local gradient = Theme.new("UIGradient", { Rotation = 90, Parent = button })
	local border = Theme.stroke(C.Border, 0)
	border.Parent = button
	local scale = Theme.new("UIScale", { Name = "Interact", Parent = holder })

	local enabled = true
	local function paint()
		if not enabled then
			local pair = Theme.Gradients.gray
			gradient.Color = ColorSequence.new(pair[1], pair[2])
			button.TextColor3 = C.InkFaint
			border.Thickness = 0
			shadow.BackgroundTransparency = 1
		elseif variant == "ghost" then
			gradient.Color = ColorSequence.new(C.White)
			button.TextColor3 = props.TextColor or C.Ink
			border.Color = props.Color or C.Border
			border.Thickness = 1.5
			shadow.BackgroundTransparency = 0.95
		else
			local pair = Theme.Gradients[variant] or Theme.Gradients.primary
			gradient.Color = ColorSequence.new(pair[1], pair[2])
			button.TextColor3 = C.White
			border.Thickness = 0
			shadow.BackgroundTransparency = 0.88
		end
	end
	paint()

	button.MouseEnter:Connect(function()
		if enabled then
			Theme.tween(scale, 0.12, { Scale = 1.03 })
		end
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			Theme.tween(scale, 0.06, { Scale = 0.97 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		Theme.tween(scale, 0.1, { Scale = 1 })
	end)

	local api = { Holder = holder, Button = button, Shadow = shadow }
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

-- Botón cuadrado del menú lateral (icono + texto) con insignia.
function Theme.tile(props)
	local holder = Theme.new("Frame", {
		Name = props.Name or "Tile",
		Size = props.Size or UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 2),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.92,
		Parent = holder,
	}, { Theme.corner(14) })
	local face = Theme.new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.04,
		AutoButtonColor = false,
		Text = "",
		Parent = holder,
	}, {
		Theme.corner(14),
		Theme.stroke(C.Border, 1),
	})
	Theme.label({
		Name = "Icon",
		Size = UDim2.new(1, 0, 0.5, 0),
		Position = UDim2.fromScale(0, 0.1),
		Text = props.Icon,
		Font = Theme.Fonts.Bold,
		MaxTextSize = props.IconSize or 26,
		Parent = face,
	})
	local caption = Theme.label({
		Name = "Caption",
		Size = UDim2.new(1, -6, 0.24, 0),
		Position = UDim2.new(0, 3, 0.66, 0),
		Text = props.Text,
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 12,
		Parent = face,
	})
	local badge = Theme.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.fromOffset(18, 18),
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
		MaxTextSize = 11,
		ZIndex = 6,
		Parent = badge,
	})
	local scale = Theme.new("UIScale", { Name = "Interact", Parent = holder })
	face.MouseEnter:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.04 })
	end)
	face.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
	face.MouseButton1Down:Connect(function()
		Theme.tween(scale, 0.06, { Scale = 0.96 })
	end)
	face.MouseButton1Up:Connect(function()
		Theme.tween(scale, 0.1, { Scale = 1 })
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
		face.BackgroundColor3 = active and C.PrimaryLight or C.White
		caption.TextColor3 = active and C.PrimaryDark or C.InkSoft
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
		BackgroundColor3 = props.TrackColor or rgb(232, 235, 240),
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

-- Ventana modal: tarjeta blanca con cabecera sencilla y línea divisoria -----------------------
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
		BackgroundTransparency = 0.55,
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
		Radius = 18,
		Color = C.Bg,
		ShadowOffset = 6,
		ShadowTransparency = 0.82,
		Stroke = false,
		Parent = wrapper,
	})
	panel.Name = "Panel"
	local header = Theme.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = C.White,
		Parent = panel,
	}, { Theme.corner(18) })
	-- Tapa las esquinas inferiores redondeadas de la cabecera y dibuja la línea.
	Theme.new("Frame", {
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Parent = header,
	})
	Theme.new("Frame", {
		Name = "Divider",
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Border,
		BorderSizePixel = 0,
		Parent = header,
	})
	local title = Theme.label({
		Name = "Title",
		Size = UDim2.new(1, -140, 0, 30),
		Position = UDim2.fromOffset(24, 12),
		Text = props.Title or "",
		Font = Theme.Fonts.Display,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = header,
	})
	local subtitle = Theme.label({
		Name = "Subtitle",
		Size = UDim2.new(1, -140, 0, 18),
		Position = UDim2.fromOffset(24, 43),
		Text = props.Subtitle or "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = header,
	})
	local close = Theme.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0, 36),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = C.PanelSoft,
		Font = Theme.Fonts.Bold,
		Text = "✕",
		TextScaled = true,
		TextColor3 = C.InkSoft,
		AutoButtonColor = true,
		Parent = header,
	}, { Theme.round(), Theme.padding(10) })
	local body = Theme.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -72),
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
		Theme.tween(dim, 0.2, { BackgroundTransparency = 0.55 })
		Theme.pop(panelCard, 0.94)
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
	Theme.tween(uiScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Quart)
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
