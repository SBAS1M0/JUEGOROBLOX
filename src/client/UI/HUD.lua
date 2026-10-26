-- Interfaz principal: monedas y cuadros en venta arriba, columna de botones a
-- la izquierda, misiones plegables, el cuadro que llevas a la espalda, avisos
-- y confeti.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Designs = require(Shared.Designs)

local Theme = require(script.Parent.Theme)
local DesignArt = require(script.Parent.DesignArt)

local HUD = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local app
local gui
local refs = {}
local tiles = {}
local questRows = {}
local shownCoins = nil
local toastHolder
local confettiHolder
local carriedKey = nil

local KIND_COLOR = { info = C.Blue, success = C.Mint, error = C.Red, gold = C.Gold, sale = C.Mint }
local KIND_ICON = { info = "i", success = "✓", error = "!", gold = "★", sale = "💵" }
local CONFETTI_COLORS = {
	Color3.fromRGB(250, 176, 40),
	Color3.fromRGB(18, 168, 148),
	Color3.fromRGB(64, 140, 240),
	Color3.fromRGB(246, 112, 90),
	Color3.fromRGB(130, 96, 220),
}

-- Avisos ------------------------------------------------------------------------------------
function HUD.notify(text, kind)
	if not toastHolder then
		return
	end
	local holder, body = Theme.card({
		Size = UDim2.new(1, 0, 0, 42),
		Radius = 21,
		Color = C.Navy,
		Transparency = 0.04,
		Stroke = false,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = toastHolder,
	})
	local accent = Theme.new("Frame", {
		Position = UDim2.fromOffset(7, 7),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = KIND_COLOR[kind] or C.Blue,
		Parent = body,
	}, { Theme.round() })
	Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = KIND_ICON[kind] or "i",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		MaxTextSize = 16,
		Parent = accent,
	})
	Theme.label({
		Size = UDim2.new(1, -56, 1, -12),
		Position = UDim2.fromOffset(44, 6),
		Text = text,
		Font = Theme.Fonts.Bold,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = body,
	})
	Theme.pop(holder, 0.7)
	if kind == "error" then
		Theme.playSound("click", 0.6)
	elseif kind == "sale" then
		Theme.playSound("success", 0.8)
		Theme.popCard(refs.coinsFrame, 0.85)
	end
	task.delay(3.8, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
	local toasts = {}
	for _, child in ipairs(toastHolder:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 3 then
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

-- Barra superior --------------------------------------------------------------------------------
local function pill(parent, props)
	local holder, body = Theme.card({
		Name = props.Name,
		Size = props.Size,
		Radius = 23,
		Color = C.Navy,
		Transparency = 0.06,
		StrokeColor = C.White,
		StrokeThickness = 2,
		LayoutOrder = props.LayoutOrder,
		Parent = parent,
	})
	body:FindFirstChildOfClass("UIStroke").Transparency = 0.75
	local icon = Theme.new("Frame", {
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.round(), Theme.gradient(Theme.Gradients[props.Accent][1], Theme.Gradients[props.Accent][2], 90) })
	Theme.label({ Size = UDim2.fromScale(1, 1), Text = props.Icon, MaxTextSize = 20, Parent = icon })
	local label = Theme.label({
		Name = "Value",
		Size = UDim2.new(1, -(props.Right or 56), 1, -12),
		Position = UDim2.fromOffset(48, 6),
		Text = "0",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = props.MaxTextSize or 24,
		Parent = body,
	})
	return holder, label, body
end

local function buildTopBar()
	local bar = Theme.new("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 360, 0, 46),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.list("h", 10, Enum.HorizontalAlignment.Center) })
	local coins, coinsLabel = pill(bar, {
		Name = "Coins",
		Size = UDim2.new(0, 206, 1, 0),
		Accent = "gold",
		Icon = "💵",
		LayoutOrder = 1,
		Right = 92,
	})
	refs.coins = coinsLabel
	refs.coinsFrame = coins
	Theme.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 2),
		Size = UDim2.fromOffset(36, 38),
		Text = "+",
		Variant = "primary",
		Radius = 18,
		Depth = 3,
		MaxTextSize = 24,
		Parent = coins:FindFirstChild("Body"),
		OnClick = function()
			app.openShop()
		end,
	})
	local _, gallery = pill(bar, {
		Name = "Gallery",
		Size = UDim2.new(0, 134, 1, 0),
		Accent = "primary",
		Icon = "🖼️",
		LayoutOrder = 2,
		MaxTextSize = 22,
		Right = 56,
	})
	refs.gallery = gallery
