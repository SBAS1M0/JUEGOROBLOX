-- Punto de entrada del servidor: crea el terreno propio de cada jugador y
-- gestiona la máquina de colores, los cuadros, la galería, las ventas,
-- las mejoras, las misiones diarias y el tutorial.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Colors = require(Shared.Colors)
local Designs = require(Shared.Designs)

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local WorldBuilder = require(Services.WorldBuilder)
local VisitorService = require(Services.VisitorService)

local rng = Random.new()

-- Remotos -------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(class, name)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
local GetState = remote("RemoteFunction", "GetState")
local StateChanged = remote("RemoteEvent", "StateChanged")
local Notify = remote("RemoteEvent", "Notify")
local RollResult = remote("RemoteEvent", "RollResult")
local OpenDesigns = remote("RemoteEvent", "OpenDesigns")
local UnlockDesign = remote("RemoteFunction", "UnlockDesign")
local StartPainting = remote("RemoteFunction", "StartPainting")
local CancelPainting = remote("RemoteEvent", "CancelPainting")
local FinishPainting = remote("RemoteFunction", "FinishPainting")
local BuyUpgrade = remote("RemoteFunction", "BuyUpgrade")
local SelectStored = remote("RemoteEvent", "SelectStored")
local SkipTutorial = remote("RemoteEvent", "SkipTutorial")
local ClaimDaily = remote("RemoteFunction", "ClaimDaily")
local ClaimQuest = remote("RemoteFunction", "ClaimQuest")
local GoHome = remote("RemoteEvent", "GoHome")
remotes.Parent = ReplicatedStorage

