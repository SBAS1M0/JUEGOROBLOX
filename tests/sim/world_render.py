import json, sys
views = json.loads(sys.argv[1])
src = sys.argv[3] if len(sys.argv) > 3 else 'out_world.json'
parts = json.load(open(src))
try:
    terrain = json.load(open(src.replace('.json', '_terrain.json')))
except FileNotFoundError:
    terrain = []
# Desplaza todo para que el terreno del jugador quede en el origen.
off = json.loads(sys.argv[4]) if len(sys.argv) > 4 else [0, 0, 0]
for p in parts:
    p['cf'][0] -= off[0]; p['cf'][1] -= off[1]; p['cf'][2] -= off[2]
for t in terrain:
    t['p'][0] -= off[0]; t['p'][1] -= off[1]; t['p'][2] -= off[2]
parts = [p for p in parts if abs(p['cf'][0]) < 600 and abs(p['cf'][2]) < 600 and p['cf'][1] < 150]
terrain = [t for t in terrain if abs(t['p'][0]) < 600 and abs(t['p'][2]) < 600]
html = """<html><body style="margin:0;background:#000"><canvas id=c width=1280 height=720></canvas>
<script src="node_modules/three/build/three.min.js"></script><script>
const parts = %s; const view = %s; const terrain = %s;
const renderer = new THREE.WebGLRenderer({canvas: document.getElementById('c'), antialias: true, preserveDrawingBuffer: true});
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.1;
const scene = new THREE.Scene(); scene.background = new THREE.Color(0xbcd8ff); scene.fog = new THREE.Fog(0xd8c8ec, 150, 520);
scene.add(new THREE.HemisphereLight(0xffffff, 0x9a8aa8, 1.3));
const sun = new THREE.DirectionalLight(0xfff2e0, 2.2); sun.position.set(120, 200, 80); sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096); const sc = sun.shadow.camera; sc.left = -260; sc.right = 260; sc.top = 260; sc.bottom = -260; sc.far = 800; sun.shadow.bias = -0.0005;
scene.add(sun);
function wedge(){ const g = new THREE.BufferGeometry();
  const v = [[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5],[-.5,.5,.5],[.5,.5,.5]];
  const f = [[0,2,1],[0,3,2],[3,4,5],[3,5,2],[0,1,5],[0,5,4],[0,4,3],[1,2,5]];
  const pos = []; for (const t of f) for (const i of t) pos.push(...v[i]);
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.computeVertexNormals(); return g; }
const box = new THREE.BoxGeometry(1,1,1), sph = new THREE.SphereGeometry(.5, 24, 16), cyl = new THREE.CylinderGeometry(.5,.5,1,28), wg = wedge();
for (const p of parts) {
  let geo = box; const s = p.s; let sx = s[0], sy = s[1], sz = s[2]; let extra = new THREE.Matrix4();
  if (p.c === 'WedgePart') geo = wg;
  else if (p.mesh === 'Sphere') geo = sph;
  else if (p.shape === 'Ball') { geo = sph; const d = Math.min(sx, sy, sz); sx = sy = sz = d; }
  else if (p.shape === 'Cylinder') { geo = cyl; const d = Math.min(sy, sz); extra.makeRotationZ(Math.PI/2); sy = sx; sx = d; sz = d; }
  const col = new THREE.Color(`rgb(${p.col[0]},${p.col[1]},${p.col[2]})`);
  const neon = p.m === 'Neon';
  const mat = new THREE.MeshStandardMaterial({color: col, roughness: p.m === 'SmoothPlastic' ? .55 : (p.m === 'Metal' ? .35 : .85), metalness: p.m === 'Metal' ? .5 : 0,
    emissive: neon ? col : 0x000000, emissiveIntensity: neon ? 1.6 : 0, transparent: p.t > 0, opacity: 1 - p.t});
  let mesh = new THREE.Mesh(geo, mat);
  if (p.art) {
    // Cuadro en la cara frontal (-Z en Roblox): figuras dibujadas en un canvas.
    const S = 256, cv = document.createElement('canvas'); cv.width = cv.height = S;
    const g = cv.getContext('2d'); g.fillStyle = '#fdfaf2'; g.fillRect(0, 0, S, S);
    for (const sh of p.art) {
      g.save(); g.translate(sh.x * S, sh.y * S); g.rotate(sh.rot * Math.PI / 180);
      const w = sh.w * S, h = sh.h * S, r = sh.r * Math.min(w, h);
      let fill = `rgb(${sh.c[0].join(',')})`;
      if (sh.c.length > 1) { const lg = g.createLinearGradient(-w/2, -h/2, w/2, h/2); sh.c.forEach((c, i) => lg.addColorStop(i / (sh.c.length - 1), `rgb(${c.join(',')})`)); fill = lg; }
      g.fillStyle = fill; g.beginPath();
      if (g.roundRect) g.roundRect(-w/2, -h/2, w, h, Math.min(r, w/2, h/2)); else g.rect(-w/2, -h/2, w, h);
      g.fill(); g.strokeStyle = 'rgba(0,0,0,.18)'; g.lineWidth = 1.2; g.stroke(); g.restore();
    }
    const tex = new THREE.CanvasTexture(cv); tex.colorSpace = THREE.SRGBColorSpace;
    const face = new THREE.MeshStandardMaterial({map: tex, roughness: .7});
    mesh = new THREE.Mesh(geo, [mat, mat, mat, mat, mat, face]);
  }
  const r = p.cf; const m = new THREE.Matrix4().set(r[3],r[4],r[5],r[0], r[6],r[7],r[8],r[1], r[9],r[10],r[11],r[2], 0,0,0,1);
  m.multiply(extra); m.multiply(new THREE.Matrix4().makeScale(sx, sy, sz));
  mesh.matrixAutoUpdate = false; mesh.matrix.copy(m);
  mesh.castShadow = p.t < .5; mesh.receiveShadow = true; scene.add(mesh);
}
const TCOL = {Grass: 0x7cbf5a, Water: 0x58b4d8, Rock: 0x9a948c, Sand: 0xe8d4a0, Mud: 0x8a6a4a, Ground: 0x9a7a5a, LeafyGrass: 0x6aae4a};
for (const t of terrain) {
  if (t.m === 'Air') continue;
  const water = t.m === 'Water';
  const mat = new THREE.MeshStandardMaterial({color: TCOL[t.m] || 0x88aa66, roughness: water ? .15 : .95, metalness: 0, transparent: water, opacity: water ? .85 : 1});
  let mesh;
  if (t.k === 'block') { mesh = new THREE.Mesh(box, mat); mesh.scale.set(...t.s); mesh.position.set(...t.p); }
  else if (t.k === 'ball') { mesh = new THREE.Mesh(sph, mat); mesh.scale.setScalar(t.r * 2); mesh.position.set(...t.p); }
  else { mesh = new THREE.Mesh(cyl, mat); mesh.scale.set(t.r * 2, water ? 0.1 : t.h, t.r * 2); mesh.position.set(t.p[0], water ? 0.06 : t.p[1], t.p[2]); }
  mesh.receiveShadow = true; scene.add(mesh);
}
const cam = new THREE.PerspectiveCamera(view.fov || 60, 1280/720, .5, 2000);
cam.position.set(...view.pos); cam.lookAt(new THREE.Vector3(...view.at));
renderer.render(scene, cam); window.done = true;
</script></body></html>""" % (json.dumps(parts), json.dumps(views), json.dumps(terrain))
open(sys.argv[2], 'w').write(html)
