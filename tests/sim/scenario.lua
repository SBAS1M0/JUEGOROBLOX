-- Partida completa: tutorial, máquina de colores manual, elegir diseño y colores,
-- pintar con estrellas, exponer en stands con tu precio, ofertas en la caja,
-- comprar y mejorar stands, ampliar la sala, mezclador de colores, misiones,
-- regalo diario, mejoras (incluido Auto-Rolling), cancelar, salir y volver.
local T = dofile(SIM_DIR .. "/test.lua")
local R, check, player = T.R, T.check, T.player
local G = R.globals
local Enum = G.Enum
local S = R.services
local pg = player.PlayerGui
local Designs, Colors, Config, DataService = T.Designs, T.Colors, T.Config, T.DataService
local UIS = S.UserInputService
local D = dofile(SIM_DIR .. "/dump.lua")
local lot = R.workspace.Plots.Lot1

local function dumpGui(name, gui)
	D.write(SIM_DIR .. "/out_" .. name .. ".json", D.gui(gui, G.typeof))
end
local function dumpWorld(name)
	D.world(R, SIM_DIR .. "/out_" .. name, function(part)
		return D.artOf(part, Designs, Colors)
	end)
end
local function buttonStarting(root, prefix)
	for _, d in ipairs(root:GetDescendants()) do
		if d.ClassName == "TextButton" and d.Text:sub(1, #prefix) == prefix then
			return d
		end
	end
	return nil
end
local function click(root, prefix)
	local b = buttonStarting(root, prefix)
	check(b ~= nil, "button '" .. prefix .. "' found")
	T.fireClick(b)
	return b
end
local function tile(name)
	return pg.HUD.Menu[name].Face
end
local function closeWindow(gui)
	local close = T.findAll(gui, function(d)
		return d.Name == "Close" and d.ClassName == "TextButton" and d.Parent.Name == "Header"
	end)[1]
	T.fireClick(close)
	R.run(0.1)
end
local function namedButton(root, name)
	return T.findAll(root, function(d)
		return d.Name == name and d.ClassName == "TextButton"
	end)[1]
end
local function isShown(gui)
	local node = gui
	while node and node.ClassName ~= "PlayerGui" do
		if node.ClassName == "ScreenGui" then
			if not node.Enabled then
				return false
			end
		elseif R.isA(node.ClassName, "GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end
local function totalPaints(data)
	local total = 0
	for _, n in pairs(data.paints) do
		total = total + n
	end
	return total
end
local data = DataService.get(player)
local machinePrompt = lot.Workshop.Machine.Body.ProximityPrompt
local autoPrompt = lot.Workshop.Machine.Dispenser.ProximityPrompt
local drawPrompt = lot.Workshop.DrawPrompt.ProximityPrompt

-- Tira en la máquina (espera a que el aviso vuelva a estar disponible).
local function rollAtMachine()
	for _ = 1, 200 do
		if machinePrompt.Enabled then
			break
		end
		R.run(0.1)
	end
	machinePrompt.Triggered:Fire(player)
	R.run(0.1)
end

local function openDesigns()
	drawPrompt.Triggered:Fire(player)
	R.run(0.2)
end

local Exhibition = R.require(S.ReplicatedStorage.Shared.Exhibition)
local function spotOf(i)
	return lot.Gallery.Spots["Spot" .. i]
end
local function standOf(i)
	return lot.Gallery.Stands:FindFirstChild("Stand" .. i)
end
local function openStand(i)
	local prompt = spotOf(i).StandPrompt
	check(prompt.Enabled, "stand " .. i .. " has a prompt (" .. prompt.ActionText .. ")")
	prompt.Triggered:Fire(player)
	R.run(0.3)
end
-- Expone el primer cuadro del almacén en el stand i (con un atajo de precio).
local function exhibitOn(i, preset)
	openStand(i)
	check(pg.StandPanel.Window.Visible, "stand panel open")
	if preset then
		click(pg.StandPanel, preset)
		R.run(0.1)
	end
	click(pg.StandPanel, "🖼️ Exponer")
	R.run(0.3)
end

local catcher = T.findAll(pg.Painter, function(d)
	return d.Name == "PaintInput"
end)[1]
local function move(x, y)
	UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = R.v2(x * 512, y * 512) })
	R.step(1 / 30)
