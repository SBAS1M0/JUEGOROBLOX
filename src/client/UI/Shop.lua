-- Tienda de mejoras del taller y la galería, agrupadas por secciones.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)

local Shop = {}

local C = Theme.Colors

local SECTIONS = {
	{ name = "Máquina de colores", ids = { "suerte", "velocidad", "auto" } },
	{ name = "Pintura", ids = { "pincel", "cubeta" } },
	{ name = "Galería", ids = { "precio", "fama", "paredes", "decoracion" } },
}

local app
local window
local cards = {}
local busy = false

-- Efecto actual → siguiente de cada mejora.
local function effectText(id, level)
	local levels = { [id] = level }
	local nextLevels = { [id] = level + 1 }
	if id == "precio" or id == "decoracion" then
		return string.format("Valor x%.2f → x%.2f", Config.payMultiplier(levels), Config.payMultiplier(nextLevels))
	elseif id == "suerte" then
		local function rare(chances)
			return (chances.raro + chances.epico + chances.legendario + chances.mitico) * 100
		end
		return string.format(
			"Raro o mejor %.1f%% → %.1f%%",
			rare(Colors.chances(Config.luck(levels))),
			rare(Colors.chances(Config.luck(nextLevels)))
		)
	elseif id == "velocidad" then
		return string.format("Recarga %.1fs → %.1fs", Config.rollInterval(levels), Config.rollInterval(nextLevels))
	elseif id == "auto" then
		return "Tira sola cada " .. string.format("%.1f", Config.autoRollInterval({})) .. "s"
	elseif id == "pincel" then
		local base = Config.brushRadius({})
		return string.format(
			"Grosor %d%% → %d%%",
			math.floor(Config.brushRadius(levels) / base * 100 + 0.5),
			math.floor(Config.brushRadius(nextLevels) / base * 100 + 0.5)
		)
	elseif id == "cubeta" then
		return "Un toque rellena una figura"
	elseif id == "fama" then
		return string.format(
			"Visitas cada %.0fs → %.0fs · VIP %d%%",
			Config.buyerInterval(levels),
			Config.buyerInterval(nextLevels),
			math.floor(Config.vipChance(nextLevels) * 100 + 0.5)
		)
	elseif id == "paredes" then
		return string.format("Cuadros en venta %d → %d", Config.gallerySlots(levels), Config.gallerySlots(nextLevels))
	end
	return ""
end

local function buildCard(upgrade, order, parent)
	local _, body = Theme.card({
		Name = upgrade.id,
		Size = UDim2.fromOffset(372, 132),
		Radius = 14,
		LayoutOrder = order,
		Parent = parent,
	})
	local icon = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = C.PanelSoft,
		Parent = body,
	}, { Theme.corner(12) })
	Theme.label({ Size = UDim2.fromScale(1, 1), Text = upgrade.icon, MaxTextSize = 30, Parent = icon })
	Theme.label({
		Position = UDim2.fromOffset(88, 10),
		Size = UDim2.new(1, -170, 0, 24),
		Text = upgrade.name,
		Font = Theme.Fonts.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = body,
	})
	local level, levelLabel = Theme.chip({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(72, 22),
		Color = C.PanelSoft,
		TextColor3 = C.InkSoft,
		Text = "",
		MaxTextSize = 12,
		Parent = body,
	})
	Theme.label({
		Position = UDim2.fromOffset(88, 34),
		Size = UDim2.new(1, -100, 0, 18),
		Text = upgrade.desc,
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = body,
	})
	local effect = Theme.label({
		Position = UDim2.fromOffset(88, 54),
		Size = UDim2.new(1, -100, 0, 18),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.Primary,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = body,
	})
	local bar = Theme.progress({
		Position = UDim2.fromOffset(12, 98),
		Size = UDim2.new(1, -170, 0, 6),
		Gradient = "primary",
		Parent = body,
	})
	local button = Theme.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(140, 40),
		Text = "",
		Variant = "primary",
		Radius = 12,
		MaxTextSize = 17,
		Parent = body,
		OnClick = function()
			Shop.buy(upgrade, body)
		end,
	})
	cards[upgrade.id] = { effect = effect, bar = bar, button = button, level = level, levelLabel = levelLabel }
end

function Shop.buy(upgrade, body)
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
		Theme.pop(body, 0.92)
	else
		app.notify(ok and message or "No se pudo comprar.", "error")
	end
end

function Shop.refresh()
	local state = app.state
	if not (state and window) then
		return
	end
	window.Subtitle.Text = "Tienes 💵 " .. Theme.formatNumber(state.coins)
	for _, upgrade in ipairs(Config.Upgrades) do
		local card = cards[upgrade.id]
		local level = state.upgrades[upgrade.id] or 0
		card.bar.Set(level / upgrade.max)
		card.levelLabel.Text = "Nv " .. level .. "/" .. upgrade.max
		if level >= upgrade.max then
			card.effect.Text = "Nivel máximo"
			card.button.SetText("Completado")
			card.button.SetEnabled(false)
		else
			local cost = Config.upgradeCost(upgrade.id, level)
			card.effect.Text = effectText(upgrade.id, level)
			card.button.SetText("💵 " .. Theme.formatNumber(cost))
			card.button.SetEnabled(state.coins >= cost)
		end
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
		Size = UDim2.fromOffset(830, 640),
		Title = "Mejoras",
		Icon = "🛒",
		Accent = "primary",
	})
	local list = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -36, 1, -24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.InkFaint,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window.Body,
	}, {
		Theme.list("v", 10),
		Theme.new("UIPadding", {
			PaddingRight = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 12),
		}),
	})
	local order = 0
	for _, section in ipairs(SECTIONS) do
		order += 1
		Theme.label({
			Size = UDim2.new(1, 0, 0, 26),
			Text = section.name,
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.InkSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			LayoutOrder = order,
			Parent = list,
		})
		order += 1
		local rows = math.ceil(#section.ids / 2)
		local grid = Theme.new("Frame", {
			Size = UDim2.new(1, 0, 0, rows * 146),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = list,
		}, {
			Theme.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(372, 132),
				CellPadding = UDim2.fromOffset(14, 14),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for i, id in ipairs(section.ids) do
			buildCard(Config.UpgradeById[id], i, grid)
		end
	end
end

return Shop
