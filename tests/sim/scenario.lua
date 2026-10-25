-- Partida completa: máquina de colores, elegir diseño y colores, pintar,
-- exponer y vender a visitantes, desbloquear niveles, mejoras y guardado.
local T = dofile(SIM_DIR .. "/test.lua")
local R, check, player, plots = T.R, T.check, T.player, T.plots
local G = R.globals
local Enum = G.Enum
local S = R.services
local pg = player.PlayerGui
local Designs, Colors, Config, DataService = T.Designs, T.Colors, T.Config, T.DataService
local UIS = S.UserInputService
local D = dofile(SIM_DIR .. "/dump.lua")

local function dumpGui(name, gui)
	D.write(SIM_DIR .. "/out_" .. name .. ".json", D.gui(gui, G.typeof))
end
local function dumpWorld(name)
	local list = D.parts(R.workspace, G.typeof, R.isA)
	D.write(SIM_DIR .. "/out_" .. name .. ".json", "[" .. table.concat(list, ",") .. "]")
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
local data = DataService.get(player)

print("== Machine auto-rolls")
dumpGui("hud", pg.HUD)
R.run(12)
local total = 0
for _, n in pairs(data.paints) do
	total = total + n
end
check(total >= 2, "auto-roll gave paints (" .. total .. ")")
check(pg.MachineBoard.Enabled, "machine billboard attached")
check(plots.Plot1.Workshop.Machine.Top:GetAttribute("ColorId") ~= "", "machine shows last color")
dumpGui("machine", pg.MachineHud)

print("== Pick design")
T.fireClick(T.buttonWithLabel(pg.HUD, "Pintar"))
R.run(0.3)
check(pg.DesignPicker.Window.Visible, "design picker open")
dumpGui("picker", pg.DesignPicker)
T.fireClick(T.findAll(pg.DesignPicker, function(d)
	return d.Name == "globo" and d.ClassName == "TextButton"
end)[1])
click(pg.DesignPicker, "🎨 Empezar")
R.run(0.3)
check(not pg.DesignPicker.Window.Visible and pg.ColorPicker.Window.Visible, "color picker open")

-- Elige un color raro (el que más haya) para el cielo.
local best, bestCount = nil, 0
for id, n in pairs(data.paints) do
	if n > bestCount then
		best, bestCount = id, n
	end
end
local cell = T.findAll(pg.ColorPicker, function(d)
	return d.Name == best and d.ClassName == "TextButton"
end)[1]
check(cell ~= nil, "owned color cell shown: " .. best)
T.fireClick(cell)
dumpGui("colors", pg.ColorPicker)
local before = data.paints[best]
click(pg.ColorPicker, "Continuar")
R.run(0.3)
check(pg.Painter.Enabled, "painter open")
check((data.paints[best] or 0) == before - 1, "paint consumed")
check(R.controlsEnabled == false, "controls disabled while painting")

local function paintAll(design, useBucket, onHalf)
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
			pg.Painter:GetDescendants() -- touch
			local catcher = T.findAll(pg.Painter, function(d)
				return d.ClassName == "TextButton" and d.ZIndex == 9
			end)[1]
			catcher.InputBegan:Fire(input)
			if not useBucket then
				R.run(Designs.shapeTime(shape) / Config.brushSpeed(data.upgrades) + 0.3)
				UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 }, false)
			end
		end
	end
	R.run(0.6)
end

