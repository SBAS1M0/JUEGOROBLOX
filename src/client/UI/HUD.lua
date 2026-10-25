-- Interfaz principal: monedas, menú lateral, misiones diarias, tutorial,
-- avisos y confeti.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Designs = require(Shared.Designs)

local Theme = require(script.Parent.Theme)

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
local questsVisible = true

local KIND_GRADIENT = { info = "primary", success = "mint", error = "red", gold = "gold" }
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
	local holder, body = Theme.card({
		Size = UDim2.new(1, 0, 0, 48),
		Radius = 24,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = toastHolder,
	})
	local accent = Theme.new("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.round(), Theme.gradient(KIND_GRADIENT[kind] or "primary", 90) })
	Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = kind == "error" and "!" or (kind == "gold" and "★" or "✓"),
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		MaxTextSize = 20,
		Parent = accent,
	})
	Theme.label({
		Size = UDim2.new(1, -62, 1, -12),
		Position = UDim2.fromOffset(50, 6),
		Text = text,
		Font = Theme.Fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 19,
		Parent = body,
	})
	Theme.pop(holder, 0.7)
	if kind == "error" then
		Theme.playSound("click", 0.6)
	end
	task.delay(4, function()
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
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
end

function HUD.celebrate()
	local random = Random.new()
	for _ = 1, 80 do
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
		Radius = 24,
		LayoutOrder = props.LayoutOrder,
		Parent = parent,
	})
	local icon = Theme.new("Frame", {
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.round(), Theme.gradient(props.Gradient, 90) })
	Theme.label({ Size = UDim2.fromScale(1, 1), Text = props.Icon, MaxTextSize = 22, Parent = icon }, nil)
	if props.Caption then
		Theme.label({
			Name = "Caption",
			Size = UDim2.new(1, -60, 0, 14),
			Position = UDim2.fromOffset(50, 5),
			Text = props.Caption,
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.InkFaint,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 12,
			Parent = body,
		})
	end
	local label = Theme.label({
		Name = "Value",
		Size = props.Caption and UDim2.new(1, -60, 0, 24) or UDim2.new(1, -60, 1, -12),
		Position = UDim2.fromOffset(50, props.Caption and 19 or 6),
		Text = "0",
		Font = props.Font or Theme.Fonts.Heavy,
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
		Size = UDim2.new(0, 620, 0, 48),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.list("h", 12, Enum.HorizontalAlignment.Center) })
	local coins, coinsLabel, coinsBody = pill(bar, {
		Name = "Coins",
		Size = UDim2.new(0, 220, 1, 0),
		Gradient = "gold",
		Icon = "💵",
		LayoutOrder = 1,
		Font = Theme.Fonts.Display,
		MaxTextSize = 28,
	})
	refs.coins = coinsLabel
	refs.coinsFrame = coins
	local plus = Theme.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = C.White,
		Font = Theme.Fonts.Heavy,
		Text = "+",
		TextScaled = true,
		TextColor3 = C.White,
		Parent = coinsBody,
	}, { Theme.round(), Theme.gradient("mint", 90), Theme.padding(5) })
	plus.Activated:Connect(function()
		Theme.playSound("click")
		app.openShop()
	end)
	local _, gallery = pill(bar, {
		Name = "Gallery",
		Size = UDim2.new(0, 160, 1, 0),
		Gradient = "pink",
		Icon = "🖼️",
		Caption = "EN VENTA",
		LayoutOrder = 2,
		MaxTextSize = 21,
	})
	refs.gallery = gallery
	local _, level = pill(bar, {
		Name = "Level",
		Size = UDim2.new(0, 160, 1, 0),
		Gradient = "purple",
		Icon = "🎨",
		Caption = "DISEÑOS",
		LayoutOrder = 3,
		MaxTextSize = 21,
	})
	refs.level = level
end

