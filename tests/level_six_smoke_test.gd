extends SceneTree
## Comprueba el nivel 6 "FORTALEZA" (2026-11-13): saltos largos que exigen
## doble salto, pinchos solo en los bordes de las plataformas, sierras
## patrullando, plataformas giratorias, un control y el portal final.
## Ejecutar con:
## godot --headless --path . --script res://tests/level_six_smoke_test.gd

const LEVEL_SCENE := preload("res://scenes/levels/level_six.tscn")
const COMPLETE_SCENE := "res://scenes/ui/game_complete.tscn"

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

	_check(level.level_variant == 6, "El nivel 6 usa la variante FORTALEZA")
	_check(level.level_name == "NIVEL 6", "El nivel se identifica como NIVEL 6")
	_check(level.next_level_path == COMPLETE_SCENE, "El nivel 6 lleva a la pantalla final")
	_check(level.time_limit == 120.0, "El nivel 6 tiene 120 segundos")
	_check(level.get_node_or_null("LevelSixGenerated") != null, "Se generó la fortaleza del nivel 6")
	_check(level.get_node("Platforms").get_child_count() == 0, "El nivel 6 limpia las plataformas base")
	_check(player.global_position.x <= 100.0, "El jugador empieza en el extremo izquierdo")

	var platforms := _collect_platforms(level.get_node("LevelSixGenerated"))
	var route: Array[Platform] = []
	var spiked := 0
	var rotating: Platform = null
	for platform in platforms:
		if platform.position.x > 1000.0 and platform.position.x < 11400.0:
			route.append(platform)
		if platform.kind == Platform.Kind.SPIKED:
			spiked += 1
		if platform.kind == Platform.Kind.ROTATING and rotating == null:
			rotating = platform
	route.sort_custom(func(a: Platform, b: Platform) -> bool:
		return a.position.x < b.position.x
	)
	_check(route.size() == LevelSixLayout.ROUTE_COUNT, "La ruta del nivel 6 tiene 14 plataformas")
	_check(spiked >= 5, "El nivel 6 tiene varias plataformas con pinchos")
	_check(rotating != null, "El nivel 6 incluye plataformas giratorias")
	_check(PlatformSpacing.collect_violations(level).is_empty(), "Las plataformas respetan el espaciado mínimo")

	var min_gap := INF
	var max_gap := 0.0
	for index in range(route.size() - 1):
		var gap := route[index + 1].position.x - route[index].position.x - LevelSixLayout.PLATFORM_SIZE.x
		min_gap = minf(min_gap, gap)
		max_gap = maxf(max_gap, gap)
	_check(min_gap >= 450.0, "Los saltos son largos y exigen doble salto (hueco mínimo %.0f px)" % min_gap)
	_check(max_gap <= 520.0, "Los saltos siguen siendo posibles con doble salto (hueco máximo %.0f px)" % max_gap)

	var start_edge := LevelSixLayout.START_CENTER + 600.0
	var end_edge := LevelSixLayout.END_CENTER - 900.0
	var first := route[0]
	var last := route[route.size() - 1]
	_check(first.position.x - LevelSixLayout.PLATFORM_SIZE.x * 0.5 - start_edge <= 300.0, "La primera plataforma está al alcance del inicio")
	_check(end_edge - (last.position.x + LevelSixLayout.PLATFORM_SIZE.x * 0.5) <= 520.0, "La última plataforma está al alcance del final")

	for platform in route:
		if platform.kind != Platform.Kind.SPIKED:
			continue
		var left := platform.get_node_or_null("SpikeLeft") as Area2D
		var right := platform.get_node_or_null("SpikeRight") as Area2D
		_check(left != null and right != null, "La plataforma con pinchos tiene pinchos en ambos bordes")
		if left != null and right != null:
			_check(left.position.x < -60.0 and right.position.x > 60.0, "Los pinchos están en los bordes, no en el centro")
			_check(left.visible and right.visible, "Los pinchos de borde son visibles")

	var saws := get_nodes_in_group("saws")
	_check(saws.size() == LevelSixLayout.SAW_INDICES.size(), "El nivel 6 tiene una sierra por plataforma elegida")
	var saw_start := Vector2.ZERO
	if saws.size() > 0:
		var saw := saws[0] as Node2D
		saw_start = saw.global_position
		await _wait_physics(35)
		_check(saw.global_position.distance_to(saw_start) > 2.0, "Las sierras patrullan sobre las plataformas")
		_check(saw.global_position.y < 550.0, "Las sierras quedan por encima de las plataformas")

	if rotating != null:
		var rotation_before := rotating.rotation
		await _wait_physics(25)
		_check(not is_equal_approx(rotating.rotation, rotation_before), "La plataforma giratoria oscila")
		_check(absf(rad_to_deg(rotating.rotation)) <= 30.01, "La plataforma no se inclina más de 30 grados")

	_check(get_nodes_in_group("checkpoints").size() == 1, "El nivel 6 tiene un único control")
	_check(get_nodes_in_group("healing_pickups").size() >= 2, "El nivel 6 incluye hierbas curativas")
	_check(get_nodes_in_group("enemies").is_empty(), "El nivel 6 se centra en las trampas, sin enemigos fijos")
	_check(get_nodes_in_group("coins").is_empty(), "El nivel 6 no tiene monedas")
	_check(portal.global_position.x > 13000.0, "El portal está en la isla final del nivel 6")
	_check(camera.limit_right == int(LevelSixLayout.LEVEL_WIDTH), "La cámara cubre todo el nivel 6")

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
