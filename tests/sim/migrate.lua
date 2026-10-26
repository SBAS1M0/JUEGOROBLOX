-- Partida de la versión anterior (marcos fijos y mejora «Más paredes»): los
-- marcos pasan a ser stands de galería con sus cuadros expuestos a su precio.
SEED_DATA = {
	coins = 5000,
	paints = { coral = 3 },
	unlocked = { globo = true, sol = true },
	made = { globo = 4 },
	upgrades = { paredes = 2, precio = 3 },
	gallery = {
		{ s = 2, d = "globo", c = "", v = 120, st = 3 },
		{ s = 5, d = "sol", c = "", v = 90, st = 2 },
	},
	storage = { { d = "globo", c = "", v = 60, st = 1 } },
	tutorial = 0,
	sold = 12,
	earned = 4000,
}
local T = dofile(SIM_DIR .. "/test.lua")
local R, check = T.R, T.check
local data = T.DataService.get(T.player)
local Exhibition = R.require(R.services.ReplicatedStorage.Shared.Exhibition)
print("== Migration from frames to stands")
check(data.upgrades.paredes == nil, "old upgrade removed")
check(Exhibition.countStands(data.stands) == 5, "3 + 2 frames became 5 stands")
check(data.stands[1] == 2 and data.stands[5] == 2 and data.stands[6] == 0, "gallery-quality stands")
check(#data.gallery == 2 and data.gallery[1].s == 1 and data.gallery[2].s == 2, "paintings kept on stands")
check(data.gallery[1].p == 120 and data.gallery[2].p == 90, "old value becomes the price")
check(data.rooms == 1, "one room open")
check(#data.storage == 1, "storage kept")
local lot = R.workspace.Plots.Lot1
local canvas = lot.Gallery.Stands.Stand1:FindFirstChild("Canvas", true)
check(canvas:GetAttribute("Design") == "globo" and canvas:GetAttribute("Price") == 120, "painting shown on the stand")
R.run(240)
check(data.sold > 12 or #data.gallery < 2, "visitors buy the migrated paintings (sold " .. data.sold .. ")")
print("errors:", #R.errors, "warnings:", #R.warnings)
