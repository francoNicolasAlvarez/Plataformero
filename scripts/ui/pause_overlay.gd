class_name PauseOverlay
extends CanvasLayer
## Menú de pausa del nivel. Enter alterna la pausa mientras el nivel está en
## juego; la guía de controles (con teclas dibujadas) solo es visible aquí y
## en el menú principal. Al pausar se congela el SceneTree (cronómetro,
## enemigos y jugador) salvo este overlay, que corre en PROCESS_MODE_ALWAYS.

signal pause_changed(is_paused: bool)

@onready var footer_label: Label = $Center/Panel/Margin/VBox/Footer


func _ready() -> void:
	visible = false
	var key_name := OS.get_keycode_string(GameSettings.get_keycode("pause"))
	if not key_name.is_empty():
		footer_label.text = "Pulsa %s para continuar" % key_name


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	## Alterna la pausa. Se ignora si la partida ya terminó (muerte, portal
	## o tiempo agotado) para no congelar las transiciones del nivel.
	var level := get_parent()
	if level != null and level.has_method("is_run_over") and level.is_run_over():
		return

	var is_paused := not visible
	visible = is_paused
	get_tree().paused = is_paused
	Sfx.play("ui", -12.0)
	pause_changed.emit(is_paused)
