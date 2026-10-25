-- Punto de entrada del servidor: crea el mundo, asigna galerías y gestiona
-- pedidos, monedas, niveles, mejoras y recompensas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Templates = require(Shared.Templates)
local Scoring = require(Shared.Scoring)

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local WorldBuilder = require(Services.WorldBuilder)
local CustomerService = require(Services.CustomerService)

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
local OpenOrder = remote("RemoteEvent", "OpenOrder")
local StartPainting = remote("RemoteFunction", "StartPainting")
local StopPainting = remote("RemoteEvent", "StopPainting")
local SubmitPainting = remote("RemoteFunction", "SubmitPainting")
local BuyUpgrade = remote("RemoteFunction", "BuyUpgrade")
local ClaimDaily = remote("RemoteFunction", "ClaimDaily")
local GoHome = remote("RemoteEvent", "GoHome")
remotes.Parent = ReplicatedStorage

-- Mundo ---------------------------------------------------------------------------
local plots = WorldBuilder.build()
local plotOf = {}
local sessions = {}

local function getSession(player)
	local session = sessions[player]
	if not session then
		session = { streak = 0, lastSubmit = 0, painting = nil }
		sessions[player] = session
	end
	return session
end

local function upgradeLevel(data, id)
	return data.upgrades[id] or 0
end

local function dailyStatus(data)
	local now = os.time()
	local ready = now - data.lastDaily >= Config.DAILY_COOLDOWN
	local streak = data.dailyStreak
	if now - data.lastDaily > Config.DAILY_COOLDOWN * 2.4 then
		streak = 0
	end
	local nextStreak = math.min(streak + 1, 7)
	local amount = 100 + data.level * 25 + nextStreak * 50
	return ready, amount, math.max(0, Config.DAILY_COOLDOWN - (now - data.lastDaily)), nextStreak
end

