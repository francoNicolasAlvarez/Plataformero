extends SceneTree
## Comprueba el nivel 5 "CIELO" (2026-11-13): plataformas del asset modular
## con los cinco tipos, separación suficiente, un control, hierbas y el
## generador de enemigos voladores cada 4 s a altura aleatoria.
## Ejecutar con:
## godot --headless --path . --script res://tests/level_five_smoke_test.gd

const LEVEL_SCENE := preload("res://scenes/levels/level_five.tscn")
const NEXT_SCENE := "res://scenes/levels/level_six.tscn"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	await _wait_physics(30)

	var portal: ExitPortal = level.get_node("ExitPortal")
	var camera: Camera2D = level.get_node("Camera")
	var player: Player = level.get_node("Player")
	var spawner := level.get_node_or_null("LevelFiveGenerated/FlyingSpawner") as FlyingSpawner
	_check(spawner != null, "El nivel 5 tiene un generador de voladores")
	if spawner != null:
		spawner.active = false

	_check(level.level_variant == 5, "El nivel 5 usa la variante CIELO")
	_check(level.level_name == "NIVEL 5", "El nivel se identifica como NIVEL 5")
	_check(level.next_level_path == NEXT_SCENE, "El nivel 5 continúa hacia el nivel 6")
	_check(level.time_limit == 110.0, "El nivel 5 tiene 110 segundos")
	_check(level.get_node_or_null("LevelFiveGenerated") != null, "Se generó el cielo del nivel 5")
	_check(level.get_node("Platforms").get_child_count() == 0, "El nivel 5 limpia las plataformas base")
	_check(player.global_position.x <= 100.0, "El jugador empieza en el extremo izquierdo")

	var platforms := _collect_platforms(level.get_node("LevelFiveGenerated"))
	_check(platforms.size() == LevelFiveLayout.ROUTE_COUNT + 2, "Hay islas de inicio/final y 21 plataformas de ruta")
	var kinds := {}
	for platform in platforms:
		kinds[int(platform.kind)] = int(kinds.get(int(platform.kind), 0)) + 1
	for kind in [
		Platform.Kind.STATIC, Platform.Kind.HORIZONTAL,
		Platform.Kind.CIRCULAR, Platform.Kind.SPIKED, Platform.Kind.ROTATING,
	]:
		_check(int(kinds.get(int(kind), 0)) >= 1, "El nivel 5 usa el tipo de plataforma %d" % int(kind))

	_check(PlatformSpacing.collect_violations(level).is_empty(), "Las plataformas estáticas respetan el espaciado mínimo")

	var route: Array[Platform] = []
	for platform in platforms:
		if platform.position.x > 1000.0 and platform.position.x < 11400.0:
			route.append(platform)
	route.sort_custom(func(a: Platform, b: Platform) -> bool:
		return a.position.x < b.position.x
	)
	_check(route.size() == LevelFiveLayout.ROUTE_COUNT, "La ruta del nivel 5 tiene 21 plataformas")
	var min_gap := INF
	var max_gap := 0.0
	for index in range(route.size() - 1):
		var gap := route[index + 1].position.x - route[index].position.x - LevelFiveLayout.PLATFORM_SIZE.x
		min_gap = minf(min_gap, gap)
		max_gap = maxf(max_gap, gap)
	_check(min_gap >= 200.0, "Las plataformas están bastante separadas (hueco mínimo %.0f px)" % min_gap)
	_check(max_gap <= 360.0, "Las plataformas siguen siendo alcanzables (hueco máximo %.0f px)" % max_gap)

	var first := route[0]
	var last := route[route.size() - 1]
	var start_edge := LevelFiveLayout.START_CENTER + 600.0
	var end_edge := LevelFiveLayout.END_CENTER - 1100.0
	_check(first.position.x - LevelFiveLayout.PLATFORM_SIZE.x * 0.5 - start_edge <= 300.0, "La primera plataforma está al alcance del inicio")
	_check(end_edge - (last.position.x + LevelFiveLayout.PLATFORM_SIZE.x * 0.5) <= 300.0, "La última plataforma está al alcance del final")

	_check(get_nodes_in_group("checkpoints").size() == 1, "El nivel 5 tiene un único control")
	_check(get_nodes_in_group("healing_pickups").size() >= 2, "El nivel 5 incluye hierbas curativas")
	_check(get_nodes_in_group("enemies").is_empty(), "El nivel 5 no tiene enemigos fijos al empezar")
	_check(get_nodes_in_group("coins").is_empty(), "El nivel 5 no tiene monedas")

	if spawner != null:
		_check(is_equal_approx(spawner.spawn_interval, 4.0), "El generador crea un volador cada 4 segundos")
		_check(spawner.height_mode == FlyingSpawner.HeightMode.RANDOM, "El volador aparece a una altura aleatoria")
		var before := get_nodes_in_group("enemies").size()
		spawner.call("_spawn")
		await _wait_physics(2)
		var enemies := get_nodes_in_group("enemies")
		_check(enemies.size() == before + 1, "El generador crea un enemigo volador")
		if enemies.size() > 0:
			var flying := enemies[0] as FlyingEnemy
			_check(flying != null, "El enemigo generado es FlyingEnemy")
			if flying != null:
				var center := camera.get_screen_center_position()
				_check(absf(flying.global_position.x - center.x) > 800.0, "El volador nace fuera del borde visible")
				_check(flying.direction != 0, "El volador cruza la pantalla en una dirección")
				var start_x := flying.position.x
				var start_y := flying.position.y
				await _wait_physics(15)
				_check(absf(flying.position.x - start_x) > 5.0, "El volador avanza horizontalmente")
				_check(absf(flying.position.y - start_y) > 2.0, "El volador se mueve con un patrón ondulante")

	_check(portal.global_position.x > 13000.0, "El portal está en la isla final del nivel 5")
	_check(camera.limit_right == int(LevelFiveLayout.LEVEL_WIDTH), "La cámara cubre todo el nivel 5")

	print("")
	print("Comprobaciones: %d | Fallos: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _collect_platforms(node: Node) -> Array[Platform]:
	var found: Array[Platform] = []
	if node is Platform:
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect_platforms(child))
	return found


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
