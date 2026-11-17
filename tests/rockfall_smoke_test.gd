extends SceneTree
## Comprueba las rocas que caen (2026-11-17): marcador de aviso durante 1,5 s,
## caída rápida, daño de un golpe al jugador, rotura contra el suelo y que no
## se creen rocas sobre un foso. Ejecutar con:
## godot --headless --path . --script res://tests/rockfall_smoke_test.gd

const LEVEL_SCENE := preload("res://scenes/levels/level_nine.tscn")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	await _wait_physics(20)

	var player: Player = level.get_node("Player")
	var camera: Camera2D = level.get_node("Camera")
	var spawner := level.get_node("LevelNineGenerated/RockfallSpawner") as RockfallSpawner
	_check(spawner != null, "El nivel 9 tiene generador de rocas")
	_check(is_equal_approx(FallingRock.WARNING_TIME, 1.5), "El aviso dura 1,5 segundos")
	_check(FallingRock.FALL_SPEED >= 1200.0, "La roca cae muy rápido")
	spawner.active = false
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _wait_physics(2)

	# Sobre un foso no hay superficie: no se crea roca.
	player.global_position = Vector2(1300.0, 600.0)
	camera.snap_to_target()
	await _wait_physics(5)
	_check(spawner.spawn_rock_at(1540.0) == null, "No cae ninguna roca sobre un foso")

	# Roca sobre el suelo, lejos de plataformas.
	var x := LevelNineLayout.section_start(0) + 100.0
	player.global_position = Vector2(x, 600.0)
	player.velocity = Vector2.ZERO
	camera.snap_to_target()
	await _wait_physics(40)
	var hp_before := player.health.current_health
	var rock := spawner.spawn_rock_at(x)
	_check(rock != null, "Se crea una roca sobre el suelo")
	if rock == null:
		print("Comprobaciones: %d | Fallos: %d" % [_checks, _failures])
		quit(1)
		return
	await _wait_physics(2)
	var markers := get_nodes_in_group("rock_warnings")
	_check(markers.size() == 1, "Aparece un marcador de aviso")
	_check(rock.state == FallingRock.State.WARNING, "La roca empieza en fase de aviso")
	_check(absf((markers[0] as Node2D).global_position.y - LevelNineLayout.GROUND_TOP) < 2.0, "El marcador está sobre la superficie de impacto")
	_check(absf((markers[0] as Node2D).global_position.x - x) < 2.0, "El marcador está en la columna de impacto")
	_check(rock.warning_left() > 1.2, "Aún queda casi todo el aviso")

	await _wait_physics(60)
	_check(rock.state == FallingRock.State.WARNING, "Tras 1 s la roca sigue en aviso")
	_check(player.health.current_health == hp_before, "Durante el aviso no hay daño")

	await _wait_physics(45)
	_check(rock.state != FallingRock.State.WARNING, "Pasado 1,5 s la roca empieza a caer")
	await _wait_physics(40)
	_check(not is_instance_valid(rock) or rock.state == FallingRock.State.DONE, "La roca se rompe al llegar al suelo")
	_check(get_nodes_in_group("rock_warnings").is_empty(), "El marcador desaparece tras el impacto")
	_check(player.health.current_health == hp_before - 1, "La roca quita un golpe al jugador que está debajo")

	# Roca que cae en un sitio libre: no daña.
	player.global_position = Vector2(x + 500.0, 600.0)
	await _wait_physics(80)
	var hp_mid := player.health.current_health
	var other := spawner.spawn_rock_at(x)
	_check(other != null, "Se crea otra roca lejos del jugador")
	await _wait_physics(150)
	_check(player.health.current_health == hp_mid, "Una roca que no cae sobre el jugador no daña")

	# Las rocas del generador siempre caen por delante del jugador.
	FallingRock.clear_rocks(self)
	await _wait_physics(2)
	var px := LevelNineLayout.section_start(2) + 100.0
	player.global_position = Vector2(px, 600.0)
	player.velocity = Vector2.ZERO
	camera.snap_to_target()
	await _wait_physics(40)
	var created := 0
	var behind := 0
	for _attempt in 40:
		spawner._spawn_event(player)
	for rock_node in get_nodes_in_group("falling_rocks"):
		created += 1
		if rock_node.position.x < player.global_position.x + spawner.min_ahead - 1.0:
			behind += 1
	_check(created > 10, "El generador crea rocas (%d)" % created)
	_check(behind == 0, "Ninguna roca aparece detrás o sobre el jugador")
	_check(spawner.interval <= 2.2 / 3.0 + 0.01, "Caen 3 veces más rocas que antes (cada %.2f s)" % spawner.interval)

	var extra := spawner.spawn_rock_at(x)
	if extra != null:
		FallingRock.clear_rocks(self)
		await _wait_physics(2)
		_check(get_nodes_in_group("falling_rocks").is_empty(), "clear_rocks elimina las rocas pendientes")

	print("")
	print("Comprobaciones: %d | Fallos: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _wait_physics(frames: int) -> void:
	for _frame in frames:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[OK]    ", message)
	else:
		_failures += 1
		print("[FALLO] ", message)