local function buildState(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local session = getSession(player)
	local ready, amount, wait, nextStreak = dailyStatus(data)
	local plot = plotOf[player]
	return {
		coins = data.coins,
		xp = data.xp,
		level = data.level,
		xpNext = Config.xpToNext(data.level),
		upgrades = data.upgrades,
		streak = session.streak,
		sold = data.sold,
		perfect = data.perfect,
		dailyReady = ready,
		dailyAmount = amount,
		dailyWait = wait,
		dailyStreak = nextStreak,
		plotIndex = plot and plot.index or 0,
	}
end

local function updateLeaderstats(player)
	local data = DataService.get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not (data and stats) then
		return
	end
	stats.Monedas.Value = data.coins
	stats.Nivel.Value = data.level
	stats.Obras.Value = data.sold
end

local function pushState(player)
	local state = buildState(player)
	if state then
		StateChanged:FireClient(player, state)
	end
	updateLeaderstats(player)
end

local function notify(player, text, kind)
	Notify:FireClient(player, text, kind or "info")
end

-- Galería en las paredes ---------------------------------------------------------
local function renderGallery(plot, data)
	local gallery = data and data.gallery or {}
	for i = 1, Config.GALLERY_SIZE do
		local entry = gallery[i]
		local canvas = plot.canvases[i]
		local plaque = plot.plaques[i]
		if entry and type(entry.c) == "string" and #entry.c == Config.CELLS then
			canvas:SetAttribute("Cells", entry.c)
			local template = Templates.get(entry.t)
			plaque.Text = string.rep("★", entry.s or 0) .. "  " .. (template and template.name or "Obra")
		else
			canvas:SetAttribute("Cells", "")
			plaque.Text = "Tu próxima obra"
		end
	end
	local latest = gallery[1]
	plot.easelCanvas:SetAttribute("Cells", latest and latest.c or "")
end

-- Asignación de galerías ------------------------------------------------------------
local function assignPlot(player)
	for _, plot in ipairs(plots) do
		if plot.model:GetAttribute("OwnerUserId") == 0 then
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plotOf[player] = plot
			plot.signLabel.Text = "Galería de " .. player.DisplayName
			return plot
		end
	end
	return nil
end

local function releasePlot(player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	CustomerService.detach(plot)
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.signLabel.Text = "Galería libre"
	renderGallery(plot, nil)
	WorldBuilder.setDecorLevel(plot, 0)
end

local function teleportHome(player)
	local plot = plotOf[player]
	local character = player.Character
	if not (plot and character) then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		character:PivotTo(plot.ownerSpawn)
	end
end

-- Jugadores -------------------------------------------------------------------------
local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs({ "Monedas", "Nivel", "Obras" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	local data = DataService.load(player)
	if not player.Parent then
		return
	end

	local plot = assignPlot(player)
	if plot then
		renderGallery(plot, data)
		WorldBuilder.setDecorLevel(plot, upgradeLevel(data, "decoracion"))
		CustomerService.attach(plot, player)
	else
		notify(player, "Todas las galerías están ocupadas. ¡Explora la plaza!", "error")
	end

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)
		teleportHome(player)
	end)
	if player.Character then
		task.defer(teleportHome, player)
	end

	pushState(player)
	notify(player, "¡Bienvenido a tu galería! Atiende a los clientes que entran 🎨", "success")
end

local function onPlayerRemoving(player)
	local session = sessions[player]
	if session and session.painting then
		local customer = CustomerService.getWaiting(player, session.painting)
		if customer then
			CustomerService.setPainting(customer, false)
		end
	end
	releasePlot(player)
	DataService.release(player)
	sessions[player] = nil
end

-- Clientes ---------------------------------------------------------------------------
CustomerService.getProfile = function(player)
	return DataService.get(player)
end

CustomerService.onPromptTriggered = function(player, customer)
	if customer.owner ~= player then
		notify(player, "Este cliente es de otra galería 😉", "error")
		return
	end
	if customer.state == "waiting" then
		OpenOrder:FireClient(player, customer.id)
	end
end

CustomerService.onExpired = function(player, customer)
	local session = getSession(player)
	if session.painting == customer.id then
		session.painting = nil
	end
	if session.streak > 0 then
		notify(player, "Un cliente se fue sin su obra. ¡Racha perdida! 💔", "error")
	else
		notify(player, "Un cliente se cansó de esperar 😤", "error")
	end
	session.streak = 0
	pushState(player)
end

-- Remotos: pintura ---------------------------------------------------------------------
StartPainting.OnServerInvoke = function(player, orderId)
	if type(orderId) ~= "string" then
		return false
	end
	local customer = CustomerService.getWaiting(player, orderId)
	if not customer then
		return false
	end
	local session = getSession(player)
	if session.painting and session.painting ~= orderId then
		local previous = CustomerService.getWaiting(player, session.painting)
		if previous then
			CustomerService.setPainting(previous, false)
		end
	end
	session.painting = orderId
	CustomerService.setPainting(customer, true)
	return true
end

StopPainting.OnServerEvent:Connect(function(player, orderId)
	local session = getSession(player)
	if type(orderId) ~= "string" or session.painting ~= orderId then
		return
	end
	session.painting = nil
	local customer = CustomerService.getWaiting(player, orderId)
	if customer then
		CustomerService.setPainting(customer, false)
	end
end)

local function pickLine(stars)
	local list
	if stars >= 3 then
		list = Config.HappyLines
	elseif stars >= 1 then
		list = Config.OkLines
	else
		list = Config.SadLines
	end
	return list[math.random(1, #list)]
end

SubmitPainting.OnServerInvoke = function(player, orderId, cells)
	local data = DataService.get(player)
	local session = getSession(player)
	if not data or type(orderId) ~= "string" then
		return { ok = false, reason = "Pedido no válido." }
	end
	local now = os.clock()
	if now - session.lastSubmit < 1 then
		return { ok = false, reason = "Espera un momento..." }
	end
	local customer = CustomerService.getWaiting(player, orderId)
	if not customer then
		return { ok = false, reason = "El cliente ya se fue 😢" }
	end
	local template = Templates.get(customer.order.templateId)
	if not template or not Scoring.isValidCanvas(cells, template) then
		return { ok = false, reason = "El lienzo no es válido." }
	end
	session.lastSubmit = now
	if session.painting == orderId then
		session.painting = nil
	end

	local result = Scoring.evaluate(customer.order, template, cells)
	local stars = result.stars
	local levels = data.upgrades

	if stars >= 2 then
		session.streak += 1
	else
		session.streak = 0
	end
	data.bestStreak = math.max(data.bestStreak, session.streak)

	local streakBonus = math.min(Config.MAX_STREAK_BONUS, math.max(0, session.streak - 1) * Config.STREAK_BONUS)
	local payment = math.floor(customer.order.reward * Config.STAR_PAY[stars] * (1 + streakBonus))
	local patienceLeft = math.clamp(customer.patience / customer.order.patience, 0, 1)
	local tip = 0
	if stars >= 1 then
		tip = math.floor(customer.order.reward * 0.5 * patienceLeft * Config.tipMultiplier(levels))
	end
	local xp = math.floor(template.xp * (0.4 + 0.3 * stars) * (customer.order.vip and 2 or 1))

	data.coins += payment + tip
	data.xp += xp
	data.sold += 1
	if stars >= 3 then
		data.perfect += 1
	end

	local oldLevel = data.level
	while data.xp >= Config.xpToNext(data.level) do
		data.xp -= Config.xpToNext(data.level)
		data.level += 1
	end
	local unlocked = {}
	for _, t in ipairs(Templates.List) do
		if t.level > oldLevel and t.level <= data.level then
			table.insert(unlocked, t.name)
		end
	end
	local newModes = {}
	for _, id in ipairs(Config.ModeOrder) do
		local mode = Config.Modes[id]
		if mode.level > oldLevel and mode.level <= data.level then
			table.insert(newModes, mode.name)
		end
	end

	if stars >= 1 then
		table.insert(data.gallery, 1, { t = template.id, c = cells, s = stars })
		while #data.gallery > Config.GALLERY_SIZE do
			table.remove(data.gallery)
		end
		local plot = plotOf[player]
		if plot then
			renderGallery(plot, data)
		end
	end

	local line = pickLine(stars)
	CustomerService.complete(customer, stars, line)
	pushState(player)

	return {
		ok = true,
		stars = stars,
		quality = result.quality,
		payment = payment,
		tip = tip,
		xp = xp,
		streak = session.streak,
		streakBonus = streakBonus,
		vip = customer.order.vip,
		line = line,
		levelUp = data.level > oldLevel and data.level or nil,
		unlocked = unlocked,
		newModes = newModes,
	}
end

-- Remotos: progreso ---------------------------------------------------------------------
GetState.OnServerInvoke = function(player)
	for _ = 1, 50 do
		if DataService.get(player) then
			break
		end
		task.wait(0.2)
	end
	return buildState(player)
end

BuyUpgrade.OnServerInvoke = function(player, id)
	local data = DataService.get(player)
	local upgrade = type(id) == "string" and Config.UpgradeById[id]
	if not (data and upgrade) then
		return false, "Mejora no válida."
	end
	local level = upgradeLevel(data, id)
	if level >= upgrade.max then
		return false, "¡Ya está al máximo!"
	end
	local cost = Config.upgradeCost(id, level)
	if data.coins < cost then
		return false, "Te faltan " .. (cost - data.coins) .. " monedas."
	end
	data.coins -= cost
	data.upgrades[id] = level + 1
	if id == "decoracion" then
		local plot = plotOf[player]
		if plot then
			WorldBuilder.setDecorLevel(plot, level + 1)
		end
	end
	pushState(player)
	return true, upgrade.name .. " subió a nivel " .. (level + 1) .. "!"
end

ClaimDaily.OnServerInvoke = function(player)
	local data = DataService.get(player)
	if not data then
		return false, 0
	end
	local ready, amount, _, nextStreak = dailyStatus(data)
	if not ready then
		return false, 0
	end
	data.lastDaily = os.time()
	data.dailyStreak = nextStreak
	data.coins += amount
	pushState(player)
	return true, amount
end

GoHome.OnServerEvent:Connect(function(player)
	local session = getSession(player)
	local now = os.clock()
	if now - (session.lastHome or 0) < 2 then
		return
	end
	session.lastHome = now
	teleportHome(player)
end)

-- Arranque -----------------------------------------------------------------------------
DataService.start()
CustomerService.start()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Refresca el contador del regalo diario cada minuto.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			pushState(player)
		end
	end
end)
