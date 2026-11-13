extends SceneTree
## Comprueba la pausa con Enter: congela el nivel, muestra la guía de controles
## con teclas dibujadas, se reanuda con la misma tecla y no se activa tras
## morir. Ejecutar con:
## godot --headless --path . --script res://tests/pause_smoke_test.gd

const LEVEL_SCENE := preload("res://scenes/levels/test_level.tscn")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)

	await _wait_physics(20)

	var player: Player = level.get_node("Player")
	var pause_overlay: PauseOverlay = level.get_node("PauseOverlay")
	var guide: ControlGuide = pause_overlay.get_node("Center/Panel/Margin/VBox/ControlGuide")
	var timer_label: Label = level.get_node("HUD/TimerLabel")

	_check(InputMap.has_action("pause"), "La acción de pausa existe en el Input Map")
	_check(pause_overlay.process_mode == Node.PROCESS_MODE_ALWAYS, "El overlay de pausa ignora la pausa del árbol")
	_check(not pause_overlay.visible, "La pausa empieza oculta")
	_check(not paused, "El juego empieza sin pausa")
	_check(level.get_node_or_null("HUD/ControlHints") == null, "La guía de comandos fue retirada del nivel")
	_check(guide != null, "La pausa muestra la guía de controles")
	_check(guide.columns == 1, "La guía de la pausa usa una columna")
	_check(_count_keycaps(guide) == 12, "La guía dibuja las teclas de todos los comandos")

	# Pausa: el jugador y el cronómetro se congelan aunque se pida moverse.
	var position_before := player.global_position
	var timer_before := timer_label.text
	_press_pause(pause_overlay)
	_check(pause_overlay.visible, "Enter muestra el overlay de pausa")
	_check(paused, "Enter congela el SceneTree")

	Input.action_press("move_right")
	await _wait_physics(30)
	_check(player.global_position == position_before, "El jugador no se mueve en pausa")
	_check(timer_label.text == timer_before, "El cronómetro no avanza en pausa")
	Input.action_release("move_right")

	# Reanudar: el mismo Enter devuelve el control y el jugador responde.
	_press_pause(pause_overlay)
	_check(not pause_overlay.visible, "Enter reanuda el juego")
	_check(not paused, "Reanudar descongela el SceneTree")

	Input.action_press("move_right")
	await _wait_physics(30)
	Input.action_release("move_right")
	_check(player.global_position.x > position_before.x, "El jugador se mueve tras reanudar")

	# Tras morir la pausa queda bloqueada (no debe congelar la transición).
	player.take_damage(9999)
	await _wait_physics(2)
	_check(level.is_run_over(), "La muerte marca la partida como terminada")
	_press_pause(pause_overlay)
	_check(not pause_overlay.visible, "No se puede pausar tras morir")
	_check(not paused, "El árbol no queda pausado tras morir")

	print("")
	print("Comprobaciones: %d | Fallos: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _press_pause(pause_overlay: PauseOverlay) -> void:
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	pause_overlay._unhandled_input(event)


func _count_keycaps(node: Node) -> int:
	## Cuenta los keycaps dibujados (PanelContainer) dentro de la guía.
	var count := 0
	for child in node.get_children():
		if child is PanelContainer:
			count += 1
		count += _count_keycaps(child)
	return count


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
