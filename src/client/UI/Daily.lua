-- Ventana del regalo diario: racha de 7 días con monedas y un color raro.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)

local Daily = {}

local C = Theme.Colors

local app
local window
local tiles = {}
local claimButton
local claiming = false

local function buildTiles(parent)
	local row = Theme.new("Frame", {
		Position = UDim2.fromOffset(20, 22),
		Size = UDim2.new(1, -40, 0, 156),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Theme.list("h", 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	for day = 1, 7 do
		local big = day == 7
		local _, body = Theme.card({
			Name = "Day" .. day,
			Size = UDim2.fromOffset(big and 120 or 92, 150),
			Radius = 14,
			LayoutOrder = day,
			Parent = row,
		})
		local title = Theme.label({
			Position = UDim2.fromOffset(4, 10),
			Size = UDim2.new(1, -8, 0, 22),
			Text = big and "Día 7 · ¡Premio!" or ("Día " .. day),
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.InkSoft,
			MaxTextSize = 17,
			Parent = body,
		})
		local icon = Theme.label({
			Position = UDim2.fromOffset(4, 36),
			Size = UDim2.new(1, -8, 0, 46),
			Text = big and "👑" or "🎁",
			MaxTextSize = big and 44 or 38,
			Parent = body,
		})
		local amount = Theme.label({
			Position = UDim2.fromOffset(4, 88),
			Size = UDim2.new(1, -8, 0, 22),
			Text = "",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Ink,
			MaxTextSize = 18,
			Parent = body,
		})
		Theme.label({
			Position = UDim2.fromOffset(4, 114),
			Size = UDim2.new(1, -8, 0, 18),
			Text = big and "+ color Épico" or "+ color raro",
			Font = Theme.Fonts.Medium,
			TextColor3 = C.InkSoft,
			MaxTextSize = 13,
			Parent = body,
		})
		local check = Theme.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(24, 24),
			Text = "✔",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.MintDark,
			MaxTextSize = 18,
			Visible = false,
			Parent = body,
		})
		tiles[day] = {
			body = body,
			big = big,
			stroke = body:FindFirstChildOfClass("UIStroke"),
			title = title,
			icon = icon,
			amount = amount,
			check = check,
		}
	end
end

function Daily.refresh()
	local state = app.state
	if not (state and window and window.Holder.Visible) then
		return
	end
	local scale = Config.questScale(state.openLevel)
	local today = state.dailyStreak
	for day, tile in ipairs(tiles) do
		tile.amount.Text = "💵 " .. Theme.formatNumber(math.floor((80 + day * 40) * scale))
		local claimed = day < today or (day == today and not state.dailyReady)
		local current = day == today and state.dailyReady
		tile.check.Visible = claimed
		tile.body.BackgroundColor3 = claimed and C.PanelSoft or C.Panel
		tile.stroke.Color = current and C.Primary or C.Border
		tile.stroke.Thickness = current and 2 or 1
		tile.title.TextColor3 = current and C.Primary or C.InkSoft
	end
	if state.dailyReady then
		claimButton.SetText("Reclamar día " .. today)
		claimButton.SetEnabled(true)
	else
		claimButton.SetText("Vuelve en " .. Theme.formatTime(state.dailyWait))
		claimButton.SetEnabled(false)
	end
end

function Daily.open()
	window.Open()
	Daily.refresh()
end

function Daily.claim()
	if claiming then
		return
	end
	claiming = true
	local ok, success, amount, colorId = pcall(function()
		return app.remotes.ClaimDaily:InvokeServer()
	end)
	claiming = false
	if ok and success then
		Theme.playSound("success", 1.1)
		local entry = Colors.ById[colorId]
		app.notify(
			"🎁 ¡Regalo diario! +💵"
				.. Theme.formatNumber(amount)
				.. (entry and (" y «" .. entry.name .. "»") or ""),
			"gold"
		)
		app.celebrate()
		window.Close()
	end
end

function Daily.init(appRef)
	app = appRef
	local gui = Theme.new("ScreenGui", {
		Name = "Daily",
		ResetOnSpawn = false,
		DisplayOrder = 14,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	window = Theme.window({
		Name = "Window",
		Parent = gui,
		Size = UDim2.fromOffset(820, 360),
		Title = "Regalo diario",
		Subtitle = "Vuelve cada día: la recompensa crece con tu racha.",
	})
	buildTiles(window.Body)
	claimButton = Theme.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(280, 48),
		Text = "",
		Variant = "primary",
		Radius = 12,
		Parent = window.Body,
		OnClick = function()
			Daily.claim()
		end,
	})
end

return Daily