end
-- Barre en filas una zona del lienzo, como haría una persona.
local function sweep(x0, y0, x1, y1)
	local r = Config.brushRadius(data.upgrades)
	local step = r * 1.1
	catcher.InputBegan:Fire({
		UserInputType = Enum.UserInputType.MouseButton1,
		Position = R.v2(x0 * 512, y0 * 512),
	})
	local row = 0
	local y = y0
	while y <= y1 + r * 0.5 do
		local forward = row % 2 == 0
		local x = forward and x0 or x1
		while (forward and x <= x1) or (not forward and x >= x0) do
			move(x, math.min(y, 1))
			x = x + (forward and step or -step)
		end
		row = row + 1
		y = y + r * 1.4
	end
	UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 }, false)
end
-- Pinta color por color: elige cada bote de la paleta y barre sus figuras.
local function paintByColor(design, afterFirst)
	for index, area in ipairs(design.areas) do
		T.fireClick(namedButton(pg.Painter, "Paint_" .. area.id))
		R.run(0.1)
		local x0, y0, x1, y1 = 1, 1, 0, 0
		for _, shape in ipairs(design.shapes) do
			if shape.area == area.id and shape.visible > 0 then
				local b = 0.5 * math.sqrt(shape.w * shape.w + shape.h * shape.h)
				x0, y0 = math.min(x0, shape.x - b), math.min(y0, shape.y - b)
				x1, y1 = math.max(x1, shape.x + b), math.max(y1, shape.y + b)
			end
		end
		sweep(math.max(0, x0), math.max(0, y0), math.min(1, x1), math.min(1, y1))
		if index == 1 and afterFirst then
			afterFirst(area)
		end
	end
	R.run(1.5)
end

print("== Fresh start: rolling only at the machine, tutorial")
check(data.autoRoll == false and not Config.hasAutoRoll(data.upgrades), "no auto-roll at start")
check(S.ReplicatedStorage.Remotes:FindFirstChild("Roll") == nil, "no remote to roll from anywhere")
check(not pg.MachineHud.RollResult.Visible, "roll result card hidden")
check(autoPrompt.Enabled == false, "auto-roll prompt hidden without the upgrade")
check(data.tutorial == 1, "tutorial starts at step 1")
check(pg.TutorialGuide.Panel.Visible, "tutorial guide panel visible")
check(not pg.HUD.Quests.Visible, "quests start folded")
check(not pg.HUD.Carry.Visible, "nothing carried yet")
local highlight = T.findAll(R.workspace, function(d)
	return d.ClassName == "Highlight"
end)[1]
check(highlight ~= nil and highlight.Adornee == lot.Workshop.Machine, "machine highlighted for step 1")
local spawnDistance = (player.Character.HumanoidRootPart.Position - lot.Workshop.Machine.Body.Position).Magnitude
check(spawnDistance < 25, "player spawns in the workshop next to the machine (" .. math.floor(spawnDistance) .. ")")
dumpGui("hud", pg.HUD)
dumpGui("guide", pg.TutorialGuide)
R.run(10)
check(totalPaints(data) == 0, "machine does not roll by itself")

print("== Rolls at the machine")
machinePrompt.Triggered:Fire(player)
R.run(0.2)
check(totalPaints(data) == 1, "machine prompt gives a paint")
check(data.coins > Config.START_COINS, "discovery bonus for a new color (+" .. (data.coins - Config.START_COINS) .. ")")
check(data.discovered[data.lastRoll] == true, "color saved in the collection")
check(machinePrompt.Enabled == false, "prompt hidden while the machine spins")
check(pg.MachineHud.RollResult.Visible, "result card shown")
machinePrompt.Triggered:Fire(player)
R.run(0.2)
check(totalPaints(data) == 1, "cooldown respected")
R.run(1)
dumpGui("machine", pg.MachineHud)
R.run(2.5)
check(machinePrompt.Enabled, "prompt back after cooldown")
check(not pg.MachineHud.RollResult.Visible, "result card hides by itself")
rollAtMachine()
rollAtMachine()
R.run(2)
check(totalPaints(data) == 3, "three rolls (" .. totalPaints(data) .. ")")
check(data.tutorial == 2, "tutorial advanced to step 2")
check(highlight.Parent == nil or highlight.Adornee ~= lot.Workshop.Machine, "highlight moved")
local path = T.findAll(R.workspace, function(d)
	return d.ClassName == "Beam" and d.Name == "TutorialPath"
end)[1]
check(path ~= nil and path.Enabled, "glowing path leads to the easel")
check(lot.Workshop.Machine.Top:GetAttribute("ColorId") ~= "", "machine shows last color")
check(pg.MachineBoard.Enabled, "machine billboard attached")
for _ = 1, 6 do
	rollAtMachine()
