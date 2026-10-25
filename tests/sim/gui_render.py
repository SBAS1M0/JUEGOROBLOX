import json, sys, html
W, H = int(sys.argv[2]), int(sys.argv[3])
INSET = 58
def rgb(c, a=1.0): return f"rgba({c[0]},{c[1]},{c[2]},{a:.3f})"
FONTS = {"FredokaOne": "'FredokaOne','Noto Color Emoji',sans-serif;font-weight:400",
         "BuilderSansExtraBold": "'Inter','Noto Color Emoji',sans-serif;font-weight:800",
         "BuilderSansBold": "'Inter','Noto Color Emoji',sans-serif;font-weight:700",
         "BuilderSansMedium": "'Inter','Noto Color Emoji',sans-serif;font-weight:500",
         "BuilderSans": "'Inter','Noto Color Emoji',sans-serif;font-weight:400",
         "GothamBold": "'Inter',sans-serif;font-weight:700", "GothamMedium": "'Inter',sans-serif;font-weight:500"}
import os
FREDOKA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "node_modules/@fontsource/fredoka-one/files/fredoka-one-latin-400-normal.woff2")
out = []
def kids(n): return n.get("k", [])
def child_of(n, cls): 
    for k in kids(n):
        if k["c"] == cls: return k
def is_gui(n): return n["c"] in ("Frame","TextLabel","TextButton","ScrollingFrame","ImageLabel","ImageButton","TextBox","CanvasGroup")
def size_of(n, pw, ph):
    s = n.get("Size", [0,0,0,0]); w = pw*s[0]+s[1]; h = ph*s[2]+s[3]
    sc = child_of(n, "UISizeConstraint")
    if sc and sc.get("MaxSize"):
        w = min(w, sc["MaxSize"][0]); h = min(h, sc["MaxSize"][1])
    ar = child_of(n, "UIAspectRatioConstraint")
    if ar:
        r = ar.get("AspectRatio", 1)
        if h > 0 and w / h > r: w = h * r
        else: h = w / r if r else h
    return w, h
def draw(n, x, y, w, h, clip, scale=1, origin=(0,0)):
    style = [f"left:{x:.1f}px;top:{y:.1f}px;width:{w:.1f}px;height:{h:.1f}px"]
    if scale != 1:
        style.append(f"transform:scale({scale});transform-origin:{origin[0]*100}% {origin[1]*100}%")
    bt = n.get("BackgroundTransparency", 0)
    bg = n.get("BackgroundColor3", [255,255,255])
    grad = child_of(n, "UIGradient")
    if bt < 1:
        if grad and grad.get("Color"):
            cols = grad["Color"]; rot = grad.get("Rotation", 0)
            c1 = [bg[i]*cols[0][i]/255 for i in range(3)]; c2 = [bg[i]*cols[-1][i]/255 for i in range(3)]
            style.append(f"background:linear-gradient({90+rot}deg,{rgb([int(v) for v in c1],1-bt)},{rgb([int(v) for v in c2],1-bt)})")
        else:
            style.append(f"background:{rgb(bg,1-bt)}")
    cor = child_of(n, "UICorner")
    if cor:
        r = cor.get("CornerRadius",[0,8]); style.append(f"border-radius:{min(w,h)*r[0]+r[1]:.1f}px")
    for st in kids(n):
        if st["c"] == "UIStroke" and (st.get("ApplyStrokeMode","Contextual") == "Border" or n["c"] not in ("TextLabel","TextButton")):
            if st.get("Thickness",1) > 0:
                style.append(f"box-shadow:0 0 0 {st.get('Thickness',1)}px {rgb(st.get('Color',[0,0,0]),1-st.get('Transparency',0))}")
    if n.get("Rotation"): style.append(f"transform:rotate({n['Rotation']}deg)")
    if clip: style.append("overflow:hidden")
    inner = ""
    text = n.get("Text")
    if n["c"] in ("TextLabel","TextButton") and text:
        tc = n.get("TextColor3",[0,0,0]); font = FONTS.get(n.get("Font",""), "'Inter','Noto Color Emoji',sans-serif")
        pad = child_of(n, "UIPadding")
        pt=pb=pl=pr=0
        if pad:
            g=lambda k: pad.get(k,[0,0]); pt=g("PaddingTop")[0]*h+g("PaddingTop")[1]; pb=g("PaddingBottom")[0]*h+g("PaddingBottom")[1]
            pl=g("PaddingLeft")[0]*w+g("PaddingLeft")[1]; pr=g("PaddingRight")[0]*w+g("PaddingRight")[1]
        mts = child_of(n, "UITextSizeConstraint"); mx = mts.get("MaxTextSize",100) if mts else 100
        shadow = ""
        for st in kids(n):
            if st["c"] == "UIStroke" and st.get("ApplyStrokeMode") == "Contextual":
                t = st.get("Thickness",1); c = rgb(st.get("Color",[0,0,0]))
                shadow = f"text-shadow:{' ,'.join(f'{dx}px {dy}px 0 {c}' for dx in (-t,0,t) for dy in (-t,0,t))};"
        ha = {"Left":"flex-start","Right":"flex-end"}.get(n.get("TextXAlignment"),"center")
        ta = {"Left":"left","Right":"right"}.get(n.get("TextXAlignment"),"center")
        va = {"Top":"flex-start","Bottom":"flex-end"}.get(n.get("TextYAlignment"),"center")
        scaled = n.get("TextScaled", False)
        fs = n.get("TextSize", 14)
        inner = (f'<div class="t" data-scaled="{1 if scaled else 0}" data-max="{mx}" style="position:absolute;left:{pl:.1f}px;top:{pt:.1f}px;right:{pr:.1f}px;bottom:{pb:.1f}px;'
                 f'display:flex;align-items:{va};justify-content:{ha};text-align:{ta};color:{rgb(tc,1-n.get("TextTransparency",0))};font-family:{font};font-size:{fs}px;line-height:1.05;white-space:pre-wrap;{shadow}"><span>{html.escape(text)}</span></div>')
    out.append(f'<div style="position:absolute;{";".join(style)}">{inner}')
    layout(n, w, h)
    out.append("</div>")
