-- Máquina de colores: panel en pantalla, cartel sobre la máquina del taller,
-- animación de colores raros y ventana de colección.

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
local lastRollAt = 0
local rolling = false
local knownPaints = nil

local function rarityLine(colorId)
	local entry = Colors.ById[colorId]
	if not entry then
		return "¡Tira tu primer color!", C.InkSoft
	end
	local rarity = Colors.rarityOf(entry)
	return rarity.name .. "  x" .. string.format("%.1f", rarity.mult), rarity.color
end

-- Panel de la esquina -----------------------------------------------------------------------
local function buildWidget()
	local frame = Theme.new("Frame", {
		Name = "Machine",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(320, 128),
		BackgroundColor3 = C.Panel,
		Parent = gui,
	}, { Theme.corner(22), Theme.stroke(Color3.fromRGB(240, 230, 220), 3) })
	refs.widget = frame
	Theme.label({
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -32, 0, 24),
		Text = "🎨 Máquina de colores",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 21,
		Parent = frame,
	})
	refs.swatch = Theme.new("Frame", {
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.fromRGB(235, 230, 225),
		Parent = frame,
	}, { Theme.corner(23) })
	refs.swatchStroke = Theme.stroke(C.InkSoft, 3)
	refs.swatchStroke.Parent = refs.swatch
	refs.name = Theme.label({
		Position = UDim2.fromOffset(72, 34),
		Size = UDim2.new(1, -88, 0, 24),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = frame,
	})
	refs.rarity = Theme.label({
		Position = UDim2.fromOffset(72, 58),
		Size = UDim2.new(1, -88, 0, 20),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = frame,
	})
	local barBack = Theme.new("Frame", {
		Position = UDim2.fromOffset(16, 86),
		Size = UDim2.new(1, -32, 0, 6),
		BackgroundColor3 = Color3.fromRGB(240, 234, 226),
		Parent = frame,
	}, { Theme.corner(3) })
	refs.bar = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Mint, Parent = barBack },
		{ Theme.corner(3) }
	)

	local row = Theme.new("Frame", {
		Position = UDim2.fromOffset(12, 96),
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	refs.rollButton = Theme.button({
		Size = UDim2.new(1 / 3, -6, 1, -2),
		Text = "🎲 Tirar",
		Soft = true,
		Color = C.Mint,
		MaxTextSize = 18,
		Radius = 12,
		Parent = row,
		OnClick = function()
			Machine.roll()
		end,
	})
	refs.autoButton = Theme.button({
		Position = UDim2.new(1 / 3, 3, 0, 0),
		Size = UDim2.new(1 / 3, -6, 1, -2),
		Text = "🔄 Auto",
		Soft = true,
		Color = C.Mint,
		MaxTextSize = 18,
		Radius = 12,
		Parent = row,
		OnClick = function()
			Machine.toggleAuto()
		end,
	})
	Theme.button({
		Position = UDim2.new(2 / 3, 6, 0, 0),
		Size = UDim2.new(1 / 3, -6, 1, -2),
		Text = "📚 Colección",
		Soft = true,
		Color = C.Yellow,
		MaxTextSize = 16,
		Radius = 12,
		Parent = row,
		OnClick = function()
			Machine.openCollection()
		end,
	})
end

-- Cartel sobre la máquina del taller (como "Auto-Rolling / Mejora").
local function buildBoard()
	board.gui = Theme.new("BillboardGui", {
		Name = "MachineBoard",
		Size = UDim2.fromOffset(230, 150),
		StudsOffset = Vector3.new(0, 2.5, 0),
		MaxDistance = 45,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Active = true,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	board.auto = Theme.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(170, 40),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Font = Theme.Fonts.Title,
		Text = "🔄 Auto-Rolling",
		TextScaled = true,
		TextColor3 = C.PrimaryDark,
		Parent = board.gui,
	}, { Theme.corner(20), Theme.stroke(C.MintSoft, 3), Theme.padding(6) })
	board.auto.Activated:Connect(function()
		Machine.toggleAuto()
	end)
	board.upgrade = Theme.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(130, 30),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		Text = "⬆ Mejora",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(200, 120, 70),
		Parent = board.gui,
	})
	Theme.textStroke(Color3.new(1, 1, 1), 2).Parent = board.upgrade
	board.upgrade.Activated:Connect(function()
		app.openShop()
	end)
	board.info = Theme.label({
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 60),
		Text = "",
		TextColor3 = C.Ink,
		MaxTextSize = 20,
		Parent = board.gui,
	})
	Theme.textStroke(Color3.new(1, 1, 1), 2).Parent = board.info