end

-- Columna de botones -------------------------------------------------------------------------------
local function buildMenu()
	local menu = Theme.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(70, 440),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.list("v", 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local entries = {
		{ "shop", "🛒", "Mejoras", "primary", app.openShop },
		{ "colors", "📚", "Colores", "blue", app.openCollection },
		{ "quests", "📜", "Misiones", "gold", HUD.toggleQuests },
		{ "daily", "🎁", "Regalo", "coral", app.openDaily },
		{
			"home",
			"🏠",
			"Taller",
			"navy",
			function()
				app.remotes.GoHome:FireServer()
			end,
		},
	}
	for order, entry in ipairs(entries) do
		local action = entry[5]
		tiles[entry[1]] = Theme.tile({
			Name = entry[1],
			Size = UDim2.fromOffset(68, 72),
			IconSize = 30,
			Icon = entry[2],
			Text = entry[3],
			Gradient = entry[4],
			LayoutOrder = order,
			Parent = menu,
			OnClick = function()
				action()
			end,
		})
	end
	-- Sonido on/off, discreto debajo de los botones.
	local sound = Theme.new("TextButton", {
		Name = "Settings",
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = C.Navy,
		BackgroundTransparency = 0.1,
		Font = Theme.Fonts.Bold,
		Text = "🔊",
		TextScaled = true,
		LayoutOrder = 99,
		Parent = menu,
	}, { Theme.round(), Theme.stroke(C.White, 2, 0.7), Theme.padding(9) })
	sound.Activated:Connect(function()
		Theme.soundsEnabled = not Theme.soundsEnabled
		sound.Text = Theme.soundsEnabled and "🔊" or "🔇"
		Theme.playSound("click")
	end)
	refs.menu = menu
end

-- Misiones diarias (plegables) ---------------------------------------------------------------------
local function buildQuests()
	local holder, body = Theme.card({
		Name = "Quests",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 94, 0.5, 0),
		Size = UDim2.fromOffset(300, 318),
		Radius = 20,
		Color = C.Bg,
		StrokeColor = C.Navy,
		StrokeThickness = 2.5,
		Visible = false,
		Parent = gui,
	})
	refs.quests = holder
	local header = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.corner(20), Theme.gradient(Theme.Gradients.navy[1], Theme.Gradients.navy[2], 90) })
	Theme.new("Frame", {
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = Theme.Gradients.navy[2],
		BorderSizePixel = 0,
		Parent = header,
	})
	Theme.label({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -64, 0, 30),
		Text = "📜 Misiones de hoy",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = header,
	})
	local close = Theme.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = C.White,
		Font = Theme.Fonts.Heavy,
		Text = "✕",
		TextScaled = true,
		TextColor3 = C.White,
		Parent = header,
	}, { Theme.round(), Theme.padding(8), Theme.gradient(Theme.Gradients.coral[1], Theme.Gradients.coral[2], 90) })
	close.Activated:Connect(function()
		Theme.playSound("click")
		HUD.toggleQuests(false)
	end)
	local list = Theme.new("Frame", {
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.new(1, -20, 1, -96),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Theme.list("v", 7) })
	for i = 1, Config.QUESTS_PER_DAY do
		local _, row = Theme.card({
			Size = UDim2.new(1, 0, 0, 66),
			Radius = 14,
			LayoutOrder = i,
			Parent = list,
		})
		local icon = Theme.new("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = C.GoldLight,
			Parent = row,
		}, { Theme.corner(10) })
		local iconLabel = Theme.label({ Size = UDim2.fromScale(1, 1), Text = "", MaxTextSize = 19, Parent = icon })
		local text = Theme.label({
			Position = UDim2.fromOffset(48, 6),
			Size = UDim2.new(1, -56, 0, 34),
			Text = "",
			Font = Theme.Fonts.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = row,
		})
		local bar = Theme.progress({
			Position = UDim2.fromOffset(10, 48),
			Size = UDim2.new(1, -134, 0, 8),
			Gradient = "gold",
			Parent = row,
		})
		local count = Theme.label({
			Position = UDim2.new(1, -120, 0, 42),
			Size = UDim2.fromOffset(48, 18),
			Text = "",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.InkSoft,
			MaxTextSize = 13,
			Parent = row,
		})
		local claim = Theme.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 34),
			Size = UDim2.fromOffset(66, 28),
			Text = "",
			Variant = "mint",
			Radius = 10,
			Depth = 3,
			MaxTextSize = 13,
			Parent = row,
			OnClick = function()
				app.claimQuest(i)
			end,
		})
		questRows[i] = { row = row, icon = iconLabel, text = text, bar = bar, count = count, claim = claim }
	end
	refs.questBonus = Theme.label({
		Position = UDim2.new(0, 10, 1, -30),
		Size = UDim2.new(1, -20, 0, 22),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.GoldDark,
		MaxTextSize = 14,
		Parent = body,
	})
