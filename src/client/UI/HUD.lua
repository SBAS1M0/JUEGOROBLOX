-- Interfaz principal: monedas, galería, botones laterales, avisos y confeti.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local HUD = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local app
local gui
local refs = {}
local shownCoins = nil
local toastHolder
local confettiHolder

local KIND_COLORS = {
	info = C.Mint,
	success = C.Green,
	error = C.Red,
	gold = C.Gold,
}
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(255, 210, 80),
	Color3.fromRGB(110, 210, 255),
	Color3.fromRGB(150, 120, 255),
	Color3.fromRGB(100, 220, 160),
}

-- Avisos ------------------------------------------------------------------------------------
function HUD.notify(text, kind)
	if not toastHolder then
		return
	end
	local color = KIND_COLORS[kind] or C.Mint
	local toast = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = C.Panel,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = toastHolder,
	}, { Theme.corner(23), Theme.stroke(color, 2.5) })
	Theme.label({
		Size = UDim2.new(1, -28, 1, -10),
		Position = UDim2.fromOffset(14, 5),
		Text = text,
		MaxTextSize = 22,
		Parent = toast,
	})
	Theme.pop(toast, 0.7)
	task.delay(3.6, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
	local toasts = {}
	for _, child in ipairs(toastHolder:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
end

function HUD.celebrate()
	local random = Random.new()
	for _ = 1, 70 do
		local piece = Theme.new("Frame", {
			Size = UDim2.fromOffset(random:NextInteger(8, 14), random:NextInteger(12, 20)),
			Position = UDim2.new(random:NextNumber(0.05, 0.95), 0, -0.05, 0),
			Rotation = random:NextInteger(0, 360),
			BackgroundColor3 = CONFETTI_COLORS[random:NextInteger(1, #CONFETTI_COLORS)],
			BorderSizePixel = 0,
			Parent = confettiHolder,
		}, { Theme.corner(3) })
		local duration = random:NextNumber(1.6, 2.8)
		Theme.tween(piece, duration, {
			Position = UDim2.new(piece.Position.X.Scale + random:NextNumber(-0.15, 0.15), 0, 1.05, 0),
			Rotation = piece.Rotation + random:NextInteger(-540, 540),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

-- Barra superior --------------------------------------------------------------------------
local function pill(parent, props)
	local frame = Theme.new("Frame", {
		Name = props.Name,
		Size = props.Size,
		BackgroundColor3 = C.Panel,
		LayoutOrder = props.LayoutOrder,
		Parent = parent,
	}, { Theme.corner(22), Theme.stroke(props.Color, 2.5) })
	Theme.label({
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(6, 2),
		Text = props.Icon,
		MaxTextSize = 26,
		Parent = frame,
	})
	local label = Theme.label({
		Name = "Value",
		Size = UDim2.new(1, -56, 1, -8),
		Position = UDim2.fromOffset(46, 4),
		Text = "0",
		MaxTextSize = 28,
		Parent = frame,
	})
	return frame, label
end

local function buildTopBar()
	local bar = Theme.new("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 560, 0, 44),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local coinsFrame, coins =
		pill(bar, { Name = "Coins", Size = UDim2.new(0, 190, 1, 0), Color = C.Gold, Icon = "💵", LayoutOrder = 1 })
	refs.coins = coins
	refs.coinsFrame = coinsFrame
	local _, gallery = pill(
		bar,
		{ Name = "Gallery", Size = UDim2.new(0, 170, 1, 0), Color = C.Pink, Icon = "🖼️", LayoutOrder = 2 }
	)
	refs.gallery = gallery
	local _, sold =
		pill(bar, { Name = "Sold", Size = UDim2.new(0, 175, 1, 0), Color = C.Mint, Icon = "🏷️", LayoutOrder = 3 })
	refs.sold = sold
end

-- Botones laterales -------------------------------------------------------------------------
local function buildSideButtons()
	local holder = Theme.new("Frame", {
		Name = "SideButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 92, 0, 430),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", {
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local function sideButton(order, icon, text, color, onClick)
		local button = Theme.button({
			Size = UDim2.new(1, 0, 0, 74),
			Text = "",
			Soft = true,
			Color = color,
			LayoutOrder = order,
			Radius = 20,
			Parent = holder,
			OnClick = onClick,
		})
		Theme.label({
			Size = UDim2.new(1, 0, 0.6, 0),
			Text = icon,
			ZIndex = 4,
			MaxTextSize = 34,
			Parent = button.Button,
		})
		local caption = Theme.label({
			Size = UDim2.new(1, 0, 0.4, 0),
			Position = UDim2.fromScale(0, 0.6),
			Text = text,
			ZIndex = 4,
			MaxTextSize = 18,
			Parent = button.Button,
		})
		return button, caption
	end
	sideButton(1, "🖌️", "Pintar", C.Mint, function()
		app.openDesigns()
	end)
	sideButton(2, "📚", "Colores", C.Purple, function()
		app.openCollection()
	end)
	sideButton(3, "🛒", "Mejoras", C.Green, function()
		app.openShop()
	end)
	local daily, dailyCaption = sideButton(4, "🎁", "Regalo", C.Pink, function()
		app.claimDaily()
	end)
	refs.dailyCaption = dailyCaption
	refs.dailyBadge = Theme.new("Frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, -14, 0, -8),
		BackgroundColor3 = C.Red,
		ZIndex = 6,
		Visible = false,
		Parent = daily.Holder,
	}, { Theme.corner(11), Theme.stroke(Color3.new(1, 1, 1), 2) })
	Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 7,
		Parent = refs.dailyBadge,
	})
	sideButton(5, "🏠", "Mi taller", C.Orange, function()
		app.remotes.GoHome:FireServer()
	end)
end

-- Estado ------------------------------------------------------------------------------------
local function animateCoins(target)
	if shownCoins == nil then
		shownCoins = target
		refs.coins.Text = Theme.formatNumber(target)
		return
	end
	local start = shownCoins
	shownCoins = target
	if start == target then
		return
	end
	if target > start then
		Theme.pop(refs.coinsFrame, 0.85)
	end
	task.spawn(function()
		local duration = 0.6
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			if shownCoins ~= target then
				return
			end
			refs.coins.Text = Theme.formatNumber(start + (target - start) * (os.clock() - t0) / duration)
			RunService.RenderStepped:Wait()
		end
		refs.coins.Text = Theme.formatNumber(target)
	end)
end

function HUD.applyState(state)
	animateCoins(state.coins)
	refs.gallery.Text = state.displayed .. "/" .. state.slots .. " en venta"
	refs.sold.Text = Theme.formatNumber(state.sold) .. " vendidos"
	refs.dailyBadge.Visible = state.dailyReady
	refs.dailyCaption.Text = state.dailyReady and "¡Regalo!" or Theme.formatTime(state.dailyWait)
	if state.painting then
		refs.hint.Text = "🎨 Tienes un cuadro a medio pintar: pulsa «Pintar» para seguir"
	elseif state.displayed >= state.slots then
		refs.hint.Text = "🖼️ Galería llena: espera a los visitantes o compra «Más paredes»"
	elseif state.sold == 0 and state.displayed == 0 then
		refs.hint.Text = "👉 Ve a la mesa de dibujo de tu taller o pulsa «Pintar»"
	else
		refs.hint.Text = ""
	end
end

function HUD.setVisible(visible)
	gui.Enabled = visible
end

function HUD.init(appRef)
	app = appRef
	gui = Theme.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildTopBar()
	buildSideButtons()
	refs.hint = Theme.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0, 560, 0, 30),
		Text = "",
		TextColor3 = C.Ink,
		MaxTextSize = 24,
		Parent = gui,
	})
	Theme.textStroke(Color3.new(1, 1, 1), 2.5).Parent = refs.hint

	local overlay = Theme.new("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	toastHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.new(0, 460, 0, 260),
		BackgroundTransparency = 1,
		Parent = overlay,
	}, {
		Theme.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	confettiHolder = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = overlay,
	})

	-- Escala en pantallas pequeñas.
	local scaled = { gui.TopBar, gui.SideButtons, toastHolder }
	local function updateScale()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1)
		for _, frame in ipairs(scaled) do
			local uiScale = frame:FindFirstChild("ViewportScale")
				or Theme.new("UIScale", { Name = "ViewportScale", Parent = frame })
			uiScale.Scale = scale
		end
	end
	updateScale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return HUD
