-- Parte visual del mundo que se dibuja en el cliente:
-- cuadros de la galería y los globos de pedido sobre cada cliente.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Scoring = require(Shared.Scoring)
local Templates = require(Shared.Templates)

local UI = script.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local PixelArt = require(UI.PixelArt)

local World = {}

local C = Theme.Colors

-- Cuadros ------------------------------------------------------------------------------
local function setupCanvas(canvas)
	if canvas:FindFirstChild("ArtGui") then
		return
	end
	local gui = Theme.new("SurfaceGui", {
		Name = "ArtGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(256, 256),
		LightInfluence = 0.4,
		Brightness = 1.2,
		Parent = canvas,
	})
	local art = Theme.new("Frame", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.EmptyColor,
		BorderSizePixel = 0,
		Parent = gui,
	})
	local placeholder = Theme.label({
		Name = "Placeholder",
		Size = UDim2.fromScale(0.8, 0.5),
		Position = UDim2.fromScale(0.1, 0.25),
		Text = "🖌️\nPróximamente",
		TextColor3 = Color3.fromRGB(190, 180, 205),
		MaxTextSize = 60,
		Parent = art,
	})
	local function refresh()
		local cells = canvas:GetAttribute("Cells")
		local valid = type(cells) == "string" and #cells == Config.CELLS
		placeholder.Visible = not valid
		PixelArt.render(art, valid and cells or nil)
	end
	canvas:GetAttributeChangedSignal("Cells"):Connect(refresh)
	refresh()
end

-- Globos de pedido ---------------------------------------------------------------------
local function orderPreview(model)
	local template = Templates.get(model:GetAttribute("TemplateId"))
	if not template then
		return nil, nil
	end
	local order = {
		mode = model:GetAttribute("Mode"),
		swapFrom = model:GetAttribute("SwapFrom"),
		swapTo = model:GetAttribute("SwapTo"),
		theme = model:GetAttribute("Theme"),
	}
	return template, Scoring.targetString(order, template) or Scoring.blankCanvas(template)
end

function World.orderPreview(model)
	return orderPreview(model)
end

local function patienceColor(fraction)
	if fraction > 0.5 then
		return C.Green:Lerp(C.Gold, (1 - fraction) * 2)
	end
	return C.Gold:Lerp(C.Red, 1 - fraction * 2)
end
World.patienceColor = patienceColor