end

function HUD.toggleQuests(show)
	if show == nil then
		show = not refs.quests.Visible
	end
	refs.quests.Visible = show
	tiles.quests.SetActive(show)
	if show then
		Theme.popCard(refs.quests, 0.9)
	end
end

local function refreshQuests(state)
	local claimable = 0
	for i, rowRefs in ipairs(questRows) do
		local quest = state.quests and state.quests[i]
		rowRefs.row.Parent.Visible = quest ~= nil
		if quest then
			local def = Config.QuestById[quest.id]
			rowRefs.icon.Text = def and def.icon or "❔"
			rowRefs.text.Text = Config.questText(quest)
			rowRefs.bar.Set(quest.progress / math.max(quest.goal, 1), true)
			rowRefs.count.Text = Theme.formatNumber(quest.progress) .. "/" .. Theme.formatNumber(quest.goal)
			local done = quest.progress >= quest.goal
			if quest.claimed then
				rowRefs.claim.SetText("✔")
				rowRefs.claim.SetEnabled(false)
			else
				if done then
					claimable += 1
				end
				rowRefs.claim.SetText("💵 " .. Theme.formatNumber(quest.reward))
				rowRefs.claim.SetEnabled(done)
			end
			rowRefs.row.BackgroundColor3 = (done and not quest.claimed) and C.MintLight or C.Panel
		end
	end
	refs.questBonus.Text = state.questBonus and "🎉 ¡Bonus de hoy reclamado!"
		or "🎁 Completa las 3: ¡color Épico o mejor!"
	tiles.quests.SetBadge(claimable > 0 and claimable or nil)
end

