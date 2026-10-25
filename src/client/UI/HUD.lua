-- Interfaz principal: monedas, nivel, racha, lista de pedidos, botones y avisos.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Templates = require(Shared.Templates)

local Theme = require(script.Parent.Theme)
local PixelArt = require(script.Parent.PixelArt)

local HUD = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local app
local gui
local refs = {}
local cards = {}
local shownCoins = nil

-- Avisos tipo "toast" --------------------------------------------------------------
local toastHolder
local KIND_COLORS = {
	info = C.Primary,
	success = C.Green,
	error = C.Red,
	gold = C.GoldDark,
}

function HUD.notify(text, kind)
	if not toastHolder then
		return
	end
	local color = KIND_COLORS[kind] or C.Primary
	local toast = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = C.Panel,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = toastHolder,
	}, {
		Theme.corner(14),
		Theme.stroke(color, 3),
	})
	Theme.new("Frame", {
		Size = UDim2.new(0, 8, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = color,
		Parent = toast,
	}, { Theme.corner(4) })
	Theme.label({
		Size = UDim2.new(1, -30, 1, -12),
		Position = UDim2.fromOffset(22, 6),
		Text = text,
		Font = Theme.Fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = toast,
	})
	Theme.pop(toast, 0.7)
	if kind == "error" then
		Theme.playSound("click", 0.6)
	end
	task.delay(3.5, function()
		if toast.Parent then
			Theme.tween(toast, 0.3, { BackgroundTransparency = 1 })
			for _, d in ipairs(toast:GetDescendants()) do
				if d:IsA("TextLabel") then
					Theme.tween(d, 0.3, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					Theme.tween(d, 0.3, { Transparency = 1 })
				elseif d:IsA("Frame") then
					Theme.tween(d, 0.3, { BackgroundTransparency = 1 })
				end
			end
			task.wait(0.35)
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

-- Barra superior ---------------------------------------------------------------------
local function pill(parent, props)
	local frame = Theme.new("Frame", {
		Name = props.Name,
		Size = props.Size,
		BackgroundColor3 = C.Panel,
		LayoutOrder = props.LayoutOrder,
		Parent = parent,
	}, {
		Theme.corner(22),
		Theme.stroke(props.Color, 3),
	})
	local icon = Theme.new("Frame", {
		Size = UDim2.new(0, 44, 0, 44),
		Position = UDim2.new(0, -6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = props.Color,
		ZIndex = 2,
		Parent = frame,
	}, { Theme.corner(22), Theme.stroke(Color3.new(1, 1, 1), 3) })
	Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = props.Icon,
		ZIndex = 3,
		MaxTextSize = 26,
		Parent = icon,
	})
	local label = Theme.label({
		Name = "Value",
		Size = UDim2.new(1, -50, 1, -10),
		Position = UDim2.fromOffset(44, 5),
		Text = "0",
		TextColor3 = C.Ink,
		MaxTextSize = 26,
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
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local coinsFrame, coinsLabel =
		pill(bar, { Name = "Coins", Size = UDim2.new(0, 180, 1, 0), Color = C.Gold, Icon = "💰", LayoutOrder = 1 })
	refs.coins = coinsLabel
	refs.coinsFrame = coinsFrame

	local levelFrame, levelLabel =
		pill(bar, { Name = "Level", Size = UDim2.new(0, 210, 1, 0), Color = C.Primary, Icon = "⭐", LayoutOrder = 2 })
	refs.level = levelLabel
	levelLabel.Size = UDim2.new(1, -54, 0.55, -2)
	levelLabel.Position = UDim2.fromOffset(46, 3)
	local xpBack = Theme.new("Frame", {
		Size = UDim2.new(1, -60, 0.28, 0),
		Position = UDim2.new(0, 46, 0.62, 0),
		BackgroundColor3 = Color3.fromRGB(232, 226, 246),
		Parent = levelFrame,
	}, { Theme.corner(6) })
	refs.xpFill = Theme.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Primary,
		Parent = xpBack,
	}, { Theme.corner(6), Theme.gradient(Color3.fromRGB(150, 120, 255), Color3.fromRGB(255, 120, 190), 0) })

	local streakFrame, streakLabel =
		pill(bar, { Name = "Streak", Size = UDim2.new(0, 120, 1, 0), Color = C.Orange, Icon = "🔥", LayoutOrder = 3 })
	refs.streak = streakLabel
	refs.streakFrame = streakFrame
end

-- Botones laterales -------------------------------------------------------------------
local function buildSideButtons()
	local holder = Theme.new("Frame", {
		Name = "SideButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 96, 0, 330),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", {
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local function sideButton(order, icon, text, color, onClick)
		local button = Theme.button({
			Size = UDim2.new(1, 0, 0, 70),
			Text = "",
			Color = color,
			LayoutOrder = order,
			Radius = 18,
			Parent = holder,
			OnClick = onClick,
		})
		Theme.label({
			Size = UDim2.new(1, 0, 0.62, 0),
			Text = icon,
			ZIndex = 4,
			MaxTextSize = 34,
			Parent = button.Button,
		})
		local caption = Theme.label({
			Size = UDim2.new(1, 0, 0.38, 0),
			Position = UDim2.fromScale(0, 0.62),
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 4,
			MaxTextSize = 16,
			Parent = button.Button,
		})
		Theme.textStroke(color:Lerp(Color3.new(0, 0, 0), 0.4), 1.5).Parent = caption
		return button, caption
	end
	refs.shopButton = sideButton(1, "🛒", "Mejoras", C.Green, function()
		app.openShop()
	end)
	local daily, dailyCaption = sideButton(2, "🎁", "Regalo", C.Pink, function()
		app.claimDaily()
	end)
	refs.dailyButton = daily
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

	sideButton(3, "🏠", "Mi galería", C.Orange, function()
		app.remotes.GoHome:FireServer()
	end)
	sideButton(4, "❓", "Ayuda", C.Primary, function()
		app.showHelp()
	end)
end

-- Lista de pedidos -----------------------------------------------------------------------
local function myCustomersFolder()
	local index = app.state and app.state.plotIndex or 0
	if index == 0 then
		return nil
	end
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. index)
	return plot and plot:FindFirstChild("Customers")
end

local function createCard(model)
	local template, preview = app.orderPreview(model)
	if not template then
		return nil
	end
	local mode = Config.Modes[model:GetAttribute("Mode")] or Config.Modes.original
	local vip = model:GetAttribute("VIP")
	local card = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = vip and Color3.fromRGB(255, 247, 220) or C.Panel,
		Parent = refs.orderList,
	}, {
		Theme.corner(16),
		Theme.stroke(vip and C.Gold or mode.color, 3),
	})
	local thumb = Theme.new("Frame", {
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = card,
	}, { Theme.corner(8), Theme.stroke(C.Ink, 2, 0.7) })
	PixelArt.render(thumb, preview)
	Theme.label({
		Size = UDim2.new(1, -170, 0, 24),
		Position = UDim2.fromOffset(92, 8),
		Text = (vip and "👑 " or "") .. tostring(model:GetAttribute("CustomerName")),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = card,
	})
	Theme.label({
		Size = UDim2.new(1, -170, 0, 20),
		Position = UDim2.fromOffset(92, 32),
		Text = mode.icon .. " " .. mode.name .. " · " .. template.name,
		Font = Theme.Fonts.Bold,
		TextColor3 = mode.color,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = card,
	})
	Theme.label({
		Size = UDim2.new(1, -170, 0, 18),
		Position = UDim2.fromOffset(92, 52),
		Text = "💰 " .. Theme.formatNumber(model:GetAttribute("Reward")),
		Font = Theme.Fonts.Bold,
		TextColor3 = C.GoldDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = card,
	})
	local barBack = Theme.new("Frame", {
		Size = UDim2.new(1, -176, 0, 8),
		Position = UDim2.fromOffset(92, 74),
		BackgroundColor3 = Color3.fromRGB(232, 226, 246),
		Parent = card,
	}, { Theme.corner(4) })
	local bar = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Green,
		Parent = barBack,
	}, { Theme.corner(4) })
	local button = Theme.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, -2),
		Size = UDim2.fromOffset(72, 56),
		Text = "🎨\nPintar",
		Color = C.Pink,
		MaxTextSize = 18,
		Parent = card,
		OnClick = function()
			app.openStudio(model)
		end,
	})
	Theme.pop(card, 0.6)
	return { frame = card, bar = bar, model = model, button = button }
