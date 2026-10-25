-- Estilo visual compartido por toda la interfaz y pequeñas utilidades.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(255, 253, 248),
	Panel = Color3.fromRGB(255, 255, 255),
	PanelSoft = Color3.fromRGB(250, 246, 240),
	Ink = Color3.fromRGB(122, 86, 64),
	InkSoft = Color3.fromRGB(196, 168, 146),
	Primary = Color3.fromRGB(96, 206, 168),
	PrimaryDark = Color3.fromRGB(56, 160, 126),
	Mint = Color3.fromRGB(96, 206, 168),
	MintSoft = Color3.fromRGB(226, 248, 240),
	Yellow = Color3.fromRGB(255, 236, 100),
	YellowSoft = Color3.fromRGB(255, 249, 200),
	Pink = Color3.fromRGB(255, 130, 186),
	Gold = Color3.fromRGB(255, 196, 40),
	GoldDark = Color3.fromRGB(214, 150, 10),
	Green = Color3.fromRGB(80, 200, 130),
	GreenDark = Color3.fromRGB(40, 150, 90),
	Red = Color3.fromRGB(240, 96, 110),
	Orange = Color3.fromRGB(255, 160, 70),
	Purple = Color3.fromRGB(150, 110, 240),
	Shadow = Color3.fromRGB(90, 60, 50),
	Line = Color3.fromRGB(236, 150, 186),
}

Theme.Fonts = {
	Title = Enum.Font.PatrickHand,
	Body = Enum.Font.PatrickHand,
	Bold = Enum.Font.FredokaOne,
}

-- Crea una instancia con propiedades e hijos en una sola llamada.
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

function Theme.stroke(color, thickness, transparency)
	return Theme.new("UIStroke", {
		Color = color or Theme.Colors.Ink,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.textStroke(color, thickness)
	return Theme.new("UIStroke", {
		Color = color or Theme.Colors.Ink,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Theme.padding(all)
	local p = UDim.new(0, all)
	return Theme.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Theme.gradient(top, bottom, rotation)
	return Theme.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function Theme.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Ink,
		TextScaled = true,
		Text = "",
	}
	for key, value in pairs(props) do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local label = Theme.new("TextLabel", defaults)
	if props.TextScaled ~= false and not label:FindFirstChildOfClass("UITextSizeConstraint") then
		Theme.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 40, Parent = label })
	end
	return label
end

-- Botón con sombra "3D" y animación al pulsar.
-- Botón con sombra suave. Soft = true: fondo blanco con borde de color
-- (como «Empezar a pintar»); si no, botón relleno de color.
function Theme.button(props)
	local color = props.Color or Theme.Colors.Primary
	local soft = props.Soft == true
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
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.fromOffset(0, 3),
		BackgroundColor3 = color,
		BackgroundTransparency = soft and 0.55 or 0,
		ZIndex = holder.ZIndex,
		Parent = holder,
	}, { Theme.corner(radius) })
	local button = Theme.new("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = soft and Color3.new(1, 1, 1) or color,
		AutoButtonColor = false,
		Font = Theme.Fonts.Title,
		Text = props.Text or "",
		TextColor3 = props.TextColor or (soft and Theme.Colors.Ink or Color3.new(1, 1, 1)),
		TextScaled = true,
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	}, {
		Theme.corner(radius),
		Theme.new("UIPadding", {
			PaddingTop = UDim.new(0.16, 0),
			PaddingBottom = UDim.new(0.16, 0),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Theme.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28 }),
	})
	local border = Theme.stroke(color, soft and 2.5 or 0)
	border.Parent = button
	if not soft then
		Theme.textStroke(color:Lerp(Color3.new(0, 0, 0), 0.35), 1).Parent = button
	end

	local enabled = true
	button.MouseButton1Down:Connect(function()
		if enabled then
			button.Position = UDim2.fromOffset(0, 2)
		end
	end)
	button.MouseButton1Up:Connect(function()
		button.Position = UDim2.fromOffset(0, 0)
	end)
	button.MouseLeave:Connect(function()
		button.Position = UDim2.fromOffset(0, 0)
	end)

	local api = { Holder = holder, Button = button, Shadow = shadow }
	function api.SetColor(newColor)
		if soft then
			border.Color = newColor
		else
			button.BackgroundColor3 = newColor
		end
		shadow.BackgroundColor3 = newColor
	end
	function api.SetEnabled(value)
		enabled = value
		button.Active = value
		api.SetColor(value and color or Color3.fromRGB(205, 198, 192))
		button.TextTransparency = value and 0 or 0.35
	end
	function api.SetBaseColor(newColor)
		color = newColor
		api.SetColor(newColor)
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