def layout(n, w, h):
    pad = child_of(n, "UIPadding")
    pl=pt=pr=pb=0
    if pad:
        g=lambda k: pad.get(k,[0,0])
        pt=g("PaddingTop")[0]*h+g("PaddingTop")[1]; pb=g("PaddingBottom")[0]*h+g("PaddingBottom")[1]
        pl=g("PaddingLeft")[0]*w+g("PaddingLeft")[1]; pr=g("PaddingRight")[0]*w+g("PaddingRight")[1]
    if n["c"] in ("TextLabel","TextButton"):
        pass
    cw, ch = w-pl-pr, h-pt-pb
    gch = [k for k in kids(n) if is_gui(k) and k.get("Visible", True)]
    lst = child_of(n, "UIListLayout"); grid = child_of(n, "UIGridLayout")
    clip = n.get("ClipsDescendants", False) or n["c"] == "ScrollingFrame"
    if lst or grid:
        so = (lst or grid).get("SortOrder","LayoutOrder")
        gch.sort(key=lambda k: (k.get("LayoutOrder",0) if so=="LayoutOrder" else 0, k["n"] if so=="Name" else 0))
    if lst:
        horiz = lst.get("FillDirection") == "Horizontal"; p = lst.get("Padding",[0,0]); gap = p[0]*(cw if horiz else ch)+p[1]
        sizes = [size_of(k, cw, ch) for k in gch]
        total = sum(s[0] if horiz else s[1] for s in sizes) + gap*max(0,len(sizes)-1)
        ha = lst.get("HorizontalAlignment","Left"); va = lst.get("VerticalAlignment","Top")
        if horiz: cur = pl + ({"Center":(cw-total)/2,"Right":cw-total}.get(ha,0))
        else: cur = pt + ({"Center":(ch-total)/2,"Bottom":ch-total}.get(va,0))
        for k,(kw,kh) in zip(gch,sizes):
            if horiz:
                ky = pt + ({"Center":(ch-kh)/2,"Bottom":ch-kh}.get(va,0)); place(k, cur, ky, kw, kh, clip); cur += kw+gap
            else:
                kx = pl + ({"Center":(cw-kw)/2,"Right":cw-kw}.get(ha,0)); place(k, kx, cur, kw, kh, clip); cur += kh+gap
    elif grid:
        cs = grid.get("CellSize",[0,100,0,100]); cp = grid.get("CellPadding",[0,5,0,5])
        cw_ = cw*cs[0]+cs[1]; chh = ch*cs[2]+cs[3]; px = cw*cp[0]+cp[1]; py = ch*cp[2]+cp[3]
        per = max(1, int((cw+px)//(cw_+px)))
        for i,k in enumerate(gch):
            place(k, pl+(i%per)*(cw_+px), pt+(i//per)*(chh+py), cw_, chh, clip)
    else:
        for k in sorted(gch, key=lambda k: k.get("ZIndex",1)):
            kw, kh = size_of(k, cw, ch)
            pos = k.get("Position",[0,0,0,0]); ap = k.get("AnchorPoint",[0,0])
            kx = pl + cw*pos[0]+pos[1] - ap[0]*kw; ky = pt + ch*pos[2]+pos[3] - ap[1]*kh
            place(k, kx, ky, kw, kh, clip)
def place(k, x, y, w, h, clip):
    sc = None
    for c in kids(k):
        if c["c"] == "UIScale": sc = (sc or 1)*c.get("Scale",1)
    draw(k, x, y, w, h, k.get("ClipsDescendants", False) or k["c"] in ("ScrollingFrame", "CanvasGroup"), sc or 1, k.get("AnchorPoint",[0,0]))
for path in sys.argv[1].split(","):
    root = json.load(open(path))
    if root.get("Enabled", True) is False: continue
    top = 0 if root.get("IgnoreGuiInset") else INSET
    out.append(f'<div style="position:absolute;left:0;top:{top}px;width:{W}px;height:{H-top}px">')
    layout(root, W, H-top)
    out.append("</div>")
bgimg = sys.argv[4] if len(sys.argv) > 4 else ""
page = f"""<html><head><style>@font-face{{font-family:'FredokaOne';src:url('file://{FREDOKA}')}}
body{{margin:0;width:{W}px;height:{H}px;position:relative;overflow:hidden;
background:{'url('+bgimg+') center/cover' if bgimg else 'linear-gradient(#9fd7ff,#b8e6a8)'};font-family:'DejaVu Sans','Noto Color Emoji'}}
div{{box-sizing:border-box}}</style></head><body>
<div style="position:absolute;left:0;top:0;width:{W}px;height:{INSET}px;background:rgba(0,0,0,.25)"></div>
{''.join(out)}
<script>
for (const t of document.querySelectorAll('.t')) {{
  if (t.dataset.scaled !== '1') continue;
  let lo = 1, hi = +t.dataset.max;
  const fits = s => {{ t.style.fontSize = s + 'px'; return t.scrollHeight <= t.clientHeight + 1 && t.scrollWidth <= t.clientWidth + 1; }};
  while (hi - lo > 0.5) {{ const mid = (lo + hi) / 2; if (fits(mid)) lo = mid; else hi = mid; }}
  t.style.fontSize = lo + 'px';
}}
</script></body></html>"""
open(sys.argv[5] if len(sys.argv) > 5 else "page.html","w").write(page)
