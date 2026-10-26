-- Pantalla de carga: se muestra mientras se construye tu galería.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local function new(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local gui = new("ScreenGui", {
	Name = "Loading",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 100,
}, player:WaitForChild("PlayerGui"))

local background = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, gui)
new("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(30, 35, 46), Color3.fromRGB(20, 24, 32)),
	Rotation = 90,
}, background)

local center = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.fromOffset(560, 300),
	BackgroundTransparency = 1,
}, background)
new("UIAspectRatioConstraint", { AspectRatio = 560 / 300 }, center)
new("UISizeConstraint", { MaxSize = Vector2.new(560, 300) }, center)

local icon = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(0.25, 0.36),
	BackgroundTransparency = 1,
	Font = Enum.Font.BuilderSansBold,
	Text = "🎨",
	TextScaled = true,
}, center)

new("TextLabel", {
	Position = UDim2.fromScale(0, 0.38),
	Size = UDim2.fromScale(1, 0.24),
	BackgroundTransparency = 1,
	Font = Enum.Font.BuilderSansExtraBold,
	Text = "Galería Pincelada",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
}, center)

new("TextLabel", {
	Position = UDim2.fromScale(0, 0.63),
	Size = UDim2.fromScale(1, 0.1),
	BackgroundTransparency = 1,
	Font = Enum.Font.BuilderSansMedium,
	Text = "Pinta · Colecciona colores · Vende tus obras",
	TextColor3 = Color3.fromRGB(170, 178, 192),
	TextScaled = true,
}, center)

local track = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.82),
	Size = UDim2.fromScale(0.7, 0.05),
	BackgroundColor3 = Color3.fromRGB(60, 68, 84),
}, center)
new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, track)
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(64, 128, 248) }, track)
new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)

local status = new("TextLabel", {
	Position = UDim2.fromScale(0, 0.9),
	Size = UDim2.fromScale(1, 0.08),
	BackgroundTransparency = 1,
	Font = Enum.Font.BuilderSansMedium,
	Text = "Preparando tu galería…",
	TextColor3 = Color3.fromRGB(170, 178, 192),
	TextScaled = true,
}, center)

-- Animación de los botes de pintura.
local dotColors = {
	Color3.fromRGB(255, 90, 110),
	Color3.fromRGB(255, 190, 60),
	Color3.fromRGB(110, 220, 120),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(190, 120, 255),
}
local dots = {}
for i, color in ipairs(dotColors) do
	local dot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, (i - 3) * 34, 0.86, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = color,
	}, background)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, dot)
	dots[i] = dot
end
local animation = RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for i, dot in ipairs(dots) do
		dot.Position = UDim2.new(0.5, (i - 3) * 34, 0.86, -math.abs(math.sin(t * 5 + i * 0.6)) * 18)
	end
	icon.Rotation = math.sin(t * 2) * 8
end)

-- Espera a que el juego, la interfaz y tu galería estén listos.
local function myPlot()
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local started = os.clock()
local steps = {
	{
		"Cargando el juego…",
		function()
			return game:IsLoaded()
		end,
	},
	{
		"Construyendo tu galería…",
		function()
			return myPlot() ~= nil
		end,
	},
	{
		"Colgando los cuadros…",
		function()
			local plot = myPlot()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			return plot ~= nil and root ~= nil and (root.Position - plot:GetPivot().Position).Magnitude < 400
		end,
	},
	{
		"Abriendo las puertas…",
		function()
			local playerGui = player:FindFirstChild("PlayerGui")
			return playerGui ~= nil and playerGui:FindFirstChild("HUD") ~= nil
		end,
	},
}
for index, step in ipairs(steps) do
	status.Text = step[1]
	TweenService:Create(fill, TweenInfo.new(0.4), { Size = UDim2.fromScale(index / #steps, 1) }):Play()
	local stepStart = os.clock()
	while not step[2]() and os.clock() - stepStart < 25 do
		task.wait(0.1)
	end
end
-- Mínimo un momento en pantalla para que no parpadee.
while os.clock() - started < 1.2 do
	task.wait(0.1)
end

status.Text = "¡Listo!"
local fade = TweenInfo.new(0.5)
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
for _, descendant in ipairs(background:GetDescendants()) do
	if descendant:IsA("TextLabel") then
		TweenService:Create(descendant, fade, { TextTransparency = 1 }):Play()
	elseif descendant:IsA("Frame") then
		TweenService:Create(descendant, fade, { BackgroundTransparency = 1 }):Play()
	elseif descendant:IsA("UIStroke") then
		TweenService:Create(descendant, fade, { Transparency = 1 }):Play()
	end
end
task.wait(0.55)
animation:Disconnect()
gui:Destroy()