-- Menú lateral --------------------------------------------------------------------------------------
local function buildMenu()
	local menu = Theme.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.new(0, 170, 0, 290),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(78, 82),
			CellPadding = UDim2.fromOffset(12, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local entries = {
		{
			"paint",
			"🖌️",
			"Pintar",
			"primary",
			function()
				app.openDesigns()
			end,
		},
		{
			"colors",
			"📚",
			"Colores",
			"blue",
			function()
				app.openCollection()
			end,
		},
		{
			"shop",
			"🛒",
			"Mejoras",
			"mint",
			function()
				app.openShop()
			end,
		},
		{
			"quests",
			"📜",
			"Misiones",
			"gold",
			function()
				HUD.toggleQuests()
			end,
		},
		{
			"daily",
			"🎁",
			"Regalo",
			"pink",
			function()
				app.openDaily()
			end,
		},
		{
			"home",
			"🏠",
			"Mi galería",
			"orange",
			function()
				app.remotes.GoHome:FireServer()
			end,
		},
	}
	for order, entry in ipairs(entries) do
		tiles[entry[1]] = Theme.tile({
			Name = entry[1],
			Icon = entry[2],
			Text = entry[3],
			Gradient = entry[4],
			LayoutOrder = order,
			Parent = menu,
			OnClick = entry[5],
		})
	end
end

-- Misiones diarias -------------------------------------------------------------------------------
local function buildQuests()
	local holder, body = Theme.card({
		Name = "Quests",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 70),
		Size = UDim2.fromOffset(290, 318),
		Radius = 20,
		Parent = gui,
	})
	refs.quests = holder
	local header = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.corner(20), Theme.gradient("gold", 0) })
	Theme.new("Frame", {
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Parent = header,
	}, { Theme.gradient("gold", 0) })
	local title = Theme.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 30),
		Text = "📜 Misiones de hoy",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = header,
	})
	Theme.textStroke(C.GoldDark, 1.5, 0.3).Parent = title
	local list = Theme.new("Frame", {
		Position = UDim2.fromOffset(10, 54),
		Size = UDim2.new(1, -20, 1, -90),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Theme.list("v", 8) })
	for i = 1, Config.QUESTS_PER_DAY do
		local row = Theme.new("Frame", {
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = C.PanelSoft,
			LayoutOrder = i,
			Parent = list,
		}, { Theme.corner(14) })
		local icon = Theme.new("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = C.GoldLight,
			Parent = row,
		}, { Theme.corner(10) })
		local iconLabel = Theme.label({ Size = UDim2.fromScale(1, 1), Text = "", MaxTextSize = 20, Parent = icon })
		local text = Theme.label({
			Position = UDim2.fromOffset(50, 6),
			Size = UDim2.new(1, -58, 0, 36),
			Text = "",
			Font = Theme.Fonts.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			Parent = row,
		})
		local bar = Theme.progress({
			Position = UDim2.fromOffset(10, 50),
			Size = UDim2.new(1, -120, 0, 12),
			Gradient = "gold",
			Parent = row,
		})
		local count = Theme.label({
			Position = UDim2.new(1, -108, 0, 44),
			Size = UDim2.fromOffset(40, 22),
			Text = "",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.InkSoft,
			MaxTextSize = 14,
			Parent = row,
		})
		local claim = Theme.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 42),
			Size = UDim2.fromOffset(62, 26),
			Text = "",
			Variant = "mint",
			Radius = 10,
			MaxTextSize = 13,
			Parent = row,
			OnClick = function()
				app.claimQuest(i)
			end,
		})
		questRows[i] = { row = row, icon = iconLabel, text = text, bar = bar, count = count, claim = claim }
	end
	refs.questBonus = Theme.label({
		Position = UDim2.new(0, 10, 1, -32),
		Size = UDim2.new(1, -20, 0, 24),
		Text = "🎁 Completa las 3: ¡color Épico o mejor!",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.GoldDark,
		MaxTextSize = 15,
		Parent = body,
	})
end

function HUD.toggleQuests()
	questsVisible = not questsVisible
	refs.quests.Visible = questsVisible
	if questsVisible then
		Theme.pop(refs.quests.Body, 0.85)
	end
end

