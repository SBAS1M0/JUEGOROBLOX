-- Exporta diseños y colores a JSON para la vista previa.
local R = dofile(SIM_DIR .. "/runtime.lua")
R.mount(R.services.ReplicatedStorage, "Shared", FILES.shared)
local Designs = R.require(R.services.ReplicatedStorage.Shared.Designs)
local Colors = R.require(R.services.ReplicatedStorage.Shared.Colors)
local function c(col) return string.format("[%d,%d,%d]", math.floor(col.R*255+.5), math.floor(col.G*255+.5), math.floor(col.B*255+.5)) end
local out = {}
for _, d in ipairs(Designs.List) do
	local shapes = {}
	for _, s in ipairs(d.shapes) do
		local entry = Colors.ById[d.areaById[s.area].default]
		local cols = {}
		if entry.gradient then for _, g in ipairs(entry.gradient) do table.insert(cols, c(g)) end else cols = { c(entry.color) } end
		table.insert(shapes, string.format('{"x":%f,"y":%f,"w":%f,"h":%f,"rot":%f,"r":%f,"c":[%s]}', s.x, s.y, s.w, s.h, s.rot, s.r, table.concat(cols, ",")))
	end
	table.insert(out, string.format('{"name":"%s","level":%d,"shapes":[%s]}', d.name, d.level, table.concat(shapes, ",")))
end
local f = io.open(SIM_DIR .. "/out_designs.json", "w"); f:write("[" .. table.concat(out, ",") .. "]"); f:close()
print("designs", #Designs.List, "errors", #R.errors)