end

-- Animación de color raro ------------------------------------------------------------------
local function buildPopup()
	refs.popup = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(300, 260),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	}, { Theme.corner(30) })
	refs.popupStroke = Theme.stroke(C.Gold, 5)
	refs.popupStroke.Parent = refs.popup
	refs.popupRarity = Theme.label({
		Position = UDim2.fromOffset(10, 14),
		Size = UDim2.new(1, -20, 0, 44),
		Text = "",
		MaxTextSize = 42,
		ZIndex = 31,
		Parent = refs.popup,
	})
	Theme.textStroke(Color3.new(1, 1, 1), 2).Parent = refs.popupRarity
	refs.popupSwatch = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(110, 110),
		ZIndex = 31,
		Parent = refs.popup,
	}, { Theme.corner(55), Theme.stroke(Color3.new(1, 1, 1), 5) })
	refs.popupName = Theme.label({
		Position = UDim2.fromOffset(10, 182),
		Size = UDim2.new(1, -20, 0, 36),
		Text = "",
		MaxTextSize = 32,
		ZIndex = 31,
		Parent = refs.popup,
	})
	refs.popupMult = Theme.label({
		Position = UDim2.fromOffset(10, 218),
		Size = UDim2.new(1, -20, 0, 28),
		Text = "",
		TextColor3 = C.PrimaryDark,
		MaxTextSize = 24,
		ZIndex = 31,
		Parent = refs.popup,
	})
end

local popupToken = 0
local function showPopup(colorId, isNew)
	local entry = Colors.ById[colorId]
	local rarity = Colors.rarityOf(entry)
	popupToken += 1
	local token = popupToken
	refs.popupStroke.Color = rarity.color
	refs.popupRarity.Text = (isNew and "¡NUEVO! " or "¡") .. string.upper(rarity.name) .. "!"
	refs.popupRarity.TextColor3 = rarity.color
	DesignArt.swatch(refs.popupSwatch, colorId)
	refs.popupName.Text = entry.name
	refs.popupMult.Text = "Multiplica el valor x" .. string.format("%.1f", rarity.mult)
	refs.popup.Visible = true
	Theme.pop(refs.popup, 0.3)
	Theme.playSound("success", 0.7 + rarity.index * 0.1)
	if rarity.index >= 4 then
		app.celebrate()
	end
	task.delay(rarity.index >= 4 and 3 or 2, function()
		if token == popupToken then
			refs.popup.Visible = false
		end
	end)
end

-- Colección ----------------------------------------------------------------------------------
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
		Size = UDim2.fromOffset(860, 600),
		Title = "📚 Mis pinturas",
		Subtitle = "Tira la máquina para descubrir colores. Cuanto más raros, más vale tu cuadro.",
	})
	refs.collectionList = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(24, 100),
		Size = UDim2.new(1, -48, 1, -120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.InkSoft,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = collection.Panel,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new(
			"UIPadding",
			{ PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }
		),
	})
end

