# AGENTS.md — Guía para agentes de IA y colaboradores

Este archivo es el punto de entrada obligatorio para cualquier agente de IA
(Claude, opencode, etc.) o persona que continúe el desarrollo del proyecto.
Debes leerlo completo antes de tocar código y **actualizarlo al terminar cada
cambio de funcionalidad** (secciones "Historial", "En progreso" y "Próximos
pasos").

---

## 1. Qué es este proyecto

Videojuego 2D de plataformas **lineal** hecho con **Godot 4.7 (GL
Compatibility) y GDScript**. Jugabilidad inspirada en Super Mario Bros. con
exploración, saltos, enemigos, trampas, controles y un final de juego.

Objetivo del jugador: atravesar los seis niveles hasta llegar al final del
juego. Cada nivel da tres vidas; al morir se reaparece en el último control
(bandera) activado y, sin vidas o sin tiempo, el nivel se reinicia. El nivel
alcanzado queda guardado para continuar la partida.

Desarrollo **incremental**: una mecánica por vez, probada antes de continuar.
Nunca implementar varios sistemas a la vez ni reescribir código existente sin
explicar qué se modifica y por qué.

## 2. Cómo ejecutar

Motor (no está en el PATH):
```
C:\Users\Usuario\Downloads\Godot_v4.7.2-stable_win64_console.exe
```

- Abrir proyecto: ejecutar el exe de arriba y elegir la carpeta del proyecto.
- Ejecutar el juego desde CLI: `--path . res://scenes/ui/main_menu.tscn`
- Regenerar caches tras crear/renombrar scripts o escenas (class_name, .uid):
  `--headless --path . --import`
- Suite de tests (todos deben pasar antes de dar por terminado un cambio):
  ```
  Get-ChildItem tests -Filter *.gd | ForEach-Object {
      & "C:\Users\Usuario\Downloads\Godot_v4.7.2-stable_win64_console.exe" `
          --headless --path . --script "res://tests/$($_.Name)" }
  ```
  Cada test es un script `SceneTree` autónomo que imprime `[OK]`/`[FALLO]`
  y devuelve exit code 0/1. Las pruebas headless no leen ni escriben el
  guardado (`SaveGame` lo desactiva detectando `headless`).
- Exportar ejecutable de Windows (las plantillas 4.7.2 ya están instaladas
  en `%APPDATA%\Godot\export_templates\4.7.2.stable`):
  ```
  & "C:\Users\Usuario\Downloads\Godot_v4.7.2-stable_win64_console.exe" `
      --headless --path . --export-release "Windows Desktop"
  ```
  Genera `dist/PlataformasRoguelite.exe` (archivo único con el PCK
  embebido, ~104 MB). El preset vive en `export_presets.cfg`.

## 3. Arquitectura actual

```
project.godot        # input map + capas físicas (World/Player/Enemies/PlayerAttack)
scenes/
  ui/main_menu.tscn        # escena inicial: jugar, instrucciones, opciones, salir
  ui/control_guide.tscn    # guía de controles con teclas dibujadas (reutilizable)
  ui/pause_overlay.tscn    # pausa con Enter: congela el SceneTree y muestra guía
  ui/game_complete.tscn    # pantalla final con tiempo total y muertes
  levels/test_level.tscn   # BASE de los 6 niveles (HUD, jugador, portal, cámara)
  levels/level_one|two|three|four|five|six.tscn  # instancias base con level_variant 1-6
  player/player.tscn       # Player + AttackHitbox + Health
  enemies/                 # training_dummy, walker, ranged, spread, projectile
  pickups/                 # healing_herb (monedas eliminadas, ver ítem 24)
  world/                   # platform, moving_platform, saw/spike_trap, fall_zone,
                           # exit_portal, checkpoint (bandera de control)
  camera/horizontal_camera.tscn
  decor/                   # árboles, arbustos, nubes, aves, sol (sin colisión)
scripts/
  player/    # player.gd (movimiento, salto/doble salto, caída rápida, pociones),
             # inventory.gd (inventario real: utilizables/permanentes + Q/E),
             # player_stats.gd,
             # attacks/ (attack_data.gd + attack_hitbox.gd)
  enemies/   # jerarquía: TrainingDummy -> RangedEnemy/SpreadEnemy/WalkerEnemy;
             # flying_enemy.gd + flying_spawner.gd (voladores ondulantes),
             # sky_sentry.gd (centinela superior que dispara cada 2 s)
  levels/    # test_level.gd (controlador común) + layouts generados por código:
             # level_one_extension.gd, level_two_layout.gd, level_three_layout.gd,
             # level_four_layout.gd (gran pozo de plataformas móviles),
             # level_four_route.gd (plataformas del pozo y enemigos a bordo),
             # level_five_layout.gd (cielo con 28 plataformas, voladores y
             # sierras suspendidas),
             # level_six_layout.gd (fortaleza de 20 plataformas, trampas y
             # centinela superior),
             # platform_spacing.gd (regla de espaciado entre plataformas)
  combat/    # health.gd (vida reutilizable por jugador y enemigos)
  core/      # save_game.gd (nivel guardado + tiempo/muertes, user://save.cfg),
             # gamepad_bindings.gd (mapeo fijo de mando, idempotente)
  ui/        # main_menu.gd, control_guide.gd (keycaps), pause_overlay.gd,
             # game_complete.gd, game_settings.gd (brillo/volumen/teclas, user://)
  audio/     # sfx.gd (sonidos sintetizados + música procedural por nivel)
  fx/        # particles.gd (class_name Fx: fábrica de partículas procedurales)
  world/, decor/, camera/, pickups/  # decor/mountain_builder.gd: capas de
             # detalle (nieve/cresta/sombra/arbolitos) para las colinas
resources/player/  # player_stats.tres y basic_attack.tres (AttackData)
assets/fx/spark.svg # textura de punto blanco para todas las partículas
assets/enemies/    # fireball.svg y crossbow_bolt.svg (proyectiles de mago/soldado)
assets/decor/      # tree/bush/cloud/bird/sun.svg (rediseñados con detalle)
tests/       # smoke tests headless, uno por sistema (31 en total)
```

Decisiones clave:
- Los 6 niveles son instancias de una misma escena base; cada variante limpia
  el contenido base y genera su mundo por código (`scripts/levels/*_layout.gd`).
- Los datos sensibles van en `Resource` exportables (`PlayerStats`,
  `AttackData`) para reutilizarlos con futuros personajes/armas.
- Comunicación entre sistemas mediante señales de Godot.
- El jugador muere con 3 golpes (cualquier daño normal consume 1 golpe;
  los valores >= 9999 son letales instantáneos: pozos y cronómetro). La
  invulnerabilidad tras recibir daño dura 1 s.
- **Modo plataformas lineal (2026-11-12)**: el objetivo es llegar al final del
  juego; no hay progresión roguelite ni botín permanente. `SaveGame` guarda el
  nivel alcanzado para continuar. Cada nivel da 3 vidas: morir reaparece en el
  último control (bandera) con la vida completa; al quedarse sin vidas o al
  agotar el tiempo se recarga el nivel. El nivel 6 termina en
  `ui/game_complete.tscn`.

Controles (reconfigurables desde Opciones):
A/D o flechas mover · Espacio saltar (otra pulsación en el aire = doble salto,
siempre disponible) · S/Abajo caer rápido · Shift correr · Q poción · E ración ·
Tab inventario · Enter pausa.
Mando: stick/DPAD mover y caer rápido · A saltar · X correr · LB/RB objetos
rápidos · Back inventario · Start pausa (mapeo fijo, ver `GamepadBindings`).
NOTA: el juego es SIN combate: la acción `attack` sigue eliminada
(`no_combat_smoke_test` y `player_smoke_test` lo verifican). `item_2` volvió
como espacio rápido de objeto (E), no como bomba ni ataque. `player.gd`
conserva `_handle_attack()` sin llamar como código muerto; no reactivarlo sin
actualizar esos tests.

## 4. Historial: lo que ya está HECHO

1. **Personaje jugable completo**: movimiento con aceleración/deceleración
   configurables, salto con altura variable (mantener botón), coyote time,
   jump buffer, carrera, ataque con cooldown y hitbox, animaciones
   procedurales, invulnerabilidad y knockback tras daño, muerte animada.
2. **Doble salto permanente (actualizado 2026-11-12)**: el jugador dispone
   siempre de un impulso aéreo por salto desde el suelo (una pulsación extra
   de salto). Ya no depende de monedas ni de cargas. Ver ítem 23.