end
R.run(3)

print("== Guaranteed rare after a bad streak")
data.pity = Config.PITY_ROLLS - 1
rollAtMachine()
R.run(2)
check(Colors.rarityOf(Colors.ById[data.lastRoll]).index >= Config.PITY_RARITY, "pity roll is Raro or better")
check(data.pity == 0, "pity counter resets")
local pityLabel = T.findAll(pg.MachineBoard, function(d)
	return d.ClassName == "TextLabel" and d.Text:find("seguro en") ~= nil
end)[1]
check(pityLabel ~= nil, "machine shows the guaranteed counter: " .. (pityLabel and pityLabel.Text or "?"))

print("== Pick design at the easel")
openDesigns()
check(pg.DesignPicker.Window.Visible, "design picker open")
dumpGui("picker", pg.DesignPicker)
T.fireClick(namedButton(pg.DesignPicker, "globo"))
click(pg.DesignPicker, "Empezar a pintar")
R.run(0.3)
check(not pg.DesignPicker.Window.Visible and pg.ColorPicker.Window.Visible, "color picker open")

-- El color que más tengas para la primera área.
local best, bestCount = nil, 0
for id, n in pairs(data.paints) do
	if n > bestCount then
		best, bestCount = id, n
	end
end
local cell = namedButton(pg.ColorPicker, best)
check(cell ~= nil, "owned color cell shown: " .. best)
T.fireClick(cell)
dumpGui("colors", pg.ColorPicker)
local before = data.paints[best]
click(pg.ColorPicker, "Empezar a pintar")
R.run(0.3)
check(pg.Painter.Enabled, "painter open")
check((data.paints[best] or 0) == before - 1, "paint consumed")
check(R.controlsEnabled == false, "controls disabled while painting")
check(not pg.HUD.Enabled, "hud hidden while painting")
check(data.tutorial == 3, "tutorial step 3 (paint)")
check(pg.Painter:FindFirstChild("Coach", true).Visible, "coach asks to pick a color first")
dumpGui("painter_start", pg.Painter)

