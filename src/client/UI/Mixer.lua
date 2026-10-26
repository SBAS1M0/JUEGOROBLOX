-- Mezclador de colores del taller: echas varios botes de una misma rareza y
-- sale un color de la rareza siguiente (la mitad de las veces, uno nuevo).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)

local Theme = require(script.Parent.Theme)
local DesignArt = require(script.Parent.DesignArt)

local Mixer = {}

local C = Theme.Colors
local MIXABLE = { "comun", "pococomun", "raro", "epico", "legendario" }

local app
local window
local refs = {}
local rarityId = "comun"
local picks = {} -- lista de colorId en los huecos
local busy = false
local shownKey = nil -- evita redibujar si nada cambió

local function need()
	return Colors.MixCost[rarityId]
end

local function owned(colorId)
	return app.state and app.state.paints[colorId] or 0
end

local function pickedCount(colorId)
	local count = 0
	for _, id in ipairs(picks) do
		if id == colorId then
			count += 1
		end
	end
	return count
end

local function picksMap()
	local map = {}
	for _, id in ipairs(picks) do
		map[id] = (map[id] or 0) + 1
	end
	return map
end

-- Huecos del mezclador y resultado ------------------------------------------------------------------
local function refreshSlots()
	for _, child in ipairs(refs.slots:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local rarity = Colors.RarityById[rarityId]
	for i = 1, need() do
		local colorId = picks[i]
		local slot = Theme.new("TextButton", {
			Name = "Slot" .. i,
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = C.PanelSoft,
			AutoButtonColor = false,
			Text = colorId and "" or "+",
			Font = Theme.Fonts.Display,
			TextColor3 = C.InkFaint,
			TextScaled = true,
			LayoutOrder = i,
			Parent = refs.slots,
		}, { Theme.round(), Theme.stroke(colorId and rarity.color or C.Border, colorId and 3 or 2) })
		if colorId then
			DesignArt.swatch(slot, colorId)
			slot.Activated:Connect(function()
				table.remove(picks, i)
				Theme.playSound("click", 0.9)
				Mixer.refresh()
			end)
		end
	end
	local nextRarity = Colors.Rarities[rarity.index + 1]
	refs.resultChip.BackgroundColor3 = nextRarity.color
	refs.resultText.Text = "1 color " .. nextRarity.name
	refs.resultSwatch.BackgroundColor3 = nextRarity.color
	refs.resultHint.Text = "Acabado "
		.. nextRarity.finish:lower()
		.. " · valor x"
		.. string.format("%.1f", nextRarity.mult)
	local full = #picks == need()
	refs.mix.SetEnabled(full)
	refs.mix.SetText(full and "🧪 ¡Mezclar!" or ("Faltan " .. need() - #picks .. " colores"))
end

-- Colores que tienes de la rareza elegida ---------------------------------------------------------
local function refreshColors()
	for _, child in ipairs(refs.grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local rarity = Colors.RarityById[rarityId]
	local any = false
	for order, entry in ipairs(Colors.ByRarity[rarityId]) do
		local count = owned(entry.id)
		if count > 0 then
			any = true
			local left = count - pickedCount(entry.id)
			local _, cell =
				Theme.card({ Size = UDim2.fromOffset(104, 112), Radius = 14, LayoutOrder = order, Parent = refs.grid })
			local swatch = Theme.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				Size = UDim2.fromOffset(54, 54),
				Parent = cell,
			}, { Theme.round(), Theme.stroke(rarity.color, 3) })
			DesignArt.swatch(swatch, entry.id)
			Theme.label({
				Position = UDim2.fromOffset(4, 68),
				Size = UDim2.new(1, -8, 0, 18),
				Text = entry.name,
				Font = Theme.Fonts.Bold,
				MaxTextSize = 14,
				Parent = cell,
			})
			Theme.label({
				Position = UDim2.fromOffset(4, 88),
				Size = UDim2.new(1, -8, 0, 16),
				Text = "x" .. left,
				Font = Theme.Fonts.Heavy,
				TextColor3 = left > 0 and C.MintDark or C.InkFaint,
				MaxTextSize = 14,
				Parent = cell,
			})
			local button = Theme.new("TextButton", {
				Name = "Add_" .. entry.id,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				Parent = cell,
			})
			button.Activated:Connect(function()
				if left > 0 and #picks < need() then
					table.insert(picks, entry.id)
					Theme.playSound("paint", 1.2)
					Mixer.refresh()
				end
			end)
		end
	end
	refs.none.Visible = not any
end

function Mixer.refresh()
	if not (window and window.Holder.Visible and app.state) then
		return
	end
	-- Quita de los huecos lo que ya no tengas.
	for i = #picks, 1, -1 do
		if pickedCount(picks[i]) > owned(picks[i]) then
			table.remove(picks, i)
		end
	end
	local key = rarityId .. ":" .. table.concat(picks, ",")
	for _, entry in ipairs(Colors.ByRarity[rarityId]) do
		key ..= "|" .. owned(entry.id)
	end
	if key == shownKey then
		return
	end
	shownKey = key
	for id, tab in pairs(refs.tabs) do
		tab.SetVariant(id == rarityId and "purple" or "ghost")
	end
	refs.rule.Text = need() .. " colores " .. Colors.RarityById[rarityId].name .. " → 1 color de la rareza siguiente"
	refreshColors()
	refreshSlots()
end

local function autoFill()
	local options = {}
	for _, entry in ipairs(Colors.ByRarity[rarityId]) do
		local left = owned(entry.id) - pickedCount(entry.id)
		if left > 0 then
			table.insert(options, { id = entry.id, left = left })
		end
	end
	-- Primero los repetidos (los que más tienes).
	table.sort(options, function(a, b)
		return a.left > b.left
	end)
	for _, option in ipairs(options) do
		while option.left > 0 and #picks < need() do
			table.insert(picks, option.id)
			option.left -= 1
		end
	end
	Mixer.refresh()
end

local function mix()
	if busy or #picks ~= need() then
		return
	end
	busy = true
	refs.mix.SetEnabled(false)
	refs.mix.SetText("Mezclando…")
	Theme.playSound("whoosh", 0.8)
	Theme.pop(refs.slots, 0.8)
	local ok, success, colorId, isNew = pcall(function()
		return app.remotes.MixColors:InvokeServer(rarityId, picksMap())
	end)
	busy = false
	picks = {}
	if ok and success and Colors.ById[colorId] then
		Mixer.close()
		app.reveal(colorId, isNew)
	else
		app.notify(ok and colorId or "No se pudo mezclar.", "error")
		Mixer.refresh()
	end
end

-- Construcción -------------------------------------------------------------------------------------
function Mixer.open()
	shownKey = nil
	window.Open()
	Mixer.refresh()
end

function Mixer.close()
	window.Close()
end

function Mixer.init(appRef)
	app = appRef
	local gui = Theme.new("ScreenGui", {
		Name = "Mixer",
		ResetOnSpawn = false,
		DisplayOrder = 14,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	window = Theme.window({
		Name = "Window",
		Parent = gui,
		Size = UDim2.fromOffset(860, 560),
		Title = "Mezclador de colores",
		Subtitle = "Junta colores repetidos y consigue uno más raro",
		Icon = "🧪",
		Accent = "purple",
	})
	local body = window.Body
	-- Pestañas de rareza.
	local tabs = Theme.new("Frame", {
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -36, 0, 44),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Theme.list("h", 8) })
	refs.tabs = {}
	for i, id in ipairs(MIXABLE) do
		local rarity = Colors.RarityById[id]
		refs.tabs[id] = Theme.button({
			Size = UDim2.new(0.2, -7, 1, 0),
			Text = rarity.name,
			Variant = "ghost",
			Radius = 12,
			MaxTextSize = 16,
			LayoutOrder = i,
			Parent = tabs,
			OnClick = function()
				if rarityId ~= id then
					rarityId = id
					picks = {}
					Mixer.refresh()
				end
			end,
		})
	end
	refs.rule = Theme.label({
		Position = UDim2.fromOffset(18, 62),
		Size = UDim2.new(1, -36, 0, 22),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = body,
	})
	-- Tus colores de esa rareza.
	refs.grid = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(18, 92),
		Size = UDim2.new(0, 470, 1, -110),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.InkFaint,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, {
		Theme.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(104, 112),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Theme.padding(4),
	})
	refs.none = Theme.label({
		Position = UDim2.fromOffset(18, 150),
		Size = UDim2.fromOffset(470, 80),
		Text = "No tienes colores de esta rareza.\nTíralos en la máquina de colores 🎰",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		MaxTextSize = 18,
		Visible = false,
		Parent = body,
	})
	-- La jarra: huecos, flecha y resultado.
	local _, jar = Theme.card({
		Position = UDim2.new(1, -350, 0, 92),
		Size = UDim2.fromOffset(332, 376),
		Radius = 18,
		Parent = body,
	})
	Theme.label({
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 22),
		Text = "En el mezclador",
		Font = Theme.Fonts.Heavy,
		MaxTextSize = 18,
		Parent = jar,
	})
	refs.slots = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 140),
		BackgroundTransparency = 1,
		Parent = jar,
	}, {
		Theme.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(64, 64),
			CellPadding = UDim2.fromOffset(10, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Theme.label({
		Position = UDim2.fromOffset(12, 182),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "⬇",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.InkFaint,
		MaxTextSize = 28,
		Parent = jar,
	})
	refs.resultSwatch = Theme.new("Frame", {
		Position = UDim2.fromOffset(24, 218),
		Size = UDim2.fromOffset(56, 56),
		Parent = jar,
	}, { Theme.round(), Theme.stroke(C.White, 3) })
	Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "?",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		MaxTextSize = 30,
		Parent = refs.resultSwatch,
	})
	refs.resultChip = Theme.new("Frame", {
		Position = UDim2.fromOffset(92, 222),
		Size = UDim2.new(1, -116, 0, 28),
		Parent = jar,
	}, { Theme.round() })
	refs.resultText = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		MaxTextSize = 16,
		Parent = refs.resultChip,
	})
	refs.resultHint = Theme.label({
		Position = UDim2.fromOffset(92, 252),
		Size = UDim2.new(1, -116, 0, 18),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 14,
		Parent = jar,
	})
	Theme.button({
		Position = UDim2.fromOffset(12, 284),
		Size = UDim2.new(0.4, -12, 0, 42),
		Text = "Auto",
		Variant = "ghost",
		Radius = 12,
		MaxTextSize = 17,
		Parent = jar,
		OnClick = autoFill,
	})
	refs.mix = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 284),
		Size = UDim2.new(0.6, -12, 0, 42),
		Text = "",
		Variant = "purple",
		Radius = 12,
		MaxTextSize = 18,
		Parent = jar,
		OnClick = mix,
	})
	Theme.label({
		Position = UDim2.fromOffset(12, 334),
		Size = UDim2.new(1, -24, 0, 32),
		Text = "La mitad de las veces sale un color que aún no tienes.",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 14,
		Parent = jar,
	})
end

function Mixer.isOpen()
	return window ~= nil and window.Holder.Visible
end

return Mixer
