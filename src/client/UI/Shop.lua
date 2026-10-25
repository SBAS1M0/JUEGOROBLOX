-- Tienda de mejoras de la galería.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)

local Shop = {}

local C = Theme.Colors

local app
local gui, panel
local cards = {}
local busy = false

-- Texto con el efecto actual y el siguiente de cada mejora.
local function effectText(id, level)
	local levels = { [id] = level }
	local nextLevels = { [id] = level + 1 }
	if id == "precio" or id == "decoracion" then
		return string.format("Pago x%.2f → x%.2f", Config.payMultiplier(levels), Config.payMultiplier(nextLevels))
	elseif id == "paciencia" then
		return string.format(
			"Paciencia x%.2f → x%.2f",
			Config.patienceMultiplier(levels),
			Config.patienceMultiplier(nextLevels)
		)
	elseif id == "fama" then
		return string.format(
			"Cliente cada %.1fs → %.1fs · Fila %d",
			Config.spawnInterval(levels),
			Config.spawnInterval(nextLevels),
			Config.maxQueue(nextLevels)
		)
	elseif id == "propinas" then
		return string.format("Propina x%.2f → x%.2f", Config.tipMultiplier(levels), Config.tipMultiplier(nextLevels))
	elseif id == "vip" then
		return string.format(
			"VIP %d%% → %d%%",
			math.floor(Config.vipChance(levels) * 100 + 0.5),
			math.floor(Config.vipChance(nextLevels) * 100 + 0.5)
		)
	elseif id == "pincel" then
		return level == 0 and "Desbloquea pincel 2x2" or "Desbloquea pincel 3x3"
	end
	return ""
end

local function buildCard(upgrade, order, parent)
	local card = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = C.Panel,
		LayoutOrder = order,
		Parent = parent,
	}, { Theme.corner(18), Theme.stroke(C.Ink, 2, 0.8) })
	local iconBack = Theme.new("Frame", {
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = C.PanelSoft,
		Parent = card,
	}, { Theme.corner(16) })
	Theme.label({ Size = UDim2.fromScale(1, 1), Text = upgrade.icon, MaxTextSize = 44, Parent = iconBack })

	Theme.label({
		Size = UDim2.new(1, -270, 0, 28),
		Position = UDim2.fromOffset(96, 8),
		Text = upgrade.name,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = card,
	})
	Theme.label({
		Size = UDim2.new(1, -270, 0, 20),
		Position = UDim2.fromOffset(96, 36),
		Text = upgrade.desc,
		Font = Theme.Fonts.Body,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = card,
	})
	local effect = Theme.label({
		Size = UDim2.new(1, -270, 0, 18),
		Position = UDim2.fromOffset(96, 58),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.Primary,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = card,
	})
	local dots = Theme.new("Frame", {
		Size = UDim2.new(1, -270, 0, 8),
		Position = UDim2.fromOffset(96, 80),
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		Theme.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 3),
		}),
	})
	local dotFrames = {}
	for i = 1, upgrade.max do
		dotFrames[i] = Theme.new("Frame", {
			Size = UDim2.new(1 / upgrade.max, -3, 1, 0),
			BackgroundColor3 = Color3.fromRGB(230, 224, 240),
			Parent = dots,
		}, { Theme.corner(4) })
	end

	local button = Theme.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, -2),
		Size = UDim2.fromOffset(150, 60),
		Text = "",
		Color = C.Green,
		Parent = card,
		OnClick = function()
			if busy then
				return
			end
			busy = true
			local ok, success, message = pcall(function()
				return app.remotes.BuyUpgrade:InvokeServer(upgrade.id)
			end)
			busy = false
			if ok and success then
				Theme.playSound("success", 1.2)
				app.notify("✨ " .. message, "success")
				Theme.pop(card, 0.9)
			else
				app.notify(ok and message or "No se pudo comprar.", "error")
			end
		end,
	})
	cards[upgrade.id] = { effect = effect, dots = dotFrames, button = button }
end

function Shop.refresh()
	local state = app.state
	if not (state and gui) then
		return
	end
	for _, upgrade in ipairs(Config.Upgrades) do
		local card = cards[upgrade.id]
		local level = state.upgrades[upgrade.id] or 0
		for i, dot in ipairs(card.dots) do
			dot.BackgroundColor3 = i <= level and C.Pink or Color3.fromRGB(230, 224, 240)
		end
		if level >= upgrade.max then
			card.effect.Text = "¡Nivel máximo!"
			card.button.Button.Text = "MÁX"
			card.button.SetEnabled(false)
		else
			local cost = Config.upgradeCost(upgrade.id, level)
			card.effect.Text = effectText(upgrade.id, level)
			card.button.Button.Text = "💰 " .. Theme.formatNumber(cost)
			card.button.SetEnabled(state.coins >= cost)
		end
	end
	if panel then
		panel.Header.Coins.Text = "💰 " .. Theme.formatNumber(state.coins)
	end
end

function Shop.open()
	gui.Enabled = true
	Shop.refresh()
	Theme.pop(panel, 0.8)
	Theme.playSound("whoosh", 1.1)
end

function Shop.close()
	gui.Enabled = false
end

function Shop.init(appRef)
	app = appRef
	gui = Theme.new("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local dim = Theme.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	})
	dim.Activated:Connect(Shop.close)

	panel = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.88, 0),
		BackgroundColor3 = C.Background,
		Parent = gui,
	}, {
		Theme.corner(24),
		Theme.stroke(C.Ink, 4),
		Theme.new("UISizeConstraint", { MaxSize = Vector2.new(720, 640) }),
	})
	local header = Theme.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = C.Green,
		Parent = panel,
	}, { Theme.corner(24), Theme.gradient(Color3.fromRGB(60, 210, 140), Color3.fromRGB(40, 170, 200), 0) })
	Theme.label({
		Size = UDim2.new(0.5, 0, 0, 40),
		Position = UDim2.fromOffset(20, 12),
		Text = "🛒 Mejoras de la Galería",
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 32,
		Parent = header,
	})
	local coins = Theme.label({
		Name = "Coins",
		Size = UDim2.new(0.3, 0, 0, 34),
		Position = UDim2.new(0.58, 0, 0, 15),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		MaxTextSize = 28,
		Parent = header,
	})
	Theme.textStroke(C.GreenDark, 2).Parent = coins
	Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		Text = "✕",
		Color = C.Red,
		Parent = header,
		OnClick = Shop.close,
	})

	local list = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 78),
		Size = UDim2.new(1, -32, 1, -92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Primary,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new(
			"UIPadding",
			{ PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8) }
		),
	})
	for order, upgrade in ipairs(Config.Upgrades) do
		buildCard(upgrade, order, list)
	end
end

return Shop
