extends SceneTree
## Prueba los acabados visuales añadidos el 2026-11-11: vestido de
## plataformas, sombra y squash & stretch del jugador, chispas de la hierba, aura del portal y capas de paralaje en los tres niveles.
## Ejecutar con:
## godot --headless --path . --script res://tests/visual_polish_smoke_test.gd

const LEVEL_SCENE := preload("res://scenes/levels/test_level.tscn")
const LEVEL_TWO_SCENE := preload("res://scenes/levels/level_two.tscn")
const LEVEL_THREE_SCENE := preload("res://scenes/levels/level_three.tscn")
const PLATFORM_SCENE := preload("res://scenes/world/platform.tscn")
const HERB_SCENE := preload("res://scenes/pickups/healing_herb.tscn")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_platform_dressing()
	await _test_player_polish()
	await _test_pickup_sparkles()
	await _test_portal_aura()
	await _test_level_parallax()
	print("")
	print("Comprobaciones: %d | Fallos: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_platform_dressing() -> void:
	var platform: Platform = PLATFORM_SCENE.instantiate()
	platform.platform_size = Vector2(200.0, 24.0)
	root.add_child(platform)
	await _wait_physics(2)

	var top := platform.get_node_or_null("TopHighlight") as Polygon2D
	var bottom := platform.get_node_or_null("BottomShadow") as Polygon2D
	_check(top != null, "Las plataformas tienen franja iluminada arriba")
	_check(bottom != null, "Las plataformas tienen sombra en la base")
	if top != null:
		_check(
			top.color.v > platform.platform_color.v,
			"La franja superior aclara el color base"
		)
	if bottom != null:
		_check(
			bottom.color.a < 1.0,
			"La sombra de la base es translúcida"
		)
	platform.queue_free()


func _test_player_polish() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	var player: Player = level.get_node("Player")
	# Se espera a que el jugador aterrice del spawn y su squash inicial se
	# recupere por completo antes de forzar otro.
	await _wait_physics(30)

	_check(player.get_node_or_null("Shadow") is Polygon2D, "El jugador tiene sombra en los pies")
	var dust := player.get_node_or_null("DustPuff") as CPUParticles2D
	_check(dust != null, "El jugador tiene polvo de partículas")
	if dust != null:
		_check(dust.one_shot, "El polvo del jugador es de un solo disparo")

	player._squash(Vector2(1.4, 0.6), 0.05)
	await _wait_physics(20)
	_check(
		player.visual_root.scale.is_equal_approx(Vector2.ONE),
		"El squash & stretch recupera la escala original"
	)
	level.queue_free()


func _test_pickup_sparkles() -> void:
	var herb: HealingHerb = HERB_SCENE.instantiate()
	root.add_child(herb)
	await _wait_physics(2)
	_check(
		herb.visual.get_node_or_null("Sparkle") is CPUParticles2D,
		"La hierba curativa destella partículas"
	)
	herb.queue_free()


func _test_portal_aura() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	await _wait_physics(2)
	var portal := level.get_node("ExitPortal")
	_check(
		portal.get_node_or_null("PortalAura") is CPUParticles2D,
		"El portal tiene aura de partículas"
	)
	level.queue_free()


func _test_level_parallax() -> void:
	var level_one := LEVEL_SCENE.instantiate()
	root.add_child(level_one)
	await _wait_physics(2)

	var hills := level_one.get_node("BackgroundDecor") as Parallax2D
	_check(hills != null, "Las colinas del nivel 1 usan Parallax2D")
	if hills != null:
		_check(hills.scroll_scale.x < 1.0, "Las colinas del nivel 1 se mueven más lento que la cámara")
		_check(
			hills.get_child_count() >= 12,
			"Las colinas del nivel 1 cubren todo el recorrido"
		)

	var clouds := level_one.get_node_or_null("LevelOneExtension/CloudParallax") as Parallax2D
	_check(clouds != null, "Las nubes del nivel 1 usan Parallax2D")
	if clouds != null:
		_check(clouds.scroll_scale.x < 1.0, "Las nubes del nivel 1 se mueven más lento que la cámara")
		_check(clouds.get_child_count() >= 6, "Hay nubes repartidas por el nivel 1")
	level_one.queue_free()

	var level_two := LEVEL_TWO_SCENE.instantiate()
	root.add_child(level_two)
	await _wait_physics(2)
	var two_world := level_two.get_node("LevelTwoGenerated")
	_check(
		two_world.get_node_or_null("HillParallax") is Parallax2D,
		"Las colinas del nivel 2 usan Parallax2D"
	)
	_check(
		two_world.get_node_or_null("CloudParallax") is Parallax2D,
		"Las nubes del nivel 2 usan Parallax2D"
	)
	level_two.queue_free()

	var level_three := LEVEL_THREE_SCENE.instantiate()
	root.add_child(level_three)
	await _wait_physics(2)
	var three_world := level_three.get_node("LevelThreeGenerated")
	_check(
		three_world.get_node_or_null("StarParallax") is Parallax2D,
		"Las estrellas del nivel 3 usan Parallax2D"
	)
	_check(
		three_world.get_node_or_null("MoonParallax") is Parallax2D,
		"La luna del nivel 3 usa Parallax2D"
	)
	_check(
		three_world.get_node_or_null("HillParallax") is Parallax2D,
		"Las colinas del nivel 3 usan Parallax2D"
	)
	level_three.queue_free()


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