3. **Cámara horizontal** suave con límites por nivel y `fixed_y`.
4. **Tres niveles distintos**:
   - Nivel 1 (día, 100 s): recorrido largo con colinas, pozos y plataformas.
   - Nivel 2 (atardecer, 80 s): fosos con plataformas móviles, sierras,
     pinchos y walkers rápidos.
   - Nivel 3 (noche, granja, 75 s): walkers muy rápidos y decoración rural.
   Cada nivel termina en un portal que lleva al siguiente; el nivel 3 vuelve
   al menú principal.
5. **Cuenta regresiva por nivel**: si llega a 0 el jugador muere. Barra de
   progreso del recorrido y cronómetro rojo bajo 10 s.
6. **Enemigos**: TrainingDummy (base con vida/daño por contacto/muerte),
   WalkerEnemy (patrulla), RangedEnemy (proyectil con línea de visión) y
   SpreadEnemy.
7. **Pickups**: hierba curativa (las monedas se eliminaron, ver ítem 24).
8. **HUD**: cronómetro, progreso, cargas de salto, slots de objetos, panel de
   inventario informativo (Tab), mensajes de muerte/completado (el conteo de
   recursos se mantiene interno; ver ítem 14).
9. **Menú principal**: jugar, opciones (brillo, volumen, rebind de teclas con
   guardado en `user://`), contador de partidas.
10. **Progreso permanente mínimo**: `GameProgress` guarda partidas jugadas en
    `user://progress.cfg` (las monedas y las mejoras de vida están eliminadas;
    el campamento futuro usará nuevos recursos).
11. **Audio procedural** (sin assets): saltos, golpes, curación, música.
12. **Último cambio (2026-11, sesión previa + esta sesión)**: eliminados los
    jefes que bloqueaban el avance. El portal está siempre disponible y el
    antiguo `BossEnemy` se convirtió en **`SpreadEnemy`** (enemigo común de
    ráfaga, 40 PV, dispara abanico de 3-5 proyectiles) que aparece
    repartido en los TRES niveles: 6 en nivel 1, 5 en nivel 2 y 4 en nivel 3.
    Ver `scripts/enemies/spread_enemy.gd` y los layouts de cada nivel.
13. **Exportación a ejecutable**: preset "Windows Desktop" en
    `export_presets.cfg` (x86_64, PCK embebido) y plantillas de exportación
    4.7.2 instaladas. Genera `dist/PlataformasRoguelite.exe`, verificado
    arrancando en modo headless y con ventana real (OpenGL).
14. **Último cambio (2026-11-11, primera mitad)**: HUD limpio y pausa. Los
    contadores de recursos/total salieron del HUD (solo queda "Saltos: x/3";
    el conteo interno y el resumen al completar el nivel se mantienen) y el
    slot de objetos muestra solo "Poción x2". La guía de comandos ya no
    aparece durante el juego: existe una guía reutilizable **con teclas
    dibujadas** (`scenes/ui/control_guide.tscn`, keycaps = PanelContainer con
    StyleBoxFlat) que se muestra en el menú principal (2 columnas) y en la
    nueva **pausa con Enter** (`scenes/ui/pause_overlay.tscn`,
    `PROCESS_MODE_ALWAYS`, congela el SceneTree; bloqueada tras morir o
    completar vía `TestLevel.is_run_over()`). Acción `pause` añadida al
    Input Map y a Opciones (rebind con GameSettings). Test nuevo:
    `pause_smoke_test.gd`.
15. **Mover con flechas (2026-11-11)**: `game_settings.gd` re-agrega las
    flechas ←/→ como teclas extra de `move_left`/`move_right` tras cada
    rebind (constante `EXTRA_KEYS`), así el jugador siempre puede moverse
    con A/D o flechas aunque reasigne las principales. La guía muestra los
    keycaps de flecha. NOTA: incluido en el exe de `dist/` desde la re-exportación del 2026-11-11.
16. **Regla de espaciado entre plataformas (2026-11-11, última)**: cualquier
    hueco entre dos plataformas debe medir >= 1.5x el tamaño del jugador en
    el eje del hueco (45 px horizontal por ancho 30, 72 px vertical por
    altura 48); si dos plataformas se tocan o se solapan en un eje, ese eje
    no tiene hueco y se tolera (suelo continuo, plataformas apiladas). Las
    plataformas móviles quedan excluidas. Implementado como helper estático
    `scripts/levels/platform_spacing.gd` (`PlatformSpacing`) + test
    `tests/platform_spacing_smoke_test.gd` que valida la regla en sí y
    recorre los 3 niveles (0 violaciones, la suite completa de 18 tests
    pasa). Para cumplirla se rediseñaron las alturas/posiciones de las
    plataformas de la escena base (`Platform1-6` en tiers 548/440), las
    secciones y arena del nivel 1 (6 plataformas por sección en tiers
    548/440/330), la escalera del nivel 2 (6 peldaños por sección, pasos de
    96 px) y las pasarelas/islas del nivel 3 (tiers 556/460/364).
    Arreglos de bugs descubiertos al aplicar la regla:
    - El portal del nivel 3 estaba a 686 px del último suelo → INALCANZABLE
      (nivel incompletable). El suelo final pasa de `[10860, 1280]` a
      `[11285, 2130]` (centro/ancho), llegando hasta x=12350; el portal se
      queda en x=12150 y la cámara en 12600 sin cambios.
    - Cuatro walkers del nivel 3 nacían sobre pozos (x 2150, 4450, 6850 y
      9350) y caían al vacío: movidos a suelo firme (2450, 4000, 7500,
      9700). La moneda en x=11900 también flotaba sobre el vacío y ahora
      apoya en el suelo ampliado.
    - Plataformas móviles del nivel 2 a y=600 dejaban solo ~29 px de hueco
      respecto al suelo (el jugador no cabía): ahora y=556 (hueco ~73 px).
    - Moneda de tierra del nivel 1 en `start+620` flotaba sobre el pozo de
      las secciones con pozo de 288 px: movida a `start+560`.
    NOTA: incluido en el exe de `dist/` desde la re-exportación del 2026-11-11.
17. **Pulido visual (2026-11-11, última)**: cinco mejoras de presentación
    aplicadas de una en una con la suite en verde tras cada una:
    - **Vestido de plataformas**: `platform.gd` crea en `_refresh()` dos
      hijos `TopHighlight` (color base `lightened(0.22)`, alto
      `clamp(y*0.22, 2, 5)`) y `BottomShadow` (base `darkened(0.45)` al 65%
      de alpha, alto `clamp(y*0.16, 2, 4)`); se recrean con `get_node_or_null`
      así el patrón es idempotente. `MovingPlatform` NO hereda de `Platform`
      y queda sin vestido (igual que queda fuera de la regla de espaciado).
    - **Squash & stretch + polvo del jugador**: `player.gd` escala `$Visual`
      (nuevo `visual_root`) con `_squash(escala, duración)` (tween que siempre
      vuelve a `Vector2.ONE`); salto (0.84, 1.18)/0.14 s, aterrizaje
      comprime según la velocidad de caída capturada antes de
      `move_and_slide()` (`_fall_speed`). Polvo `DustPuff` (CPUParticles2D
      one-shot, se reutiliza con `restart()`) al saltar y aterrizar; se
      cancela el tween al morir. Sombra `Shadow` (Polygon2D) en `player.tscn`
      a los pies, igual que los enemigos.
    - **Chispas y auras**: `scripts/fx/particles.gd` (`class_name Fx`,
      RefCounted, todo estático) configura CPUParticles2D por código con la
      única textura `assets/fx/spark.svg`: `make_dust` (jugador),
      `make_sparkle` (destello continuo de moneda y hierba), `make_burst`
      (estallido al recoger; se cuelga del PADRE del pickup porque el pickup
      hace `queue_free()` inmediato y se autolibera por timer) y
      `make_portal_aura` (aura cian ascendente del portal). OJO: en Godot 4.7
      el área de emisión rectangular de CPUParticles2D es
      `emission_rect_extents` (no `emission_box_extents`).
    - **Paralaje**: fondos con `Parallax2D` (sin `repetition_size`; la banda
      visible se cubre a mano: ventana visible = [sC - ancho_pantalla/2,
      sC + ancho_pantalla/2] en el espacio de la capa). Nivel 1:
      `BackgroundDecor` de la base pasa de Node2D a Parallax2D (escala 0.3,
      z -16, detrás de las colinas estáticas de la extensión que quedan a
      z -14) con 12 colinas (Hill5-12 clones a +2900/+5800) y las nubes
      migran de las secciones a `CloudParallax` (escala 0.55, z -8, 11
      nubes). El sol ya iba fijo en pantalla por script (`screen_sun.gd`,
      top_level) y no se toca. Nivel 2: `HillParallax` (0.3) y `CloudParallax`
      (0.55, z -8) dentro de `LevelTwoGenerated` con posiciones compactadas
      a la banda visible. Nivel 3: `StarParallax` (0.08, estrellas solo en
      x [0,2200]), `MoonParallax` (0.02) y `HillParallax` (0.3). La
      variación por run de `_apply_run_variation` sigue funcionando (itera
      los hijos Polygon2D de BackgroundDecor).
    - Test nuevo: `visual_polish_smoke_test.gd` (22 comprobaciones: vestido,
      sombra/polvo/squash, chispas, aura y capas Parallax2D de los tres
      niveles).
    NOTA: incluido en el exe de `dist/` desde la re-exportación del 2026-11-11.
