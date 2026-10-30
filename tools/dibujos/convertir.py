"""Convierte un dibujo de líneas (PNG/JPG en blanco y negro) en un diseño para
colorear del juego.

Uso:
    pip install pillow numpy scipy
    python3 tools/dibujos/convertir.py tools/dibujos/chica.json

El .json dice qué imagen usar, el nombre del dibujo y sus áreas de color
(pelo, piel...). Cada área lista "semillas": puntos (x, y) en píxeles de la
imagen original que caen dentro de una zona de esa área. Las zonas cerradas
por las líneas se detectan solas; cada zona toma el área de su semilla. Las
zonas sin semilla toman el área de la zona vecina con más borde en común (el
script avisa para que puedas revisarlas) y las diminutas, o las de la lista
"white", se quedan blancas (brillos de los ojos, botones...).

Genera:
  src/shared/Drawings/<id>.lua   datos del dibujo para el juego
  tools/dibujos/<id>_zonas.png   vista previa: cada zona con el color de su área
"""

import base64
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIZE = 512  # resolución del dibujo en el juego
MIN_REGION = 40  # zonas más pequeñas (en píxeles originales) quedan blancas

PREVIEW_COLORS = {
    "amarillo": (255, 210, 66), "rosa": (255, 138, 190), "negro": (54, 52, 68),
    "durazno": (255, 200, 164), "azul": (60, 118, 228), "blanco": (255, 255, 255),
    "verdeoscuro": (42, 132, 88), "celeste": (126, 204, 250), "rojo": (236, 70, 80),
    "cafe": (146, 94, 62), "morado": (150, 96, 222), "naranja": (255, 148, 56),
    "verde": (100, 196, 92), "crema": (255, 243, 220), "gris": (168, 172, 186),
    "marino": (40, 50, 112),
}


def varint(n, out):
    while True:
        byte = n & 0x7F
        n >>= 7
        if n:
            out.append(byte | 0x80)
        else:
            out.append(byte)
            return


def encode_labels(flat):
    out = bytearray()
    i, total = 0, len(flat)
    while i < total:
        value = int(flat[i])
        j = i
        while j < total and flat[j] == value:
            j += 1
        out.append(value)
        varint(j - i, out)
        i = j
    return out


def encode_alpha(flat):
    out = bytearray()
    i, total = 0, len(flat)
    while i < total:
        value = int(flat[i])
        j = i
        while j < total and flat[j] == value:
            j += 1
        run = j - i
        if run < 15:
            out.append(value * 16 + run)
        else:
            out.append(value * 16 + 15)
            varint(run - 15, out)
        i = j
    return out


def lua_string(data, indent="\t\t"):
    text = base64.b64encode(bytes(data)).decode()
    chunks = [text[k:k + 1000] for k in range(0, len(text), 1000)]
    return "table.concat({\n" + "".join(f'{indent}"{c}",\n' for c in chunks) + indent[:-1] + "})"