local function setupCustomer(model)
	local root = model:WaitForChild("Root", 5)
	if not root or root:FindFirstChild("OrderBubble") then
		return
	end
	local isMine = model:GetAttribute("Owner") == game:GetService("Players").LocalPlayer.UserId
	if not isMine then
		-- Solo el dueño de la galería ve el aviso para atender a sus clientes.
		local prompt = root:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.MaxActivationDistance = 0
		end
	end
	local _, preview = orderPreview(model)
	local mode = Config.Modes[model:GetAttribute("Mode")] or Config.Modes.original
	local vip = model:GetAttribute("VIP")

	local billboard = Theme.new("BillboardGui", {
		Name = "OrderBubble",
		Size = UDim2.new(5.2, 0, 6.4, 0),
		StudsOffset = Vector3.new(0, 7.6, 0),
		MaxDistance = isMine and 90 or 45,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = root,
	})

	local bubble = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 0.86),
		BackgroundColor3 = vip and Color3.fromRGB(255, 246, 214) or C.Panel,
		Parent = billboard,
	}, {
		Theme.corner(16),
		Theme.stroke(vip and C.Gold or mode.color, 3),
	})
	Theme.new("Frame", {
		Size = UDim2.fromScale(0.16, 0.12),
		Position = UDim2.fromScale(0.42, 0.93),
		Rotation = 45,
		BackgroundColor3 = bubble.BackgroundColor3,
		BorderSizePixel = 0,
		Parent = billboard,
	})

	local nameLabel = Theme.label({
		Size = UDim2.fromScale(0.92, 0.13),
		Position = UDim2.fromScale(0.04, 0.03),
		Text = (vip and "👑 " or "") .. tostring(model:GetAttribute("CustomerName")),
		TextColor3 = vip and C.GoldDark or C.Ink,
		Parent = bubble,
	})

	local thumb = Theme.new("Frame", {
		Size = UDim2.fromScale(0.62, 0.5),
		Position = UDim2.fromScale(0.19, 0.18),
		BackgroundColor3 = Palette.EmptyColor,
		Parent = bubble,
	}, {
		Theme.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Theme.stroke(C.Ink, 2, 0.6),
	})
	if preview then
		PixelArt.render(thumb, preview)
	end
	Theme.label({
		Size = UDim2.fromScale(0.3, 0.3),
		Position = UDim2.fromScale(0.82, -0.08),
		Text = mode.icon,
		Parent = thumb,
	})

	local rewardLabel = Theme.label({
		Size = UDim2.fromScale(0.92, 0.13),
		Position = UDim2.fromScale(0.04, 0.69),
		Text = "💰 " .. Theme.formatNumber(model:GetAttribute("Reward")),
		TextColor3 = C.GoldDark,
		Parent = bubble,
	})

	local barBack = Theme.new("Frame", {
		Size = UDim2.fromScale(0.84, 0.07),
		Position = UDim2.fromScale(0.08, 0.86),
		BackgroundColor3 = Color3.fromRGB(230, 224, 240),
		Parent = bubble,
	}, { Theme.corner(8) })
	local bar = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Green,
		Parent = barBack,
	}, { Theme.corner(8) })

	local reaction = Theme.label({
		Name = "Reaction",
		Size = UDim2.fromScale(0.92, 0.6),
		Position = UDim2.fromScale(0.04, 0.2),
		Text = "",
		Visible = false,
		Font = Theme.Fonts.Title,
		Parent = bubble,
	})

	local function refresh()
		local state = model:GetAttribute("State")
		local reactionText = model:GetAttribute("Reaction") or ""
		local leaving = state == "leaving" and reactionText ~= ""
		reaction.Visible = leaving
		reaction.Text = reactionText
		thumb.Visible = not leaving
		rewardLabel.Visible = not leaving
		barBack.Visible = state == "waiting"
		nameLabel.Visible = true
		if state == "leaving" and reactionText == "" then
			billboard.Enabled = false
		end
		local max = model:GetAttribute("MaxPatience") or 1
		local fraction = math.clamp((model:GetAttribute("Patience") or 0) / math.max(max, 1), 0, 1)
		bar.Size = UDim2.fromScale(fraction, 1)
		bar.BackgroundColor3 = patienceColor(fraction)
		if model:GetAttribute("Painting") and state == "waiting" then
			rewardLabel.Text = "🎨 Pintando..."
		else
			rewardLabel.Text = "💰 " .. Theme.formatNumber(model:GetAttribute("Reward"))
		end
	end

	model.AttributeChanged:Connect(refresh)
	refresh()
	Theme.pop(bubble, 0.3)
end

local function watchPlot(plot)
	local gallery = plot:WaitForChild("Gallery", 10)
	if gallery then
		for _, descendant in ipairs(gallery:GetDescendants()) do
			if descendant.Name == "Canvas" and descendant:IsA("BasePart") then
				setupCanvas(descendant)
			end
		end
		gallery.DescendantAdded:Connect(function(descendant)
			if descendant.Name == "Canvas" and descendant:IsA("BasePart") then
				setupCanvas(descendant)
			end
		end)
	end
	local shop = plot:WaitForChild("Shop", 10)
	local easel = shop and shop:WaitForChild("Easel", 10)
	local easelCanvas = easel and easel:WaitForChild("Canvas", 10)
	if easelCanvas then
		setupCanvas(easelCanvas)
	end
	local customers = plot:WaitForChild("Customers", 10)
	if customers then
		for _, model in ipairs(customers:GetChildren()) do
			task.spawn(setupCustomer, model)
		end
		customers.ChildAdded:Connect(function(model)
			task.spawn(setupCustomer, model)
		end)
	end
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