local function colorCell(parent, entry, count, order)
	local known = entry.basic or count > 0 or (knownPaints and knownPaints[entry.id])
	local cell = Theme.new("Frame", {
		BackgroundColor3 = C.Panel,
		LayoutOrder = order,
		Parent = parent,
	}, { Theme.corner(14) })
	local swatch = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Color3.fromRGB(236, 232, 226),
		Parent = cell,
	}, { Theme.corner(26) })
	if known then
		DesignArt.swatch(swatch, entry.id)
	else
		Theme.label({
			Size = UDim2.fromScale(1, 1),
			Text = "?",
			TextColor3 = C.InkSoft,
			MaxTextSize = 30,
			Parent = swatch,
		})
	end
	Theme.label({
		Position = UDim2.fromOffset(3, 60),
		Size = UDim2.new(1, -6, 0, 18),
		Text = known and entry.name or "???",
		MaxTextSize = 16,
		Parent = cell,
	})
	Theme.label({
		Position = UDim2.fromOffset(3, 78),
		Size = UDim2.new(1, -6, 0, 16),
		Text = entry.basic and "∞" or ("x" .. count),
		TextColor3 = count > 0 and C.PrimaryDark or C.InkSoft,
		MaxTextSize = 15,
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
	local order = 0
	local sections = {}
	for i = #Colors.Rarities, 1, -1 do
		table.insert(sections, Colors.Rarities[i])
	end
	table.insert(sections, Colors.BASIC_RARITY)
	for _, rarity in ipairs(sections) do
		order += 1
		local header = Theme.label({
			Size = UDim2.new(1, 0, 0, 30),
			Text = rarity.id == "basico" and "Básicos · siempre disponibles" or string.format(
				"%s · x%.1f · %s%% por tirada",
				rarity.name,
				rarity.mult,
				string.format("%.1f", chances[rarity.id] * 100)
			),
			TextColor3 = rarity.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			LayoutOrder = order,
			Parent = list,
		})
		Theme.textStroke(Color3.new(1, 1, 1), 1).Parent = header
		order += 1
		local entries = {}
		for _, entry in ipairs(Colors.List) do
			if (rarity.id == "basico" and entry.basic) or entry.rarity == rarity.id then
				table.insert(entries, entry)
			end
		end
		local rows = math.ceil(#entries / 7)
		local grid = Theme.new("Frame", {
			Size = UDim2.new(1, 0, 0, rows * 104),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = list,
		}, {
			Theme.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(104, 98),
				CellPadding = UDim2.fromOffset(6, 6),
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

-- Acciones -----------------------------------------------------------------------------------
function Machine.roll()
	if rolling then
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
	local enabled = not (app.state and app.state.autoRoll)
	app.remotes.SetAutoRoll:FireServer(enabled)
	Theme.playSound("click", enabled and 1.2 or 0.9)
end

function Machine.onRoll(colorId)
	lastRollAt = os.clock()
	local entry = Colors.ById[colorId]
	if not entry then
		return
	end
	local isNew = knownPaints ~= nil and not knownPaints[colorId]
	if knownPaints then
		knownPaints[colorId] = true
	end
	Theme.pop(refs.swatch, 0.6)
	local rarity = Colors.rarityOf(entry)
	if rarity.index >= 3 or isNew then
		showPopup(colorId, isNew)
	else
		Theme.playSound("click", 1.4)
	end
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
	local colorId = state.lastRoll
	local entry = Colors.ById[colorId]
	if entry then
		DesignArt.swatch(refs.swatch, colorId)
		refs.name.Text = entry.name .. "  ·  x" .. (state.paints[colorId] or 0)
	else
		refs.name.Text = "Sin colores todavía"
	end
	local text, color = rarityLine(colorId)
	refs.rarity.Text = text
	refs.rarity.TextColor3 = color
	refs.swatchStroke.Color = color
	refs.autoButton.Button.Text = state.autoRoll and "🔄 Auto: Sí" or "🔄 Auto: No"
	refs.autoButton.SetBaseColor(state.autoRoll and C.Mint or Color3.fromRGB(220, 210, 200))
	board.auto.Text = state.autoRoll and "🔄 Auto-Rolling" or "⏸ Auto-Rolling"
	board.auto.TextColor3 = state.autoRoll and C.PrimaryDark or C.InkSoft
	board.info.Text = entry and (entry.name .. "\n" .. text) or "¡Tira tu primer color!"
	board.info.TextColor3 = color
	Machine.refreshCollection()
end

-- Coloca el cartel sobre la máquina de mi taller.
local function attachBoard()
	local index = app.state and app.state.plotIndex or 0
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. index)
	local workshop = plot and plot:FindFirstChild("Workshop")
	local machine = workshop and workshop:FindFirstChild("Machine")
	local top = machine and machine:FindFirstChild("Top")
	board.gui.Adornee = top
	board.gui.Enabled = top ~= nil
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

	-- Barra de recarga y cartel.
	task.spawn(function()
		while true do
			task.wait(0.1)
			local state = app.state
			if state then
				if not board.gui.Enabled then
					attachBoard()
				end
				local interval = state.rollInterval or 4
				local fraction = math.clamp((os.clock() - lastRollAt) / interval, 0, 1)
				refs.bar.Size = UDim2.fromScale(fraction, 1)
				refs.rollButton.SetEnabled(fraction >= 1)
			end
		end
	end)

	-- Escala en pantallas pequeñas.
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
end

function Machine.setVisible(visible)
	gui.Enabled = visible
end

return Machine
