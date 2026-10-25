-- Partida completa: tutorial, máquina de colores manual, elegir diseño y colores,
-- pintar con estrellas, exponer y vender, misiones, regalo diario, mejoras
-- (incluido Auto-Rolling), cancelar, salir y volver.
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
	local list = D.parts(R.workspace, G.typeof, R.isA)
	D.write(SIM_DIR .. "/out_" .. name .. ".json", "[" .. table.concat(list, ",") .. "]")
	-- Terreno: rellenos en orden (el render los aproxima con primitivas).
	local fills = {}
	for _, f in ipairs(R.terrainFills) do
		if f.kind == "block" then
			local p, sz = f.cframe.Position, f.size
			table.insert(fills, string.format('{"k":"block","m":"%s","p":[%.2f,%.2f,%.2f],"s":[%.2f,%.2f,%.2f]}', f.material, p.X, p.Y, p.Z, sz.X, sz.Y, sz.Z))
		elseif f.kind == "ball" then
			local p = f.center
			table.insert(fills, string.format('{"k":"ball","m":"%s","p":[%.2f,%.2f,%.2f],"r":%.2f}', f.material, p.X, p.Y, p.Z, f.radius))
		else
			local p = f.cframe.Position
			table.insert(fills, string.format('{"k":"cylinder","m":"%s","p":[%.2f,%.2f,%.2f],"h":%.2f,"r":%.2f}', f.material, p.X, p.Y, p.Z, f.height, f.radius))
		end
	end
	D.write(SIM_DIR .. "/out_" .. name .. "_terrain.json", "[" .. table.concat(fills, ",") .. "]")
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

print("== Fresh start: manual machine, tutorial")
check(data.autoRoll == false and not Config.hasAutoRoll(data.upgrades), "no auto-roll at start")
check(data.tutorial == 1, "tutorial starts at step 1")
check(pg.HUD.Tutorial.Visible, "tutorial banner visible")
check(pg:FindFirstChild("TutorialArrow") ~= nil, "tutorial arrow exists")
local highlight = T.findAll(R.workspace, function(d)
	return d.ClassName == "Highlight"
end)[1]
check(highlight ~= nil and highlight.Adornee == lot.Workshop.Machine, "machine highlighted for step 1")
dumpGui("hud", pg.HUD)
R.run(10)
check(totalPaints(data) == 0, "machine does not roll by itself")
check(buttonStarting(pg.MachineHud, "🔒 Auto") ~= nil, "auto button locked")

print("== Manual rolls")
click(pg.MachineHud, "🎲 TIRAR")
R.run(0.2)
check(totalPaints(data) == 1, "button roll gives a paint")
click(pg.MachineHud, "🎲 TIRAR")
R.run(0.2)
check(totalPaints(data) == 1, "cooldown respected")
R.run(3)
lot.Workshop.Machine.Body.ProximityPrompt.Triggered:Fire(player)
R.run(3)
click(pg.MachineHud, "🎲 TIRAR")
R.run(2)
check(totalPaints(data) == 3, "three rolls (" .. totalPaints(data) .. ")")
check(data.tutorial == 2, "tutorial advanced to step 2")
check(highlight.Parent == nil or highlight.Adornee ~= lot.Workshop.Machine, "highlight moved")
check(lot.Workshop.Machine.Top:GetAttribute("ColorId") ~= "", "machine shows last color")
check(pg.MachineBoard.Enabled, "machine billboard attached")
-- Gana un par de colores más para la prueba.
for _ = 1, 6 do
	R.run(3)
	click(pg.MachineHud, "🎲 TIRAR")
end
R.run(2)
dumpGui("machine", pg.MachineHud)
click(pg.MachineHud, "🔒 Auto")
R.run(0.3)
check(pg.Shop.Window.Visible, "locked auto button opens the shop")
closeWindow(pg.Shop)

print("== Pick design at the easel")
lot.Workshop.DrawPrompt.ProximityPrompt.Triggered:Fire(player)
R.run(0.3)
check(pg.DesignPicker.Window.Visible, "design picker open")
dumpGui("picker", pg.DesignPicker)
T.fireClick(namedButton(pg.DesignPicker, "globo"))
click(pg.DesignPicker, "🎨 Empezar")
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

