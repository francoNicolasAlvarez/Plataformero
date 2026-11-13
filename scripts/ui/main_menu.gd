extends Control
## Menú principal. Jugar continúa desde el último nivel guardado (o empieza
## una nueva expedición si el juego ya se completó); Opciones ajusta brillo,
## volumen y controles.

const LEVEL_PATHS := [
	"res://scenes/levels/level_one.tscn",
	"res://scenes/levels/level_two.tscn",
	"res://scenes/levels/level_three.tscn",
	"res://scenes/levels/level_four.tscn",
]

@onready var brightness_slider: HSlider = $OptionsPanel/PanelMargin/VBox/BrightnessRow/BrightnessSlider
@onready var brightness_value: Label = $OptionsPanel/PanelMargin/VBox/BrightnessRow/BrightnessValue
@onready var volume_slider: HSlider = $OptionsPanel/PanelMargin/VBox/VolumeRow/VolumeSlider
@onready var volume_value: Label = $OptionsPanel/PanelMargin/VBox/VolumeRow/VolumeValue
@onready var controls_grid: GridContainer = $OptionsPanel/PanelMargin/VBox/ControlsGrid
@onready var options_panel: PanelContainer = $OptionsPanel
@onready var instructions_panel: PanelContainer = $InstructionsPanel
@onready var main_panel: PanelContainer = $MainPanel
@onready var total_label: Label = $MainPanel/PanelMargin/VBox/TotalLabel
@onready var status_label: Label = $OptionsPanel/PanelMargin/VBox/StatusLabel

var _awaiting_action: String = ""
var _control_buttons: Dictionary = {}


func _ready() -> void:
	GameSettings.ensure_loaded()
	SaveGame.ensure_loaded()
	GameSettings.apply_brightness($Brightness)
	GameSettings.apply_audio()
	Sfx.stop_music(0.4)
	options_panel.visible = false
	instructions_panel.visible = false
	total_label.text = "NIVEL %d DE %d" % [SaveGame.level, SaveGame.LAST_LEVEL]
	_build_control_rows()
	_build_level_selector()
	_sync_options()
	$MainPanel/PanelMargin/VBox/PlayButton.pressed.connect(_on_play_pressed)
	$MainPanel/PanelMargin/VBox/OptionsButton.pressed.connect(_on_options_pressed)
	$MainPanel/PanelMargin/VBox/InstructionsButton.pressed.connect(_on_instructions_pressed)
	$MainPanel/PanelMargin/VBox/QuitButton.pressed.connect(_on_quit_pressed)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	$OptionsPanel/PanelMargin/VBox/Buttons/ResetControlsButton.pressed.connect(_on_reset_controls_pressed)
	$OptionsPanel/PanelMargin/VBox/Buttons/BackButton.pressed.connect(_close_options)
	$InstructionsPanel/PanelMargin/VBox/BackButton.pressed.connect(_close_instructions)
	$MainPanel/PanelMargin/VBox/PlayButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if instructions_panel.visible:
			_close_instructions()
		elif options_panel.visible:
			_close_options()
		else:
			get_tree().quit()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _awaiting_action.is_empty():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	var key := event as InputEventKey
	if key.physical_keycode == KEY_ESCAPE:
		_cancel_rebind()
	else:
		GameSettings.set_key(_awaiting_action, key.physical_keycode)
		status_label.text = "Control actualizado."
		_awaiting_action = ""
		_refresh_control_buttons()
	get_viewport().set_input_as_handled()