print("== Paint")
paintAll(Designs.get("globo"), false, function()
	R.task.spawn(function() end)
	dumpGui("painter_mid", pg.Painter)
end)
dumpGui("painter", pg.Painter)
local doneFrame = pg.Painter:GetChildren()[2]
check(doneFrame.Visible, "completion window shown")
click(pg.Painter, "🖼️ Exponer")
R.run(0.5)
check(not pg.Painter.Enabled and R.controlsEnabled, "painter closed")
check(#data.gallery == 1, "painting exhibited")
check(plots.Plot1.Gallery.Frame1.Canvas:GetAttribute("Design") == "globo", "canvas shows design")
check(#plots.Plot1.Gallery.Frame1.Canvas.ArtGui.Art.Art:GetChildren() > 5, "gallery art rendered")
check(data.made.globo == 1, "made counter")

print("== Visitor buys")
local coins0 = data.coins
local sawVisitor = false
for _ = 1, 60 do
	R.run(1)
	if #plots.Plot1.Visitors:GetChildren() > 0 then
		sawVisitor = true
		local v = plots.Plot1.Visitors:GetChildren()[1]
		if v.Head:FindFirstChild("VisitorBubble") and v:GetAttribute("Reaction"):find("💰") then
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
R.run(20)
check(#plots.Plot1.Visitors:GetChildren() == 0, "visitor left")

print("== Quick sell")
T.fireClick(T.buttonWithLabel(pg.HUD, "Pintar"))
click(pg.DesignPicker, "🎨 Empezar")
click(pg.ColorPicker, "Continuar")
R.run(0.2)
paintAll(Designs.get("globo"), false)
local coins1 = data.coins
click(pg.Painter, "💰 Vender ya")
R.run(0.3)
check(data.coins > coins1 and data.sold == 2, "quick sold")

print("== Unlock designs & levels")
data.coins = 10000000
for _, id in ipairs({ "sol", "taza", "gatito" }) do
	T.fireClick(T.buttonWithLabel(pg.HUD, "Pintar"))
	T.fireClick(T.findAll(pg.DesignPicker, function(d)
		return d.Name == id and d.ClassName == "TextButton"
	end)[1])
	click(pg.DesignPicker, "Desbloquear")
	check(data.unlocked[id], "unlocked " .. id)
	T.fireClick(pg.DesignPicker.Window.Wrapper.Panel.Close)
end
-- Nivel 2 cerrado hasta pintar todo el nivel 1.
T.fireClick(T.buttonWithLabel(pg.HUD, "Pintar"))
T.fireClick(T.findAll(pg.DesignPicker, function(d)
	return d.Name == "hongo" and d.ClassName == "TextButton"
end)[1])
check(buttonStarting(pg.DesignPicker, "🔒") ~= nil, "level 2 locked")
T.fireClick(pg.DesignPicker.Window.Wrapper.Panel.Close)

print("== Shop (all upgrades)")
T.fireClick(T.buttonWithLabel(pg.HUD, "Mejoras"))
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
check(#plots.Plot1.Decor:GetChildren() == 6, "decor built")
check(plots.Plot1.Gallery.Frame7.Canvas:GetAttribute("Locked") == false, "all walls unlocked")
T.fireClick(pg.Shop.Window.Wrapper.Panel.Close)

print("== Paint level 1 with bucket")
for _, id in ipairs({ "sol", "taza", "gatito" }) do
	T.fireClick(T.buttonWithLabel(pg.HUD, "Pintar"))
	T.fireClick(T.findAll(pg.DesignPicker, function(d)
		return d.Name == id and d.ClassName == "TextButton"
	end)[1])
	click(pg.DesignPicker, "🎨 Empezar")
	click(pg.ColorPicker, "Continuar")
	R.run(0.2)
	click(pg.Painter, "🪣")
	paintAll(Designs.get(id), true)
	R.run(1)
	click(pg.Painter, "🖼️ Exponer")
	R.run(0.3)
	check(data.made[id] == 1, "painted " .. id)
end
check(R.require(S.ServerScriptService.Server.Services.DataService) == DataService, "same module")
T.fireClick(T.buttonWithLabel(pg.HUD, "Pintar"))
T.fireClick(T.findAll(pg.DesignPicker, function(d)
	return d.Name == "hongo" and d.ClassName == "TextButton"
end)[1])
click(pg.DesignPicker, "Desbloquear")
check(data.unlocked.hongo, "level 2 design unlocked")
T.fireClick(pg.DesignPicker.Window.Wrapper.Panel.Close)

print("== Cancel refunds paints")
local paintsBefore = 0
for _, n in pairs(data.paints) do
	paintsBefore = paintsBefore + n
end
T.fireClick(T.buttonWithLabel(pg.HUD, "Pintar"))
T.fireClick(T.findAll(pg.DesignPicker, function(d)
	return d.Name == "hongo" and d.ClassName == "TextButton"
end)[1])
click(pg.DesignPicker, "🎨 Empezar")
-- elige colores no básicos si hay
for _, area in ipairs(Designs.get("hongo").areas) do
	local owned = nil
	for id, n in pairs(data.paints) do
		if n > 3 then
			owned = id
		end
	end
	if owned then
		local c = T.findAll(pg.ColorPicker, function(d)
			return d.Name == owned and d.ClassName == "TextButton"
		end)[1]
		if c then
			T.fireClick(c)
		end
	end
end
click(pg.ColorPicker, "Continuar")
R.run(0.2)
check(pg.Painter.Enabled, "painting hongo")
click(pg.Painter, "✕ Salir")
click(pg.Painter, "¿Salir?")
R.run(0.2)
local paintsAfter = 0
for _, n in pairs(data.paints) do
	paintsAfter = paintsAfter + n
end
check(not pg.Painter.Enabled, "painter closed on cancel")
check(paintsAfter >= paintsBefore, "paints refunded (" .. paintsBefore .. " -> " .. paintsAfter .. ")")

print("== Collection & daily")
T.fireClick(T.buttonWithLabel(pg.HUD, "Colores"))
check(pg.Collection.Window.Visible, "collection open")
dumpGui("collection", pg.Collection)
T.fireClick(pg.Collection.Window.Wrapper.Panel.Close)
local c0 = data.coins
T.fireClick(T.buttonWithLabel(pg.HUD, "🎁"))
check(data.coins > c0, "daily claimed")
T.fireClick(T.buttonWithLabel(pg.HUD, "Mi taller"))
local rollBtn = buttonStarting(pg.MachineHud, "🎲")
R.run(2)
T.fireClick(rollBtn)
T.fireClick(buttonStarting(pg.MachineHud, "🔄"))
R.run(0.2)
check(data.autoRoll == false, "auto-roll toggled off")

print("== Visitors buy exhibited paintings")
R.run(120)
dumpWorld("world2")
check(data.sold >= 4, "visitors keep buying (sold " .. data.sold .. ")")

print("== Leave & rejoin")
local saved = { coins = data.coins, sold = data.sold, gallery = #data.gallery }
player.Parent = nil
S.Players.PlayerRemoving:Fire(player)
R.run(2)
check(plots.Plot1:GetAttribute("OwnerUserId") == 0, "plot released")
check(#plots.Plot1.Visitors:GetChildren() == 0, "visitors cleared")
local p2 = R.makePlayer(101, "Simon")
R.localPlayer = p2
p2.Parent = S.Players
S.Players.PlayerAdded:Fire(p2)
R.makeCharacter(p2)
R.run(2)
local d2 = DataService.get(p2)
check(d2 and d2.coins == saved.coins and d2.sold == saved.sold and #d2.gallery == saved.gallery, "data restored")
check(d2.made.gatito == 1 and d2.unlocked.hongo, "progress restored")
for _, f in ipairs(R.closeCallbacks) do
	R.task.spawn(f)
end
R.run(3)

print("errors:", #R.errors, "warnings:", #R.warnings)
for _, w in ipairs(R.warnings) do
	print("warn:", w)
end
