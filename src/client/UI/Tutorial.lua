-- Tutorial guiado: un panel con la guía (paso, instrucción, progreso y botón
-- para saltarlo) y, en el mundo, un camino luminoso desde tu personaje hasta
-- el objetivo, que además se resalta con una flecha flotante.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)

local Tutorial = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local STEP_TITLES = {
	"La máquina de colores",
	"Tu mesa de dibujo",
	"¡A pintar!",
	"La sala de exposición",
	"Tu primera venta",
}
local ARROW_TEXT = { "¡Tira aquí!", "¡Pinta aquí!", nil, "¡Cuélgalo aquí!", "¡Tu cuadro!" }

local app
local gui
local refs = {}
local highlight
local arrow
local arrowLabel
local beam
local fromAttachment
local toAttachment
local currentTarget
local lastStep = nil

local function myPlot()
	local plotName = app.state and app.state.plotName or ""
	local plots = Workspace:FindFirstChild("Plots")
	return plots and plotName ~= "" and plots:FindFirstChild(plotName) or nil
end

-- Devuelve el modelo a resaltar y la pieza sobre la que va la flecha.
local function findTarget(name)
	local plot = myPlot()
	if not plot then
		return nil, nil
	end
	local workshop = plot:FindFirstChild("Workshop")
	local gallery = plot:FindFirstChild("Gallery")
	if name == "machine" then
		local machine = workshop and workshop:FindFirstChild("Machine")
		return machine, machine and machine:FindFirstChild("Body")
	elseif name == "easel" then
		local easel = workshop and workshop:FindFirstChild("Easel")
		return easel, easel and easel:FindFirstChild("Canvas")
	elseif name == "freeFrame" or name == "gallery" then
		if not gallery then
			return nil, nil
		end
		for i = 1, Config.GALLERY_SIZE do
			local frame = gallery:FindFirstChild("Frame" .. i)
			local canvas = frame and frame:FindFirstChild("Canvas")
			if canvas and not canvas:GetAttribute("Locked") then
				local hung = (canvas:GetAttribute("Design") or "") ~= ""
				if (name == "freeFrame" and not hung) or (name == "gallery" and hung) then
					return frame, canvas
				end
			end
		end
	end
	return nil, nil
end

local function setWorldTarget(model, anchor, text)
	if model ~= currentTarget then
		currentTarget = model
		highlight.Adornee = model
		highlight.Parent = model
		highlight.Enabled = model ~= nil
	end
	arrow.Adornee = anchor
	arrow.Enabled = anchor ~= nil
	arrowLabel.Text = text or "¡Aquí!"
	-- Camino luminoso desde los pies del personaje hasta el objetivo.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if anchor and root then
		if fromAttachment.Parent ~= root then
			fromAttachment.Parent = root
		end
		if toAttachment.Parent ~= anchor then
			toAttachment.Parent = anchor
		end
		beam.Parent = anchor
		beam.Enabled = (root.Position - anchor.Position).Magnitude > 8
	else
		beam.Enabled = false
	end
end

function Tutorial.update()
	local state = app.state
	local step = state and state.tutorial or 0
	local def = Config.Tutorial[step]
	local busy = app.isBusy()
	refs.panel.Visible = def ~= nil and not busy
	if def then
		refs.step.Text = "PASO " .. step .. " DE " .. #Config.Tutorial
		refs.title.Text = STEP_TITLES[step] or ""
		local suffix = def.goal > 1 and ("  (" .. (state.tutorialProgress or 0) .. "/" .. def.goal .. ")") or ""
		refs.text.Text = def.text .. suffix
		for i, dot in ipairs(refs.dots) do
			dot.BackgroundColor3 = i < step and C.Mint or (i == step and C.Gold or C.Border)
			dot.Size = UDim2.fromOffset(i == step and 22 or 10, 10)
		end
		if lastStep ~= step then
			lastStep = step
			Theme.popCard(refs.panel, 0.85)
			Theme.playSound("success", 1.4)
		end
	end
	local model, anchor = nil, nil
	if def and def.target and not busy then
		model, anchor = findTarget(def.target)
	end
	setWorldTarget(model, anchor, ARROW_TEXT[step])
end

function Tutorial.applyState()
	if refs.panel then
		Tutorial.update()
	end
end

