-- Parte visual del mundo que se dibuja en el cliente: cuadros de la galería,
-- caballete del taller y globos de diálogo de los visitantes.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Designs = require(Shared.Designs)

local UI = script.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local DesignArt = require(UI.DesignArt)

local World = {}

local C = Theme.Colors
local player = Players.LocalPlayer

-- Cuadros -------------------------------------------------------------------------------
local function setupCanvas(canvas)
	if canvas:FindFirstChild("ArtGui") then
		return
	end
	local gui = Theme.new("SurfaceGui", {
		Name = "ArtGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(300, 300),
		LightInfluence = 0.35,
		Brightness = 1.15,
		Parent = canvas,
	})
	local art = Theme.new("Frame", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(252, 248, 240),
		BorderSizePixel = 0,
		Parent = gui,
	})
	local placeholder = Theme.label({
		Name = "Placeholder",
		Size = UDim2.fromScale(0.84, 0.5),
		Position = UDim2.fromScale(0.08, 0.25),
		Text = "",
		TextColor3 = Color3.fromRGB(196, 180, 170),
		MaxTextSize = 60,
		Parent = art,
	})
	local function refresh()
		local design = Designs.get(canvas:GetAttribute("Design") or "")
		if design then
			placeholder.Visible = false
			DesignArt.render(art, design, {
				mode = "color",
				colors = Designs.decodeColors(canvas:GetAttribute("Colors")),
				outlineThickness = 1.5,
			})
		else
			local old = art:FindFirstChild("Art")
			if old then
				old:Destroy()
			end
			placeholder.Visible = true
			placeholder.Text = canvas:GetAttribute("Locked") and "🔒" or "🖌️\nEspacio libre"
		end
	end
	canvas:GetAttributeChangedSignal("Design"):Connect(refresh)
	canvas:GetAttributeChangedSignal("Colors"):Connect(refresh)
	canvas:GetAttributeChangedSignal("Locked"):Connect(refresh)
	refresh()
end

-- Visitantes -----------------------------------------------------------------------------
local function setupVisitor(model)
	local head = model:WaitForChild("Head", 10)
	if not head or head:FindFirstChild("VisitorBubble") then
		return
	end
	local billboard = Theme.new("BillboardGui", {
		Name = "VisitorBubble",
		Size = UDim2.fromOffset(240, 110),
		StudsOffset = Vector3.new(0, 3.2, 0),
		MaxDistance = 70,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = head,
	})
	local bubble = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(220, 54),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = billboard,
	}, { Theme.corner(18), Theme.stroke(C.Pink, 2.5) })
	local reaction = Theme.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = "",
		MaxTextSize = 22,
		Parent = bubble,
	})
	local name = Theme.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(220, 26),
		Text = tostring(model:GetAttribute("VisitorName") or ""),
		TextColor3 = Color3.new(1, 1, 1),
		MaxTextSize = 22,
		Parent = billboard,
	})
	Theme.textStroke(C.Ink, 2).Parent = name
	local function refresh()
		local text = model:GetAttribute("Reaction") or ""
		bubble.Visible = text ~= ""
		reaction.Text = text
		bubble.Size = UDim2.fromOffset(text == "🤔" and 60 or 220, string.find(text, "\n") and 64 or 46)
		if bubble.Visible then
			Theme.pop(bubble, 0.5)
		end
	end
	model:GetAttributeChangedSignal("Reaction"):Connect(refresh)
	refresh()
end

-- Avisos solo para el dueño del taller.
local function updatePrompts(plot)
	local mine = plot:GetAttribute("OwnerUserId") == player.UserId
	local workshop = plot:FindFirstChild("Workshop")
	if not workshop then
		return
	end
	for _, descendant in ipairs(workshop:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			descendant.MaxActivationDistance = mine and 12 or 0
		end
	end
end

local function watchPlot(plot)
	local gallery = plot:WaitForChild("Gallery", 10)
	if gallery then
		for _, descendant in ipairs(gallery:GetDescendants()) do
			if descendant.Name == "Canvas" and descendant:IsA("BasePart") then
				setupCanvas(descendant)
			end
		end
	end
	local workshop = plot:WaitForChild("Workshop", 10)
	local easel = workshop and workshop:WaitForChild("Easel", 10)
	local easelCanvas = easel and easel:WaitForChild("Canvas", 10)
	if easelCanvas then
		setupCanvas(easelCanvas)
	end
	local visitors = plot:WaitForChild("Visitors", 10)
	if visitors then
		for _, model in ipairs(visitors:GetChildren()) do
			task.spawn(setupVisitor, model)
		end
		visitors.ChildAdded:Connect(function(model)
			task.spawn(setupVisitor, model)
		end)
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		updatePrompts(plot)
	end)
	updatePrompts(plot)
end

function World.start()
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in ipairs(plots:GetChildren()) do
		task.spawn(watchPlot, plot)
	end
	plots.ChildAdded:Connect(function(plot)
		task.spawn(watchPlot, plot)
	end)
end

return World