end

local function updateOrders()
	local folder = myCustomersFolder()
	local alive = {}
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:GetAttribute("State") == "waiting" then
				alive[model] = true
				if not cards[model] then
					cards[model] = createCard(model)
				end
			end
		end
	end
	local list = {}
	for model, card in pairs(cards) do
		if not alive[model] or not card then
			if card then
				card.frame:Destroy()
			end
			cards[model] = nil
		else
			local max = model:GetAttribute("MaxPatience") or 1
			local fraction = math.clamp((model:GetAttribute("Patience") or 0) / math.max(max, 1), 0, 1)
			card.bar.Size = UDim2.fromScale(fraction, 1)
			card.bar.BackgroundColor3 = app.patienceColor(fraction)
			card.fraction = fraction
			table.insert(list, card)
		end
	end
	table.sort(list, function(a, b)
		return a.fraction < b.fraction
	end)
	for order, card in ipairs(list) do
		card.frame.LayoutOrder = order
	end
	refs.emptyOrders.Visible = #list == 0
	refs.ordersTitle.Text = "📋 Pedidos (" .. #list .. ")"
end

local function buildOrders()
	local panel = Theme.new("Frame", {
		Name = "Orders",
		Position = UDim2.new(0, 12, 0, 70),
		Size = UDim2.new(0, 320, 1, -150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.new("UISizeConstraint", { MaxSize = Vector2.new(320, 520) }) })
	local title = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = C.Primary,
		Parent = panel,
	}, {
		Theme.corner(14),
		Theme.gradient(Color3.fromRGB(150, 120, 255), Color3.fromRGB(255, 120, 190), 0),
		Theme.stroke(Color3.new(1, 1, 1), 3),
	})
	refs.ordersTitle = Theme.label({
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Text = "📋 Pedidos",
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = title,
	})
	Theme.textStroke(C.PrimaryDark, 2).Parent = refs.ordersTitle

	refs.orderList = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Primary,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new(
			"UIPadding",
			{ PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }
		),
	})
	refs.emptyOrders = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		LayoutOrder = 999,
		Parent = refs.orderList,
	}, { Theme.corner(16), Theme.padding(10) })
	Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "Esperando clientes... ☕\n¡Ya vienen en camino!",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 18,
		Parent = refs.emptyOrders,
	})
