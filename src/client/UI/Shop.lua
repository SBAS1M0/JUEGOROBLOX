-- Tienda de mejoras de la galería y del taller.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)

local Shop = {}

local C = Theme.Colors

local app
local window
local cards = {}
local busy = false

-- Texto con el efecto actual y el siguiente de cada mejora.
local function effectText(id, level)
	local levels = { [id] = level }
	local nextLevels = { [id] = level + 1 }
	if id == "precio" or id == "decoracion" then
		return string.format("Valor x%.2f → x%.2f", Config.payMultiplier(levels), Config.payMultiplier(nextLevels))
	elseif id == "suerte" then
		local now = Colors.chances(Config.luck(levels))
		local after = Colors.chances(Config.luck(nextLevels))
		local rare = function(chances)
			return (chances.raro + chances.epico + chances.legendario + chances.mitico) * 100
		end
		return string.format("Raro o mejor: %.1f%% → %.1f%%", rare(now), rare(after))
	elseif id == "velocidad" then
		return string.format(
			"Un color cada %.1fs → %.1fs",
			Config.rollInterval(levels),
			Config.rollInterval(nextLevels)
		)
	elseif id == "pincel" then
		return string.format("Velocidad x%.1f → x%.1f", Config.brushSpeed(levels), Config.brushSpeed(nextLevels))
	elseif id == "cubeta" then
		return "Toca una figura y se rellena entera"
	elseif id == "fama" then
		return string.format(
			"Visitante cada %.0fs → %.0fs",
			Config.buyerInterval(levels),
			Config.buyerInterval(nextLevels)
		)
	elseif id == "paredes" then
		return string.format("Cuadros en venta %d → %d", Config.gallerySlots(levels), Config.gallerySlots(nextLevels))
	end
	return ""
end

local function buildCard(upgrade, order, parent)
	local card = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = C.Panel,
		LayoutOrder = order,
		Parent = parent,
	}, { Theme.corner(18), Theme.stroke(Color3.fromRGB(240, 230, 220), 2.5) })
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
		TextColor3 = C.PrimaryDark,
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
		Color = C.Mint,
		Soft = true,
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
	if not (state and window) then
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
	if window then
		window.Subtitle.Text = "Tienes 💵 " .. Theme.formatNumber(state.coins)
	end
end

function Shop.open()
	window.Open()
	Shop.refresh()
end

function Shop.close()
	window.Close()
end

function Shop.init(appRef)
	app = appRef
	local gui = Theme.new("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		DisplayOrder = 14,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	window = Theme.window({
		Name = "Window",
		Parent = gui,
		Size = UDim2.fromOffset(760, 620),
		Title = "🛒 Mejoras",
	})
	local list = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(24, 100),
		Size = UDim2.new(1, -48, 1, -120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.InkSoft,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window.Panel,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", {
			PaddingRight = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 3),
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 8),
		}),
	})
	for order, upgrade in ipairs(Config.Upgrades) do
		buildCard(upgrade, order, list)
	end
end

return Shop
