extends SceneTree
## Comprueba que el enemigo a distancia solo dispara cuando la línea de visión
## está despejada.
## Ejecutar con:
## godot --headless --path . --script res://tests/enemy_los_smoke_test.gd

const LEVEL_SCENE := preload("res://scenes/levels/test_level.tscn")
const PLATFORM_SCENE := preload("res://scenes/world/platform.tscn")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)

	var ranged: RangedEnemy = level.get_node("RangedEnemy")
	var player: Player = level.get_node("Player")
	ranged.patrol_speed = 0.0

	await _wait_physics(20)

	player.global_position = ranged.global_position + Vector2(-220.0, 0.0)

	var wall: Platform = PLATFORM_SCENE.instantiate()
	wall.platform_size = Vector2(40.0, 300.0)
	wall.platform_color = Color("#3d5a80")
	wall.position = ranged.global_position + Vector2(-110.0, -60.0)
	level.add_child(wall)

	for child in level.get_children():
		if child is EnemyProjectile:
			child.free()

	await _wait_physics(120)
	_check(_count_projectiles(level) == 0, "Una pared bloquea el disparo enemigo")

	wall.free()
	await _wait_physics(40)
	_check(_count_projectiles(level) >= 1, "Al despejar la línea de visión vuelve a disparar")

	print("")
	print("Comprobaciones: %d | Fallos: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _count_projectiles(level: Node) -> int:
	var total := 0
	for child in level.get_children():
		if child is EnemyProjectile:
			total += 1
	return total


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
