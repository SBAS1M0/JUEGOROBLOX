# 🎨 Galería Pincelada (juego de Roblox)

Tienes un **taller de arte** junto a tu **galería**. En el taller sacas pinturas
de una máquina de colores (con rarezas), eliges un diseño, decides qué color va
en cada parte y lo pintas a mano. Después lo cuelgas en tu galería y llegan
visitantes (avatares reales de Roblox, por ejemplo tus amigos) a comprarlo.

![Mapa](docs/mapa.jpg)

| Galería y taller | Dentro del taller |
| --- | --- |
| ![Galería](docs/galeria.jpg) | ![Taller](docs/taller.jpg) |

## Cómo se juega

1. **Máquina de colores**: tira para conseguir pinturas. Cada color tiene una
   rareza que **multiplica** el valor del cuadro:

   | Rareza | Multiplicador |
   | --- | --- |
   | Básico (infinito) | x1.0 |
   | Común | x1.1 |
   | Poco común | x1.3 |
   | Raro | x1.6 |
   | Épico (degradado) | x2.2 |
   | Legendario (degradado) | x3.5 |
   | Mítico (arcoíris, galaxia) | x6.0 |

   Con **Auto-Rolling** la máquina tira sola. Con **Mejora** tira más rápido y
   con más suerte.
2. **Elige un diseño**: hay 16 diseños repartidos en 4 niveles. Los niveles
   altos se venden más caros. Para abrir un nivel tienes que pintar todos los
   diseños del anterior, y luego desbloquear cada diseño con dinero.
3. **Elige tus colores**: cada área del dibujo (cielo, globo, nubes…) toma el
   color que elijas. Verás el **valor** del cuadro en vivo: los colores raros
   rinden más en las áreas grandes.
4. **Pinta**: el dibujo aparece en líneas y cada figura se va rellenando
   mientras pasas el pincel. Se muestra el % de cada área. La mejora
   🪣 *Cubeta mágica* rellena una figura entera de un toque.
5. **Vende**:
   - 🖼️ **Expón** el cuadro en tu galería: un visitante entra, lo mira y lo
     compra por un **25% más**.
   - 💰 **Véndelo ya** si tienes prisa o la galería está llena.

| Elige un diseño | Elige tus colores |
| --- | --- |
| ![Diseños](docs/disenos.jpg) | ![Colores](docs/colores.jpg) |
| **Pintando** | **¡Terminado!** |
| ![Pintando](docs/pintando.jpg) | ![Terminado](docs/terminado.jpg) |

### Lo que te engancha

- **Colección de colores**: 30 pinturas para descubrir, con su probabilidad
  por tirada. Las que no tienes salen como «???».
- **Maestría** por diseño: 🥉 Bronce (3 cuadros, +5%), 🥈 Plata (8, +10%) y
  🥇 Oro (20, +20%).
- **8 mejoras**:
  - Suerte y velocidad de la máquina.
  - Pincel grande y cubeta mágica.
  - Precios, fama (llegan más visitantes) y más paredes (hasta 7 cuadros en venta).
  - Decoración: plantas, alfombra roja, estatua, guirnalda de luces,
    candelabro y arco de globos.
- **Visitantes con avatares reales**: tus amigos de Roblox (o avatares
  conocidos) entran caminando con animaciones, admiran el cuadro, celebran
  y te lo compran.
- **Regalo diario 🎁**: monedas y un color raro o mejor.
- El progreso se guarda automáticamente.

![Obras](docs/obras.jpg)

![Colección](docs/coleccion.jpg)

## Cómo abrirlo en Roblox Studio

### Opción fácil

1. Descarga **`GaleriaPincelada.rbxlx`**.
2. Ábrelo con **Roblox Studio** y pulsa **Play** ▶️. Todo (mundo, visitantes,
   interfaz) se crea por código.

Para **guardar el progreso** de los jugadores:

1. *Archivo → Publicar en Roblox*.
2. *Configuración del juego → Seguridad*: activa **«Permitir que Studio acceda
   a los servicios de API»**.
3. *Configuración del juego → Lugares*: pon el **máximo de jugadores en 6**.

### Opción para recibir cambios sin descargar nada (Rojo)

1. Clona el repositorio (por ejemplo con GitHub Desktop).
2. Instala [Rojo](https://rojo.space) y su plugin de Studio.
3. Ejecuta `rojo serve` en la carpeta del repositorio y pulsa
   *Rojo → Connect* en Studio.
4. Para cada actualización solo tienes que hacer *Pull* en GitHub Desktop y
   Studio se actualiza solo.

## Personalizar

- **Diseños nuevos**: `src/shared/Designs.lua`. Cada diseño se arma con
  figuras: `R` (rectángulo), `C` (círculo), `P` (píldora), `Heart`,
  `Sparkle` y `Ring`, sobre un lienzo de 0 a 1. Cada figura pertenece a un área.
- **Colores y rarezas**: `src/shared/Colors.lua`.
- **Economía, mejoras y maestría**: `src/shared/Config.lua`.
- **Mundo** (galería, taller, plaza): `src/server/Services/WorldBuilder.lua`.

## Estructura

```
src/
  shared/      Colores, diseños, configuración (servidor y cliente)
  server/      Mundo, visitantes, guardado, máquina, ventas y mejoras
  client/      Ventanas: diseños, colores, pintura, máquina, mejoras, HUD
tests/sim/     Simulador que ejecuta el juego completo fuera de Roblox
```

El servidor valida todo: pinturas suficientes, diseño desbloqueado, tiempo
mínimo de pintura y precios. Así los jugadores no pueden hacer trampas.
