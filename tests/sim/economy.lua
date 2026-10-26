-- Imprime la economía: valor de cada diseño (colores básicos, 3 estrellas) y precios.
local R = dofile(SIM_DIR .. "/runtime.lua")
local S = R.services
R.mount(S.ReplicatedStorage, "Shared", FILES.shared)
local Config = R.require(S.ReplicatedStorage.Shared.Config)
local Designs = R.require(S.ReplicatedStorage.Shared.Designs)
local lv = {}
for _, d in ipairs(Designs.List) do
	local colors = Designs.defaultColors(d)
	local v1 = Config.paintingValue(d, colors, lv, 0, 1)
	local v3 = Config.paintingValue(d, colors, lv, 0, 3)
	print(string.format("L%d %-10s price %6d  value %5d..%5d  par %.1fs  min %.1fs  shapes %d", d.level, d.id, d.price, v1, v3,
		Config.parTime(d, lv), Config.minPaintTime(d, lv), #d.shapes))
end