end

-- Estado ----------------------------------------------------------------------------------
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
			local alpha = (os.clock() - t0) / duration
			refs.coins.Text = Theme.formatNumber(start + (target - start) * alpha)
			RunService.RenderStepped:Wait()
		end
		refs.coins.Text = Theme.formatNumber(target)
	end)
end

function HUD.applyState(state)
	animateCoins(state.coins)
	refs.level.Text = "Nivel " .. state.level
	refs.xpFill.Size = UDim2.fromScale(math.clamp(state.xp / math.max(state.xpNext, 1), 0, 1), 1)
	refs.streak.Text = "x" .. state.streak
	refs.streakFrame.Visible = state.streak > 0
	refs.dailyBadge.Visible = state.dailyReady
	refs.dailyCaption.Text = state.dailyReady and "¡Regalo!" or Theme.formatTime(state.dailyWait)
	local nextTemplate = Templates.nextUnlock(state.level)
	refs.nextUnlock.Text = nextTemplate and ("🔓 Nivel " .. nextTemplate.level .. ": " .. nextTemplate.name)
		or "🏆 ¡Todas las obras desbloqueadas!"
end

function HUD.init(appRef)
	app = appRef
	gui = Theme.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildTopBar()
	buildSideButtons()
	buildOrders()

	refs.nextUnlock = Theme.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0, 420, 0, 30),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		MaxTextSize = 22,
		Parent = gui,
	})
	Theme.textStroke(C.Ink, 2.5).Parent = refs.nextUnlock

	local notifyGui = Theme.new("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	toastHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.new(0, 420, 0, 260),
		BackgroundTransparency = 1,
		Parent = notifyGui,
	}, {
		Theme.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	-- Escala la interfaz en pantallas pequeñas (móviles).
	local scaled = { gui.TopBar, gui.SideButtons, gui.Orders, toastHolder }
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
		-- La lista de pedidos ocupa el alto disponible aunque esté escalada.
		gui.Orders.Size = UDim2.new(0, 320, 1 / scale, -150 / scale)
	end
	updateScale()
	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end
	bindCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

	task.spawn(function()
		while true do
			pcall(updateOrders)
			task.wait(0.2)
		end
	end)
end

function HUD.setVisible(visible)
	if gui then
		gui.Enabled = visible
	end
end

return HUD