local function refreshQuests(state)
	local claimable = 0
	for i, rowRefs in ipairs(questRows) do
		local quest = state.quests and state.quests[i]
		rowRefs.row.Visible = quest ~= nil
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
			elseif done then
				claimable += 1
				rowRefs.claim.SetText("💵 " .. Theme.formatNumber(quest.reward))
				rowRefs.claim.SetEnabled(true)
			else
				rowRefs.claim.SetText("💵 " .. Theme.formatNumber(quest.reward))
				rowRefs.claim.SetEnabled(false)
			end
			rowRefs.row.BackgroundColor3 = (done and not quest.claimed) and C.MintLight or C.PanelSoft
		end
	end
	refs.questBonus.Text = state.questBonus and "🎉 ¡Bonus de hoy reclamado!"
		or "🎁 Completa las 3: ¡color Épico o mejor!"
	tiles.quests.SetBadge(claimable > 0 and claimable or nil)
end

-- Tutorial ------------------------------------------------------------------------------------------
local function buildTutorial()
	local holder, body = Theme.card({
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(470, 62),
		Radius = 20,
		Color = C.White,
		StrokeColor = C.Primary,
		StrokeThickness = 2.5,
		Visible = false,
		Parent = gui,
	})
	refs.tutorial = holder
	local step = Theme.new("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.round(), Theme.gradient("primary", 90) })
	refs.tutorialStep = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "1",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		MaxTextSize = 24,
		Parent = step,
	})
	refs.tutorialTitle = Theme.label({
		Position = UDim2.fromOffset(64, 6),
		Size = UDim2.new(1, -76, 0, 18),
		Text = "TUTORIAL",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.Primary,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = body,
	})
	refs.tutorialText = Theme.label({
		Position = UDim2.fromOffset(64, 24),
		Size = UDim2.new(1, -76, 0, 30),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = body,
	})
end

local function refreshTutorial(state)
	local step = state.tutorial or 0
	local def = Config.Tutorial[step]
	local visible = step > 0 and def ~= nil and not app.isBusy()
	refs.tutorial.Visible = visible
	if def then
		refs.tutorialStep.Text = tostring(step)
		refs.tutorialTitle.Text = "TUTORIAL · PASO " .. step .. " DE " .. #Config.Tutorial
		local suffix = def.goal > 1 and ("  (" .. (state.tutorialProgress or 0) .. "/" .. def.goal .. ")") or ""
		refs.tutorialText.Text = "👉 " .. def.text .. suffix
	end
	if refs.lastTutorial ~= step then
		refs.lastTutorial = step
		if visible then
			Theme.pop(refs.tutorial.Body, 0.8)
		end
	end
end

-- Ajustes (sonido) -----------------------------------------------------------------------------------
local function buildSettings()
	local button = Theme.new("TextButton", {
		Name = "Settings",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = C.White,
		Font = Theme.Fonts.Bold,
		Text = "🔊",
		TextScaled = true,
		Parent = gui,
	}, { Theme.round(), Theme.stroke(C.Border, 2), Theme.padding(9) })
	refs.settings = button
	button.Activated:Connect(function()
		Theme.soundsEnabled = not Theme.soundsEnabled
		button.Text = Theme.soundsEnabled and "🔊" or "🔇"
		Theme.playSound("click")
	end)
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
		Theme.pop(refs.coinsFrame, 0.88)
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
	refs.gallery.Text = state.displayed .. " / " .. state.slots
	refs.level.Text = "Nivel " .. state.openLevel .. " / " .. Designs.MAX_LEVEL
	tiles.daily.SetBadge(state.dailyReady)
	tiles.daily.Caption.Text = state.dailyReady and "¡Regalo!" or Theme.formatTime(state.dailyWait)
	tiles.paint.SetBadge(state.painting and "…" or nil)
	refreshQuests(state)
	refreshTutorial(state)
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
	buildTutorial()
	buildSettings()

	local overlay = Theme.new("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	toastHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 136),
		Size = UDim2.new(0, 480, 0, 280),
		BackgroundTransparency = 1,
		Parent = overlay,
	}, { Theme.list("v", 8, Enum.HorizontalAlignment.Center) })
	confettiHolder = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = overlay,
	})

	-- Escala en pantallas pequeñas.
	local scaled = { gui.TopBar, gui.Menu, refs.quests, refs.tutorial, toastHolder, refs.settings }
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
		-- En pantallas estrechas las misiones empiezan ocultas.
		if viewport.X < 900 and refs.quests.Visible and not refs.questsAutoHidden then
			refs.questsAutoHidden = true
			questsVisible = false
			refs.quests.Visible = false
		end
	end
	updateScale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return HUD
