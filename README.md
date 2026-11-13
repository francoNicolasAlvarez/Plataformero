# Plataformero

Videojuego 2D de plataformas lineal hecho con **Godot 4.7 (GL Compatibility)** y
GDScript. La jugabilidad está inspirada en Super Mario Bros.: saltos, enemigos,
trampas, checkpoints y cuatro niveles con ambientaciones distintas.

## Jugar

La forma más rápida es descargar el ejecutable incluido en el repositorio:

1. Abre `dist/PlataformasRoguelite.exe`.
2. Si GitHub muestra el archivo como "Stored with Git LFS", usa el botón de
   descarga del repositorio o ejecuta `git lfs pull` después de clonar.
3. No hace falta instalar Godot para jugar.

También puedes abrir el proyecto desde el editor de Godot 4.7:

```
Godot_v4.7.2-stable_win64_console.exe --path .
```

Y ejecutar directamente el menú principal:

```
Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/ui/main_menu.tscn
```

## Objetivo

Atraviesa los cuatro niveles hasta llegar al final del juego. Cada nivel da tres
vidas: al morir reapareces en el último control (bandera) activado con la vida
completa; si te quedas sin vidas o se agota el tiempo, el nivel se reinicia. El
nivel alcanzado se guarda para continuar la partida.

- **Nivel 1:** día, recorrido largo con colinas, pozos y plataformas.
- **Nivel 2:** atardecer, fosos con plataformas móviles, sierras y pinchos.
- **Nivel 3:** noche, granja con enemigos rápidos y decoración rural.
- **Nivel 4:** "El Gran Pozo", un abismo cruzado por plataformas móviles.

## Controles

| Acción | Teclado | Mando |
| --- | --- | --- |
| Mover | A/D o flechas | Stick / DPAD |
| Saltar / doble salto | Espacio | A |
| Caer rápido | S o flecha abajo | Stick abajo / DPAD abajo |
| Correr | Shift | X |
| Objeto rápido Q | Q | LB |
| Objeto rápido E | E | RB |
| Inventario | Tab | Back |
| Pausa | Enter | Start |

Los controles de teclado se pueden reasignar desde **Opciones**. El mando usa
un mapeo fijo.

## Objetos

- **Poción (Q):** cura un golpe de vida.
- **Ración (E):** añade 5 segundos al cronómetro.
- **Hierba curativa:** restaura vida al recogerla.
- **Doble salto:** disponible siempre con una pulsación extra en el aire.

## Enemigos y trampas

- **Dummy de entrenamiento:** enemigo básico de contacto.
- **Walker:** patrulla el suelo y persigue su ruta.
- **Mago:** lanza bolas de fuego en horizontal.
- **Arquero:** dispara una flecha rápida.
- **Sierras y pinchos:** trampas con aviso visual antes de dañar.

## Desarrollo

Requisitos:

- Godot 4.7.2.
- Git LFS si vas a clonar el ejecutable incluido.

Regenerar caches tras crear o renombrar scripts/escenas:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
```

Ejecutar la suite de pruebas headless:

```
Get-ChildItem tests -Filter *.gd | ForEach-Object {
    & "Godot_v4.7.2-stable_win64_console.exe" `
        --headless --path . --script "res://tests/$($_.Name)" }
```

Exportar el ejecutable de Windows:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop"
```

El ejecutable se genera en `dist/PlataformasRoguelite.exe`.

## Estructura

```
scenes/      Escenas de menús, niveles, jugador, enemigos, mundo y UI
scripts/     Lógica en GDScript (jugador, niveles, combate, UI, audio, FX)
assets/      Sprites SVG, partículas y decoración
resources/   Recursos exportables (estadísticas del jugador, ataques)
tests/       Smoke tests headless de cada sistema
dist/        Ejecutable de Windows
```

La documentación técnica y el historial de cambios están en `AGENTS.md`.
