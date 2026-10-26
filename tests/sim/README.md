# Simulador de pruebas

Ejecuta el juego completo (servidor + cliente) fuera de Roblox, sobre una
imitación del motor que valida cada propiedad, enum y clase contra la base de
datos oficial de la API de Roblox. Sirve para detectar errores antes de abrir
Studio.

```bash
pip install lupa msgpack
cargo install rojo          # descarga la base de datos de la API de Roblox
python3 tests/sim/gen_db.py # genera rbxdb.lua y defaults.lua
python3 tests/sim/run.py scenario.lua   # partida completa: tutorial, pintar, stands, ofertas, mezclador...
python3 tests/sim/run.py multi.lua      # 13 jugadores (cada uno su terreno) sin DataStore
python3 tests/sim/run.py studio.lua     # Studio sin acceso a las APIs
python3 tests/sim/run.py migrate.lua    # partidas antiguas: marcos -> stands
python3 tests/sim/run.py showcase.lua   # galería con 3 salas para las capturas
```

Cada escenario imprime `ok - ...` por comprobación y termina con `errors: 0`.
