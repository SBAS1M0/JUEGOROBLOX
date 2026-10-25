import json, sys
ds = json.load(open('out_designs.json'))
S = 220
cells = []
for d in ds:
    divs = []
    for s in d["shapes"]:
        w, h = s["w"]*S, s["h"]*S
        rad = s["r"]*min(w, h)
        cols = s["c"]
        bg = f"rgb({cols[0][0]},{cols[0][1]},{cols[0][2]})" if len(cols) == 1 else "linear-gradient(90deg," + ",".join(f"rgb({c[0]},{c[1]},{c[2]})" for c in cols) + ")"
        divs.append(f'<div style="position:absolute;left:{s["x"]*S-w/2}px;top:{s["y"]*S-h/2}px;width:{w}px;height:{h}px;border-radius:{rad}px;background:{bg};transform:rotate({s["rot"]}deg);outline:1px solid rgba(0,0,0,.12)"></div>')
    cells.append(f'<div style="display:inline-block;margin:8px;text-align:center;font:16px sans-serif"><div style="position:relative;width:{S}px;height:{S}px;overflow:hidden;border-radius:8px">{"".join(divs)}</div>N{d["level"]} · {d["name"]}</div>')
open('designs.html', 'w').write(f'<html><body style="margin:0;background:#fff;width:{4*(S+16)}px">{"".join(cells)}</body></html>')
