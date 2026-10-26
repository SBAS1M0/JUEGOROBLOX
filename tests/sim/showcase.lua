-- Galería avanzada para las capturas: tres salas, stands de todas las
-- calidades y cuadros expuestos con distintos precios.
SEED_DATA = {
	coins = 250000,
	paints = { coral = 3, oro = 1, arcoiris = 1, coco = 4 },
	unlocked = { globo = true, sol = true, taza = true, gatito = true },
	made = { globo = 5, sol = 3, taza = 3, gatito = 3 },
	upgrades = { fama = 6, decoracion = 6, cajero = 1, precio = 4 },
	stands = { 3, 2, 3, 2, 1, 2, 2, 1, 2, 2, 3, 3, 1, 1, 2, 2, 3, 3, 3, 2, 2, 1, 1, 0 },
	rooms = 3,
	gallery = {
		{ s = 1, d = "gatito", c = "fondo:aurora,hocico:coco,ojos:negro,orejas:sakura,pelaje:mandarina", v = 140, p = 150, st = 3 },
		{ s = 2, d = "taza", c = "corazon:frambuesa,mesa:cobre,pared:melocoton,plato:turquesa,taza:coco,vapor:nacar", v = 120, p = 115, st = 3 },
		{ s = 3, d = "sol", c = "cara:cafe,cielo:cieloclaro,mejillas:coral,rayos:mandarina,sol:oro", v = 110, p = 160, st = 2 },
		{ s = 4, d = "globo", c = "brillo:algodon,cielo:atardecer,cuerda:cafe,globo:cereza,nubes:coco", v = 90, p = 90, st = 3 },
		{ s = 5, d = "sol", c = "cielo:lavanda,rayos:frambuesa,sol:limonada", v = 100, p = 95, st = 3 },
		{ s = 9, d = "gatito", c = "fondo:selva,pelaje:arena", v = 140, p = 140, st = 3 },
		{ s = 11, d = "taza", c = "pared:golosina,taza:zafiro", v = 120, p = 130, st = 2 },
		{ s = 17, d = "globo", c = "brillo:limonada,cielo:galaxia,cuerda:plata,globo:arcoiris,nubes:lavanda", v = 90, p = 100, st = 3 },
		{ s = 18, d = "gatito", c = "fondo:oceano,pelaje:oro,orejas:rosaoro", v = 140, p = 180, st = 3 },
	},
	storage = { { d = "globo", c = "", v = 60, st = 3 } },
	tutorial = 0,
	sold = 40,
	earned = 20000,
}
local T = dofile(SIM_DIR .. "/test.lua")
local R, check = T.R, T.check
local D = dofile(SIM_DIR .. "/dump.lua")
local G = R.globals
local lot = R.workspace.Plots.Lot1
check(lot.Gallery.Rooms:FindFirstChild("Room3") ~= nil, "third room built")
-- Espera a que haya visitantes en la caja.
for _ = 1, 120 do
	R.run(0.5)
	local queued = 0
	for _, v in ipairs(lot.Visitors:GetChildren()) do
		local root = v:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - lot.GalleryInterior.Caja.Register.Position).Magnitude < 12 then
			queued = queued + 1
		end
	end
	if queued >= 1 and #lot.Visitors:GetChildren() >= 2 then
		break
	end
end
-- Los avatares del simulador son cajas: fuera de las capturas.
local visitors = #lot.Visitors:GetChildren()
lot.Visitors:ClearAllChildren()
D.world(R, SIM_DIR .. "/out_showcase", function(part)
	return D.artOf(part, T.Designs, T.Colors)
end)
D.write(SIM_DIR .. "/out_hud_show.json", D.gui(T.player.PlayerGui.HUD, G.typeof))
print("visitors:", visitors)
print("errors:", #R.errors, "warnings:", #R.warnings)
