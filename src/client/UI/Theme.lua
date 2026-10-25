-- Sistema de diseño de la interfaz: colores, tipografías y componentes
-- (botones, tarjetas, ventanas, barras, insignias) con animaciones.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Theme.Colors = {
	Bg = rgb(246, 243, 255),
	Panel = rgb(255, 255, 255),
	PanelSoft = rgb(248, 246, 255),
	Border = rgb(230, 224, 246),
	Ink = rgb(43, 36, 69),
	InkSoft = rgb(116, 108, 146),
	InkFaint = rgb(176, 170, 198),
	Primary = rgb(124, 92, 255),
	PrimaryDark = rgb(88, 60, 210),
	PrimaryLight = rgb(236, 230, 255),
	Pink = rgb(255, 102, 170),
	PinkLight = rgb(255, 232, 244),
	Mint = rgb(40, 200, 150),
	MintDark = rgb(22, 150, 110),
	MintLight = rgb(220, 248, 238),
	Gold = rgb(255, 186, 36),
	GoldDark = rgb(206, 130, 0),
	GoldLight = rgb(255, 246, 214),
	Red = rgb(240, 84, 104),
	RedLight = rgb(255, 228, 232),
	Orange = rgb(255, 146, 60),
	Blue = rgb(64, 146, 255),
	Purple = rgb(150, 100, 250),
	Shadow = rgb(24, 14, 54),
	White = rgb(255, 255, 255),
}
local C = Theme.Colors

-- Pares de colores para degradados.
Theme.Gradients = {
	primary = { rgb(150, 110, 255), rgb(255, 104, 182) },
	mint = { rgb(56, 222, 170), rgb(24, 178, 196) },
	gold = { rgb(255, 214, 80), rgb(255, 146, 40) },
	red = { rgb(255, 120, 130), rgb(230, 60, 100) },
	blue = { rgb(90, 180, 255), rgb(90, 110, 255) },
	purple = { rgb(186, 120, 255), rgb(120, 90, 250) },
	pink = { rgb(255, 150, 200), rgb(255, 90, 150) },
	orange = { rgb(255, 190, 90), rgb(255, 120, 70) },
	dark = { rgb(70, 60, 104), rgb(44, 36, 72) },
	gray = { rgb(214, 210, 226), rgb(190, 184, 206) },
}

Theme.Fonts = {
	Display = Enum.Font.FredokaOne,
	Heavy = Enum.Font.BuilderSansExtraBold,
	Bold = Enum.Font.BuilderSansBold,
	Medium = Enum.Font.BuilderSansMedium,
	Body = Enum.Font.BuilderSans,
	Title = Enum.Font.FredokaOne,
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
	local radius = props.Radius or 18
	Theme.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, props.ShadowOffset or 5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = props.ShadowTransparency or 0.86,
		Parent = holder,
	}, { Theme.corner(radius) })
	local body = Theme.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = props.Color or C.Panel,
		Parent = holder,
	}, { Theme.corner(radius) })
	if props.Stroke ~= false then
		Theme.stroke(props.StrokeColor or C.Border, props.StrokeThickness or 1.5).Parent = body
	end
	return holder, body
end