local function buildPanel()
	gui = Theme.new("ScreenGui", {
		Name = "TutorialGuide",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local holder, body = Theme.card({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(500, 92),
		Radius = 22,
		Color = C.Bg,
		StrokeColor = C.Navy,
		StrokeThickness = 2.5,
		Visible = false,
		Parent = gui,
	})
	refs.panel = holder
	local avatar = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(68, 68),
		BackgroundColor3 = C.White,
		Parent = body,
	}, {
		Theme.round(),
		Theme.gradient(Theme.Gradients.primary[1], Theme.Gradients.primary[2], 90),
		Theme.stroke(C.White, 3),
	})
	Theme.label({ Size = UDim2.fromScale(1, 1), Text = "🧑‍🎨", MaxTextSize = 40, Parent = avatar })
	refs.step = Theme.label({
		Position = UDim2.fromOffset(92, 10),
		Size = UDim2.fromOffset(120, 16),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.GoldDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = body,
	})
	refs.title = Theme.label({
		Position = UDim2.fromOffset(92, 25),
		Size = UDim2.new(1, -190, 0, 24),
		Text = "",
		Font = Theme.Fonts.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 21,
		Parent = body,
	})
	refs.text = Theme.label({
		Position = UDim2.fromOffset(92, 50),
		Size = UDim2.new(1, -104, 0, 22),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = body,
	})
	local dots = Theme.new("Frame", {
		Position = UDim2.fromOffset(92, 76),
		Size = UDim2.fromOffset(200, 10),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Theme.list("h", 5, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	refs.dots = {}
	for i = 1, #Config.Tutorial do
		refs.dots[i] = Theme.new("Frame", {
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = C.Border,
			LayoutOrder = i,
			Parent = dots,
		}, { Theme.round() })
	end
	Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(82, 32),
		Text = "Saltar",
		Variant = "ghost",
		Radius = 12,
		Depth = 3,
		MaxTextSize = 14,
		Parent = body,
		OnClick = function()
			app.remotes.SkipTutorial:FireServer()
		end,
	})
	local scale = Theme.new("UIScale", { Name = "ViewportScale", Parent = holder })
	local function updateScale()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.6, 1)
		end
	end
	updateScale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

local function buildWorldMarkers()
	highlight = Instance.new("Highlight")
	highlight.Name = "TutorialHighlight"
	highlight.FillColor = C.Gold
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = C.White
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false

	arrow = Theme.new("BillboardGui", {
		Name = "TutorialArrow",
		Size = UDim2.fromOffset(170, 110),
		StudsOffset = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local bubble = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(156, 40),
		BackgroundColor3 = C.White,
		Parent = arrow,
	}, {
		Theme.round(),
		Theme.gradient(Theme.Gradients.gold[1], Theme.Gradients.gold[2], 90),
		Theme.stroke(C.White, 2.5),
	})
	arrowLabel = Theme.label({
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		Text = "",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		MaxTextSize = 19,
		Parent = bubble,
	})
	Theme.textStroke(C.GoldDark, 1.5, 0.2).Parent = arrowLabel
	local pointer = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 42),
		Size = UDim2.fromOffset(60, 60),
		Text = "▼",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.Gold,
		MaxTextSize = 46,
		Parent = arrow,
	})
	Theme.textStroke(C.White, 3).Parent = pointer

	fromAttachment = Instance.new("Attachment")
	fromAttachment.Name = "TutorialFrom"
	fromAttachment.Position = Vector3.new(0, -2.6, 0)
	toAttachment = Instance.new("Attachment")
	toAttachment.Name = "TutorialTo"
	beam = Instance.new("Beam")
	beam.Name = "TutorialPath"
	beam.Attachment0 = fromAttachment
	beam.Attachment1 = toAttachment
	beam.Color = ColorSequence.new(C.Gold, C.Primary)
	beam.Transparency = NumberSequence.new(0.15, 0.35)
	beam.Width0 = 0.9
	beam.Width1 = 0.9
	beam.FaceCamera = true
	beam.LightEmission = 0.6
	beam.Segments = 12
	beam.Enabled = false
end

function Tutorial.init(appRef)
	app = appRef
	buildPanel()
	buildWorldMarkers()
	-- La flecha flota arriba y abajo y el camino parpadea suavemente.
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if arrow.Enabled then
			arrow.StudsOffset = Vector3.new(0, 6 + math.sin(t * 4) * 0.6, 0)
		end
		if beam.Enabled then
			local a = 0.15 + 0.2 * (0.5 + 0.5 * math.sin(t * 3))
			beam.Transparency = NumberSequence.new(a, a + 0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.4)
			Tutorial.update()
		end
	end)
end

return Tutorial