-- Cuadro que llevas a la espalda (almacén) ----------------------------------------------------------
local function buildCarry()
	local holder, body = Theme.card({
		Name = "Carry",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(268, 152),
		Radius = 20,
		Color = C.Bg,
		StrokeColor = C.Navy,
		StrokeThickness = 2.5,
		Visible = false,
		Parent = gui,
	})
	refs.carry = holder
	local header = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.corner(20), Theme.gradient(Theme.Gradients.navy[1], Theme.Gradients.navy[2], 90) })
	Theme.new("Frame", {
		Position = UDim2.new(0, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = Theme.Gradients.navy[2],
		BorderSizePixel = 0,
		Parent = header,
	})
	refs.carryTitle = Theme.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 22),
		Text = "🖼️ Llevas a la espalda",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = header,
	})
	local thumb = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.corner(4), Theme.stroke(C.Navy, 4) })
	refs.carryArt = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = thumb })
	refs.carryName = Theme.label({
		Position = UDim2.fromOffset(86, 44),
		Size = UDim2.new(1, -96, 0, 22),
		Text = "",
		Font = Theme.Fonts.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 19,
		Parent = body,
	})
	refs.carryInfo = Theme.label({
		Position = UDim2.fromOffset(86, 68),
		Size = UDim2.new(1, -96, 0, 18),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.GoldDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = body,
	})
	refs.carryCount = Theme.label({
		Position = UDim2.fromOffset(86, 88),
		Size = UDim2.new(1, -96, 0, 18),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = body,
	})
	refs.carryHint = Theme.label({
		Position = UDim2.fromOffset(12, 114),
		Size = UDim2.new(1, -100, 0, 30),
		Text = "Exponlo en un stand de la sala y ponle precio",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.PrimaryDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = body,
	})
	refs.carryNext = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 112),
		Size = UDim2.fromOffset(84, 32),
		Text = "Cambiar ▶",
		Variant = "navy",
		Radius = 12,
		Depth = 3,
		MaxTextSize = 14,
		Parent = body,
		OnClick = function()
			local storage = app.state and app.state.storage or {}
			if #storage > 1 then
				app.remotes.SelectStored:FireServer(#storage)
			end
		end,
	})
end

local function refreshCarry(state)
	local storage = state.storage or {}
	local entry = storage[1]
	refs.carry.Visible = entry ~= nil
	if not entry then
		carriedKey = nil
		return
	end
	local design = Designs.get(entry.d)
	local key = entry.d .. entry.c .. #storage
	if key ~= carriedKey and design then
		carriedKey = key
		DesignArt.render(
			refs.carryArt,
			design,
			{ mode = "color", colors = Designs.decodeColors(entry.c), outline = false }
		)
		Theme.popCard(refs.carry, 0.9)
	end
	refs.carryName.Text = design and design.name or "?"
	refs.carryInfo.Text = string.rep("★", entry.st or 1) .. "   Precio medio 💵 " .. Theme.formatNumber(entry.v)
	refs.carryCount.Text = #storage > 1 and ("Tienes " .. #storage .. " cuadros guardados")
		or "Tu único cuadro guardado"
	local free = (state.standCount or 0) - (state.displayed or 0)
	refs.carryHint.Text = free > 0 and "Exponlo en un stand de la sala y ponle precio"
		or "Stands llenos: compra otro stand (＋) en la sala"
	refs.carryNext.Holder.Visible = #storage > 1
end

-- Estado --------------------------------------------------------------------------------------------
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
		Theme.popCard(refs.coinsFrame, 0.9)
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
	refs.gallery.Text = state.displayed .. "/" .. (state.standCount or 0)
	tiles.daily.SetBadge(state.dailyReady)
	tiles.daily.Caption.Text = state.dailyReady and "¡Regalo!" or Theme.formatTime(state.dailyWait)
	refreshQuests(state)
	refreshCarry(state)
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
	buildMenu()
	buildQuests()
	buildCarry()

	local overlay = Theme.new("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	toastHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.new(0, 460, 0, 160),
		BackgroundTransparency = 1,
		Parent = overlay,
	}, { Theme.list("v", 6, Enum.HorizontalAlignment.Center) })
	confettiHolder = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = overlay,
	})

	-- Escala en pantallas pequeñas.
	local scaled = { gui.TopBar, refs.menu, refs.quests, refs.carry, toastHolder }
	local function updateScale()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.6, 1)
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
