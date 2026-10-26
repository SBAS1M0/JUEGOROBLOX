-- Máquina de colores: los colores solo se tiran en la máquina del taller
-- (aviso «Tirar color»). Aquí está el cartel sobre la máquina, la tarjeta con
-- el resultado de cada tirada, el aviso de colores raros y la colección.

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
local spinning = false
local spinToken = 0
local cardToken = 0
local knownPaints = nil

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

-- Tarjeta con el resultado (aparece un momento al tirar en la máquina) ------------------------
local function buildResultCard()
	local holder, body = Theme.card({
		Name = "RollResult",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(330, 84),
		Radius = 24,
		Visible = false,
		Parent = gui,
	})
	refs.card = holder
	local reel = Theme.new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = C.PanelSoft,
		Parent = body,
	}, { Theme.corner(14) })
	refs.reelStroke = Theme.stroke(C.Border, 2)
	refs.reelStroke.Parent = reel
	refs.swatch = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C.Border,
		Parent = reel,
	}, { Theme.round(), Theme.stroke(C.White, 2) })
	Theme.new("Frame", {
		Position = UDim2.fromScale(0.2, 0.14),
		Size = UDim2.fromScale(0.28, 0.2),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.45,
		Rotation = -25,
		Parent = refs.swatch,
	}, { Theme.round() })
	refs.name = Theme.label({
		Position = UDim2.fromOffset(86, 10),
		Size = UDim2.new(1, -98, 0, 28),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 21,
		Parent = body,
	})
	local chip, chipLabel = Theme.chip({
		Position = UDim2.fromOffset(86, 44),
		Size = UDim2.fromOffset(130, 24),
		Color = C.PanelSoft,
		Text = "",
		MaxTextSize = 13,
		Parent = body,
	})
	refs.rarityChip = chip
	refs.rarityLabel = chipLabel
	refs.count = Theme.label({
		Position = UDim2.fromOffset(224, 46),
		Size = UDim2.new(1, -234, 0, 20),
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = body,
	})
end

-- Cartel sobre la máquina del taller.
local function buildBoard()
	board.gui = Theme.new("BillboardGui", {
		Name = "MachineBoard",
		Size = UDim2.fromOffset(230, 112),
		StudsOffset = Vector3.new(0, 1.5, 0),
		MaxDistance = 50,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local card = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.04,
		Parent = board.gui,
	}, { Theme.corner(14), Theme.stroke(C.Border, 1) })
	board.name = Theme.label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 26),
		Text = "",
		Font = Theme.Fonts.Heavy,
		MaxTextSize = 20,
		Parent = card,
	})
	board.rarity = Theme.label({
		Position = UDim2.fromOffset(10, 33),
		Size = UDim2.new(1, -20, 0, 20),
		Text = "",
		Font = Theme.Fonts.Bold,
		MaxTextSize = 15,
		Parent = card,
	})
	board.pity = Theme.label({
		Position = UDim2.fromOffset(10, 56),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 13,
		Parent = card,
	})
	board.auto = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 89),
		Size = UDim2.fromOffset(180, 22),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.04,
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = C.MintDark,
		MaxTextSize = 13,
		Visible = false,
		Parent = board.gui,
	})
	Theme.round().Parent = board.auto
	Theme.padding(4, 10).Parent = board.auto
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
		Radius = 22,
		ShadowOffset = 6,
		ShadowTransparency = 0.8,
		Parent = refs.popup,
	})
	refs.popupHolder = cardHolder
	refs.popupStroke = card:FindFirstChildOfClass("UIStroke")
	refs.popupBand = Theme.new("Frame", {
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -48, 0, 5),
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.round() })
	refs.popupRarity = Theme.label({
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -20, 0, 34),
		Text = "",
		Font = Theme.Fonts.Heavy,
		TextColor3 = C.Ink,
		MaxTextSize = 28,
		Parent = card,
	})
	refs.popupSwatch = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.fromOffset(120, 120),
		Parent = card,
	}, { Theme.round(), Theme.stroke(C.Border, 1) })
	refs.popupSparkles = {}
	for i = 1, 6 do
		local sparkle = Theme.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(28, 28),
			Text = "✦",
			Font = Theme.Fonts.Heavy,
			TextColor3 = C.Gold,
			MaxTextSize = 20,
			Parent = card,
		})
		refs.popupSparkles[i] = sparkle
	end
	refs.popupName = Theme.label({
		Position = UDim2.fromOffset(10, 214),
		Size = UDim2.new(1, -20, 0, 36),
		Text = "",
		Font = Theme.Fonts.Heavy,
		MaxTextSize = 26,
		Parent = card,
	})
	refs.popupMult = Theme.label({
		Position = UDim2.fromOffset(10, 252),
		Size = UDim2.new(1, -20, 0, 22),
		Text = "",
		Font = Theme.Fonts.Medium,
		TextColor3 = C.InkSoft,
		MaxTextSize = 17,
		Parent = card,
	})
