extends SceneTree
## Comprueba el enemigo volador (2026-11-13): cruza en horizontal, ondula en
## vertical, no usa gravedad ni colisión con el mundo y se autodestruye al
## terminar su recorrido.
## Ejecutar con:
## godot --headless --path . --script res://tests/flying_enemy_smoke_test.gd

const ENEMY_SCENE := preload("res://scenes/enemies/flying_enemy.tscn")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var enemy := ENEMY_SCENE.instantiate() as FlyingEnemy
	enemy.position = Vector2(100.0, 300.0)
	enemy.horizontal_speed = 200.0
	enemy.wave_amplitude = 45.0
	enemy.wave_frequency = 2.5
	enemy.lifetime = 5.0
	enemy.direction = 1
	root.add_child(enemy)
	await _wait_physics(2)

	_check(enemy is FlyingEnemy, "La escena crea un FlyingEnemy")
	_check(enemy is TrainingDummy, "El volador reutiliza la base de enemigos")
	_check(enemy.collision_mask == 0, "El volador no colisiona con el mundo")
	_check(enemy.damage_area.collision_mask == 2, "El área de daño detecta al jugador")
	_check(enemy.contact_damage > 0, "El volador hace daño por contacto")

	var start_position := enemy.position
	await _wait_physics(18)
	_check(enemy.position.x > start_position.x + 10.0, "El volador cruza la pantalla en horizontal")
	_check(absf(enemy.position.y - start_position.y) > 3.0, "El volador ondula en vertical")

	enemy.direction = -1
	var turn_position := enemy.position
	await _wait_physics(15)
	_check(enemy.position.x < turn_position.x - 5.0, "La dirección del volador se puede invertir")

	enemy.lifetime = 0.0
	await _wait_physics(4)
	_check(not is_instance_valid(enemy), "El volador se autodestruye al terminar su recorrido")

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