18. **Disparo horizontal sin apuntar (2026-11-11, última)**: los enemigos a
    distancia ya NO apuntan al jugador. `RangedEnemy._shoot()` ahora recibe
    solo `direction` y construye `aim = Vector2(direction, 0)`: el proyectil
    vuela siempre en horizontal hacia el lado en que esté el jugador (se
    esquiva saltando o cambiando de altura). El `SpreadEnemy` mantiene su
    abanico (3 disparos a ±10° alrededor de la horizontal; 5 a ±20° por debajo
    del 50% de vida) con la misma firma `_shoot(direction)`. No cambian los
    chequeos de rango (|offset.x| <= shoot_range, |offset.y| <= 170), el
    cooldown, ni la línea de visión (el rayo sigue mirando AL jugador para
    decidir si dispara; solo la trayectoria del proyectil es horizontal).
    Test actualizado: `enemy_ranged_smoke_test.gd` (ahora 14 comprobaciones:
    jugador en repisa a otra altura -> proyectil horizontal que pasa por
    debajo sin golpear; jugador a la misma altura -> 1 golpe consumido; y
    abanico horizontal del SpreadEnemy). El test de LOS no cambió.
    NOTA: el exe de `dist/` fue exportado ANTES de este cambio y NO lo
    incluye; re-exportar cuando se pida.
19. **Rediseño de enemigos y ambiente (2026-11-11, última)**:
    - **Sombrero mejicano pisable** en dummy y walker: se añade
      `HeadShape` (RectangleShape2D 68×10 en y −32) y el daño baja a
      36×38 en (0,5); el jugador puede posarse sobre la cabeza sin daño y
      el sombrero (ala 72×14, copa, banda con zigzag, pompones) tapa la
      antigua cabeza. HealthBar a −66/−58. Walker conserva patrulla,
      `FloorAhead`, mask 3 y paleta morada.
    - **RangedEnemy → mago azul**: túnica con dobladillo zigzag, cinturón,
      mangas, barba, cejas y `WizardHat` (ala + cono doblado + banda +
      estrella); bastón con orbe de fuego. HealthBar a −70/−62. Dispara
      bolas de fuego (`assets/enemies/fireball.svg`) con estela de llamas
      (`FlameTrail`) y estallido naranja al impactar.
    - **SpreadEnemy → soldado medieval**: malla, tabardo rojo con emblema,
      hombreras, `Helmet` con penacho y `Crossbow` (culata, arco, cuerda,
      virote). HealthBar a −78/−70. Dispara virotes
      (`assets/enemies/crossbow_bolt.svg`) sin estela y sin giro.
      Colisión 56×80 y daño 64×82 intactos (sigue dañando al pisarlo).
    - **`enemy_projectile.gd`**: `enum Style { FIRE, BOLT }` con
      `use_fire_style()`/`use_bolt_style()` idempotentes (helper
      `apply_style()`); `particles.gd` gana `make_fire_trail()` y
      `_fire_ramp()`. TRAMPA: `Gradient.remove_point()` falla con
      `points.size() <= 1`; rellenar con `ramp.offsets`/`ramp.colors`.
      `energy_orb.svg` eliminado.
    - **Ambiente SVG**: `tree` (raíces, corteza, ramas, frutas),
      `bush` (racimos, bayas, florecitas, briznas), `cloud` (bultos,
      borde iluminado), `bird` (alas por capas, cola, patas con dedos) y
      `sun` (dos capas de rayos + halos). Canvas y anclajes intactos.
    - **Colinas con detalle**: `scripts/decor/mountain_builder.gd`
      (`MountainBuilder.decorate()`, idempotente, crea `MountainDetail`
      con cima de nieve en zigzag, cresta iluminada, ladera en sombra y
      arbolitos lejanos). Enganchado en `_decorate_base_hills` (solo
      variante 1), `_add_hill` de la extensión del nivel 1, las colinas
      del nivel 2 (sin nieve) y las del nivel 3 (con nieve).
    - **Nivel 3**: cráteres en la luna; silo con remate, franja de luz y
      puerta; molino con buje, puerta, ventana y velas en las aspas;
      vallas con remates puntiagudos; cultivos con espigas doradas; heno
      con vetas y bandas.
    - Tests: `enemy_visual_smoke_test.gd` nuevo (15 comprobaciones),
      `enemy_ranged_smoke_test.gd` ampliado a 18 (FIRE+FlameTrail, BOLT
      sin estela) y `decor_detail_smoke_test.gd` nuevo (16). Suite
      completa: 21/21.
    NOTA: el exe de `dist/` NO incluye los ítems 18 y 19; re-exportar
    cuando se pida.
20. **Enemigos humanoides sin barras de vida (2026-11-11, última)**:
    - **Barra de vida eliminada** de los 4 enemigos (nodos `HealthBar`,
      StyleBox y referencias en `training_dummy.gd`); el nodo `Health` y la
      lógica de daño/muerte se mantienen.
    - **Humanoides proporcionales** (~48 px, escala del jugador): piernas,
      brazos, manos, torso, cuello, cabeza y ojos con rectángulos
      (pixel-art procedural, sin curvas). Dummy rojo/marrón, walker morado.
      Colisiones y daños intactos.
    - **Sombrero simplificado**: `SombreroDome` (domo) + `SombreroBrimLine`
      (línea de 70×3.5). Eliminados banda con zigzag, pompones y ala ovalada.
    - **Mago**: cada disparo lanza 3 bolas de fuego en abanico horizontal de
      ±10° (`RangedEnemy.FIREBALL_COUNT` y `FIREBALL_SPREAD_DEG`). Sigue con
      túnica, barba, sombrero de mago y bastón; ahora con piernas visibles.
    - **Arquero** (`SpreadEnemy`): una sola flecha por disparo a 300 px/s
      (más rápida que la bola de fuego a 240). Proyectil con forma de flecha
      (`crossbow_bolt.svg` rediseñado, 32×12). Se reduce su escala al resto:
      colisión 32×48 (antes 56×80) y daño 36×38 en (0,5) (antes 64×82).
    - Tests: `enemy_visual_smoke_test.gd` 25 comprobaciones (sombrero simple,
      humanoides, sin barras) y `enemy_ranged_smoke_test.gd` 23 (ráfaga de 3
      del mago y flecha única más rápida del arquero). Suite: 21/21.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se
    pida.