-- Colisiones: los visitantes no empujan a los jugadores ni entre ellos.
local PLAYER_GROUP = "Jugadores"
pcall(function()
	PhysicsService:RegisterCollisionGroup(VisitorService.COLLISION_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(VisitorService.COLLISION_GROUP, VisitorService.COLLISION_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(VisitorService.COLLISION_GROUP, PLAYER_GROUP, false)
end)

local tryRoll
local renderAutoPrompt
local toggleAutoRoll
local hangPainting
local takeDownPainting

-- Estado de la sesión --------------------------------------------------------------------
local plotOf = {}
local usedSlots = {}
local sessions = {}

local function getSession(player)
	local session = sessions[player]
	if not session then
		session = { nextRoll = 0, nextAuto = 0, painting = nil, lastHome = 0 }
		sessions[player] = session
	end
	return session
end

local function notify(player, text, kind)
	Notify:FireClient(player, text, kind or "info")
end

local function openLevel(data)
	local level = 1
	for l = 2, Designs.MAX_LEVEL do
		if Designs.isLevelOpen(l, data.made) then
			level = l
		end
	end
	return level
end

local function dailyStatus(data)
	local now = os.time()
	local ready = now - data.lastDaily >= Config.DAILY_COOLDOWN
	local streak = data.dailyStreak
	if now - data.lastDaily > Config.DAILY_COOLDOWN * 2.4 then
		streak = 0
	end
	local nextStreak = math.min(streak + 1, 7)
	local amount = math.floor((80 + nextStreak * 40) * Config.questScale(openLevel(data)))
	return ready, amount, math.max(0, Config.DAILY_COOLDOWN - (now - data.lastDaily)), nextStreak
end

-- Misiones diarias -----------------------------------------------------------------------
local function ensureQuests(data)
	local day = math.floor(os.time() / 86400)
	if data.questDay == day and #data.quests == Config.QUESTS_PER_DAY then
		return
	end
	data.questDay = day
	data.questBonus = false
	data.quests = {}
	local scale = Config.questScale(openLevel(data))
	local pool = {}
	for _, def in ipairs(Config.QuestTypes) do
		table.insert(pool, def)
	end
	for _ = 1, Config.QUESTS_PER_DAY do
		local def = table.remove(pool, rng:NextInteger(1, #pool))
		local tier = rng:NextInteger(1, #def.goals)
		local goal = def.goals[tier]
		if def.scale then
			goal = math.floor(goal * scale / 10 + 0.5) * 10
		end
		table.insert(data.quests, {
			id = def.id,
			goal = goal,
			progress = 0,
			reward = math.floor((40 + 35 * tier) * scale),
			claimed = false,
		})
	end
end

-- Tutorial ----------------------------------------------------------------------------------
local pushState

local function tutorialEvent(player, data, step, amount)
	if data.tutorial ~= step then
		return
	end
	local def = Config.Tutorial[step]
	data.tutorialProgress += amount or 1
	if data.tutorialProgress >= def.goal then
		data.tutorial += 1
		data.tutorialProgress = 0
		if data.tutorial > #Config.Tutorial then
			data.tutorial = 0
			data.coins += Config.TUTORIAL_REWARD
			notify(player, "🎓 ¡Tutorial completado! +💵" .. Config.TUTORIAL_REWARD, "gold")
		end
	end
end

local function questEvent(player, data, id, amount)
	ensureQuests(data)
	for _, quest in ipairs(data.quests) do
		if quest.id == id and quest.progress < quest.goal then
			quest.progress = math.min(quest.goal, quest.progress + amount)
			if quest.progress >= quest.goal then
				notify(player, "✅ Misión lista: " .. Config.questText(quest) .. " (¡reclámala!)", "success")
			end
		end
	end
end

local function earn(player, data, amount)
	data.coins += amount
	data.earned += amount
	questEvent(player, data, "ganar", amount)
end

-- Estado para el cliente -------------------------------------------------------------------
local function buildState(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	ensureQuests(data)
	local session = getSession(player)
	local ready, amount, wait, nextStreak = dailyStatus(data)
	local plot = plotOf[player]
	return {
		coins = data.coins,
		paints = data.paints,
		unlocked = data.unlocked,
		made = data.made,
		upgrades = data.upgrades,
		openLevel = openLevel(data),
		slots = Config.gallerySlots(data.upgrades),
		displayed = #data.gallery,
		storage = data.storage,
		storageMax = Config.STORAGE_SIZE,
		autoUnlocked = Config.hasAutoRoll(data.upgrades),
		autoRoll = data.autoRoll and Config.hasAutoRoll(data.upgrades),
		lastRoll = data.lastRoll,
		rolls = data.rolls,
		discovered = data.discovered,
		pity = data.pity,
		pityMax = Config.PITY_ROLLS,
		rollInterval = Config.rollInterval(data.upgrades),
		sold = data.sold,
		earned = data.earned,
		painting = session.painting and session.painting.designId or nil,
		quests = data.quests,
		questBonus = data.questBonus,
		tutorial = data.tutorial,
		tutorialProgress = data.tutorialProgress,
		dailyReady = ready,
		dailyAmount = amount,
		dailyWait = wait,
		dailyStreak = nextStreak,
		plotName = plot and plot.model.Name or "",
	}
end

local function updateLeaderstats(player)
	local data = DataService.get(player)
	local stats = player:FindFirstChild("leaderstats")
	if data and stats then
		stats.Monedas.Value = data.coins
		stats.Vendidos.Value = data.sold
	end
end

function pushState(player)
	local state = buildState(player)
	if state then
		StateChanged:FireClient(player, state)
	end
	updateLeaderstats(player)
end

-- Visuales del terreno ----------------------------------------------------------------------
local function rarityIndex(colorId)
	return Colors.rarityOf(Colors.ById[colorId]).index
end

local function ownedSorted(data)
	local owned = {}
	for colorId, count in pairs(data and data.paints or {}) do
		if count > 0 and Colors.ById[colorId] then
			table.insert(owned, colorId)
		end
	end
	table.sort(owned, function(a, b)
		local ra, rb = rarityIndex(a), rarityIndex(b)
		if ra ~= rb then
			return ra > rb
		end
		return Colors.ById[a].index < Colors.ById[b].index
	end)
	return owned
end

local function renderShelf(plot, data)
	local owned = ownedSorted(data)
	for i, can in ipairs(plot.workshop.shelfCans) do
		local colorId = owned[i]
		if colorId then
			local rarity = rarityIndex(colorId)
			can.Color = Colors.mainColor(colorId)
			can.Transparency = 0
			can.Material = rarity >= 6 and Enum.Material.Neon
				or (rarity >= 5 and Enum.Material.Metal or Enum.Material.SmoothPlastic)
		else
			can.Color = Color3.fromRGB(230, 230, 236)
			can.Transparency = 0.7
			can.Material = Enum.Material.SmoothPlastic
		end
	end
	-- Las bolas de la máquina muestran tus colores.
	if #owned > 0 then
		for i, ball in ipairs(plot.workshop.machineBalls) do
			ball.Color = Colors.mainColor(owned[(i - 1) % #owned + 1])
		end
	end
end

local function renderMachine(plot, colorId)
	local workshop = plot.workshop
	local entry = Colors.ById[colorId]
	workshop.machineTop:SetAttribute("ColorId", entry and colorId or "")
	if entry then
		workshop.machineCan.Color = Colors.mainColor(colorId)
		workshop.machineGlow.Color = Colors.rarityOf(entry).color
	end
end

renderAutoPrompt = function(plot, data)
	if not (plot and data) then
		return
	end
	local autoPrompt = plot.workshop.autoPrompt
	autoPrompt.Enabled = Config.hasAutoRoll(data.upgrades)
	autoPrompt.ActionText = data.autoRoll and "Pausar Auto-Rolling" or "Activar Auto-Rolling"
end

local function slotEntry(data, slot)
	for i, entry in ipairs(data.gallery) do
		if entry.s == slot then
			return entry, i
		end
	end
	return nil
end

local function renderGallery(plot, data)
	local slots = Config.gallerySlots(data.upgrades)
	for i = 1, Config.GALLERY_SIZE do
		local canvas = plot.canvases[i]
		local plaque = plot.plaques[i]
		local entry = slotEntry(data, i)
		local design = entry and Designs.get(entry.d)
		canvas:SetAttribute("Locked", i > slots)
		if design then
			canvas:SetAttribute("Design", entry.d)
			canvas:SetAttribute("Colors", entry.c)
			canvas:SetAttribute("Price", entry.v)
			canvas:SetAttribute("Stars", entry.st or 1)
			plaque.Text = design.name .. "  ·  💵 " .. entry.v
		else
			canvas:SetAttribute("Design", "")
			canvas:SetAttribute("Colors", "")
			canvas:SetAttribute("Price", 0)
			canvas:SetAttribute("Stars", 0)
			plaque.Text = i > slots and "🔒 Mejora «Más paredes»" or "Marco libre"
		end
		plot.hangPrompts[i].Enabled = not design and i <= slots and #data.storage > 0
		plot.takePrompts[i].Enabled = design ~= nil
		if design then
			plot.takePrompts[i].ObjectText = design.name
		end
	end
end

-- El cuadro que llevas a la espalda (el primero del almacén).
local function renderCarry(player, data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local old = character:FindFirstChild("CarriedPainting")
	if old then
		old:Destroy()
	end
	local entry = data and data.storage[1]
	if not entry then
		return
	end
	local model = Instance.new("Model")
	model.Name = "CarriedPainting"
	local base = root.CFrame * CFrame.new(0, 0.4, 0.95) * CFrame.Angles(math.rad(-8), math.pi, 0)
	local back = Instance.new("Part")
	back.Name = "Back"
	back.Size = Vector3.new(3.4, 3.4, 0.25)
	back.CFrame = base
	back.Color = Color3.fromRGB(44, 48, 56)
	back.Material = Enum.Material.Metal
	local canvas = Instance.new("Part")
	canvas.Name = "Canvas"
	canvas.Size = Vector3.new(3, 3, 0.1)
	canvas.CFrame = base * CFrame.new(0, 0, -0.16)
	canvas.Color = Color3.fromRGB(250, 248, 242)
	for _, piece in ipairs({ back, canvas }) do
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.CastShadow = false
		piece.Parent = model
	end
	canvas:SetAttribute("Design", entry.d)
	canvas:SetAttribute("Colors", entry.c)
	canvas:SetAttribute("Stars", entry.st or 1)
	for _, piece in ipairs({ back, canvas }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = piece
		weld.Parent = piece
	end
	model.Parent = character
end

local function renderEasel(plot, designId, colors)
	plot.workshop.easelCanvas:SetAttribute("Design", designId or "")
	plot.workshop.easelCanvas:SetAttribute("Colors", colors or "")
end

local function refreshPlot(player)
	local plot = plotOf[player]
	local data = DataService.get(player)
	if plot and data then
		renderGallery(plot, data)
		renderShelf(plot, data)
	end
end

-- Terreno propio de cada jugador ----------------------------------------------------------------
local function createPlot(player, data)
	local slot
	for i = 1, Config.MAX_PLOTS do
		if not usedSlots[i] then
			slot = i
			break
		end
	end
	if not slot then
		return nil
	end
	usedSlots[slot] = player
	local plot = WorldBuilder.buildLot(slot)
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	pcall(function()
		plot.model:AddPersistentPlayer(player)
	end)
	WorldBuilder.setOwnerName(plot, player.DisplayName)
	plotOf[player] = plot
	renderGallery(plot, data)
	renderShelf(plot, data)
	renderMachine(plot, data.lastRoll)
	WorldBuilder.setDecorLevel(plot, data.upgrades.decoracion or 0)
	VisitorService.attach(plot, player)

	plot.workshop.drawPrompt.Triggered:Connect(function(who)
		if who == player then
			OpenDesigns:FireClient(player)
		end
	end)
	plot.workshop.machinePrompt.Triggered:Connect(function(who)
		if who == player then
			tryRoll(player)
		end
	end)
	plot.workshop.autoPrompt.Triggered:Connect(function(who)
		if who == player then
			toggleAutoRoll(player)
		end
	end)
	renderAutoPrompt(plot, data)
	for i = 1, Config.GALLERY_SIZE do
		plot.hangPrompts[i].Triggered:Connect(function(who)
			if who == player then
				hangPainting(player, i)
			end
		end)
		plot.takePrompts[i].Triggered:Connect(function(who)
			if who == player then
				takeDownPainting(player, i)
			end
		end)
	end
	return plot
end

local function releasePlot(player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	usedSlots[plot.slot] = nil
	VisitorService.detach(plot)
	WorldBuilder.destroyLot(plot)
end

local function teleportHome(player)
	local plot = plotOf[player]
	local character = player.Character
	if not (plot and character and character:FindFirstChild("HumanoidRootPart")) then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(plot.ownerSpawn.Position, 5)
	end)
	if character.Parent then
		character:PivotTo(plot.ownerSpawn)
	end
end

-- Máquina de colores ---------------------------------------------------------------------------
-- Suma pintura y la apunta en la colección; devuelve true si es nueva.
local function addPaint(data, colorId, amount)
	data.paints[colorId] = math.min(Config.MAX_PAINT_STACK, (data.paints[colorId] or 0) + amount)
	if not data.discovered[colorId] then
		data.discovered[colorId] = true
		return true
	end
	return false
end

local function doRoll(player, auto)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	-- Tras muchas tiradas sin suerte, la siguiente es Raro o mejor seguro.
	local guaranteed = data.pity + 1 >= Config.PITY_ROLLS
	local entry = Colors.roll(Config.luck(data.upgrades), rng, guaranteed and Config.PITY_RARITY or 1)
	local rarity = Colors.rarityOf(entry)
	local isNew = addPaint(data, entry.id, 1)
	data.lastRoll = entry.id
	data.rolls += 1
	data.pity = rarity.index >= Config.PITY_RARITY and 0 or data.pity + 1
	questEvent(player, data, "tirar", 1)
	if rarity.index >= 3 then
		questEvent(player, data, "raro", 1)
	end
	if isNew then
		local bonus = Config.discoveryBonus(rarity)
		earn(player, data, bonus)
		notify(player, "✨ Color nuevo en tu colección: +💵" .. bonus, "gold")
	end
	tutorialEvent(player, data, 1, 1)
	local plot = plotOf[player]
	if plot then
		renderMachine(plot, entry.id)
		renderShelf(plot, data)
	end
	RollResult:FireClient(player, entry.id, auto == true)
	pushState(player)
	return entry.id
end

function tryRoll(player)
	local data = DataService.get(player)
	local session = getSession(player)
	if not data then
		return nil
	end
	local now = os.clock()
	if now < session.nextRoll then
		return nil
	end
	local interval = Config.rollInterval(data.upgrades)
	session.nextRoll = now + interval
	-- El aviso de la máquina desaparece mientras gira.
	local plot = plotOf[player]
	if plot then
		local machinePrompt = plot.workshop.machinePrompt
		machinePrompt.Enabled = false
		task.delay(interval, function()
			if plotOf[player] == plot then
				machinePrompt.Enabled = true
			end
		end)
	end
	return doRoll(player, false)
end

toggleAutoRoll = function(player)
	local data = DataService.get(player)
	if not (data and Config.hasAutoRoll(data.upgrades)) then
		return
	end
	data.autoRoll = not data.autoRoll
	renderAutoPrompt(plotOf[player], data)
	notify(player, data.autoRoll and "🤖 Auto-Rolling activado" or "⏸ Auto-Rolling en pausa", "info")
	pushState(player)
end

-- Diseños y pintura -------------------------------------------------------------------------------
UnlockDesign.OnServerInvoke = function(player, designId)
	local data = DataService.get(player)
	local design = type(designId) == "string" and Designs.get(designId)
	if not (data and design) then
		return false, "Diseño no válido."
	end
	if data.unlocked[designId] then
		return false, "Ya lo tienes."
	end
	if not Designs.isLevelOpen(design.level, data.made) then
		return false, "Pinta todos los diseños del nivel " .. (design.level - 1) .. " primero."
	end
	if data.coins < design.price then
		return false, "Te faltan " .. (design.price - data.coins) .. " monedas."
	end
	data.coins -= design.price
	data.unlocked[designId] = true
	pushState(player)
	return true, "¡Desbloqueaste «" .. design.name .. "»!"
end

-- Unidades de cada color que pide la elección (las básicas no se gastan).
local function paintCost(colors)
	local cost = {}
	for _, colorId in pairs(colors) do
		local entry = Colors.ById[colorId]
		if entry and not entry.basic then
			cost[colorId] = (cost[colorId] or 0) + 1
		end
	end
	return cost
end

StartPainting.OnServerInvoke = function(player, designId, colors)
	local data = DataService.get(player)
	local session = getSession(player)
	local design = type(designId) == "string" and Designs.get(designId)
	if not (data and design) or type(colors) ~= "table" then
		return false, "Diseño no válido."
	end
	if session.painting then
		return false, "Ya estás pintando un cuadro."
	end
	if #data.storage >= Config.STORAGE_SIZE then
		return false, "Tu almacén está lleno: cuelga tus cuadros en la galería."
	end
	if not data.unlocked[designId] or not Designs.isLevelOpen(design.level, data.made) then
		return false, "Ese diseño está bloqueado."
	end
	local chosen = {}
	for _, area in ipairs(design.areas) do
		local colorId = colors[area.id]
		if type(colorId) ~= "string" or not Colors.ById[colorId] then
			return false, "Elige un color para «" .. area.name .. "»."
		end
		chosen[area.id] = colorId
	end
	local cost = paintCost(chosen)
	for colorId, amount in pairs(cost) do
		if (data.paints[colorId] or 0) < amount then
			return false, "No tienes suficiente «" .. Colors.ById[colorId].name .. "»."
		end
	end
	for colorId, amount in pairs(cost) do
		data.paints[colorId] -= amount
		if data.paints[colorId] <= 0 then
			data.paints[colorId] = nil
		end
	end
	session.painting = {
		designId = designId,
		colors = chosen,
		started = os.clock(),
		minTime = Config.minPaintTime(design, data.upgrades),
	}
	tutorialEvent(player, data, 2, 1)
	refreshPlot(player)
	pushState(player)
	return true
end

local function cancelPainting(player)
	local data = DataService.get(player)
	local session = getSession(player)
	local painting = session.painting
	if not (data and painting) then
		return
	end
	session.painting = nil
	for colorId, amount in pairs(paintCost(painting.colors)) do
		addPaint(data, colorId, amount)
	end
	refreshPlot(player)
	pushState(player)
end

CancelPainting.OnServerEvent:Connect(cancelPainting)

local function freeSlot(data)
	for slot = 1, Config.gallerySlots(data.upgrades) do
		if not slotEntry(data, slot) then
			return slot
		end
	end
	return nil
end

FinishPainting.OnServerInvoke = function(player)
	local data = DataService.get(player)
	local session = getSession(player)
	local painting = session.painting
	if not (data and painting) then
		return { ok = false, reason = "No estás pintando nada." }
	end
	local elapsed = os.clock() - painting.started
	if elapsed < painting.minTime then
		return { ok = false, reason = "¡Aún no está terminado!" }
	end
	local design = Designs.get(painting.designId)
	local madeBefore = data.made[design.id] or 0
	-- Las estrellas se calculan sobre el primer intento de entrega.
	painting.stars = painting.stars or Config.starsFor(design, data.upgrades, elapsed)
	local stars = painting.stars
	local value = Config.paintingValue(design, painting.colors, data.upgrades, madeBefore, stars)
	local encoded = Designs.encodeColors(painting.colors)
	local levelBefore = openLevel(data)
	local tierBefore = Config.masteryFor(madeBefore)

	session.painting = nil
	data.made[design.id] = madeBefore + 1
	questEvent(player, data, "pintar", 1)
	if stars >= 3 then
		questEvent(player, data, "estrellas", 1)
	end
	tutorialEvent(player, data, 3, 1)

	-- El cuadro no se vende aquí: va al almacén y lo llevas a la galería.
	local price = math.floor(value * Config.GALLERY_BONUS)
	table.insert(data.storage, 1, { d = design.id, c = encoded, v = price, st = stars })
	local result = { ok = true, value = value, price = price, stars = stars, designId = design.id }
	result.freeFrames = freeSlot(data) ~= nil

	local tierAfter = Config.masteryFor(data.made[design.id])
	if tierAfter and tierAfter ~= tierBefore then
		result.mastery = tierAfter.name
	end
	local levelAfter = openLevel(data)
	if levelAfter > levelBefore then
		result.newLevel = levelAfter
	end

	local plot = plotOf[player]
	if plot then
		renderEasel(plot, design.id, encoded)
	end
	renderCarry(player, data)
	refreshPlot(player)
	pushState(player)
	return result
end

-- Colgar y descolgar cuadros en la galería -----------------------------------------------------
hangPainting = function(player, slot)
	local data = DataService.get(player)
	if not data or #data.storage == 0 then
		return
	end
	if slot > Config.gallerySlots(data.upgrades) or slotEntry(data, slot) then
		return
	end
	local entry = table.remove(data.storage, 1)
	table.insert(data.gallery, { s = slot, d = entry.d, c = entry.c, v = entry.v, st = entry.st })
	tutorialEvent(player, data, 4, 1)
	local design = Designs.get(entry.d)
	notify(
		player,
		"🖼️ Colgaste «" .. (design and design.name or "tu cuadro") .. "». ¡Pronto vendrá un visitante!",
		"success"
	)
	renderCarry(player, data)
	refreshPlot(player)
	pushState(player)
end

takeDownPainting = function(player, slot)
	local data = DataService.get(player)
	if not data then
		return
	end
	local entry, index = slotEntry(data, slot)
	if not entry then
		return
	end
	if #data.storage >= Config.STORAGE_SIZE then
		notify(player, "Tu almacén está lleno.", "error")
		return
	end
	table.remove(data.gallery, index)
	table.insert(data.storage, 1, { d = entry.d, c = entry.c, v = entry.v, st = entry.st })
	renderCarry(player, data)
	refreshPlot(player)
	pushState(player)
end

SkipTutorial.OnServerEvent:Connect(function(player)
	local data = DataService.get(player)
	if data and data.tutorial ~= 0 then
		data.tutorial = 0
		data.tutorialProgress = 0
		notify(player, "Tutorial omitido. ¡Suerte con tu galería!", "info")
		pushState(player)
	end
end)

-- Elige qué cuadro del almacén llevas (pasa al primer puesto).
SelectStored.OnServerEvent:Connect(function(player, index)
	local data = DataService.get(player)
	if not data or type(index) ~= "number" then
		return
	end
	index = math.floor(index)
	if index < 2 or index > #data.storage then
		return
	end
	local entry = table.remove(data.storage, index)
	table.insert(data.storage, 1, entry)
	renderCarry(player, data)
	pushState(player)
end)

-- Ventas a visitantes ---------------------------------------------------------------------------
VisitorService.getProfile = function(player)
	return DataService.get(player)
end

VisitorService.availableSlots = function(player)
	local data = DataService.get(player)
	local list = {}
	if data then
		for _, entry in ipairs(data.gallery) do
			table.insert(list, entry.s)
		end
	end
	return list
end

VisitorService.onPurchase = function(player, slot, buyerName, vip)
	local data = DataService.get(player)
	if not data or not player.Parent then
		return nil
	end
	local entry, index = slotEntry(data, slot)
	if not entry then
		return nil
	end
	table.remove(data.gallery, index)
	local price = vip and math.floor(entry.v * Config.VIP_MULTIPLIER) or entry.v
	earn(player, data, price)
	data.sold += 1
	questEvent(player, data, "vender", 1)
	tutorialEvent(player, data, 5, 1)
	local design = Designs.get(entry.d)
	notify(
		player,
		(vip and "👑 ¡Coleccionista! " or "🖼️ ")
			.. tostring(buyerName)
			.. " compró «"
			.. (design and design.name or "tu cuadro")
			.. "» por 💵"
			.. price,
		"gold"
	)
	refreshPlot(player)
	pushState(player)
	return price
end

-- Mejoras, regalo diario y misiones ----------------------------------------------------------------
BuyUpgrade.OnServerInvoke = function(player, id)
	local data = DataService.get(player)
	local upgrade = type(id) == "string" and Config.UpgradeById[id]
	if not (data and upgrade) then
		return false, "Mejora no válida."
	end
	local level = data.upgrades[id] or 0
	if level >= upgrade.max then
		return false, "¡Ya está al máximo!"
	end
	local cost = Config.upgradeCost(id, level)
	if data.coins < cost then
		return false, "Te faltan " .. (cost - data.coins) .. " monedas."
	end
	data.coins -= cost
	data.upgrades[id] = level + 1
	local plot = plotOf[player]
	if plot then
		if id == "decoracion" then
			WorldBuilder.setDecorLevel(plot, level + 1)
		elseif id == "paredes" then
			renderGallery(plot, data)
		end
	end
	if id == "auto" then
		data.autoRoll = true
		renderAutoPrompt(plotOf[player], data)
	end
	pushState(player)
	return true, upgrade.name .. " subió a nivel " .. (level + 1) .. "!"
end

local function rareGift(minRarity)
	local gift
	for _ = 1, 200 do
		gift = Colors.roll(4, rng)
		if Colors.rarityOf(gift).index >= (minRarity or 3) then
			break
		end
	end
	return gift
end

ClaimDaily.OnServerInvoke = function(player)
	local data = DataService.get(player)
	if not data then
		return false
	end
	local ready, amount, _, nextStreak = dailyStatus(data)
	if not ready then
		return false
	end
	data.lastDaily = os.time()
	data.dailyStreak = nextStreak
	earn(player, data, amount)
	-- El séptimo día de racha regala un color Épico o mejor.
	local gift = rareGift(nextStreak >= 7 and 4 or 3)
	addPaint(data, gift.id, 1)
	refreshPlot(player)
	pushState(player)
	return true, amount, gift.id
end

ClaimQuest.OnServerInvoke = function(player, index)
	local data = DataService.get(player)
	if not data or type(index) ~= "number" then
		return false
	end
	ensureQuests(data)
	local quest = data.quests[index]
	if not quest or quest.claimed or quest.progress < quest.goal then
		return false
	end
	quest.claimed = true
	data.coins += quest.reward
	local result = { reward = quest.reward }
	local allDone = true
	for _, q in ipairs(data.quests) do
		if not q.claimed then
			allDone = false
		end
	end
	if allDone and not data.questBonus then
		data.questBonus = true
		local bonus = nil
		for _ = 1, 80 do
			bonus = Colors.roll(6, rng)
			if Colors.rarityOf(bonus).index >= 4 then
				break
			end
		end
		addPaint(data, bonus.id, 1)
		result.bonusColor = bonus.id
	end
	refreshPlot(player)
	pushState(player)
	return true, result
end

GetState.OnServerInvoke = function(player)
	for _ = 1, 50 do
		if DataService.get(player) then
			break
		end
		task.wait(0.2)
	end
	return buildState(player)
end

GoHome.OnServerEvent:Connect(function(player)
	local session = getSession(player)
	if os.clock() - session.lastHome >= 2 then
		session.lastHome = os.clock()
		teleportHome(player)
	end
end)

-- Jugadores -----------------------------------------------------------------------------------------
local function setCharacterGroup(character)
	local function apply(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = PLAYER_GROUP
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		apply(descendant)
	end
	character.DescendantAdded:Connect(apply)
end

local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs({ "Monedas", "Vendidos" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	player.CharacterAdded:Connect(function(character)
		setCharacterGroup(character)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)
		teleportHome(player)
		renderCarry(player, DataService.get(player))
	end)

	local data = DataService.load(player)
	if not player.Parent then
		return
	end
	-- Los jugadores que ya habían vendido no necesitan el tutorial.
	if data.tutorial ~= 0 and data.sold > 0 then
		data.tutorial = 0
	end
	if not Config.hasAutoRoll(data.upgrades) then
		data.autoRoll = false
	end
	-- Partidas anteriores: la colección empieza con los colores que ya tenías.
	for colorId, count in pairs(data.paints) do
		if count > 0 then
			data.discovered[colorId] = true
		end
	end
	ensureQuests(data)

	local plot = createPlot(player, data)
	if not plot then
		notify(player, "El servidor está lleno, prueba en otro servidor.", "error")
	end
	if player.Character then
		setCharacterGroup(player.Character)
		task.defer(teleportHome, player)
	end
	pushState(player)
	notify(player, "¡Bienvenido a tu galería! 🎨", "success")
end

-- Si el servidor estaba lleno, el primero que esperaba recibe el terreno libre.
local function assignWaitingPlayers()
	for _, waiting in ipairs(Players:GetPlayers()) do
		local data = DataService.get(waiting)
		if data and not plotOf[waiting] then
			if not createPlot(waiting, data) then
				return
			end
			teleportHome(waiting)
			pushState(waiting)
			notify(waiting, "¡Tu galería está lista! 🎨", "success")
		end
	end
end

local function onPlayerRemoving(player)
	cancelPainting(player)
	releasePlot(player)
	DataService.release(player)
	sessions[player] = nil
	task.defer(assignWaitingPlayers)
end

-- Arranque -------------------------------------------------------------------------------------------
WorldBuilder.buildSpawn()
DataService.start()
VisitorService.start()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Tiradas automáticas (solo con la mejora Auto-Rolling).
task.spawn(function()
	while true do
		task.wait(0.2)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local data = DataService.get(player)
			local session = sessions[player]
			if data and session and data.autoRoll and Config.hasAutoRoll(data.upgrades) and plotOf[player] then
				if now >= session.nextAuto then
					session.nextAuto = now + Config.autoRollInterval(data.upgrades)
					doRoll(player, true)
				end
			end
		end
	end
end)

-- Refresca el contador del regalo diario y cambia las misiones al cambiar el día.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			pushState(player)
		end
	end
end)