-- Botones -------------------------------------------------------------------------------------
-- Variant: primary, mint, gold, red, blue, purple, pink, orange, dark, ghost.
function Theme.button(props)
	local variant = props.Variant or (props.Soft and "ghost") or "primary"
	local radius = props.Radius or 14
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
	local shadow = Theme.new("Frame", {
		Name = "Shadow",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.75,
		ZIndex = holder.ZIndex,
		Parent = holder,
	}, { Theme.corner(radius) })
	local button = Theme.new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
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
		Theme.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 24 }),
	})
	local gradient = Theme.new("UIGradient", { Rotation = 90, Parent = button })
	local border = Theme.stroke(C.Border, 0)
	border.Parent = button
	local textStroke = Theme.textStroke(C.Shadow, 1.2, 0.75)
	textStroke.Parent = button
	local scale = Theme.new("UIScale", { Name = "Interact", Parent = holder })

	local enabled = true
	local function paint()
		local v = enabled and variant or "gray"
		if v == "ghost" then
			gradient.Color = ColorSequence.new(C.White, C.PanelSoft)
			button.TextColor3 = props.TextColor or C.Ink
			border.Color = props.Color or C.Border
			border.Thickness = 2
			textStroke.Transparency = 1
			shadow.BackgroundTransparency = 0.88
		else
			local pair = Theme.Gradients[v] or Theme.Gradients.primary
			gradient.Color = ColorSequence.new(pair[1], pair[2])
			button.TextColor3 = C.White
			border.Thickness = 0
			textStroke.Transparency = 0.7
			shadow.BackgroundTransparency = 0.72
		end
		button.TextTransparency = enabled and 0 or 0.25
	end
	paint()

	button.MouseEnter:Connect(function()
		if enabled then
			Theme.tween(scale, 0.12, { Scale = 1.05 })
		end
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			Theme.tween(scale, 0.06, { Scale = 0.94 })
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
		Size = props.Size or UDim2.fromOffset(78, 78),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.7,
		Parent = holder,
	}, { Theme.corner(20) })
	local face = Theme.new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		AutoButtonColor = false,
		Text = "",
		Parent = holder,
	}, {
		Theme.corner(20),
		Theme.gradient(props.Gradient or "primary", 90),
		Theme.stroke(C.White, 2.5, 0.35),
	})
	Theme.label({
		Name = "Icon",
		Size = UDim2.new(1, 0, 0.58, 0),
		Position = UDim2.fromScale(0, 0.04),
		Text = props.Icon,
		Font = Theme.Fonts.Bold,
		MaxTextSize = props.IconSize or 34,
		Parent = face,
	})
	local caption = Theme.label({
		Name = "Caption",
		Size = UDim2.new(1, -6, 0.3, 0),
		Position = UDim2.new(0, 3, 0.64, 0),
		Text = props.Text,
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		MaxTextSize = 15,
		Parent = face,
	})
	Theme.textStroke(C.Shadow, 1.2, 0.6).Parent = caption
	local badge = Theme.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = C.Red,
		Visible = false,
		ZIndex = 5,
		Parent = holder,
	}, { Theme.round(), Theme.stroke(C.White, 2.5) })
	local badgeText = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		MaxTextSize = 14,
		ZIndex = 6,
		Parent = badge,
	})
	local scale = Theme.new("UIScale", { Name = "Interact", Parent = holder })
	face.MouseEnter:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.07 })
	end)
	face.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
	face.MouseButton1Down:Connect(function()
		Theme.tween(scale, 0.06, { Scale = 0.93 })
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
	return api
end

-- Barra de progreso con degradado.
function Theme.progress(props)
	local track = Theme.new("Frame", {
		Name = props.Name or "Progress",
		Size = props.Size or UDim2.new(1, 0, 0, 10),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = props.TrackColor or C.Border,
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

-- Ventana modal con cabecera de color --------------------------------------------------------
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
		BackgroundTransparency = 0.45,
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
		Radius = 26,
		Color = C.Bg,
		ShadowOffset = 10,
		ShadowTransparency = 0.6,
		StrokeColor = C.White,
		StrokeThickness = 3,
		Parent = wrapper,
	})
	panel.Name = "Panel"
	local header = Theme.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = C.White,
		Parent = panel,
	}, { Theme.corner(26), Theme.gradient(props.Gradient or "primary", 0) })
	-- Tapa las esquinas inferiores redondeadas de la cabecera.
	Theme.new("Frame", {
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Parent = header,
	}, { Theme.gradient(props.Gradient or "primary", 0) })
	local title = Theme.label({
		Name = "Title",
		Size = UDim2.new(1, -140, 0, 40),
		Position = UDim2.fromOffset(28, 12),
		Text = props.Title or "",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 36,
		Parent = header,
	})
	Theme.textStroke(C.Shadow, 2, 0.75).Parent = title
	local subtitle = Theme.label({
		Name = "Subtitle",
		Size = UDim2.new(1, -140, 0, 22),
		Position = UDim2.fromOffset(28, 52),
		Text = props.Subtitle or "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.White,
		TextTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = header,
	})
	local close = Theme.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0, 42),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.1,
		Font = Theme.Fonts.Heavy,
		Text = "✕",
		TextScaled = true,
		TextColor3 = C.Ink,
		Parent = header,
	}, { Theme.round(), Theme.padding(11) })
	local body = Theme.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -84),
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
		Theme.tween(dim, 0.2, { BackgroundTransparency = 0.45 })
		Theme.pop(panelCard, 0.85)
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
		uiScale.Scale = math.clamp(scale, 0.4, 1.15)
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
	Theme.tween(uiScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
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