21. **Enemigos más grandes, instrucciones y HUD (2026-11-12)**:
    - **Sin escalado de disparo en niveles posteriores**: se eliminaron los
      overrides `shoot_interval 1.05` y `projectile_speed 280` del mago en
      `level_two_layout.gd` (el nivel 2 usa los valores base 1.7 s / 240);
      se conserva `shoot_range 520`. El nivel 3 nunca tuvo overrides.
    - **Enemigos +25%**: los 4 enemigos llevan `Visual.scale = (1.25, 1.25)`
      y `Visual.position.y = -6` (los pies siguen a +24 con la colisión
      intacta). Los sombreros de dummy/walker van dentro del Visual con
      pivote `(0,-25)` y `scale = 0.6` (tamaño neto 0.75, es decir 25% más
      pequeños) y `HeadShape` sube a y −42 para que el jugador siga
      posándose sobre el domo.
    - **Menú — Instrucciones**: nuevo botón `INSTRUCCIONES` (antes de
      MEJORAS) y panel `InstructionsPanel` con guía de controles en 2
      columnas + secciones OBJETIVO, OBJETOS DEL NIVEL (moneda, hierba,
      portal, plataformas, pinchos, enemigos), TIEMPO (100/80/75/90 s) e ITEMS
      (poción Q, doble salto, inventario Tab). Esc/Volver cierra. El panel
      principal se compacta (márgenes 18, separación 10, botones 44) para
      que quepa el botón nuevo. La guía del panel principal se retiró el
      2026-11-12 (solo queda en Instrucciones y en la pausa).
    - **HUD**: `LevelProgress` pasa a **borde blanco**, interior **gris
      claro** y relleno **gris oscuro**, `show_percentage = false`; nuevo
      `ProgressLabel` (hijo, anclado a toda la barra) con letras negras
      "PROGRESO DE NIVEL  n%", actualizado en `_update_progress_bar()`.
    - **Cartel de nivel**: `_show_level_banner()` crea un `LevelBanner`
      ("NIVEL n · DÍA/ATARDECER/NOCHE") centrado al empezar y lo desvanece
      con un tween (1.2 s + 0.6 s de fade, se autolibera).
    - **Menú**: la línea de progreso permanente pasa a
      "Monedas: N · Partidas: N · Mejor: N" (sin nodos nuevos).
    - **Audio**: `Sfx.start_music()` registra el reproductor con
      `add_child.call_deferred` y arranca en su señal `ready`, eliminando el
      error "Parent node is busy setting up children" al entrar al nivel.
    - Tests: `menu_smoke_test.gd` 30 comprobaciones (instrucciones ocultas,
      botón, guía, textos, abrir/cerrar y línea de progreso),
      `timer_progress_smoke_test.gd` 11 (marcador de progreso, porcentaje y
      cartel de nivel) y `enemy_visual_smoke_test.gd`
      29 (escala 1.25 del cuerpo y sombrero neto 0.75). Suite: 21/21.
    NOTA: el exe de `dist/` NO incluye los ítems 18-21; re-exportar cuando se
    pida.
22. **Nivel 4 "El Gran Pozo" (2026-11-12)**:
    - **Gorro del mago más pequeño**: `WizardHat` pasa a `scale 0.7` con
      pivote en la base (`position (0,-7.8)`): ala 52→36 px y copa 20→14 px,
      sin moverse de la cabeza.
    - **Plataformas móviles nuevas**: `moving_platform.gd` gana
      `circle_radius`/`circle_speed` (órbita) y `rotation_speed` (giro sobre
      su eje); el vaivén lineal/diagonal sigue usando `travel`/`speed`
      (niveles 2/3 intactos).
    - **Nivel 4**: `level_four.tscn` (variante 4, "ABISMO", 90 s) y
      `level_four_layout.gd`. Solo hay dos islas firmes (inicio 0..1900 y
      final 10100..12400 separadas por un pozo de 8200 px con una única
      `FallZonePit`); todo el centro se cruza por una cadena directa de 31
      plataformas móviles (grupo `main_route`, x de 2140 en pasos de 260)
      que alternan vertical (travel y 80), diagonal (±70, 55), circular
      (r=55) y giratoria (0.7 rad/s), más 6 plataformas opcionales con
      monedas a y=430. Escenario: cielo abisal, colinas con parallax 0.3 y
      rocas flotantes decorativas. El nivel 3 ahora continúa hacia el 4 y el
      4 vuelve al menú. Texto de TIEMPO del menú ampliado con 90 s.
    - **Regla de alcance**: las trayectorias de plataformas consecutivas del
      tramo principal se solapan o quedan a ≤300 px (constante
      `MAX_JUMP_DISTANCE`), validado muestreando 40 puntos por trayectoria.
      El test también exige que la primera/última plataforma estén al alcance
      de los bordes de las islas, que existan los 4 movimientos, que los
      walkers solo patrullen suelo firme y que el portal/cámara cubran el
      final.
    - Tests: `level_four_smoke_test.gd` nuevo (30 comprobaciones),
      `level_three_smoke_test.gd` actualizado (continúa al nivel 4),
      `platform_spacing_smoke_test.gd` incluye el nivel 4. Suite: 22/22.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se
    pida.
23. **Doble salto permanente y caída rápida (2026-11-12)**:
    - **Sin monedas de salto ni marcadores**: `coin.gd` ya solo suma
      recursos (`add_double_jump_charge` eliminado de `player.gd`, junto con
      `double_jumps`, `MAX_DOUBLE_JUMPS`, la señal `double_jumps_changed` y
      el nodo `HUD/Resources`). El `JumpsInfo` del inventario es ahora texto
      fijo: "Doble salto: disponible siempre en el aire. Abajo/S: caer
      rápido."
    - **Doble salto siempre disponible**: `_handle_jump()` permite un salto
      aéreo mientras `_jumps_used < 2`; el suelo/coyote lo reinicia. Un
      tercer salto en el aire no impulsa.
    - **Caída rápida**: nueva acción `move_down` (S + flecha abajo, también
      rebindable en Opciones; `GameSettings.CONTROLS/EXTRA_KEYS`). En el aire
      fija `velocity.y` a `stats.fast_fall_speed` (nuevo export de
      `PlayerStats`, 900) y cancela la carga del salto. En el suelo no hace
      nada (no hay crouch).
    - **Instrucciones**: la guía de controles añade la fila "Caer rápido"
      (teclas S y ↓, 11 keycaps) y la fila de salto pasa a "Saltar / doble
      salto"; el menú de Instrucciones actualiza OBJETOS (moneda solo
      recurso) e ITEMS (doble salto permanente, caída rápida, Tab).
    - Tests actualizados: `player_smoke_test` 31 (move_down, doble salto
      permanente, sin tercer salto, caída rápida), `jump_control_smoke_test`
      11, `pickup_smoke_test` 7, `inventory_smoke_test` 17,
      `exit_smoke_test` 9, `menu_smoke_test` 31, `pause_smoke_test` 18
      (11 keycaps). Suite: 22/22.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se
    pida.
24. **Ajustes de juego (2026-11-12)**: tres cambios pedidos tras probar:
    - **Daño por contacto fiable**: `training_dummy.gd` añade
      `_check_contact_damage()` (recorre `damage_area.get_overlapping_bodies()`
      cada frame de física) y lo llaman también `walker_enemy.gd` y
      `ranged_enemy.gd` al final de su `_physics_process`. Antes solo se usaba
      la señal `body_entered`: si el jugador seguía pegado al enemigo al
      terminar la invulnerabilidad no volvía a recibir daño. El área de daño
      del walker pasa de 36×38 a 44×38 (el borde superior sigue en y −14, así
      el sombrero continúa siendo pisable).
    - **Nivel 2 sin el primer walker**: en la sección inicial se omite el
      walker de suelo en `start_x + 560` (se conserva el de `+1420`); el
      eliminado patrullaba hasta el punto de salida y golpeaba al jugador
      inmóvil. `level_two_smoke_test.gd` comprueba que no haya walkers de
      suelo a menos de 900 px del spawn.
    - **Monedas eliminadas por completo**: borrados
      `scenes/pickups/coin.tscn`, `scripts/pickups/coin.gd`, sus spawns en
      `test_level.tscn` y en los cuatro layouts, `_reduce_coin_density`, el
      intercambio de monedas de `_apply_run_variation`, el sonido `coin` de
      `sfx.gd` y las menciones del menú/instrucciones. `GameProgress` deja de
      contar monedas y "mejor run": solo guarda `runs` (`add_run_result()`
      sin parámetro). El mensaje de nivel completado es solo
      "NIVEL n COMPLETADO" (sin recursos ni total) y el HUD/inventario y el
      menú muestran únicamente "Partidas: n". Las plataformas opcionales del
      nivel 4 se mantienen (antes tenían monedas encima).
    - Tests: `pickup_smoke_test` reescrito (7 comprobaciones: escena de
      moneda borrada, 0 monedas en los 4 niveles, hierba sigue curando),
      `enemy_patrol_smoke_test` 7 (contacto continuo vuelve a dañar),
      `level_two_smoke_test` 27, `exit_smoke_test` 10,
      `menu_smoke_test` 31, `visual_polish_smoke_test` 21,
      `level_one_layout_smoke_test` 18, `level_three_smoke_test` 24,
      `level_four_smoke_test` 30, `inventory_smoke_test` 17. Suite: 22/22.
    NOTA: el exe de `dist/` NO incluye los ítems 18-24; re-exportar cuando se
    pida.
