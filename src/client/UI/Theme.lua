-- Estilo visual compartido por toda la interfaz y pequeñas utilidades.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(255, 249, 242),
	Panel = Color3.fromRGB(255, 255, 255),
	PanelSoft = Color3.fromRGB(246, 240, 255),
	Ink = Color3.fromRGB(52, 40, 74),
	InkSoft = Color3.fromRGB(122, 108, 150),
	Primary = Color3.fromRGB(124, 92, 255),
	PrimaryDark = Color3.fromRGB(92, 64, 214),
	Pink = Color3.fromRGB(255, 105, 180),
	Gold = Color3.fromRGB(255, 196, 40),
	GoldDark = Color3.fromRGB(214, 150, 10),
	Green = Color3.fromRGB(46, 196, 120),
	GreenDark = Color3.fromRGB(26, 150, 90),
	Red = Color3.fromRGB(240, 80, 100),
	Orange = Color3.fromRGB(255, 150, 50),
	Shadow = Color3.fromRGB(40, 20, 70),
}

Theme.Fonts = {
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
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
function Theme.button(props)
	local color = props.Color or Theme.Colors.Primary
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
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35),
		ZIndex = holder.ZIndex,
		Parent = holder,
	}, { Theme.corner(props.Radius or 14) })
	local button = Theme.new("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Font = Theme.Fonts.Title,
		Text = props.Text or "",
		TextColor3 = props.TextColor or Color3.new(1, 1, 1),
		TextScaled = true,
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	}, {
		Theme.corner(props.Radius or 14),
		Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
		Theme.new("UIPadding", {
			PaddingTop = UDim.new(0.18, 0),
			PaddingBottom = UDim.new(0.18, 0),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Theme.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28 }),
	})
	Theme.textStroke(color:Lerp(Color3.new(0, 0, 0), 0.45), 1.5).Parent = button

	local enabled = true
	button.MouseButton1Down:Connect(function()
		if enabled then
			button.Position = UDim2.fromOffset(0, 3)
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
		button.BackgroundColor3 = newColor
		shadow.BackgroundColor3 = newColor:Lerp(Color3.new(0, 0, 0), 0.35)
	end
	function api.SetEnabled(value)
		enabled = value
		button.Active = value
		button.AutoButtonColor = false
		api.SetColor(value and color or Color3.fromRGB(190, 184, 200))
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
