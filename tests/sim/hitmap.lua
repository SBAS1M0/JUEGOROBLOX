local R = dofile(SIM_DIR .. "/runtime.lua")
R.mount(R.services.ReplicatedStorage, "Shared", FILES.shared)
local Designs = R.require(R.services.ReplicatedStorage.Shared.Designs)
local Colors = R.require(R.services.ReplicatedStorage.Shared.Colors)
local N = 110
local f = io.open(SIM_DIR .. "/out_hitmap.txt", "w")
for _, d in ipairs(Designs.List) do
	for y = 0, N - 1 do
		local row = {}
		for x = 0, N - 1 do
			local i = Designs.shapeAt(d, (x + .5) / N, (y + .5) / N)
			local c = i and Colors.mainColor(d.areaById[d.shapes[i].area].default) or Color3.new(0, 0, 0)
			row[#row + 1] = string.format("%d,%d,%d", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
		end
		f:write(table.concat(row, " "), "\n")
	end
end
f:close()