25. **Modo plataformas lineal: checkpoints, vidas, guardado y final
    (2026-11-12)**: seis mejoras acordadas tras descartar el roguelite.
    - **Capa roguelite eliminada**: borrado `scripts/core/game_progress.gd`
      (sustituido por `scripts/core/save_game.gd`, `class_name SaveGame`),
      botón MEJORAS del menú y contador de partidas. El menú queda en Jugar /
      Instrucciones / Opciones / Salir y muestra "NIVEL n DE 4".
    - **Checkpoints y vidas**: `scripts/world/checkpoint.gd` +
      `scenes/world/checkpoint.tscn` (Area2D mask 2, grupo `checkpoints`,
      señal `activated`); al pisarlo cura toda la vida y fija el punto de
      reaparición. Tres vidas por nivel; al morir se reaparece en el último
      control tras 1,2 s con la vida completa; sin vidas se recarga el nivel
      tras 2,2 s. Checkpoints: nivel 1 en x 3200/9100/16500, nivel 2 en
      3700/8600/10900, nivel 3 en 3100/8200/12000 y nivel 4 en 1700/10750
      (islas de inicio y final). `Player.revive(spawn_position)` restaura el
      cuerpo sin recargar la escena. El ítem 26 redujo los controles a uno por
      nivel a mitad del recorrido.
    - **HUD**: `HUD/HealthIcons` (corazones `♥`/`♡`), `HUD/LivesLabel`
      ("VIDAS: n") y `HUD/DamageFlash` (ColorRect rojo con tween). El daño
      también sacude la cámara (`HorizontalCamera.shake()`); al reaparecer se
      llama `snap_to_target()`. La etiqueta de muerte distingue
      "HAS MUERTO", "SIN VIDAS" y "TIEMPO AGOTADO". El panel principal del
      menú ya no muestra la guía de controles (queda solo en Instrucciones y
      en la pausa).
    - **Guardado simple**: `SaveGame` (user://save.cfg) guarda nivel, tiempo
      total, muertes y completado; Jugar continúa el nivel guardado y, si la
      partida estaba completada, empieza una nueva. Completar un nivel guarda
      el siguiente y el tiempo se acumula sin duplicarse al morir
      (`_account_time()`).
    - **Pantalla final**: `scenes/ui/game_complete.tscn` +
      `scripts/ui/game_complete.gd` con tiempo total formateado, muertes,
      botones JUGAR DE NUEVO (reinicia estadísticas), MENÚ y SALIR.
      `level_four.tscn` apunta a ella.
    - **Presentación**: fundido a negro al empezar y entre escenas (CanvasLayer
      layer 90 creado por código), música procedural distinta por nivel
      (`Sfx.start_music(level_index)`: raíz/tempo/arpegio cambian; el
      reproductor persiste en la raíz) y créditos en la pantalla final.
    - **Legibilidad**: sierras con parpadeo de aviso (`warmup_time`, 0,6 s)
      antes de moverse y pinchos con brillo pulsante.
    - Tests: `checkpoint_smoke_test` nuevo (10), `game_complete_smoke_test`
      nuevo (11), `survival_smoke_test` 22 (corazones, flash, respawn, vidas),
      `timer_progress_smoke_test` 12, `exit_smoke_test` 11 (guarda nivel 2),
      `menu_smoke_test` 30 (sin mejoras, sin guía en el panel principal,
      nivel guardado),
      `level_two/three/four` 28/25/31 (checkpoints y final). Suite: 24/24.
    NOTA: el exe de `dist/` NO incluye este cambio ni los ítems 18-24;
    re-exportar cuando se pida.
26. **Ajuste de checkpoints, vidas y tiempo de respawn (2026-11-12)**:
    - **Un checkpoint por nivel a mitad del recorrido**: nivel 1 en x=11500
      (extensión del nivel), nivel 2 en x=6700, nivel 3 en x=6000 y nivel 4 en
      x=6000. En el gran pozo se añadió una **isla de descanso estática**
      (300×80 en y=720, superficie a y=680) sobre la zona de caída para alojar
      el control sin tocar la ruta móvil; ahora hay 3 islas firmes (inicio,
      descanso central y final).
    - **3 vidas por nivel**: se mantiene la cantidad; el HUD muestra
      "VIDAS: n" y los corazones siguen representando los 2 golpes de vida.
    - **Tiempo al reaparecer**: al revivir en un control se suman solo 10 s;
      si al morir quedaban 20 s o menos, el tiempo restante pasa a 30 s.
      Nunca supera el límite del nivel. Sustituye la regla anterior del 25 %.
    - **Fundido/transición de música**: `Sfx.start_music(level, fade_in)` entra
      con fundido, `Sfx.stop_music(fade_out)` baja el volumen y detiene el
      reproductor; imagen y música se funden a la vez en las transiciones de
      nivel, menú y pantalla final (`SceneFade` centraliza los cambios de
      escena desde menús/pantalla final).
    - **Agentes opencode**: `.opencode/agent/` define subagentes por área
      (`player-survival`, `levels-world`, `enemies-hazards`, `ui-flow`,
      `audio-fx`, `core-save`, `testing`) con instrucciones específicas y la
      obligación de correr la suite completa.
    - Tests: `checkpoint_smoke_test` 12 (1 control, cura, respawn, reglas de
      tiempo +10/30), `level_two` 28, `level_three` 25, `level_four` 33
      (3 islas y control central). Suite: 24/24.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se pida.
27. **Inventario real (2026-11-12)**: el panel de Tab deja de ser informativo.
    - **`scripts/player/inventory.gd`** (`class_name Inventory`,
      RefCounted): fuente de verdad de cantidades y espacios rápidos. Enum
      `Category { PERMANENT, USABLE }`, catálogo `ITEMS` (poción, doble salto,
      caída rápida), `SLOT_COUNT=2` y `SLOT_ACTIONS=["item_1","item_2"]`.
      API: `add_item`, `consume`, `count`, `usable_items`, `permanent_items`,
      `unlock_permanent`, `equip`, `slot_item`, `slot_label`; señal `changed`.
    - **Jugador**: `Player.inventory` sustituye al contador suelto; `potions`
      pasa a getter de solo lectura sobre el inventario. `use_quick_slot(0/1)`
      usa el objeto equipado (Q/E) y `use_potion()` sigue existiendo como
      atajo. Al agotarse una poción su espacio rápido queda vacío; al añadir
      otra se auto-equipa en el primer hueco.
    - **Controles**: nueva acción `item_2` (E) en el Input Map, Opciones y
      guía de controles (ahora 12 keycaps). `attack` sigue sin existir; los
      tests de no-combate verifican que `item_2` es un espacio de objeto.
    - **HUD**: `ItemSlots` muestra `Q <objeto> - E <objeto>`; el panel de Tab
      separa `UTILIZABLES` y `PERMANENTES` y muestra los dos espacios rápidos
      (`PotionInfo`, `JumpsInfo`, `MetaInfo` reutilizados).
    - **Instrucciones**: el texto de ITEMS explica Q/E, las categorías y que
      Tab abre el inventario real.
    - Tests: `inventory_smoke_test` reescrito (37 comprobaciones),
      `pause_smoke_test` 18 (12 keycaps), `no_combat_smoke_test` 7,
      `player_smoke_test` 31, `menu_smoke_test` 31. Suite: 24/24.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se pida.
28. **Nivel 4 poblado y walkers más rápidos (2026-11-13)**:
    - **WalkerEnemy**: nueva constante `MOVE_SPEED_SCALE = 1.25` aplicada a
      `velocity.x`; afecta a todos los walkers de todos los niveles sin tocar
      sus overrides de `patrol_speed`. RangedEnemy y SpreadEnemy (los que
      disparan) no cambian.
    - **Nivel 4**: además de los 4 walkers de salida/llegada, se añadió un
      walker en la isla de descanso central (x=6000, patrulla 95) y tres
      guardias SpreadEnemy (dos fijos en la isla de descanso en 5920/6080 y
      uno en la llegada en 11600) más otro en la salida (x=1000). Los guardias
      de la isla tienen `patrol_speed=0` para no caer al pozo.
    - Tests: `level_four_smoke_test` 36 (walkers >= 5, walker en la isla
      central, SpreadEnemy >= 4, ningún walker en el aire) y
      `enemy_patrol_smoke_test` 8 (escala de velocidad). Suite: 25/25.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se pida.
29. **Ración, mando y selección de nivel (2026-11-13)**:
    - **Ración (E)**: nuevo objeto utilizable en `Inventory.ITEMS` (categoría
      USABLE, descripción "Añade 5 s al cronómetro"). El jugador empieza con
      1 (`starting_rations`), se auto-equipa en E y `use_quick_slot(1)` la
      consume y emite `item_used("ration")`. `TestLevel._on_item_used()` suma
      `RATION_TIME_BONUS = 5.0` segundos sin superar `time_limit`.
    - **Mando**: `scripts/core/gamepad_bindings.gd` (`class_name
      GamepadBindings`) mapea stick/DPAD y botones A/X/LB/RB/Back/Start a las
      acciones de juego. `GameSettings.ensure_loaded()` lo aplica y
      `_set_action_key()` lo re-aplica tras cada rebind para no perder el
      mando. Test nuevo `gamepad_smoke_test` (18 comprobaciones).
    - **Selección de nivel**: fila `LevelSelect` creada por código en el menú
      (botones 1-4 antes de Jugar); `SaveGame.start_at_level()` reinicia
      tiempo/muertes/completado y guarda el nivel elegido. Tests de menú
      ampliados a 34 comprobaciones.
    - Tests: `inventory_smoke_test` 43 (ración, señal y +5 s),
      `menu_smoke_test` 34, `gamepad_smoke_test` 18, `level_four` 36,
      `enemy_patrol` 8. Suite: 25/25.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se pida.
30. **Legibilidad de controles y trampas (2026-11-13)**:
    - **Descanso en checkpoints**: al activar una bandera,
      `TestLevel._show_checkpoint_banner()` muestra durante ~1,8 s el aviso
      "CONTROL ACTIVADO / DESCANSO · VIDA RESTAURADA" sobre el HUD. El control
      sigue curando toda la vida y fijando el punto de reaparición.
    - **Trampas**: ya existían el parpadeo de aviso de las sierras
      (`warmup_time`) y el brillo pulsante de los pinchos; ahora un test
      dedicado comprueba ambos comportamientos.
    - Tests: `checkpoint_smoke_test` 13 (aviso de descanso),
      `hazard_legibility_smoke_test` nuevo (7 comprobaciones). Suite: 26/26.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se pida.
31. **Nivel 4: plataformas en streaming y enemigos a bordo (2026-11-13)**:
    - **Máximo 6 plataformas activas**: nuevo `scripts/levels/level_four_route.gd`
      (`class_name LevelFourRoute`) sustituye las 31 plataformas simultáneas.
      La ruta conserva 31 huecos (`ROUTE_COUNT`) y 4 movimientos, pero solo
      mantiene 6 nodos vivos: al avanzar el jugador la plataforma más antigua
      se recicla al siguiente hueco. Al reaparecer, la ruta se recoloca
      alrededor del jugador (detecta retrocesos >900 px). Los huecos y
      trayectorias son funciones estáticas para que el test valide el alcance
      completo sin instanciar 31 nodos.
    - **30% más rápidas**: `LevelFourRoute.SPEED_SCALE = 1.3` multiplica la
      velocidad de vaivén, órbita y giro. Se eliminan las 6 plataformas
      opcionales de y=430.
    - **Enemigos a bordo**: los `SpreadEnemy` de las plataformas son hijos de
      plataformas no giratorias (`gravity=0`, `patrol_speed=0`, posición local
      `(0,-35)`) y viajan con ellas. Se eliminan el walker y los dos guardias
      de la isla de descanso; el control central queda despejado. Se añaden
      walkers en la salida/llegada (6 en total) y se mantienen los 2 arqueros
      de las islas.
    - Tests: `level_four_smoke_test` 49 (6 activas, reciclado, recolocación,
      alcance de los 31 huecos, 4 movimientos, enemigos a bordo y control
      limpio). Suite: 26/26.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se pida.
32. **Inicio del nivel 4 despejado (2026-11-13)**:
    - **Jugador al borde izquierdo**: `LevelFourLayout.PLAYER_START = (70, 600)`
      coloca al jugador pegado al extremo izquierdo de la isla inicial y
      `camera.snap_to_target()` recoloca la cámara tras construir el nivel.
    - **Sin enemigos en la mitad izquierda**: se eliminan el walker de x=700 y
      el arquero de x=1000; la salida conserva dos walkers en x=1350 y x=1700
      (mitad derecha). `START_SAFE_X = 1100` documenta el límite.
    - Tests: `level_four_smoke_test` 49 (inicio en el borde y 0 enemigos con
      x < 1100). Suite: 26/26.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se pida.
33. **Corrección del reciclado del nivel 4 (2026-11-13)**:
    - **Plataformas giratorias recolocadas sin tocar `sync_to_physics`**:
      teletransportar una giratoria con sync activo deja el cuerpo físico en
      la transformación vieja, y desactivar sync mueve el nodo pero deja la
      colisión en el sitio anterior (el jugador atraviesa la plataforma
      visible). `LevelFourRoute._recycle_platform()` devuelve `bool`: si el
      hueco destino es giratorio descarta la plataforma vieja
      (`_discard_platform()`) y crea una nueva con `_spawn_slot()` (así nodo y
      cuerpo físico nacen alineados); si no gira, reutiliza la plataforma con
      `teleport_to()`. `MovingPlatform.teleport_to()` solo reinicia `_origin`,
      `_time`, `_base_rotation`, `rotation` y `position`; nunca cambia sync.
    - **Guardias anclados**: `RangedEnemy` gana `anchored`; cuando está activo
      no ejecuta gravedad ni `move_and_slide()` y solo comprueba el daño por
      contacto. Los guardias de plataforma lo activan, así mantienen su
      posición local `(0,-35)` en lugar de despegarse y flotar.
    - **Proyectiles fuera de la plataforma**: `_projectile_parent()` sube por
      los padres hasta salir de un nodo del grupo `moving_platforms`. Las
      flechas/bolas de los guardias ya no se crean como hijas de la
      plataforma y dejan de viajar/desaparecer con ella.
    - Tests: `level_four_smoke_test` 57 (plataformas recicladas en su hueco,
      colisión física alineada con el cuerpo, giro tras reciclado, guardias
      anclados y proyectiles en el mundo). Suite: 26/26.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se pida.
34. **Nivel 4 sin límite de plataformas y giro limitado (2026-11-13)**:
    - **Todas las plataformas activas**: `LevelFourRoute` deja de reciclar y
      de hacer desaparecer plataformas. La ruta queda en 17 huecos
      (`ROUTE_STEP = 480`) y todos existen a la vez; `get_active_slot_indices()`
      devuelve la ruta completa. Se eliminan `MAX_ACTIVE`, el reciclado y la
      recolocación por retroceso.
    - **Sin solapes**: el paso de 480 px y los recorridos reducidos (diagonal
      ±65 px, órbita 50 px) mantienen disjuntas las trayectorias consecutivas;
      el test comprueba que los rangos horizontales no se cruzan y que el
      hueco entre bordes sigue siendo <= 300 px.
    - **Inclinación máxima 30°**: `MovingPlatform` ya no da vueltas completas;
      `rotation = base + sin(t * rotation_speed) * PI/6`, así ninguna
      plataforma (incluidas las giratorias estáticas) supera ±30°.
    - Tests: `level_four_smoke_test` 57 (todas activas, sin reciclado, sin
      solapes, inclinación <= 30°, colisión alineada, guardias anclados y
      proyectiles en el mundo). Suite: 26/26.
    NOTA: el exe de `dist/` se re-exportó con este cambio.

35. **Magos, densidad del nivel 3 y reinicio al nivel 1 (2026-11-13)**:
    - **Magos recuperados**: nivel 3 en x=3300/6400/8800 y nivel 4 en
      x=1200/12200, fuera de las zonas seguras y del control central.
    - **Nivel 3 más legible**: los walkers de suelo bajan de 20 a 14
      posiciones (se quitan 1550, 3850, 5950, 8750, 11050 y 11350).
    - **Game over y tiempo agotado**: `TestLevel._restart_from_first_level()`
      usa `SaveGame.start_at_level(SaveGame.FIRST_LEVEL)` y
      `FIRST_LEVEL_PATH`; con vidas restantes se mantiene la reaparición en
      el control. HUD: "SIN VIDAS - Volviendo al nivel 1..." y
      "TIEMPO AGOTADO - Volviendo al nivel 1...".
    - Tests: `survival_smoke_test` 24, `timer_progress_smoke_test` 13,
      `level_three_smoke_test` 26, `level_four_smoke_test` 58. README
      actualizado.
36. **Niveles 5 y 6, plataformas modulares y voladores (2026-11-13)**:
    - **Asset modular de plataformas**: `scripts/world/platform.gd` pasa a
      `AnimatableBody2D` con `enum Kind { STATIC, HORIZONTAL, CIRCULAR,
      SPIKED, ROTATING }`. Vaivén con `travel`/`speed`, órbita horaria con
      `circle_radius`/`circle_speed`, giro limitado a ±30° y pinchos solo en
      los bordes (`SpikeLeft`/`SpikeRight`, centro libre). `platform.tscn`
      cambia su tipo de nodo y conserva el vestido visual. `PlatformSpacing`
      excluye las plataformas móviles del asset.
    - **Voladores**: `scripts/enemies/flying_enemy.gd` + escena (criatura
      alada, 20 PV, daño por contacto, sin gravedad ni colisión con el
      mundo); `scripts/enemies/flying_spawner.gd` los crea fuera del borde
      visible, alterna lado y permite altura aleatoria o la del jugador. La
      cámara se añade al grupo `camera` para localizar el centro de pantalla.
    - **Nivel 5 "CIELO"**: `level_five.tscn` + `level_five_layout.gd`, 110 s.
      Islas de inicio/final, 21 plataformas de ruta (paso 480, ancho 190,
      huecos ~290), los cinco tipos, un control en el índice 9, dos hierbas y
      un `FlyingSpawner` cada 4 s a altura aleatoria (150-520). Solo hay
      voladores como enemigos.
    - **Nivel 6 "FORTALEZA"**: `level_six.tscn` + `level_six_layout.gd`,
      120 s. 14 plataformas (paso 740, ancho 260, huecos de 480 px que
      exigen doble salto), pinchos en los bordes, 3 sierras patrullando y 2
      plataformas giratorias; control en el índice 6 y dos hierbas. Sin
      enemigos fijos: el reto son las trampas y los saltos.
    - **Integración**: `level_four.tscn` encadena al 5, el 5 al 6 y el 6 a
      `game_complete`; `SaveGame.LAST_LEVEL = 6`; el menú ofrece 6 niveles y
      las instrucciones muestran 110/120 s; `MOODS` añade CIELO y FORTALEZA.
    - Tests nuevos: `level_five_smoke_test` 34, `level_six_smoke_test` 44,
      `platform_asset_smoke_test` 15 y `flying_enemy_smoke_test` 9.
      Actualizados: `level_four_smoke_test` 58, `menu_smoke_test` 35,
      `platform_spacing_smoke_test` 22 (incluye niveles 5/6). Suite: 30/30.
    NOTA: el exe de `dist/` se re-exportó con los ítems 35-36.
37. **Menú de pausa completo, pinchos sobre suelo y vuelo duplicado
    (2026-11-16)**:
    - **Pausa con menú**: `scenes/ui/pause_overlay.tscn` pasa de una guía
      simple a tres paneles (`MenuPanel`, `GuidePanel`, `SettingsPanel`).
      El menú ofrece CONTINUAR, GUÍA, CONFIGURACIÓN, VOLVER AL MENÚ PRINCIPAL
      y SALIR. La guía reutiliza `ControlGuide` en una columna (12 keycaps);
      Configuración replica brillo, volumen, rebinding y restaurar controles
      del menú principal. `scripts/ui/pause_overlay.gd` conserva la pausa con
      Enter y sigue bloqueada al morir/completar; volver al menú reanuda el
      árbol y usa `SceneFade`, y Salir cierra el juego.
    - **Brillo en pausa**: se aplica al `CanvasModulate` del nivel mediante
      `GameSettings.apply_brightness()`, no a una capa nueva.
    - **Pinchos solo en suelo**: en `level_two_layout.gd` se eliminan los
      cuatro pinchos del fondo de los fosos y el de x=5450 se mueve a x=5800
      (isla de tierra 5620-7000). Los pinchos de borde de las plataformas
      `Platform.Kind.SPIKED` siguen permitidos. Tests: `level_two` 29 y
      `hazard_legibility` 7 validan que no haya pinchos sueltos en el aire.
    - **Vuelo más amplio y rápido**: `FlyingEnemy.wave_amplitude` pasa de
      42 a 84 y `wave_frequency` de 2.2 a 4.4 (+100 % de recorrido vertical y
      de velocidad de oscilación). `flying_enemy_smoke_test` 11 comprueba los
      valores base.
    - **Tests**: `pause_smoke_test` 38 (menú, guía, configuración, paneles que
      caben en pantalla, cancelación de rebinding, reanudar y bloqueo tras
      morir),
      `level_two_smoke_test` 29, `flying_enemy_smoke_test` 11 y
      `hazard_legibility_smoke_test` 7. Suite completa: 30/30.
    NOTA: el exe de `dist/` se re-exportó con los ítems 18-37.
38. **Contornos negros en formas geométricas básicas (2026-11-16)**:
    - **Objetivo**: mejorar la legibilidad de las trampas y estructuras
      dibujadas con polígonos planos. Se añadió un contorno negro cerrado
      (`Line2D`, 2-3.5 px, unión y extremos redondeados) a las plataformas,
      plataformas móviles, pinchos, sierras, controles (base, mástil y
      bandera) y portal (borde exterior, anillo medio y núcleo).
    - **Plataformas dinámicas**: `platform.gd` crea/actualiza `Outline` en
      `_refresh()` con los mismos límites que `platform_size`; así el
      contorno sigue el tamaño y queda por encima del vestido visual.
    - **Animaciones intactas**: los contornos son hijos de los polígonos en
      controles, portal y sierras, por lo que acompañan al recoloreo, al
      pulso del portal y al giro de la sierra. El pincho mantiene su pulso
      de `Visual` y el contorno queda fijo.
    - **Tests**: `visual_polish_smoke_test` pasa a 55 comprobaciones
      (existencia, cierre y color negro de 11 contornos, además del ajuste
      dinámico del contorno de plataforma). Suite completa: 30/30.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se
    pida.
39. **Murciélagos al borde visible y resistencia del jugador (2026-11-16)**:
    - **Despawn por pantalla**: `FlyingEnemy` elimina `lifetime` y usa
      `despawn_margin` (48 px) + `_visible_world_rect()` (Camera2D actual,
      zoom y `get_screen_center_position()`). Desaparece al cruzar el borde
      visible en su dirección, no por tiempo ni distancia.
    - **Tres golpes**: `scenes/player/player.tscn` sube
      `Health.max_health` a 3; el HUD dibuja tres corazones de forma
      dinámica (`test_level.gd`).
    - **Invulnerabilidad 1 s**: `PlayerStats.invulnerability_time` pasa de
      0.5 a 1.0 tanto en el recurso como en el valor por defecto.
    - Tests: `flying_enemy_smoke_test` 12 (borde derecho e izquierdo con
      Camera2D), `survival_smoke_test` 26 (tres golpes y HUD),
      `checkpoint` 13, `healing` 5, `inventory` 43, `pickup` 7,
      `enemy_patrol` 8, `enemy_ranged` 23, `enemy_visual` 29 y `level_two`
      29 ajustados a las nuevas esperas de 1 s. Suite: 30/30.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se
    pida.
40. **Texturas procedurales de plataformas (2026-11-16)**:
    - **Helper reutilizable**: `scripts/world/platform_texture.gd`
      (`class_name PlatformTexture`) crea/actualiza `TextureDetail` con vetas
      horizontales y motas deterministas de baja opacidad. Usa semilla basada
      en tamaño/color, no necesita assets y se inserta debajo de los remates y
      del contorno.
    - **Cobertura**: `Platform._refresh()` aplica la textura a las plataformas
      estáticas, móviles, circulares, giratorias y con pinchos de los seis
      niveles; `MovingPlatform._ready()` hace lo mismo con su tamaño y color
      del nivel 4.
    - Tests: `visual_polish_smoke_test` pasa a 62 comprobaciones (textura en
      plataforma fija y móvil, opacidad sutil, adaptación al ancho y orden
      bajo el contorno). Suite completa: 30/30.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se
    pida.
41. **Niveles 5 y 6 ampliados, sierras aéreas y centinela (2026-11-16)**:
    - **Nivel 5**: recorrido de 28 plataformas (antes 21), ancho 17000 px,
      portal en 16400, control en el índice 13, hierbas en 5/18/24 y cuatro
      sierras suspendidas en los índices 4/10/17/23. El tipo de plataforma
      alterna seis variantes (con más pinchos) y el fondo crece a 12 colinas,
      16 nubes, 7 aves y rocas flotantes adicionales.
    - **Nivel 6**: recorrido de 20 plataformas (antes 14), ancho 18000 px,
      portal en 17400, control en el índice 10 y hierbas en 5/13/19. Suma
      cinco sierras de suelo (1/5/9/14/18) y cinco suspendidas
      (2/6/10/14/17), además del centinela superior.
    - **Sierras**: `saw_trap.gd` dibuja una rueda de 12 dientes (radios 27/18)
      y un `PathGuide` (`Line2D`, `top_level`) con el recorrido completo.
      `move_range` sigue siendo la mitad del trayecto; las suspendidas usan
      `PLATFORM_SIZE.x`, así su recorrido mide el doble del ancho de una
      plataforma normal.
    - **Centinela**: `SkySentry` + escena, grupo `sky_sentries`, se mantiene en
      el centro del borde superior de la cámara, oscila ligeramente y dispara
      cada 2 s un proyectil apuntado a 260 px/s. No tiene vida ni colisión.
      Aparece en el nivel 6.
    - Tests: `level_five_smoke_test` 39, `level_six_smoke_test` 55 y
      `sky_sentry_smoke_test` 9. Suite completa: 31/31.
    NOTA: el exe de `dist/` NO incluye este cambio; re-exportar cuando se
    pida.


42. **Ajustes del centinela, voladores, pozos y mago azul (2026-11-16)**:
    - **Centinela**: `SkySentry` dispara 5 proyectiles en un cono de 70°
      equidistante y apuntado al jugador (antes 10); se ancla en la esquina
      superior derecha de la cámara (`right_margin` 120, `top_margin` 80) y
      su visual crece a escala 1.75.
    - **Voladores del nivel 5**: `FlyingSpawner` lanza uno cada 3 s (antes 4)
      con retardo inicial 1.5 s, altura aleatoria 110-560, lado y margen
      aleatorios; los murciélagos entran en el grupo `flying_enemies` y
      `TestLevel._on_player_died()` los limpia con
      `FlyingSpawner.clear_flying_enemies()`.
    - **Contacto fiable**: se ampliaron las `DamageArea` de flying (46x32),
      ranged (40x50) y spread (40x40) para que el daño por contacto se note
      con los cuerpos más pequeños.
    - **Nivel 5**: se eliminaron las aves decorativas del layout.
    - **Nivel 6**: la capa de montañas (`HillParallax`) gana un suelo que
      llega al borde inferior (y 650-720) y el suelo inicial baja hasta 720;
      se añadió `GiantCreatureParallax` (0.05, z -28) con la silueta negra
      de una criatura gigante, haz de luz azul y ojo en forma de luna
      creciente (el haz se recorta en y=640, sin salir de pantalla).
    - **Pozos mortales**: la `FallZone` de los niveles 5 y 6 medía 14000 px
      centrada en x=6800 y dejaba sin protección los últimos huecos (hasta
      x≈16000); ahora se centra en el nivel y su forma cubre todo el ancho
      (`LEVEL_WIDTH + 800`, alto 120). Tests de regresión añadidos.
    - **Mago azul y sonidos**: `fireball.svg` pasa a paleta azul/cian (orbe
      de energía), la estela y el estallido al impactar también son azules y
      el `Glow` se tiñe de azul. Nuevos sonidos procedurales en `sfx.gd`:
      `magic` (orbe del mago), `arrow` (flecha del arquero) y `sentry`
      (descarga del centinela); cada enemigo usa el suyo.
    - Tests: `sky_sentry` 16, `flying_enemy` 14, `level_five` 41,
      `level_six` 58 y `enemy_ranged` 25 (incluye comprobación de sonidos
      distintos). Suite completa: 31/31.
    NOTA: el exe de `dist/` se re-exportó con los ítems 18-42.

## 5. En progreso / estado actual

- Suite de 31 smoke tests en verde (verificado en esta sesión) tras aplicar
  los ítems 28-42: modo plataformas lineal con un único checkpoint a mitad de
  cada nivel, tres vidas por nivel, reglas de tiempo de reaparición (+10 s /
  30 s), inventario real con poción/ración y espacios Q/E, selección directa
  de nivel, soporte de mando, guardado de nivel/tiempo/muertes, pantalla de
  juego completado, fundidos de imagen y música, aviso de descanso en
  controles, trampas legibles, menú de pausa completo con guía y
  configuración, contornos negros en formas geométricas básicas, agentes
  opencode por área, murciélagos que desaparecen al salir del borde visible,
  tres golpes de vida e invulnerabilidad de 1 s.
  Las plataformas de todos los niveles llevan una textura procedural sutil
  (vetas y motas) que se adapta a su tamaño y color.
  El nivel 4 tiene las 17 plataformas de la ruta activas a la vez (sin
  reciclado ni desapariciones), con enemigos a bordo, el control central
  despejado y el inicio sin enemigos en la mitad izquierda. Sus trayectorias
  no se solapan y ninguna plataforma se inclina más de 30°.
  Los niveles 5 y 6 usan el asset modular de plataformas: el 5 es un cielo
  de 28 plataformas con voladores cada 3 s (recorrido ondulante duplicado),
  cuatro sierras suspendidas y sin aves decorativas; el 6 es una fortaleza
  de 20 plataformas con pinchos, diez sierras (cinco de suelo y cinco
  suspendidas), giros, la criatura gigante de fondo y un centinela en la
  esquina superior derecha que dispara 5 proyectiles cada 2 s. Los pozos de
  ambos niveles están cubiertos por una única FallZone a todo el ancho.
  El mago lanza orbes de energía azules con estela y sonido propios; el
  arquero y el centinela tienen efectos de sonido distintos. La cadena
  termina en la pantalla final. El ejecutable de `dist/` se re-exportó con
  los ítems 18-42.

## 6. Próximos pasos (roadmap acordado, en orden de prioridad)

1. **Nuevos tipos de recursos** (materiales, llaves) y más objetos
   utilizables para el inventario y los espacios Q/E (la ración ya ocupa E).
2. **Desbloqueo de personajes** con estadísticas distintas (aprovechar que
   `PlayerStats` ya es un Resource intercambiable).
3. **Dificultad progresiva** y repetición de niveles ya desbloqueados (la
   selección directa de nivel desde el menú ya existe).
4. **Polish**: más partículas, transiciones decoradas y créditos ampliados.

## 7. Convenciones y reglas para agentes

- Idioma: código y comentarios en inglés; **comentarios de documentación en
  español** (docstrings `##` al inicio de cada archivo explicando su rol).
- Cada archivo GDScript importante lleva un comentario de cabecera con su
  propósito; los cambios relevantes se anotan con fecha corta y motivo.
- Comentarios solo donde aportan (algoritmos, decisiones, trampas conocidas).
- Tests: smoke tests headless en `tests/`, uno por sistema, patrón
  `_check(condición, mensaje)` + `_wait_physics(frames)`. Al añadir
  funcionalidad, añadir/actualizar su test.
- **Antes de terminar cualquier cambio**: correr la suite completa (sección 2)
  y actualizar las secciones 4-6 de este archivo.
- No usar librerías externas; el motor y GDScript puro bastan.
- Nombres de nodos en las escenas base (`Player`, `ExitPortal`, `Camera`,
  `HUD/...`) son contratos usados por scripts y tests: no renombrar sin
  actualizar todo lo que referencian.
- `scenes/levels/test_level.tscn` es compartida: sus nodos sueltos son
  contenido del NIVEL 1 y las variantes 2/3 los liberan por nombre (ver
  `_prepare_level_two/three` en `test_level.gd`); el contenido nuevo de
  esas variantes se genera por código en sus layouts.
- **Subagentes opencode** (`.opencode/agent/*.md`): `player-survival`
  (jugador, vidas, daño, respawn, cámara), `levels-world` (layouts,
  plataformas, checkpoints, portal), `enemies-hazards` (IA, proyectiles,
  trampas), `ui-flow` (menús, HUD, pausa, pantalla final), `audio-fx` (música
  y partículas), `core-save` (guardado y configuración) y `testing` (smoke
  tests). Todos deben leer este archivo y correr la suite completa.