-- Panel blanco con borde suave y título a mano (como las ventanas del juego).
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
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Shadow,
		BackgroundTransparency = 0.6,
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
	local panel = Theme.new("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		Parent = wrapper,
	}, {
		Theme.corner(28),
		Theme.stroke(Color3.fromRGB(240, 230, 220), 3),
	})
	local title = Theme.label({
		Name = "Title",
		Size = UDim2.new(1, -120, 0, 44),
		Position = UDim2.fromOffset(32, 20),
		Text = props.Title or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 38,
		Parent = panel,
	})
	local subtitle = Theme.label({
		Name = "Subtitle",
		Size = UDim2.new(1, -120, 0, 22),
		Position = UDim2.fromOffset(32, 62),
		Text = props.Subtitle or "",
		TextColor3 = Theme.Colors.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = panel,
	})
	local close = Theme.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 18),
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		Text = "✕",
		TextScaled = true,
		TextColor3 = Theme.Colors.Ink,
		Parent = panel,
	})
	local api = { Holder = holder, Panel = panel, Wrapper = wrapper, Title = title, Subtitle = subtitle, Close = close }
	function api.Open()
		holder.Visible = true
		Theme.pop(panel, 0.85)
		Theme.playSound("whoosh", 1.1)
	end
	function api.Close()
		holder.Visible = false
	end
	close.Activated:Connect(function()
		Theme.playSound("click")
		if props.OnClose then
			props.OnClose()
		else
			api.Close()
		end
	end)
	if not props.Modal then
		dim.Activated:Connect(function()
			if props.OnClose then
				props.OnClose()
			else
				api.Close()
			end
		end)
	end
	-- Ajusta el tamaño a pantallas pequeñas.
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
		uiScale.Scale = math.clamp(scale, 0.4, 1.2)
	end
	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	api.UpdateScale = updateScale
	return api
end

function Theme.tween(instance, time, props, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- Pequeño "rebote" al aparecer.
function Theme.pop(guiObject, scale)
	local uiScale = guiObject:FindFirstChild("PopScale")
	if not uiScale then
		uiScale = Theme.new("UIScale", { Name = "PopScale", Parent = guiObject })
	end
	uiScale.Scale = scale or 0.6
	Theme.tween(uiScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Formatea números grandes: 1234 -> 1.234, 1500000 -> 1,5M
function Theme.formatNumber(n)
	n = math.floor(n or 0)
	if n >= 1000000 then
		return (string.gsub(string.format("%.1fM", n / 1000000), "%.", ","))
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

-- Sonidos incluidos en el cliente de Roblox (no requieren subir audio).
local SOUND_IDS = {
	click = "rbxasset://sounds/button.wav",
	paint = "rbxasset://sounds/clickfast.wav",
	success = "rbxasset://sounds/electronicpingshort.wav",
	whoosh = "rbxasset://sounds/swoosh.wav",
}
local SOUND_VOLUME = {
	click = 0.4,
	paint = 0.15,
	success = 0.6,
	whoosh = 0.4,
}
local soundCache = {}

function Theme.playSound(name, pitch)
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