func _build_level_selector() -> void:
	## Fila de selección directa de nivel (2026-11-13), insertada antes de Jugar.
	var vbox: VBoxContainer = $MainPanel/PanelMargin/VBox
	var row := HBoxContainer.new()
	row.name = "LevelSelect"
	row.add_theme_constant_override("separation", 6)
	var caption := Label.new()
	caption.text = "NIVELES"
	caption.custom_minimum_size = Vector2(86.0, 0.0)
	caption.add_theme_color_override("font_color", Color("#c9dcf0"))
	row.add_child(caption)
	for index in LEVEL_PATHS.size():
		var button := Button.new()
		button.name = "Level%dButton" % (index + 1)
		button.text = str(index + 1)
		button.custom_minimum_size = Vector2(44.0, 40.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_level_button_pressed.bind(index + 1))
		row.add_child(button)
	vbox.add_child(row)
	vbox.move_child(row, $MainPanel/PanelMargin/VBox/PlayButton.get_index())


func _build_control_rows() -> void:
	for action in GameSettings.CONTROLS:
		var label := Label.new()
		label.text = GameSettings.CONTROL_LABELS[action]
		label.custom_minimum_size = Vector2(150.0, 0.0)
		label.add_theme_color_override("font_color", Color("#c9dcf0"))
		controls_grid.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(210.0, 38.0)
		button.pressed.connect(_start_rebind.bind(action))
		controls_grid.add_child(button)
		_control_buttons[action] = button
	_refresh_control_buttons()


func _refresh_control_buttons() -> void:
	for action in GameSettings.CONTROLS:
		var button: Button = _control_buttons[action]
		if action == _awaiting_action:
			button.text = "Presiona una tecla..."
		else:
			button.text = GameSettings.get_key_label(action)


func _start_rebind(action: String) -> void:
	_awaiting_action = action
	status_label.text = "Pulsa la nueva tecla para %s (Esc cancela)." % GameSettings.CONTROL_LABELS[action]
	_refresh_control_buttons()


func _cancel_rebind() -> void:
	_awaiting_action = ""
	status_label.text = "Asignación cancelada."
	_refresh_control_buttons()


func _sync_options() -> void:
	brightness_slider.value = GameSettings.brightness * 100.0
	volume_slider.value = GameSettings.master_volume * 100.0
	_update_option_labels()


func _update_option_labels() -> void:
	brightness_value.text = "%d%%" % roundi(brightness_slider.value)
	volume_value.text = "%d%%" % roundi(volume_slider.value)


func _on_brightness_changed(value: float) -> void:
	GameSettings.set_brightness(value / 100.0)
	GameSettings.apply_brightness($Brightness)
	_update_option_labels()


func _on_volume_changed(value: float) -> void:
	GameSettings.set_master_volume(value / 100.0)
	_update_option_labels()


func _on_level_button_pressed(level_index: int) -> void:
	SaveGame.start_at_level(level_index)
	SceneFade.change_scene(get_tree(), LEVEL_PATHS[level_index - 1])


func _on_play_pressed() -> void:
	if SaveGame.completed:
		SaveGame.begin_new_run()
	var index := clampi(SaveGame.level - SaveGame.FIRST_LEVEL, 0, LEVEL_PATHS.size() - 1)
	SceneFade.change_scene(get_tree(), LEVEL_PATHS[index])


func _on_options_pressed() -> void:
	main_panel.visible = false
	options_panel.visible = true
	_awaiting_action = ""
	status_label.text = "Ajusta los valores y pulsa Volver para guardar."
	brightness_slider.grab_focus()


func _close_options() -> void:
	_awaiting_action = ""
	options_panel.visible = false
	main_panel.visible = true
	$MainPanel/PanelMargin/VBox/OptionsButton.grab_focus()


func _on_instructions_pressed() -> void:
	main_panel.visible = false
	instructions_panel.visible = true
	$InstructionsPanel/PanelMargin/VBox/BackButton.grab_focus()


func _close_instructions() -> void:
	instructions_panel.visible = false
	main_panel.visible = true
	$MainPanel/PanelMargin/VBox/InstructionsButton.grab_focus()


func _on_reset_controls_pressed() -> void:
	GameSettings.reset_controls()
	_awaiting_action = ""
	status_label.text = "Controles restaurados."
	_refresh_control_buttons()


func _on_quit_pressed() -> void:
	get_tree().quit()