local function paintAll(design, useBucket, onHalf)
	local catcher = T.findAll(pg.Painter, function(d)
		return d.Name == "PaintInput"
	end)[1]
	for i, shape in ipairs(design.shapes) do
		if onHalf and i == math.floor(#design.shapes * 0.6) then
			onHalf()
		end
		if shape.visible > 0 then
			-- Busca un punto donde esta figura sea la visible.
			local px, py
			for gx = 0, 39 do
				for gy = 0, 39 do
					local x, y = (gx + 0.5) / 40, (gy + 0.5) / 40
					if not px and Designs.shapeAt(design, x, y) == i then
						px, py = x, y
					end
				end
			end
			local input = { UserInputType = Enum.UserInputType.MouseButton1, Position = R.v2(px * 512, py * 512) }
			catcher.InputBegan:Fire(input)
			if not useBucket then
				R.run(Designs.shapeTime(shape) / Config.brushSpeed(data.upgrades) + 0.2)
				UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 }, false)
			end
		end
	end
	R.run(0.6)
end

print("== Paint")
paintAll(Designs.get("globo"), false, function()
	dumpGui("painter_mid", pg.Painter)
end)
R.run(2)
dumpGui("painter", pg.Painter)
local exhibit = buttonStarting(pg.Painter, "🖼️ Exponer")
check(exhibit ~= nil and isShown(exhibit), "completion window shown")
T.fireClick(exhibit)
R.run(0.5)
check(not pg.Painter.Enabled and R.controlsEnabled, "painter closed")
check(#data.gallery == 1, "painting exhibited")
check(data.gallery[1].st == 3, "fast painting earns 3 stars (" .. tostring(data.gallery[1].st) .. ")")
local canvas = lot.Gallery.Frame1.Canvas
check(canvas:GetAttribute("Design") == "globo", "canvas shows design")
check(canvas:GetAttribute("Stars") == 3, "canvas shows stars")
check(#canvas.ArtGui.Art:GetDescendants() > 5, "gallery art rendered")
check(data.made.globo == 1, "made counter")
check(data.tutorial == 5, "tutorial step 5 (wait for a buyer)")

print("== Visitor buys")
local coins0 = data.coins
local sawVisitor = false
for _ = 1, 90 do
	R.run(1)
	if #lot.Visitors:GetChildren() > 0 then
		sawVisitor = true
		local v = lot.Visitors:GetChildren()[1]
		local reaction = v:GetAttribute("Reaction") or ""
		if reaction:find("💰") then
			dumpWorld("world")
		end
	end
	if data.sold >= 1 then
		break
	end
end
check(sawVisitor, "visitor appeared")
check(data.sold == 1 and data.coins > coins0, "visitor bought painting (+" .. (data.coins - coins0) .. ")")
check(#data.gallery == 0, "gallery emptied")
check(data.tutorial == 0, "tutorial completed")
check(not pg.HUD.Tutorial.Visible, "tutorial banner hidden")
R.run(30)
check(#lot.Visitors:GetChildren() == 0, "visitor left")

print("== Quick sell")
T.fireClick(tile("paint"))
R.run(0.2)
click(pg.DesignPicker, "🎨 Empezar")
click(pg.ColorPicker, "Empezar a pintar")
R.run(0.2)
paintAll(Designs.get("globo"), false)
R.run(2)
local coins1 = data.coins
click(pg.Painter, "💰 Vender ya")
R.run(0.3)
check(data.coins > coins1 and data.sold == 2, "quick sold")

print("== Quests")
check(#data.quests == Config.QUESTS_PER_DAY, "daily quests generated")
dumpGui("hud2", pg.HUD)
for i, quest in ipairs(data.quests) do
	quest.progress = quest.goal
end
local coins2 = data.coins
-- Fuerza un push de estado haciendo una tirada.
R.run(3)
click(pg.MachineHud, "🎲 TIRAR")
R.run(2)
if not pg.HUD.Quests.Visible then
	T.fireClick(tile("quests"))
	R.run(0.2)
end
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

print("== Daily gift")
T.fireClick(tile("daily"))
R.run(0.3)
check(pg.Daily.Window.Visible, "daily window open")
dumpGui("daily", pg.Daily)
local c0 = data.coins
click(pg.Daily, "🎁 Reclamar")
R.run(0.5)
check(data.coins > c0 and data.dailyStreak == 1, "daily claimed (streak " .. data.dailyStreak .. ")")
check(not pg.Daily.Window.Visible, "daily window closed")
T.fireClick(tile("daily"))
R.run(0.2)
check(buttonStarting(pg.Daily, "⏰") ~= nil, "daily shows countdown")
closeWindow(pg.Daily)

print("== Unlock designs & levels")
data.coins = 10000000
for _, id in ipairs({ "sol", "taza", "gatito" }) do
	T.fireClick(tile("paint"))
	T.fireClick(namedButton(pg.DesignPicker, id))
	click(pg.DesignPicker, "🔓 Desbloquear")
	check(data.unlocked[id], "unlocked " .. id)
	closeWindow(pg.DesignPicker)
end
T.fireClick(tile("paint"))
T.fireClick(namedButton(pg.DesignPicker, "hongo"))
check(buttonStarting(pg.DesignPicker, "🔒 Pinta") ~= nil, "level 2 locked")
closeWindow(pg.DesignPicker)

print("== Shop (all upgrades)")
T.fireClick(tile("shop"))
R.run(0.2)
check(pg.Shop.Window.Visible, "shop open")
dumpGui("shop", pg.Shop)
for _ = 1, 16 do
	local btns = T.findAll(pg.Shop, function(d)
		return d.ClassName == "TextButton" and d.Text:sub(1, 4) == "💰"
	end)
	for _, b in ipairs(btns) do
		T.fireClick(b)
	end
end
for _, upgrade in ipairs(Config.Upgrades) do
	check((data.upgrades[upgrade.id] or 0) == upgrade.max, upgrade.id .. " maxed")
end
check(#lot.Decor:GetChildren() == 6, "decor built")
check(lot.Gallery.Frame7.Canvas:GetAttribute("Locked") == false, "all walls unlocked")
closeWindow(pg.Shop)

print("== Auto-Rolling after buying it")
check(data.autoRoll == true, "auto-roll enabled on purchase")
local p0 = totalPaints(data)
R.run(6)
check(totalPaints(data) > p0, "machine rolls by itself now (" .. p0 .. " -> " .. totalPaints(data) .. ")")
click(pg.MachineHud, "🔄 Auto")
R.run(0.3)
check(data.autoRoll == false, "auto-roll toggled off")
p0 = totalPaints(data)
R.run(5)
check(totalPaints(data) == p0, "no rolls while paused")
click(pg.MachineHud, "⏸ Auto")
R.run(0.3)
check(data.autoRoll == true, "auto-roll toggled on again")

print("== Paint level 1 with bucket")
for _, id in ipairs({ "sol", "taza", "gatito" }) do
	T.fireClick(tile("paint"))
	T.fireClick(namedButton(pg.DesignPicker, id))
	click(pg.DesignPicker, "🎨 Empezar")
	click(pg.ColorPicker, "✨ Mejores")
	click(pg.ColorPicker, "Empezar a pintar")
	R.run(0.2)
	click(pg.Painter, "🪣")
	paintAll(Designs.get(id), true)
	R.run(3)
	click(pg.Painter, "🖼️ Exponer")
	R.run(0.3)
	check(data.made[id] == 1, "painted " .. id)
end
T.fireClick(tile("paint"))
T.fireClick(namedButton(pg.DesignPicker, "hongo"))
click(pg.DesignPicker, "🔓 Desbloquear")
check(data.unlocked.hongo, "level 2 design unlocked")
closeWindow(pg.DesignPicker)

print("== Cancel refunds paints")
data.autoRoll = false
local paintsBefore = totalPaints(data)
T.fireClick(tile("paint"))
T.fireClick(namedButton(pg.DesignPicker, "hongo"))
click(pg.DesignPicker, "🎨 Empezar")
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
local distance = (character.HumanoidRootPart.Position - lot:GetPivot().Position).Magnitude
check(distance < 80, "home button brings you back (" .. math.floor(distance) .. ")")

print("== Visitors buy exhibited paintings")
data.autoRoll = true
local sold0 = data.sold
R.run(150)
dumpWorld("world2")
check(data.sold >= sold0 + 2, "visitors keep buying (sold " .. data.sold .. ")")

print("== Leave & rejoin")
local saved = { coins = data.coins, sold = data.sold, gallery = #data.gallery }
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
check(d2 and d2.coins == saved.coins and d2.sold == saved.sold and #d2.gallery == saved.gallery, "data restored")
check(d2.made.gatito == 1 and d2.unlocked.hongo and d2.upgrades.auto == 1, "progress restored")
check(d2.tutorial == 0, "tutorial stays completed")
local lot2 = R.workspace.Plots:FindFirstChild("Lot1")
check(lot2 and lot2:GetAttribute("OwnerUserId") == 101, "new lot built on rejoin")
local shown = 0
for _, frame in ipairs(lot2.Gallery:GetChildren()) do
	if frame.Canvas:GetAttribute("Design") ~= "" then
		shown = shown + 1
	end
end
check(shown == saved.gallery, "gallery restored on walls (" .. shown .. ")")
for _, f in ipairs(R.closeCallbacks) do
	R.task.spawn(f)
end
R.run(3)

print("errors:", #R.errors, "warnings:", #R.warnings)
for _, w in ipairs(R.warnings) do
	print("warn:", w)
end