print("== Paint color by color")
local globo = Designs.get("globo")
sweep(0.05, 0.05, 0.95, 0.3)
local strokes = T.findAll(pg.Painter, function(d)
	return d.ClassName == "CanvasGroup"
end)
check(#strokes == 0, "without a color the brush leaves no paint")
local firstArea
paintByColor(globo, function(area)
	firstArea = area
	local painted, others = 0, 0
	for _, d in ipairs(T.findAll(pg.Painter, function(x)
		return x.ClassName == "CanvasGroup"
	end)) do
		local index = tonumber(d.Parent.Name:match("^S(%d+)$"))
		if index and globo.shapes[index].area == area.id then
			painted = painted + 1
		elseif index then
			others = others + 1
		end
	end
	check(others == 0, "only shapes of the chosen color take paint")
	dumpGui("painter_mid", pg.Painter)
	-- Al elegir el siguiente color sus zonas se resaltan con su número.
	local nextArea = globo.areas[2]
	T.fireClick(namedButton(pg.Painter, "Paint_" .. nextArea.id))
	R.run(0.5)
	local numbers = T.findAll(pg.Painter, function(d)
		return d.Name:match("^Number%d+$") ~= nil and d.Visible
	end)
	check(#numbers > 0, "zones show their color number (" .. #numbers .. ")")
	local strong = 0
	for _, label in ipairs(numbers) do
		local index = tonumber(label.Name:match("%d+"))
		if globo.shapes[index].area == nextArea.id and label.BackgroundTransparency == 0 then
			strong = strong + 1
		end
	end
	check(strong > 0, "numbers of the chosen color stand out")
	dumpGui("painter_focus", pg.Painter)
end)
check(firstArea ~= nil, "painted the first color")
dumpGui("painter", pg.Painter)
local carryButton = buttonStarting(pg.Painter, "🖼️ Llevar")
check(carryButton ~= nil and isShown(carryButton), "completion window shown")
T.fireClick(carryButton)
R.run(0.5)
check(not pg.Painter.Enabled and R.controlsEnabled, "painter closed")
check(#data.storage == 1 and #data.gallery == 0, "painting stored, not sold")
check(data.sold == 0, "nothing sold instantly")
check(data.storage[1].st == 3, "a good painting session earns 3 stars (" .. tostring(data.storage[1].st) .. ")")
local carried = player.Character:FindFirstChild("CarriedPainting")
check(carried ~= nil and carried.Canvas:GetAttribute("Design") == "globo", "painting carried on the back")
check(carried.Canvas:FindFirstChild("ArtGui") ~= nil, "carried painting shows its art")
check(pg.HUD.Carry.Visible, "carry card shows the painting")
check(data.tutorial == 4, "tutorial step 4 (hang it)")
check(data.made.globo == 1, "made counter")
dumpGui("hud_carry", pg.HUD)

print("== Exhibit it on a stand with your own price")
check(Exhibition.countStands(data.stands) == 1 and data.stands[1] == 1, "starts with one free stand (an easel)")
check(standOf(1) ~= nil and standOf(1):FindFirstChild("Canvas", true) ~= nil, "free easel built in the room")
check(spotOf(2):GetAttribute("Open") and not spotOf(2):GetAttribute("Owned"), "other spots are for sale")
check(spotOf(2).StandPrompt.ActionText == "Comprar stand", "empty spot offers to buy a stand")
check(spotOf(2):FindFirstChild("SpotTag") ~= nil and spotOf(2).SpotTag.Enabled, "empty spot shows the ＋ Stand tag")
check(spotOf(1).StandPrompt.ActionText == "Exponer cuadro", "stand offers to exhibit the carried painting")
openStand(1)
check(pg.StandPanel.Window.Visible, "stand panel opens")
local market = Exhibition.marketPrice(data.storage[1].v, 1)
local marketLabel = T.findAll(pg.StandPanel, function(d)
	return d.ClassName == "TextLabel" and d.Text:find("Precio medio: ") ~= nil
end)[1]
check(marketLabel ~= nil and marketLabel.Text:find(tostring(market), 1, true) ~= nil, "panel shows the average price: " .. (marketLabel and marketLabel.Text or "?"))
click(pg.StandPanel, "+")
click(pg.StandPanel, "+")
R.run(0.1)
local bandText = Exhibition.band(Exhibition.clampPrice(market + 2 * Exhibition.priceStep(market), market) / market).text
local bandLabel = T.findAll(pg.StandPanel, function(d)
	return d.ClassName == "TextLabel" and d.Text == bandText
end)[1]
check(bandLabel ~= nil, "meter explains how fast it will sell: " .. bandText)
dumpGui("stand", pg.StandPanel)
local expected = Exhibition.clampPrice(market + 2 * Exhibition.priceStep(market), market)
click(pg.StandPanel, "🖼️ Exponer")
R.run(0.3)
check(not pg.StandPanel.Window.Visible, "panel closes after exhibiting")
check(#data.storage == 0 and #data.gallery == 1, "painting on the stand")
check(data.gallery[1].p == expected, "your price is used (" .. data.gallery[1].p .. " vs market " .. market .. ")")
check(player.Character:FindFirstChild("CarriedPainting") == nil, "hands free again")
local canvas = standOf(1):FindFirstChild("Canvas", true)
check(canvas:GetAttribute("Design") == "globo", "canvas shows design")
check(canvas:GetAttribute("Price") == expected, "canvas shows your price")
check(#canvas.ArtGui.Art:GetDescendants() > 5, "stand art rendered")
check(canvas.ArtGui.Art.PriceTag.Visible, "price tag on the painting")
check(spotOf(1).StandPrompt.ActionText == "Gestionar", "stand now offers to manage the painting")
check(data.tutorial == 5, "tutorial step 5 (offer at the caja)")

print("== A visitor goes to the caja and makes an offer")
local coins0 = data.coins
local sawVisitor, offerCard = false, nil
for _ = 1, 120 do
	R.run(0.5)
	if #lot.Visitors:GetChildren() > 0 then
		sawVisitor = true
	end
	offerCard = T.findAll(pg.Offers, function(d)
		return d.Name:match("^Offer%d+$") ~= nil
	end)[1]
	if offerCard then
		break
	end
end
check(sawVisitor, "visitor appeared")
check(offerCard ~= nil, "offer card shown")
local visitor = lot.Visitors:GetChildren()[1]
check(visitor ~= nil and (visitor:GetAttribute("Reaction") or ""):find("Te doy") ~= nil, "visitor asks at the caja: " .. tostring(visitor and visitor:GetAttribute("Reaction")))
local queueSpot = lot.GalleryInterior.Caja
check((visitor.HumanoidRootPart.Position - queueSpot.Register.Position).Magnitude < 10, "visitor is at the caja")
dumpGui("offer", pg.Offers)
dumpWorld("world")
local counterButton = buttonStarting(pg.Offers, "Pedir")
check(counterButton ~= nil, "counter-offer button")
local counterPrice = tonumber((counterButton.Text:gsub("[^%d]", "")))
T.fireClick(counterButton)
R.run(4)
check(data.sold == 1, "deal closed after the counter-offer")
check(data.coins - coins0 >= counterPrice - 1, "paid the counter price (+" .. (data.coins - coins0) .. ")")
check(#data.gallery == 0, "stand emptied")
check(data.tutorial == 0, "tutorial completed")
check(not pg.TutorialGuide.Panel.Visible, "tutorial guide hidden")
check(visitor:FindFirstChild("BoughtPainting") ~= nil, "buyer carries the painting out")
R.run(40)
check(#lot.Visitors:GetChildren() == 0, "visitor left")
check(#T.findAll(pg.Offers, function(d)
	return d.Name:match("^Offer%d+$") ~= nil
end) == 0, "offer card closed")

print("== Buy a stand, store and paint another, manage it")
data.coins = data.coins + 200
local coinsBefore = data.coins
local standCost = Exhibition.standCost(1)
spotOf(2).StandPrompt.Triggered:Fire(player)
R.run(0.3)
check(data.stands[2] == 1 and data.coins == coinsBefore - standCost, "bought a second stand for " .. standCost)
check(standOf(2):FindFirstChild("Canvas", true) ~= nil, "second easel appears")
check(not spotOf(2).SpotTag.Enabled, "tag hidden once bought")
openDesigns()
click(pg.DesignPicker, "Empezar a pintar")
click(pg.ColorPicker, "Empezar a pintar")
R.run(0.2)
paintByColor(globo)
click(pg.Painter, "🎨 Guardarlo")
R.run(0.5)
check(#data.storage == 1, "second painting stored")
check(pg.DesignPicker.Window.Visible, "design picker reopened to paint another")
closeWindow(pg.DesignPicker)
exhibitOn(2)
check(#data.gallery == 1 and #data.storage == 0, "exhibited on stand 2")
openStand(2)
click(pg.StandPanel, "+50%")
click(pg.StandPanel, "💾 Guardar")
R.run(0.3)
local onStand = data.gallery[1]
check(onStand.p == Exhibition.roundPrice(Exhibition.marketPrice(onStand.v, 1) * 1.5), "price changed to +50% (" .. onStand.p .. ")")
click(pg.StandPanel, "↩ Retirar")
R.run(0.3)
check(#data.gallery == 0 and #data.storage == 1, "taken down back to storage")
data.storage[2] = { d = "globo", c = data.storage[1].c, v = 1, st = 1 }
S.ReplicatedStorage.Remotes.SelectStored:FireServer(2)
R.run(0.2)
check(data.storage[1].v == 1, "chose which painting to carry")
table.remove(data.storage, 1)
exhibitOn(2, "Precio medio")
check(#data.gallery == 1, "exhibited again")

print("== Upgrade a stand")
data.coins = data.coins + 5000
openStand(2)
click(pg.StandPanel, "Mejorar")
R.run(0.3)
check(data.stands[2] == 2, "stand upgraded to a gallery panel")
check(standOf(2):GetAttribute("Tier") == 2, "stand rebuilt with the new quality")
check(standOf(2):FindFirstChild("Canvas", true):GetAttribute("Design") == "globo", "painting kept on the upgraded stand")
click(pg.StandPanel, "Mejorar")
R.run(0.3)
check(data.stands[2] == 3, "stand upgraded to the luxury showcase")
dumpGui("stand_full", pg.StandPanel)
closeWindow(pg.StandPanel)

print("== Color mixer")
data.paints.coco = 2
data.paints.arena = 1
lot.Workshop.Mixer.Body.MixPrompt.Triggered:Fire(player)
R.run(0.3)
check(pg.Mixer.Window.Visible, "mixer window open")
click(pg.Mixer, "Auto")
R.run(0.1)
dumpGui("mixer", pg.Mixer)
local uncommonBefore = 0
for _, entry in ipairs(Colors.ByRarity.pococomun) do
	uncommonBefore = uncommonBefore + (data.paints[entry.id] or 0)
end
click(pg.Mixer, "🧪")
R.run(0.5)
local uncommonAfter = 0
for _, entry in ipairs(Colors.ByRarity.pococomun) do
	uncommonAfter = uncommonAfter + (data.paints[entry.id] or 0)
end
check((data.paints.coco or 0) == 0 and (data.paints.arena or 0) == 0 or totalPaints(data) > 0, "common paints used")
check(uncommonAfter == uncommonBefore + 1, "mixer gives one Poco común color")
check(not pg.Mixer.Window.Visible, "mixer closes to reveal the color")
local ok2 = S.ReplicatedStorage.Remotes.MixColors:InvokeServer("comun", { coco = 99 })
check(ok2 == false, "cannot mix paints you don't have")

print("== Quests")
check(#data.quests == Config.QUESTS_PER_DAY, "daily quests generated")
for _, quest in ipairs(data.quests) do
	quest.progress = quest.goal
end
local coins2 = data.coins
rollAtMachine()
R.run(2)
T.fireClick(tile("quests"))
R.run(0.3)
check(pg.HUD.Quests.Visible, "quests unfold from the menu")
dumpGui("hud2", pg.HUD)
for _ = 1, Config.QUESTS_PER_DAY do
	local claim = T.findAll(pg.HUD.Quests, function(d)
		return d.ClassName == "TextButton" and d.Text:sub(1, 4) == "💵" and d.Active
	end)[1]
	check(claim ~= nil, "claim button available")
	T.fireClick(claim)
	R.run(0.3)
end
check(data.coins > coins2, "quest rewards paid (+" .. (data.coins - coins2) .. ")")
check(data.questBonus == true, "all-quests bonus given")
for _, quest in ipairs(data.quests) do
	check(quest.claimed, "quest " .. quest.id .. " claimed")
end
check(R.services.ReplicatedStorage.Remotes.ClaimQuest:InvokeServer(1) == false, "cannot claim twice")
T.fireClick(tile("quests"))
R.run(0.1)
check(not pg.HUD.Quests.Visible, "quests fold again")

print("== Daily gift")
T.fireClick(tile("daily"))
R.run(0.3)
check(pg.Daily.Window.Visible, "daily window open")
dumpGui("daily", pg.Daily)
local c0 = data.coins
click(pg.Daily, "Reclamar")
R.run(0.5)
check(data.coins > c0 and data.dailyStreak == 1, "daily claimed (streak " .. data.dailyStreak .. ")")
check(not pg.Daily.Window.Visible, "daily window closed")
T.fireClick(tile("daily"))
R.run(0.2)
check(buttonStarting(pg.Daily, "Vuelve en") ~= nil, "daily shows countdown")
closeWindow(pg.Daily)

print("== Unlock designs & levels")
data.coins = 10000000
for _, id in ipairs({ "sol", "taza", "gatito" }) do
	openDesigns()
	T.fireClick(namedButton(pg.DesignPicker, id))
	click(pg.DesignPicker, "Desbloquear")
	check(data.unlocked[id], "unlocked " .. id)
	closeWindow(pg.DesignPicker)
end
openDesigns()
T.fireClick(namedButton(pg.DesignPicker, "hongo"))
check(buttonStarting(pg.DesignPicker, "Pinta todo") ~= nil, "level 2 locked")
closeWindow(pg.DesignPicker)

print("== Shop (all upgrades)")
T.fireClick(tile("shop"))
R.run(0.2)
check(pg.Shop.Window.Visible, "shop open")
dumpGui("shop", pg.Shop)
for _ = 1, 16 do
	local btns = T.findAll(pg.Shop, function(d)
		return d.ClassName == "TextButton" and d.Text:sub(1, 4) == "💵"
	end)
	for _, b in ipairs(btns) do
		T.fireClick(b)
	end
end
for _, upgrade in ipairs(Config.Upgrades) do
	check((data.upgrades[upgrade.id] or 0) == upgrade.max, upgrade.id .. " maxed")
end
check(#lot.Decor:GetChildren() == 6, "decor built")
check(lot.GalleryInterior.Caja:FindFirstChild("Cajero") ~= nil, "cashier behind the counter")
closeWindow(pg.Shop)

print("== Expand the gallery")
data.coins = 10000000
check(lot.Gallery.Rooms:FindFirstChild("Expansion2") ~= nil, "hoarding closes the next room")
local hoarding = lot.Gallery.Rooms.Expansion2.Sign.ExpandPrompt
hoarding.Triggered:Fire(player)
R.run(0.3)
check(data.rooms == 1, "cannot expand without enough stands")
for i = 3, 6 do
	spotOf(i).StandPrompt.Triggered:Fire(player)
	R.run(0.2)
end
check(Exhibition.countStands(data.stands) == 6, "six stands bought")
check(standOf(3):FindFirstChild("Canvas", true) ~= nil, "wall frame stand built")
hoarding.Triggered:Fire(player)
R.run(1.5)
check(data.rooms == 2, "gallery expanded")
check(lot.Gallery.Rooms:FindFirstChild("Room2") ~= nil, "new room built")
check(lot.Gallery.Rooms:FindFirstChild("Expansion2") == nil, "hoarding removed")
check(lot.Gallery.Rooms:FindFirstChild("Expansion3") ~= nil, "next hoarding appears in the new room")
check(spotOf(9):GetAttribute("Open") and spotOf(9).StandPrompt.Enabled, "new room has spots for stands")
spotOf(9).StandPrompt.Triggered:Fire(player)
R.run(0.3)
check(data.stands[9] == 1, "stand bought in the new room")

print("== Auto-Rolling after buying it")
check(data.autoRoll == true, "auto-roll enabled on purchase")
check(autoPrompt.Enabled and autoPrompt.ActionText == "Pausar Auto-Rolling", "auto prompt appears on the machine")
local p0 = totalPaints(data)
R.run(6)
check(totalPaints(data) > p0, "machine rolls by itself now (" .. p0 .. " -> " .. totalPaints(data) .. ")")
check(not pg.MachineHud.RollResult.Visible, "auto rolls don't pop the result card")
autoPrompt.Triggered:Fire(player)
R.run(0.3)
check(data.autoRoll == false and autoPrompt.ActionText == "Activar Auto-Rolling", "auto-roll paused at the machine")
p0 = totalPaints(data)
R.run(5)
check(totalPaints(data) == p0, "no rolls while paused")
autoPrompt.Triggered:Fire(player)
R.run(0.3)
check(data.autoRoll == true, "auto-roll on again")

print("== Paint level 1 with the bucket, color by color")
local nextFrame = 3
for _, id in ipairs({ "sol", "taza", "gatito" }) do
	openDesigns()
	T.fireClick(namedButton(pg.DesignPicker, id))
	click(pg.DesignPicker, "Empezar a pintar")
	click(pg.ColorPicker, "✨ Mejores")
	click(pg.ColorPicker, "Empezar a pintar")
	R.run(0.2)
	click(pg.Painter, "🪣")
	local design = Designs.get(id)
	for _, area in ipairs(design.areas) do
		T.fireClick(namedButton(pg.Painter, "Paint_" .. area.id))
		for i, shape in ipairs(design.shapes) do
			if shape.area == area.id then
				for gx = 0, 39 do
					local found = false
					for gy = 0, 39 do
						local x, y = (gx + 0.5) / 40, (gy + 0.5) / 40
						if Designs.shapeAt(design, x, y) == i then
							catcher.InputBegan:Fire({
								UserInputType = Enum.UserInputType.MouseButton1,
								Position = R.v2(x * 512, y * 512),
							})
							found = true
							break
						end
					end
					if found then
						break
					end
				end
				R.run(0.1)
			end
		end
	end
	R.run(3)
	click(pg.Painter, "🖼️ Llevar")
	R.run(0.3)
	check(data.made[id] == 1, "painted " .. id .. " with the bucket")
	exhibitOn(nextFrame, "Rápido")
	nextFrame = nextFrame + 1
end
openDesigns()
T.fireClick(namedButton(pg.DesignPicker, "hongo"))
click(pg.DesignPicker, "Desbloquear")
check(data.unlocked.hongo, "level 2 design unlocked")
closeWindow(pg.DesignPicker)

print("== Cancel refunds paints")
data.autoRoll = false
local paintsBefore = totalPaints(data)
openDesigns()
T.fireClick(namedButton(pg.DesignPicker, "hongo"))
click(pg.DesignPicker, "Empezar a pintar")
click(pg.ColorPicker, "✨ Mejores")
click(pg.ColorPicker, "Empezar a pintar")
R.run(0.2)
check(pg.Painter.Enabled, "painting hongo")
check(totalPaints(data) < paintsBefore, "paints taken")
click(pg.Painter, "✕ Salir")
click(pg.Painter, "¿Salir?")
R.run(0.2)
check(not pg.Painter.Enabled, "painter closed on cancel")
check(totalPaints(data) == paintsBefore, "paints refunded (" .. paintsBefore .. " -> " .. totalPaints(data) .. ")")

print("== Storage limit")
local saved = data.storage
data.storage = {}
for i = 1, Config.STORAGE_SIZE do
	data.storage[i] = { d = "globo", c = "", v = 1, st = 1 }
end
local ok, message = S.ReplicatedStorage.Remotes.StartPainting:InvokeServer("globo", Designs.defaultColors(globo))
check(not ok and tostring(message):find("almacén") ~= nil, "full storage blocks a new painting")
data.storage = saved

print("== Collection & home")
T.fireClick(tile("colors"))
R.run(0.2)
check(pg.Collection.Window.Visible, "collection open")
dumpGui("collection", pg.Collection)
closeWindow(pg.Collection)
local character = player.Character
character:PivotTo(G.CFrame.new(lot:GetPivot().Position + G.Vector3.new(150, 5, 150)))
T.fireClick(tile("home"))
R.run(0.5)
local distance = (character.HumanoidRootPart.Position - lot.Workshop.Machine.Body.Position).Magnitude
check(distance < 25, "home button brings you back to the workshop (" .. math.floor(distance) .. ")")

print("== Visitors buy hung paintings")
data.autoRoll = true
local sold0 = data.sold
R.run(150)
dumpWorld("world2")
check(data.sold >= sold0 + 2, "visitors keep buying (sold " .. data.sold .. ")")

print("== Leave & rejoin")
data.storage = { { d = "sol", c = "", v = 10, st = 2 } }
-- Sin Auto-Rolling para que las monedas no cambien al volver a entrar.
data.autoRoll = false
local savedState = { coins = data.coins, sold = data.sold, gallery = #data.gallery }
player.Parent = nil
S.Players.PlayerRemoving:Fire(player)
R.run(2)
check(R.workspace.Plots:FindFirstChild("Lot1") == nil, "lot destroyed on leave")
local p2 = R.makePlayer(101, "Simon")
R.localPlayer = p2
p2.Parent = S.Players
S.Players.PlayerAdded:Fire(p2)
R.makeCharacter(p2)
R.run(2)
local d2 = DataService.get(p2)
check(
	d2 and d2.coins == savedState.coins and d2.sold == savedState.sold and #d2.gallery == savedState.gallery,
	"data restored"
)
check(d2.made.gatito == 1 and d2.unlocked.hongo and d2.upgrades.auto == 1, "progress restored")
check(#d2.storage == 1 and d2.storage[1].d == "sol", "storage restored")
check(p2.Character:FindFirstChild("CarriedPainting") ~= nil, "carried painting back on the new character")
check(d2.tutorial == 0, "tutorial stays completed")
local lot2 = R.workspace.Plots:FindFirstChild("Lot1")
check(lot2 and lot2:GetAttribute("OwnerUserId") == 101, "new lot built on rejoin")
for _, f in ipairs(R.closeCallbacks) do
	R.task.spawn(f)
end
R.run(3)

print("errors:", #R.errors, "warnings:", #R.warnings)
for _, w in ipairs(R.warnings) do
	print("warn:", w)
end
