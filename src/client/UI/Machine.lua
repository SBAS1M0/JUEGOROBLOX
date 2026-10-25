-- Máquina de colores: panel inferior con carrete animado, cartel sobre la
-- máquina del taller, aviso de colores raros y ventana de colección.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Colors = require(Shared.Colors)
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)
local DesignArt = require(script.Parent.DesignArt)

local Machine = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local app
local gui
local refs = {}
local board = {}
local collection
local lastRollAt = -100
local rolling = false
local spinning = false
local spinToken = 0
local knownPaints = nil
local rollCooldown = 2.5

local function rarityText(colorId)
	local entry = Colors.ById[colorId]
	if not entry then
		return "¡Tira tu primer color!", C.InkSoft
	end
	local rarity = Colors.rarityOf(entry)
	return rarity.name .. "  ·  x" .. string.format("%.1f", rarity.mult), rarity.color
end

local function myMachine()
	local name = app.state and app.state.plotName or ""
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and name ~= "" and plots:FindFirstChild(name)
	local workshop = plot and plot:FindFirstChild("Workshop")
	return workshop and workshop:FindFirstChild("Machine")
end

-- Panel inferior -------------------------------------------------------------------------------
local function buildWidget()
	local holder, body = Theme.card({
		Name = "MachineWidget",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(500, 120),
		Radius = 24,
		Parent = gui,
	})
	refs.widget = holder

	-- Carrete.
	local reel = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = C.White,
		Parent = body,
	}, { Theme.corner(22), Theme.gradient("dark", 90) })
	refs.reelStroke = Theme.stroke(C.InkFaint, 3)
	refs.reelStroke.Parent = reel
	refs.swatch = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = Color3.fromRGB(90, 80, 120),
		Parent = reel,
	}, { Theme.round(), Theme.stroke(C.White, 3, 0.2) })
	refs.swatchShine = Theme.new("Frame", {
		Position = UDim2.fromScale(0.2, 0.14),
		Size = UDim2.fromScale(0.28, 0.2),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.45,
		Rotation = -25,
		Parent = refs.swatch,
	}, { Theme.round() })

	-- Texto.
	Theme.label({
		Position = UDim2.fromOffset(122, 12),
		Size = UDim2.new(1, -290, 0, 16),
		Text = "MÁQUINA DE COLORES",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.InkFaint,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 13,
		Parent = body,
	})
	refs.name = Theme.label({
		Position = UDim2.fromOffset(122, 30),
		Size = UDim2.new(1, -290, 0, 30),
		Text = "",
		Font = Theme.Fonts.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = body,
	})
	local chip, chipLabel = Theme.chip({
		Position = UDim2.fromOffset(122, 64),
		Size = UDim2.fromOffset(150, 24),
		Color = C.PanelSoft,
		Text = "",
		MaxTextSize = 13,
		Parent = body,
	})
	refs.rarityChip = chip
	refs.rarityLabel = chipLabel
	refs.count = Theme.label({
		Position = UDim2.fromOffset(122, 92),
		Size = UDim2.new(1, -290, 0, 18),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = body,
	})

	-- Botones.
	refs.rollButton = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(148, 54),
		Text = "🎲 TIRAR",
		Variant = "primary",
		Radius = 16,
		MaxTextSize = 24,
		Parent = body,
		OnClick = function()
			Machine.roll()
		end,
	})
	refs.cooldown = Theme.progress({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 72),
		Size = UDim2.fromOffset(148, 6),
		Gradient = "mint",
		Parent = body,
	})
	refs.autoButton = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -62, 0, 84),
		Size = UDim2.fromOffset(100, 28),
		Text = "🔒 Auto",
		Variant = "ghost",
		Radius = 14,
		MaxTextSize = 14,
		Parent = body,
		OnClick = function()
			Machine.toggleAuto()
		end,
	})
	Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 84),
		Size = UDim2.fromOffset(42, 28),
		Text = "📚",
		Variant = "ghost",
		Radius = 14,
		MaxTextSize = 16,
		Parent = body,
		OnClick = function()
			Machine.openCollection()
		end,
	})
end