end

local popupToken = 0
local function showPopup(colorId, isNew)
	local entry = Colors.ById[colorId]
	local rarity = Colors.rarityOf(entry)
	popupToken += 1
	local token = popupToken
	refs.popupBand.BackgroundColor3 = rarity.color
	refs.popupRarity.TextColor3 = rarity.color:Lerp(C.Ink, 0.25)
	refs.popupRarity.Text = (isNew and "Nuevo · " or "") .. rarity.name
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
				sparkle.TextColor3 = rarity.color:Lerp(C.White, (math.sin(t * 5 + i) + 1) * 0.2)
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
		Subtitle = "Consíguelas en la máquina del taller. Cuanto más raras, más valen tus cuadros.",
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

-- Tiradas ----------------------------------------------------------------------------------------
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
	refs.name.Text = entry and entry.name or ""
	refs.rarityLabel.Text = text
	refs.rarityChip.BackgroundColor3 = entry and color or C.PanelSoft
	refs.rarityLabel.TextColor3 = entry and C.White or C.InkSoft
	refs.reelStroke.Color = color
	board.name.Text = entry and entry.name or "Máquina de colores"
	board.rarity.Text = text
	board.rarity.TextColor3 = color
end

local function hideCardLater()
	cardToken += 1
	local token = cardToken
	task.delay(2.2, function()
		if token == cardToken then
			refs.card.Visible = false
		end
	end)
end

function Machine.onRoll(colorId, auto)
	local entry = Colors.ById[colorId]
	if not entry then
		return
	end
	local isNew = knownPaints ~= nil and not knownPaints[colorId]
	if knownPaints then
		knownPaints[colorId] = true
	end
	local rarity = Colors.rarityOf(entry)
	jiggleBalls()
	if auto then
		-- Las tiradas automáticas no interrumpen: solo avisan si sale algo bueno.
		if not spinning then
			showColor(colorId)
		end
		if rarity.index >= 3 or isNew then
			app.notify(
				"🤖 «" .. entry.name .. "» · " .. rarity.name .. " x" .. string.format("%.1f", rarity.mult),
				rarity.index >= 4 and "gold" or "success"
			)
		end
		return
	end
	spinToken += 1
	local token = spinToken
	spinning = true
	cardToken += 1
	refs.card.Visible = true
	Theme.popCard(refs.card, 0.85)
	refs.name.Text = "Girando…"
	refs.rarityLabel.Text = ""
	refs.rarityChip.BackgroundColor3 = C.PanelSoft
	refs.count.Text = ""
	task.spawn(function()
		local options = {}
		for _, option in ipairs(Colors.List) do
			if not option.basic then
				table.insert(options, option.id)
			end
		end
		for i = 1, 12 do
			if token ~= spinToken then
				return
			end
			DesignArt.swatch(refs.swatch, options[math.random(1, #options)])
			if i % 2 == 0 then
				Theme.playSound("click", 1.4 + i * 0.03)
			end
			task.wait(0.03 + i * 0.009)
		end
		if token ~= spinToken then
			return
		end
		spinning = false
		showColor(colorId)
		Theme.pop(refs.swatch, 0.5)
		if app.state then
			refs.count.Text = "Tienes x" .. (app.state.paints[colorId] or 0)
		end
		if rarity.index >= 3 or isNew then
			showPopup(colorId, isNew)
		else
			Theme.playSound("success", 1.3)
		end
		hideCardLater()
	end)
end

function Machine.applyState(state)
	knownPaints = table.clone(state.discovered or {})
	if not spinning then
		showColor(state.lastRoll)
	end
	local left = (state.pityMax or 0) - (state.pity or 0)
	board.pity.Text = left <= 1 and "🎯 ¡La próxima es Raro o mejor!"
		or ("🎯 Raro o mejor seguro en " .. left .. " tiradas")
	board.auto.Visible = state.autoUnlocked == true
	board.auto.Text = state.autoRoll and "Auto-Rolling activo  [F]" or "Auto-Rolling en pausa  [F]"
	board.auto.TextColor3 = state.autoRoll and C.MintDark or C.InkSoft
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
	buildResultCard()
	buildBoard()
	buildPopup()
	buildCollection()

	-- Coloca el cartel sobre tu máquina cuando aparece tu terreno.
	task.spawn(function()
		while true do
			task.wait(0.25)
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

	local cardScale = Theme.new("UIScale", { Name = "ViewportScale", Parent = refs.card })
	local popupScale = Theme.new("UIScale", { Name = "ViewportScale", Parent = refs.popup })
	local function updateScale()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			cardScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.6, 1)
			popupScale.Scale = math.clamp(viewport.Y / 720, 0.6, 1)
		end
	end
	updateScale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

function Machine.setVisible(visible)
	gui.Enabled = visible
end

return Machine
