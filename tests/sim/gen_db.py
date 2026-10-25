"""Genera rbxdb.lua y defaults.lua a partir de la base de datos de reflexión
de Roblox que trae el crate rbx_reflection_database (se descarga al instalar Rojo
con `cargo install rojo`). Uso: python3 gen_db.py [ruta/a/database.msgpack]"""
import glob, os, sys
import msgpack

HERE = os.path.dirname(os.path.abspath(__file__))
path = sys.argv[1] if len(sys.argv) > 1 else sorted(glob.glob(os.path.expanduser(
    "~/.cargo/registry/src/*/rbx_reflection_database-*/database.msgpack")))[-1]
db = msgpack.unpackb(open(path, "rb").read(), raw=False, strict_map_key=False)
classes, enums = db[1], db[2]

def lstr(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
def num(v):
    v = float(v)
    if v != v: return "(0/0)"
    if v == float("inf"): return "math.huge"
    if v == float("-inf"): return "-math.huge"
    return repr(v)
def value(d):
    if not isinstance(d, dict) or len(d) != 1: return None
    k, v = list(d.items())[0]
    if k == "Bool": return "true" if v else "false"
    if k in ("Float32", "Float64"): return num(v)
    if k in ("Int32", "Int64"): return str(int(v))
    if k == "String": return lstr(v)
    if k == "Enum": return "{enum=%d}" % int(v)
    if k == "Vector3": return "{v3={%s}}" % ",".join(num(x) for x in v)
    if k == "Vector2": return "{v2={%s}}" % ",".join(num(x) for x in v)
    if k == "Color3": return "{c3={%s}}" % ",".join(num(x) for x in v)
    if k == "Color3uint8": return "{c3={%s}}" % ",".join(num(x / 255) for x in v)
    return None

out = ["return {classes={"]
for name, c in classes.items():
    _, tags, sup, props, defaults = c
    ps = []
    for pn, p in props.items():
        dt = p[2]
        t = "Enum:" + dt["Enum"] if "Enum" in dt else dt.get("Value", "Ref" if "Ref" in dt else str(dt))
        d = value(defaults.get(pn)) if isinstance(defaults, dict) else None
        ps.append("[%s]={t=%s,ro=%s,acc=%s,d=%s}" % (lstr(pn), lstr(t), "true" if p[1] != "ReadWrite" else "false", lstr(p[1]), d or "nil"))
    out.append("[%s]={super=%s,tags={%s},props={%s}}," % (lstr(name), lstr(sup) if sup else "nil", ",".join(lstr(t) for t in tags), ",".join(ps)))
out.append("},enums={")
for en, e in enums.items():
    out.append("[%s]={%s}," % (lstr(en), ",".join("[%s]=%d" % (lstr(k), v) for k, v in e[1].items())))
out.append("}}")
open(os.path.join(HERE, "rbxdb.lua"), "w").write("\n".join(out))

lines = ["local D = {}"]
for name, c in classes.items():
    defaults = c[4]
    if not isinstance(defaults, dict) or not defaults: continue
    ent = ["[%s]=%s" % (lstr(pn), v) for pn, d in defaults.items() if (v := value(d)) is not None]
    lines.append("D[%s]={%s}" % (lstr(name), ",".join(ent)))
lines.append("return D")
open(os.path.join(HERE, "defaults.lua"), "w").write("\n".join(lines))
print("ok:", len(classes), "clases,", len(enums), "enums")