-- Cartel sobre la máquina del taller.
local function buildBoard()
	board.gui = Theme.new("BillboardGui", {
		Name = "MachineBoard",
		Size = UDim2.fromOffset(240, 130),
		StudsOffset = Vector3.new(0, 1.5, 0),
		MaxDistance = 50,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = true,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local card = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.05,
		Parent = board.gui,
	}, { Theme.corner(18), Theme.stroke(C.Border, 2) })
	board.name = Theme.label({
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 30),
		Text = "",
		Font = Theme.Fonts.Display,
		MaxTextSize = 22,
		Parent = card,
	})
	board.rarity = Theme.label({
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 0, 24),
		Text = "",
		Font = Theme.Fonts.Heavy,
		MaxTextSize = 17,
		Parent = card,
	})
	board.auto = Theme.new("TextButton", {
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(0.56, -4, 0, 40),
		BackgroundColor3 = C.White,
		Font = Theme.Fonts.Heavy,
		Text = "🔒 Auto-Rolling",
		TextScaled = true,
		TextColor3 = C.InkSoft,
		Parent = board.gui,
	}, { Theme.round(), Theme.stroke(C.Border, 2), Theme.padding(9, 10) })
	board.auto.Activated:Connect(function()
		Machine.toggleAuto()
	end)
	local upgrade = Theme.new("TextButton", {
		Position = UDim2.new(0.56, 4, 0, 82),
		Size = UDim2.new(0.44, -4, 0, 40),
		BackgroundColor3 = C.White,
		Font = Theme.Fonts.Heavy,
		Text = "⬆ Mejora",
		TextScaled = true,
		TextColor3 = C.White,
		Parent = board.gui,
	}, { Theme.round(), Theme.gradient("gold", 90), Theme.padding(9, 10) })
	upgrade.Activated:Connect(function()
		app.openShop()
	end)
end

-- Aviso grande de color raro.
local function buildPopup()
	refs.popup = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(320, 300),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	local cardHolder, card = Theme.card({
		Size = UDim2.fromScale(1, 1),
		Radius = 30,
		ShadowTransparency = 0.6,
		Parent = refs.popup,
	})
	refs.popupCard = card
	refs.popupHolder = cardHolder
	refs.popupStroke = card:FindFirstChildOfClass("UIStroke")
	refs.popupStroke.Thickness = 5
	refs.popupBand = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = C.White,
		Parent = card,
	}, { Theme.corner(30), Theme.gradient("gold", 0) })
	refs.popupRarity = Theme.label({
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 46),
		Text = "",
		Font = Theme.Fonts.Display,
		TextColor3 = C.White,
		MaxTextSize = 40,
		Parent = card,
	})
	Theme.textStroke(C.Shadow, 2, 0.6).Parent = refs.popupRarity
	refs.popupSwatch = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.fromOffset(120, 120),
		Parent = card,
	}, { Theme.round(), Theme.stroke(C.White, 6) })
	refs.popupSparkles = {}
	for i = 1, 6 do
		local sparkle = Theme.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(28, 28),
			Text = "✦",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Gold,
			MaxTextSize = 26,
			Parent = card,
		})
		refs.popupSparkles[i] = sparkle
	end
	refs.popupName = Theme.label({
		Position = UDim2.fromOffset(10, 214),
		Size = UDim2.new(1, -20, 0, 36),
		Text = "",
		Font = Theme.Fonts.Display,
		MaxTextSize = 30,
		Parent = card,
	})
	refs.popupMult = Theme.label({
		Position = UDim2.fromOffset(10, 252),
		Size = UDim2.new(1, -20, 0, 26),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.MintDark,
		MaxTextSize = 20,
		Parent = card,
	})
end