def main(config_path):
    cfg = json.load(open(config_path, encoding="utf-8"))
    base = os.path.dirname(os.path.abspath(config_path))
    gray = np.array(Image.open(os.path.join(base, cfg["image"])).convert("L")).astype(np.float32)
    h, w = gray.shape
    side = max(h, w)
    top, left = (side - h) // 2, (side - w) // 2
    gray = np.pad(gray, ((top, side - h - top), (left, side - w - left)), constant_values=255)
    line = gray < cfg.get("umbral", 160)

    regions, count = ndimage.label(~line)
    sizes = ndimage.sum(np.ones_like(regions), regions, range(1, count + 1))

    # Área de cada zona según las semillas.
    area_ids = [a["id"] for a in cfg["areas"]]
    area_of = {}
    for area_index, area in enumerate(cfg["areas"]):
        for x, y in area["seeds"]:
            r = regions[y + top, x + left]
            if r == 0:
                print(f"aviso: la semilla {x},{y} de «{area['id']}» cae sobre una línea")
                continue
            area_of[r] = area_index
    white = set()
    for x, y in cfg.get("white", []):
        r = regions[y + top, x + left]
        if r:
            white.add(r)
            area_of.pop(r, None)
    for r in range(1, count + 1):
        if r not in area_of and sizes[r - 1] < MIN_REGION:
            white.add(r)

    # Zonas sin semilla: toman el área de la vecina con más borde en común.
    pending = [r for r in range(1, count + 1) if r not in area_of and r not in white]
    guessed = []
    while pending:
        progress = False
        for r in list(pending):
            ring = ndimage.binary_dilation(regions == r, iterations=5) & (regions != r) & (regions > 0)
            votes = {}
            for other in regions[ring]:
                if other in area_of:
                    votes[area_of[other]] = votes.get(area_of[other], 0) + 1
            if votes:
                area_of[r] = max(votes, key=votes.get)
                guessed.append((r, area_ids[area_of[r]]))
                pending.remove(r)
                progress = True
        if not progress:
            for r in pending:
                white.add(r)
            break
    if guessed:
        print("zonas sin semilla (revisa la vista previa):",
              ", ".join(f"{a} en {np.argwhere(regions == r)[0][::-1] - [left, top]}" for r, a in guessed))

    # Numeración final: por área y de mayor a menor.
    kept = sorted(area_of, key=lambda r: (area_of[r], -sizes[r - 1]))
    if len(kept) > 255:
        sys.exit("demasiadas zonas (máximo 255): sube MIN_REGION o simplifica el dibujo")
    new_index = np.zeros(count + 1, dtype=np.int32)
    for i, r in enumerate(kept):
        new_index[r] = i + 1

    # Las líneas toman la zona más cercana (así no quedan huecos bajo el trazo).
    _, (iy, ix) = ndimage.distance_transform_edt(line, return_indices=True)
    full = new_index[regions[iy, ix]]

    scale = side / SIZE
    centers = ((np.arange(SIZE) + 0.5) * scale).astype(int)
    labels = full[np.ix_(centers, centers)]
    darkness = Image.fromarray((255 - gray).astype(np.uint8)).resize((SIZE, SIZE), Image.BOX)
    alpha = np.clip(np.array(darkness, dtype=np.float32) / 255 * 1.4, 0, 1)
    alpha_q = np.round(alpha * 15).astype(np.int32)

    # Datos de cada zona (en fracciones del lienzo).
    region_rows = []
    for i, r in enumerate(kept):
        mask = labels == i + 1
        if not mask.any():
            mask = full[np.ix_(centers, centers)] == i + 1
        ys, xs = np.nonzero(mask)
        if len(xs) == 0:
            ys, xs = np.array([0]), np.array([0])
        # El borde del lienzo también cuenta como borde (el número no queda cortado).
        inner = np.where(mask, ndimage.distance_transform_edt(np.pad(mask, 1))[1:-1, 1:-1], 0)
        ly, lx = np.unravel_index(inner.argmax(), inner.shape)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        region_rows.append(
            "\t\t{ a = %s, x = %.4f, y = %.4f, w = %.4f, h = %.4f, v = %.5f, lx = %.4f, ly = %.4f, lr = %.4f },"
            % (
                json.dumps(area_ids[area_of[r]]),
                (x0 + x1) / 2 / SIZE, (y0 + y1) / 2 / SIZE, (x1 - x0) / SIZE, (y1 - y0) / SIZE,
                mask.sum() / SIZE / SIZE, (lx + 0.5) / SIZE, (ly + 0.5) / SIZE, inner.max() / SIZE,
            )
        )

    label_bytes = encode_labels(labels.flatten())
    alpha_bytes = encode_alpha(alpha_q.flatten())
    areas_lua = "\n".join(
        f'\t\t{{ id = "{a["id"]}", name = "{a["name"]}", default = "{a["default"]}" }},' for a in cfg["areas"]
    )
    lua = f"""-- Dibujo «{cfg["name"]}» para colorear. Generado por tools/dibujos/convertir.py
-- a partir de tools/dibujos/{cfg["image"]}: no lo edites a mano, vuelve a convertirlo.
-- labels: zona de cada píxel ({SIZE}x{SIZE}, 0 = blanco fijo) en RLE y base64.
-- alpha: oscuridad de la línea de cada píxel (0-15) en RLE y base64.
return {{
	id = "{cfg["id"]}",
	size = {SIZE},
	areas = {{
{areas_lua}
	}},
	regions = {{
{chr(10).join(region_rows)}
	}},
	labels = {lua_string(label_bytes)},
	alpha = {lua_string(alpha_bytes)},
}}
"""
    out_dir = os.path.join(ROOT, "src", "shared", "Drawings")
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, cfg["id"] + ".lua"), "w", encoding="utf-8") as f:
        f.write(lua)

    # Vista previa con los colores por defecto y el número de cada área.
    colors = np.array([(255, 255, 255)] + [PREVIEW_COLORS.get(cfg["areas"][area_of[r]]["default"], (200, 200, 200))
                                           for r in kept], dtype=np.float32)
    fill = colors[labels]
    ink = np.array([34, 34, 44], dtype=np.float32)
    a = (alpha_q / 15.0)[..., None]
    preview = Image.fromarray((fill * (1 - a) + ink * a).astype(np.uint8))
    draw = ImageDraw.Draw(preview)
    for i, r in enumerate(kept):
        row = region_rows[i]
        if sizes[r - 1] > 1500:
            lx = float(row.split("lx = ")[1].split(",")[0]) * SIZE
            ly = float(row.split("ly = ")[1].split(",")[0]) * SIZE
            draw.text((lx - 3, ly - 5), str(area_of[r] + 1), fill=(0, 0, 0))
    preview.save(os.path.join(base, cfg["id"] + "_zonas.png"))
    print(f"{cfg['id']}: {len(kept)} zonas, {len(white)} blancas, labels {len(label_bytes)} B, "
          f"alpha {len(alpha_bytes)} B")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
