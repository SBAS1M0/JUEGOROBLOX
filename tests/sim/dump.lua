-- Serializes GUI trees and parts to JSON for visual previews.
local D = {}
local function esc(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		if c == "\n" then return "\\n" end
		if c == '"' then return '\\"' end
		if c == "\\" then return "\\\\" end
		return ""
	end) .. '"'
end
local function enc(v, typeofFn)
	local t = typeofFn(v)
	if v == nil then return "null"
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "0" end
		return string.format("%.4f", v)
	elseif t == "boolean" then return tostring(v)
	elseif t == "string" then return esc(v)
	elseif t == "Color3" then return string.format("[%d,%d,%d]", math.floor(v.R * 255 + .5), math.floor(v.G * 255 + .5), math.floor(v.B * 255 + .5))
	elseif t == "UDim2" then return string.format("[%.4f,%.4f,%.4f,%.4f]", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
	elseif t == "UDim" then return string.format("[%.4f,%.4f]", v.Scale, v.Offset)
	elseif t == "Vector2" then return string.format("[%.4f,%.4f]", v.X, v.Y)
	elseif t == "Vector3" then return string.format("[%.4f,%.4f,%.4f]", v.X, v.Y, v.Z)
	elseif t == "EnumItem" then return esc(v.Name)
	elseif t == "ColorSequence" then
		local parts = {}
		for _, k in ipairs(v.Keypoints) do
			local c = (typeofFn(k) == "Color3") and k or k.Value
			table.insert(parts, enc(c, typeofFn))
		end
		return "[" .. table.concat(parts, ",") .. "]"
	elseif t == "NumberSequence" then
		local parts = {}
		for _, k in ipairs(v.Keypoints) do
			if type(k) == "number" then
				table.insert(parts, string.format("[%d,%.3f]", #parts == 0 and 0 or 1, k))
			else
				table.insert(parts, string.format("[%.3f,%.3f]", k.Time, k.Value))
			end
		end
		return "[" .. table.concat(parts, ",") .. "]"
	elseif t == "CFrame" then
		local r = v.r
		return string.format("[%.4f,%.4f,%.4f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f]", v.p.X, v.p.Y, v.p.Z,
			r[1][1], r[1][2], r[1][3], r[2][1], r[2][2], r[2][3], r[3][1], r[3][2], r[3][3])
	end
	return "null"
end
local GUI_PROPS = { "Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "Visible", "Text",
	"TextColor3", "TextScaled", "TextXAlignment", "TextYAlignment", "Font", "ZIndex", "LayoutOrder", "Rotation", "Enabled",
	"CornerRadius", "Color", "Thickness", "Transparency", "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight",
	"FillDirection", "Padding", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "CellSize", "CellPadding",
	"AspectRatio", "MaxSize", "Scale", "MaxTextSize", "ClipsDescendants", "TextWrapped", "TextTransparency", "ApplyStrokeMode", "TextSize", "Transparency" }
function D.gui(inst, typeofFn)
	local fields = { '"c":' .. esc(inst.ClassName), '"n":' .. esc(inst.props.Name) }
	for _, p in ipairs(GUI_PROPS) do
		local ok, val = pcall(function() return inst[p] end)
		if ok and val ~= nil and type(val) ~= "function" and typeofFn(val) ~= "Instance" and typeofFn(val) ~= "RBXScriptSignal" then
			table.insert(fields, esc(p) .. ":" .. enc(val, typeofFn))
		end
	end
	local kids = {}
	for _, c in ipairs(inst.children) do
		table.insert(kids, D.gui(c, typeofFn))
	end
	table.insert(fields, '"k":[' .. table.concat(kids, ",") .. "]")
	return "{" .. table.concat(fields, ",") .. "}"
end
-- artFn(part) puede devolver el JSON de un cuadro dibujado en la pieza.
function D.parts(root, typeofFn, isA, out, artFn)
	out = out or {}
	for _, c in ipairs(root.children) do
		if isA(c.ClassName, "BasePart") then
			local tr = c.Transparency
			if tr < 0.98 then
				local art = artFn and artFn(c)
				table.insert(out, string.format('{"c":%s,"s":%s,"cf":%s,"col":%s,"t":%s,"m":%s,"shape":%s,"mesh":%s,"art":%s}',
					esc(c.ClassName), enc(c.Size, typeofFn), enc(c.CFrame, typeofFn), enc(c.Color, typeofFn), enc(tr, typeofFn),
					esc(c.Material and c.Material.Name or "Plastic"), c.ClassName == "Part" and esc(c.Shape and c.Shape.Name or "Block") or '"Block"',
					c:FindFirstChildOfClass("SpecialMesh") and '"Sphere"' or "null", art or "null"))
			end
		end
		D.parts(c, typeofFn, isA, out, artFn)
	end
	return out
end

-- Figuras de un cuadro (para pintarlo en las capturas del mundo).
function D.artOf(part, Designs, Colors)
	if part.Name ~= "Canvas" then
		return nil
	end
	local design = Designs.get(part:GetAttribute("Design") or "")
	if not design then
		return nil
	end
	local colors = Designs.defaultColors(design)
	for areaId, colorId in pairs(Designs.decodeColors(part:GetAttribute("Colors"))) do
		colors[areaId] = colorId
	end
	local function c(col)
		return string.format("[%d,%d,%d]", math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5))
	end
	local shapes = {}
	for _, s in ipairs(design.shapes) do
		local entry = Colors.ById[colors[s.area]]
		local cols = {}
		if entry and entry.gradient then
			for _, g in ipairs(entry.gradient) do
				table.insert(cols, c(g))
			end
		else
			cols = { c(entry and entry.color or Colors.mainColor(colors[s.area])) }
		end
		table.insert(shapes, string.format('{"x":%f,"y":%f,"w":%f,"h":%f,"rot":%f,"r":%f,"c":[%s]}', s.x, s.y, s.w, s.h, s.rot, s.r, table.concat(cols, ",")))
	end
	return "[" .. table.concat(shapes, ",") .. "]"
end
-- Piezas y rellenos de terreno del mundo (para world_render.py).
function D.world(R, path, artFn)
	local list = D.parts(R.workspace, R.globals.typeof, R.isA, nil, artFn)
	D.write(path .. ".json", "[" .. table.concat(list, ",") .. "]")
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
	D.write(path .. "_terrain.json", "[" .. table.concat(fills, ",") .. "]")
end

function D.write(path, s)
	local f = io.open(path, "w"); f:write(s); f:close()
end
return D
