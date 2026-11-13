extends SceneTree
## Prueba la vida del jugador, el daño por contacto de un enemigo móvil, la
## invulnerabilidad, el HUD y la pantalla de muerte.
## Ejecutar con:
## godot --headless --path . --script res://tests/survival_smoke_test.gd

const LEVEL_SCENE := preload("res://scenes/levels/test_level.tscn")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)

	var player: Player = level.get_node("Player")
	var walker: WalkerEnemy = level.get_node("WalkerEnemy")
	var timer_label: Label = level.get_node("HUD/TimerLabel")
	var game_over: Label = level.get_node("HUD/GameOver")
	var health_icons: Label = level.get_node("HUD/HealthIcons")
	var lives_label: Label = level.get_node("HUD/LivesLabel")
	var damage_flash: ColorRect = level.get_node("HUD/DamageFlash")

	walker.set_physics_process(false)
	await _wait_physics(20)

	_check(player.health.max_health == 2, "El jugador tiene solo 2 golpes de vida")
	_check(player.health.current_health == 2, "El jugador empieza con los 2 golpes")
	_check(level.get_node_or_null("HUD/PlayerHealth") == null, "La barra de vida fue eliminada del HUD")
	_check(timer_label.visible and timer_label.text.begins_with("TIEMPO:"), "El HUD muestra la cuenta regresiva")
	_check(not game_over.visible, "La pantalla de muerte empieza oculta")
	_check(health_icons.text == "\u2665\u2665", "El HUD dibuja un corazón por golpe disponible")
	_check(lives_label.text.contains("3"), "El HUD muestra las tres vidas del nivel")

	player.global_position = walker.global_position + Vector2(-30.0, 0.0)
	await _wait_physics(2)

	_check(player.health.current_health == 1, "El primer golpe deja al jugador a un impacto de morir")
	_check(health_icons.text == "\u2665\u2661", "El HUD pierde un corazón al recibir daño")
	_check(damage_flash.modulate.a > 0.5, "El daño produce un destello rojo en pantalla")
	_check(player.velocity.y < 0.0, "El daño aplica un retroceso vertical")
	_check(absf(player.velocity.x) > 100.0, "El daño empuja al jugador en horizontal")

	player.take_damage(20, walker)
	_check(player.health.current_health == 1, "La invulnerabilidad evita daño repetido")

	await _wait_physics(36)
	player.take_damage(20, walker)
	await _wait_physics(2)
	_check(player.health.is_dead, "El segundo golpe elimina al jugador")
	_check(game_over.visible, "Aparece el mensaje de muerte")
	_check(player.visual.animation == &"death", "El jugador reproduce la animación de muerte")

	await _wait_physics(40)
	_check(absf(player.visual.rotation) > 0.2, "El cuerpo cae de costado al morir")
	_check(player.visual.modulate.a < 0.9, "La animación de muerte se desvanece")

	await _wait_physics(40)
	_check(not player.health.is_dead, "El jugador reaparece tras unos segundos")
	_check(player.health.current_health == 2, "Reaparecer restaura los dos golpes de vida")
	_check(not game_over.visible, "El mensaje de muerte desaparece al reaparecer")
	_check(lives_label.text.contains("2"), "Morir consume una de las tres vidas")

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
