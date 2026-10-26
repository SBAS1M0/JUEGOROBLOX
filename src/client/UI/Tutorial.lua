-- Marcas del tutorial en el mundo: resalta el objeto del paso actual y pone
-- una flecha flotante encima.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)

local Tutorial = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local app
local highlight
local arrow
local arrowLabel
local currentTarget

local function findTarget(name)
	local plotName = app.state and app.state.plotName or ""
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and plotName ~= "" and plots:FindFirstChild(plotName)
	if not plot then
		return nil, nil
	end
	local workshop = plot:FindFirstChild("Workshop")
	if name == "machine" then
		local machine = workshop and workshop:FindFirstChild("Machine")
		return machine, machine and machine:FindFirstChild("Top")
	elseif name == "easel" then
		local easel = workshop and workshop:FindFirstChild("Easel")
		return easel, easel and easel:FindFirstChild("Canvas")
	elseif name == "gallery" then
		local gallery = plot:FindFirstChild("Gallery")
		local frame = gallery and gallery:FindFirstChild("Frame1")
		return frame, frame and frame:FindFirstChild("Canvas")
	end
	return nil, nil
end

function Tutorial.update()
	local state = app.state
	local step = state and state.tutorial or 0
	local def = Config.Tutorial[step]
	local targetName = def and def.target or nil
	local model, anchor = nil, nil
	if targetName and not app.isBusy() then
		model, anchor = findTarget(targetName)
	end
	if model ~= currentTarget then
		currentTarget = model
		highlight.Adornee = model
		highlight.Parent = model
		highlight.Enabled = model ~= nil
	end
	arrow.Adornee = anchor
	arrow.Enabled = anchor ~= nil
	if def then
		arrowLabel.Text = step == 1 and "¡Tira aquí!" or (step == 2 and "¡Pinta aquí!" or "¡Aquí!")
	end
end

function Tutorial.init(appRef)
	app = appRef
	highlight = Instance.new("Highlight")
	highlight.Name = "TutorialHighlight"
	highlight.FillColor = C.Primary
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = C.White
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false

	arrow = Theme.new("BillboardGui", {
		Name = "TutorialArrow",
		Size = UDim2.fromOffset(170, 110),
		StudsOffset = Vector3.new(0, 3, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local bubble = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(150, 38),
		BackgroundColor3 = C.Primary,
		Parent = arrow,
	}, { Theme.round(), Theme.stroke(C.White, 2) })
	arrowLabel = Theme.label({
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.White,
		MaxTextSize = 18,
		Parent = bubble,
	})
	local pointer = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(60, 60),
		Text = "⬇",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.Primary,
		MaxTextSize = 46,
		Parent = arrow,
	})
	Theme.textStroke(C.White, 2).Parent = pointer

	-- La flecha flota arriba y abajo.
	RunService.RenderStepped:Connect(function()
		if arrow.Enabled then
			arrow.StudsOffset = Vector3.new(0, 3 + math.sin(os.clock() * 4) * 0.6, 0)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			Tutorial.update()
		end
	end)
end

return Tutorial