local popupToken = 0
local function showPopup(colorId, isNew)
	local entry = Colors.ById[colorId]
	local rarity = Colors.rarityOf(entry)
	popupToken += 1
	local token = popupToken
	refs.popupStroke.Color = rarity.color
	local band = refs.popupBand:FindFirstChildOfClass("UIGradient")
	band.Color = ColorSequence.new(rarity.color:Lerp(C.White, 0.25), rarity.color)
	refs.popupRarity.Text = "¡" .. (isNew and "NUEVO · " or "") .. Theme.upper(rarity.name) .. "!"
	DesignArt.swatch(refs.popupSwatch, colorId)
	refs.popupName.Text = entry.name
	refs.popupMult.Text = "Multiplica tus cuadros x" .. string.format("%.1f", rarity.mult)
	refs.popup.Visible = true
	Theme.pop(refs.popupHolder, 0.3)
	Theme.playSound("success", 0.7 + rarity.index * 0.1)
	if rarity.index >= 4 then
		app.celebrate()
	end
	task.spawn(function()
		local t0 = os.clock()
		while token == popupToken and refs.popup.Visible do
			local t = os.clock() - t0
			for i, sparkle in ipairs(refs.popupSparkles) do
				local angle = t * 1.6 + i / #refs.popupSparkles * math.pi * 2
				sparkle.Position = UDim2.new(0.5, math.cos(angle) * 92, 0, 146 + math.sin(angle) * 74)
				sparkle.Rotation = t * 120
				sparkle.TextColor3 = rarity.color:Lerp(C.White, (math.sin(t * 5 + i) + 1) * 0.25)
			end
			task.wait()
		end
	end)
	task.delay(rarity.index >= 4 and 3.2 or 2.2, function()
		if token == popupToken then
			refs.popup.Visible = false
		end
	end)
end

-- Colección -------------------------------------------------------------------------------------
local function buildCollection()
	local holderGui = Theme.new("ScreenGui", {
		Name = "Collection",
		ResetOnSpawn = false,
		DisplayOrder = 12,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	collection = Theme.window({
		Name = "Window",
		Parent = holderGui,
		Size = UDim2.fromOffset(880, 600),
		Gradient = "blue",
		Title = "📚 Colección de pinturas",
		Subtitle = "Descubre todos los colores. Cuanto más raros, más valen tus cuadros.",
	})
	refs.collectionProgress = Theme.label({
		Position = UDim2.new(1, -330, 0, 14),
		Size = UDim2.fromOffset(250, 24),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 18,
		Parent = collection.Header,
	})
	refs.collectionList = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 1, -28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.InkFaint,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = collection.Body,
	}, {
		Theme.list("v", 8),
		Theme.new("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 10),
		}),
	})
end

local function colorCell(parent, entry, count, order)
	local known = entry.basic or count > 0 or (knownPaints and knownPaints[entry.id])
	local _, cell = Theme.card({ Size = UDim2.fromOffset(110, 112), Radius = 16, LayoutOrder = order, Parent = parent })
	local swatch = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.Border,
		Parent = cell,
	}, { Theme.round() })
	if known then
		DesignArt.swatch(swatch, entry.id)
		Theme.stroke(Colors.rarityOf(entry).color, 3).Parent = swatch
	else
		Theme.label({
			Size = UDim2.fromScale(1, 1),
			Text = "?",
			Font = Theme.Fonts.Display,
			TextColor3 = C.InkFaint,
			MaxTextSize = 30,
			Parent = swatch,
		})
	end
	Theme.label({
		Position = UDim2.fromOffset(4, 70),
		Size = UDim2.new(1, -8, 0, 18),
		Text = known and entry.name or "???",
		Font = Theme.Fonts.Bold,
		MaxTextSize = 15,
		Parent = cell,
	})
	Theme.label({
		Position = UDim2.fromOffset(4, 88),
		Size = UDim2.new(1, -8, 0, 16),
		Text = entry.basic and "∞" or ("x" .. count),
		Font = Theme.Fonts.Heavy,
		TextColor3 = count > 0 and C.MintDark or C.InkFaint,
		MaxTextSize = 14,
		Parent = cell,
	})
end

function Machine.refreshCollection()
	if not (collection and collection.Holder.Visible and app.state) then
		return
	end
	local list = refs.collectionList
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local chances = Colors.chances(Config.luck(app.state.upgrades))
	local found, total = 0, 0
	for _, entry in ipairs(Colors.List) do
		if not entry.basic then
			total += 1
			if knownPaints and knownPaints[entry.id] then
				found += 1
			end
		end
	end
	refs.collectionProgress.Text = "Descubiertos " .. found .. "/" .. total
	local order = 0
	local sections = {}
	for i = #Colors.Rarities, 1, -1 do
		table.insert(sections, Colors.Rarities[i])
	end
	table.insert(sections, Colors.BASIC_RARITY)
	for _, rarity in ipairs(sections) do
		order += 1
		local header = Theme.new(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = order, Parent = list }
		)
		local chip = Theme.chip({
			Size = UDim2.fromOffset(150, 30),
			Color = rarity.color,
			Text = rarity.name,
			TextColor3 = C.White,
			MaxTextSize = 16,
			Parent = header,
		})
		chip.Position = UDim2.fromOffset(0, 2)
		Theme.label({
			Position = UDim2.fromOffset(160, 4),
			Size = UDim2.new(1, -170, 0, 26),
			Text = rarity.id == "basico" and "Siempre disponibles · x1.0"
				or string.format("Valor x%.1f  ·  %.1f%% por tirada", rarity.mult, chances[rarity.id] * 100),
			Font = Theme.Fonts.Bold,
			TextColor3 = C.InkSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 17,
			Parent = header,
		})
		order += 1
		local entries = {}
		for _, entry in ipairs(Colors.List) do
			if (rarity.id == "basico" and entry.basic) or entry.rarity == rarity.id then
				table.insert(entries, entry)
			end
		end
		local rows = math.ceil(#entries / 7)
		local grid = Theme.new("Frame", {
			Size = UDim2.new(1, 0, 0, rows * 122),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = list,
		}, {
			Theme.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(110, 112),
				CellPadding = UDim2.fromOffset(8, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for i, entry in ipairs(entries) do
			colorCell(grid, entry, app.state.paints[entry.id] or 0, i)
		end
	end
end

function Machine.openCollection()
	collection.Open()
	Machine.refreshCollection()
end

-- Acciones -------------------------------------------------------------------------------------
local function jiggleBalls()
	local machine = myMachine()
	if not machine then
		return
	end
	for _, ball in ipairs(machine:GetChildren()) do
		if ball.Name == "Ball" and ball:IsA("BasePart") then
			local base = ball.CFrame
			local up = base * CFrame.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5)
			Theme.tween(ball, 0.12, { CFrame = up })
			task.delay(0.14, function()
				if ball.Parent then
					Theme.tween(ball, 0.25, { CFrame = base }, Enum.EasingStyle.Bounce)
				end
			end)
		end
	end
end

local function showColor(colorId)
	local entry = Colors.ById[colorId]
	if entry then
		DesignArt.swatch(refs.swatch, colorId)
	end
	local text, color = rarityText(colorId)
	refs.name.Text = entry and entry.name or "Sin colores"
	refs.rarityLabel.Text = text
	refs.rarityChip.BackgroundColor3 = entry and color or C.PanelSoft
	refs.rarityLabel.TextColor3 = entry and C.White or C.InkSoft
	refs.reelStroke.Color = color
	board.name.Text = entry and entry.name or "Máquina de colores"
	board.rarity.Text = text
	board.rarity.TextColor3 = color
end

function Machine.roll()
	if rolling or spinning then
		return
	end
	if os.clock() - lastRollAt < rollCooldown then
		return
	end
	rolling = true
	local ok, result = pcall(function()
		return app.remotes.Roll:InvokeServer()
	end)
	rolling = false
	if ok and not result then
		app.notify("La máquina se está recargando ⚙️", "info")
	end
end

function Machine.toggleAuto()
	local state = app.state
	if not (state and state.autoUnlocked) then
		app.notify("🔒 Compra «Auto-Rolling» en Mejoras para que la máquina tire sola", "info")
		app.openShop()
		return
	end
	app.remotes.SetAutoRoll:FireServer(not state.autoRoll)
	Theme.playSound("click", state.autoRoll and 0.9 or 1.2)
end

function Machine.onRoll(colorId, auto)
	lastRollAt = os.clock()
	local entry = Colors.ById[colorId]
	if not entry then
		return
	end
	local isNew = knownPaints ~= nil and not knownPaints[colorId]
	if knownPaints then
		knownPaints[colorId] = true
	end
	spinToken += 1
	local token = spinToken
	spinning = true
	jiggleBalls()
	task.spawn(function()
		local steps = auto and 7 or 14
		local options = {}
		for _, option in ipairs(Colors.List) do
			if not option.basic then
				table.insert(options, option.id)
			end
		end
		for i = 1, steps do
			if token ~= spinToken then
				return
			end
			DesignArt.swatch(refs.swatch, options[math.random(1, #options)])
			if i % 2 == 0 then
				Theme.playSound("click", 1.4 + i * 0.03)
			end
			task.wait(0.03 + i * (auto and 0.006 or 0.009))
		end
		if token ~= spinToken then
			return
		end
		spinning = false
		showColor(colorId)
		Theme.pop(refs.swatch, 0.5)
		local rarity = Colors.rarityOf(entry)
		if rarity.index >= 3 or isNew then
			showPopup(colorId, isNew)
		else
			Theme.playSound("success", 1.3)
		end
		if app.state then
			refs.count.Text = "Tienes x" .. (app.state.paints[colorId] or 0) .. " de este color"
		end
	end)
end

function Machine.applyState(state)
	if knownPaints == nil then
		knownPaints = {}
		for colorId, count in pairs(state.paints) do
			if count > 0 then
				knownPaints[colorId] = true
			end
		end
	end
	rollCooldown = state.rollInterval or rollCooldown
	if not spinning then
		showColor(state.lastRoll)
		refs.count.Text = Colors.ById[state.lastRoll]
				and ("Tienes x" .. (state.paints[state.lastRoll] or 0) .. " de este color")
			or "Pulsa TIRAR o acércate a la máquina"
	end
	if not state.autoUnlocked then
		refs.autoButton.SetText("🔒 Auto")
		refs.autoButton.SetVariant("ghost")
		board.auto.Text = "🔒 Auto-Rolling"
		board.auto.TextColor3 = C.InkSoft
	elseif state.autoRoll then
		refs.autoButton.SetText("🔄 Auto: Sí")
		refs.autoButton.SetVariant("mint")
		board.auto.Text = "🔄 Auto-Rolling"
		board.auto.TextColor3 = C.MintDark
	else
		refs.autoButton.SetText("⏸ Auto: No")
		refs.autoButton.SetVariant("ghost")
		board.auto.Text = "⏸ Auto-Rolling"
		board.auto.TextColor3 = C.InkSoft
	end
	Machine.refreshCollection()
end

function Machine.init(appRef)
	app = appRef
	gui = Theme.new("ScreenGui", {
		Name = "MachineHud",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildWidget()
	buildBoard()
	buildPopup()
	buildCollection()

	-- Recarga del botón y cartel sobre la máquina.
	task.spawn(function()
		while true do
			task.wait(0.05)
			local fraction = math.clamp((os.clock() - lastRollAt) / rollCooldown, 0, 1)
			refs.cooldown.Set(fraction)
			refs.rollButton.SetEnabled(fraction >= 1 and not spinning)
			if app.state and not board.gui.Adornee then
				local machine = myMachine()
				local top = machine and machine:FindFirstChild("Top")
				board.gui.Adornee = top
				board.gui.Enabled = top ~= nil
			elseif board.gui.Adornee and not board.gui.Adornee.Parent then
				board.gui.Adornee = nil
				board.gui.Enabled = false
			end
		end
	end)

	local function updateScale()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			local scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.6, 1)
			local uiScale = refs.widget:FindFirstChild("ViewportScale")
				or Theme.new("UIScale", { Name = "ViewportScale", Parent = refs.widget })
			uiScale.Scale = scale
		end
	end
	updateScale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	local popupScale = Theme.new("UIScale", { Name = "ViewportScale", Parent = refs.popup })
	local function updatePopupScale()
		local camera = Workspace.CurrentCamera
		if camera then
			popupScale.Scale = math.clamp(camera.ViewportSize.Y / 720, 0.6, 1)
		end
	end
	updatePopupScale()
end

function Machine.setVisible(visible)
	gui.Enabled = visible
end

return Machine
