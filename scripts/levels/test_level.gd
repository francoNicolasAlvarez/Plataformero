extends Node2D
## Nivel jugable. Une la vida del jugador con el HUD y controla el portal.
## Permite construir ocho variantes: día, atardecer, noche, abismo, cielo,
## fortaleza, inversa y espejo.
## Desde 2026-11-12 el juego es un plataformas lineal: hay checkpoints,
## tres vidas por nivel, fundido entre escenas y una pantalla de final.
## Sin vidas o sin tiempo la expedición vuelve a empezar en el nivel 1.
## Fase contrarreloj (2026-11-17): el reloj sigue corriendo al morir, no hay
## bonus de tiempo y el resultado se guarda con medalla y mejor tiempo.

@export var level_variant: int = 1
@export_file("*.tscn") var next_level_path: String = ""
@export var level_name: String = "NIVEL 1"
@export var time_limit: float = 70.0
@export var gold_medal_time: float = 35.0
@export var silver_medal_time: float = 50.0
@export var bronze_medal_time: float = 70.0

const MAX_LIVES := 3
const FIRST_LEVEL_PATH := "res://scenes/levels/level_one.tscn"
const RESULTS_PATH := "res://scenes/ui/level_results.tscn"
const HEART_FULL := "\u2665"
const HEART_EMPTY := "\u2661"

@onready var player: Player = $Player
@onready var portal: ExitPortal = $ExitPortal
@onready var camera: HorizontalCamera = $Camera
@onready var portal_hint: Label = $HUD/PortalHint
@onready var timer_label: Label = $HUD/TimerLabel
@onready var medal_label: Label = $HUD/MedalLabel
@onready var progress_bar: ProgressBar = $HUD/LevelProgress
@onready var progress_label: Label = $HUD/LevelProgress/ProgressLabel
@onready var game_over_label: Label = $HUD/GameOver
@onready var completed_label: Label = $HUD/Completed
@onready var item_slots: Label = $HUD/ItemSlots
@onready var inventory_panel: PanelContainer = $HUD/InventoryPanel
@onready var potion_info: Label = $HUD/InventoryPanel/PanelMargin/VBox/PotionInfo
@onready var jumps_info: Label = $HUD/InventoryPanel/PanelMargin/VBox/JumpsInfo
@onready var meta_info: Label = $HUD/InventoryPanel/PanelMargin/VBox/MetaInfo
@onready var bonus_info: Label = $HUD/InventoryPanel/PanelMargin/VBox/BonusInfo
@onready var health_icons: Label = $HUD/HealthIcons
@onready var lives_label: Label = $HUD/LivesLabel
@onready var damage_flash: ColorRect = $HUD/DamageFlash

var _completed: bool = false
var _time_left: float = 0.0
var _timer := RunTimer.new()
var _progress_start_x: float = 0.0
var _timer_expired: bool = false
var _lives: int = MAX_LIVES
var _level_deaths: int = 0
var _respawn_point: Vector2 = Vector2.ZERO
var _fade_rect: ColorRect
var _damage_tween: Tween


func _ready() -> void:
	SaveGame.ensure_loaded()
	GameSettings.ensure_loaded()
	GameSettings.apply_brightness($Brightness)
	GameSettings.apply_audio()

	if level_variant == 2:
		_prepare_level_two()
	elif level_variant == 3:
		_prepare_level_three()
	elif level_variant == 4:
		_prepare_level_four()
	elif level_variant == 5:
		_prepare_level_five()
	elif level_variant == 6:
		_prepare_level_six()
	elif level_variant == 7:
		_prepare_level_seven()
	elif level_variant == 8:
		_prepare_level_eight()
	elif level_variant == 9:
		_prepare_level_nine()
	elif level_variant == 10:
		_prepare_level_ten()
	elif level_variant == 11:
		_prepare_level_eleven()
	elif level_variant == 12:
		_prepare_level_twelve()
	elif level_variant == 13:
		_prepare_level_thirteen()
	elif level_variant == 14:
		_prepare_level_fourteen()
	elif level_variant == 15:
		_prepare_level_fifteen()

	_apply_run_variation()
	_decorate_base_hills()
	_timer.start(time_limit)
	_time_left = _timer.remaining
	_level_deaths = 0
	_progress_start_x = player.global_position.x
	_respawn_point = player.global_position
	player.health.died.connect(_on_player_died)
	player.health.health_changed.connect(_on_health_changed)
	player.health.damaged.connect(_on_player_damaged)
	player.inventory_changed.connect(_on_inventory_changed)
	player.item_used.connect(_on_item_used)
	_on_inventory_changed(player.potions)
	_on_health_changed(player.health.current_health, player.health.max_health)
	_update_lives_label()
	_connect_checkpoints()
	game_over_label.visible = false
	completed_label.visible = false
	inventory_panel.visible = false
	portal_hint.visible = false
	portal.reached.connect(_on_portal_reached)

	_update_meta_labels()
	_update_timer_label()
	_update_medal_label()
	_update_progress_bar()
	_show_level_banner()
	_build_fade()
	SaveGame.set_level(level_variant)
	Sfx.start_music(level_variant)


func _connect_checkpoints() -> void:
	for checkpoint in get_tree().get_nodes_in_group("checkpoints"):
		if checkpoint is Checkpoint and not checkpoint.activated.is_connected(_on_checkpoint_activated):
			checkpoint.activated.connect(_on_checkpoint_activated)


## Cartel del nivel al comenzar: aparece centrado y se desvanece solo.
func _show_level_banner() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	const MOODS := {1: "DÍA", 2: "ATARDECER", 3: "NOCHE", 4: "ABISMO", 5: "CIELO", 6: "FORTALEZA", 7: "INVERSO", 8: "ESPEJO", 9: "RUINAS", 10: "TEMPLO", 11: "VIENTO", 12: "DUNAS", 13: "OASIS", 14: "CAÑÓN", 15: "TORMENTA"}
	var banner := Label.new()
	banner.name = "LevelBanner"
	banner.text = "%s · %s" % [level_name, MOODS.get(level_variant, "")]
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 108.0
	banner.offset_bottom = 150.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_size_override("font_size", 30)
	banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	banner.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	banner.add_theme_constant_override("outline_size", 6)
	hud.add_child(banner)
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(banner, "modulate:a", 0.0, 0.6)
	tween.tween_callback(banner.queue_free)


func _process(delta: float) -> void:
	if _completed:
		return

	# El reloj avanza también mientras el jugador está muerto: la muerte no
	# puede conceder tiempo extra ni congelar la medalla (2026-11-17).
	_timer.tick(delta)
	_time_left = _timer.remaining
	_update_timer_label()
	_update_progress_bar()
	_update_medal_label()

	if _timer.expired:
		if not _timer_expired:
			_timer_expired = true
			player.health.take_damage(9999)
		return

	if player.health.is_dead:
		return


func _prepare_level_two() -> void:
	# La variante 2 limpia el contenido base del nivel 1 y construye el
	# atardecer con sus propios enemigos (incluidos los ráfaga comunes).
	_clear_base_content()
	LevelTwoLayout.build(self)


func _prepare_level_three() -> void:
	# La variante 3 limpia el contenido base del nivel 1 y construye la
	# granja nocturna con sus propios enemigos (incluidos los ráfaga comunes).
	_clear_base_content()
	LevelThreeLayout.build(self)


func _prepare_level_four() -> void:
	# La variante 4 limpia el contenido base y construye el gran pozo.
	_clear_base_content()
	LevelFourLayout.build(self)


func _prepare_level_five() -> void:
	# La variante 5 construye el cielo de plataformas y los voladores.
	_clear_base_content()
	LevelFiveLayout.build(self)


func _prepare_level_six() -> void:
	# La variante 6 construye la fortaleza de trampas y saltos largos.
	_clear_base_content()
	LevelSixLayout.build(self)


func _prepare_level_seven() -> void:
	_clear_base_content()
	LevelSevenLayout.build(self)


func _prepare_level_eight() -> void:
	_clear_base_content()
	LevelEightLayout.build(self)


func _prepare_level_nine() -> void:
	_clear_base_content()
	LevelNineLayout.build(self)


func _prepare_level_ten() -> void:
	_clear_base_content()
	LevelTenLayout.build(self)


func _prepare_level_eleven() -> void:
	_clear_base_content()
	LevelElevenLayout.build(self)


func _prepare_level_twelve() -> void:
	_clear_base_content()
	LevelTwelveLayout.build(self)


func _prepare_level_thirteen() -> void:
	_clear_base_content()
	LevelThirteenLayout.build(self)


func _prepare_level_fourteen() -> void:
	_clear_base_content()
	LevelFourteenLayout.build(self)


func _prepare_level_fifteen() -> void:
	_clear_base_content()
	LevelFifteenLayout.build(self)


func _clear_base_content() -> void:
	for child in $Platforms.get_children():
		child.free()

	var base_nodes := [
		"TrainingDummy", "WalkerEnemy", "RangedEnemy", "SpreadEnemy",
		"HealingHerbLeft", "HealingHerbRight",
	]
	for node_name in base_nodes:
		var node := get_node_or_null(node_name)
		if node != null:
			node.free()

	$Background.visible = false
	$BackgroundDecor.visible = false


func _apply_run_variation() -> void:
	# Las pruebas headless necesitan posiciones estables.
	if DisplayServer.get_name() == "headless":
		return

	# Variación procedural: el fondo cambia ligeramente en cada partida.
	for hill in $BackgroundDecor.get_children():
		hill.position.x += randf_range(-70.0, 70.0)
		hill.position.y += randf_range(-18.0, 12.0)


func _decorate_base_hills() -> void:
	# Detalle de colinas (2026-11-11): solo la variante 1 (día) muestra las
	# colinas base de BackgroundDecor; las variantes 2/3 crean las suyas.
	if not $BackgroundDecor.visible:
		return
	for hill in $BackgroundDecor.get_children():
		MountainBuilder.decorate(
			hill,
			Color("#cfe3dc"),
			hill.color.lightened(0.10),
			hill.color.darkened(0.22),
			true
		)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		inventory_panel.visible = not inventory_panel.visible
		Sfx.play("ui", -12.0)
		get_viewport().set_input_as_handled()


func _update_timer_label() -> void:
	var seconds := ceili(_time_left)
	timer_label.text = "TIEMPO: %d" % seconds
	var color := Color(1.0, 0.32, 0.28, 1.0) if _time_left <= 10.0 else Color.WHITE
	timer_label.add_theme_color_override("font_color", color)


func _update_medal_label() -> void:
	var medal := _current_medal()
	medal_label.text = "MEDALLA ACTUAL: %s  ·  %s" % [
		MedalRules.display(medal),
		SaveGame.format_time_precise(_timer.elapsed),
	]


func _current_medal() -> String:
	return MedalRules.for_time(
		_timer.elapsed,
		gold_medal_time,
		silver_medal_time,
		bronze_medal_time
	)


func _update_progress_bar() -> void:
	var total_distance := maxf(1.0, portal.global_position.x - _progress_start_x)
	var travelled := player.global_position.x - _progress_start_x
	progress_bar.value = clampf(travelled / total_distance * 100.0, 0.0, 100.0)
	progress_label.text = "PROGRESO DE NIVEL  %d%%" % roundi(progress_bar.value)


func _on_health_changed(current: int, maximum: int) -> void:
	var hearts := ""
	for index in maximum:
		hearts += HEART_FULL if index < current else HEART_EMPTY
	health_icons.text = hearts


func _update_lives_label() -> void:
	lives_label.text = "VIDAS: %d" % _lives


func _on_player_damaged(_amount: int, _source: Node) -> void:
	_flash_damage()
	camera.shake(7.0, 0.25)


func _flash_damage() -> void:
	if _damage_tween != null and _damage_tween.is_valid():
		_damage_tween.kill()
	damage_flash.modulate.a = 1.0
	_damage_tween = create_tween()
	_damage_tween.tween_property(damage_flash, "modulate:a", 0.0, 0.35)


func _on_player_died() -> void:
	if _completed:
		return

	FlyingSpawner.clear_flying_enemies(get_tree())
	FallingRock.clear_rocks(get_tree())
	_level_deaths += 1
	SaveGame.register_death()
	_lives = maxi(0, _lives - 1)
	_update_lives_label()
	inventory_panel.visible = false
	game_over_label.visible = true

	if _timer_expired:
		game_over_label.text = "TIEMPO AGOTADO - Volviendo al nivel 1..."
		await get_tree().create_timer(2.0).timeout
		await _restart_from_first_level()
		return

	if _lives > 0:
		game_over_label.text = "HAS MUERTO - Reapareciendo..."
		await get_tree().create_timer(1.2).timeout
		_respawn_player()
	else:
		game_over_label.text = "SIN VIDAS - Volviendo al nivel 1..."
		await get_tree().create_timer(2.2).timeout
		await _restart_from_first_level()


func _restart_from_first_level() -> void:
	## Game over (2026-11-13): sin vidas o sin tiempo la expedición vuelve a
	## empezar en el nivel 1, reiniciando tiempo y muertes.
	SaveGame.start_at_level(SaveGame.FIRST_LEVEL)
	await _fade_to_scene(FIRST_LEVEL_PATH)


func _respawn_player() -> void:
	if _completed or not player.health.is_dead:
		return
	game_over_label.visible = false
	player.revive(_respawn_point)
	camera.snap_to_target()
	# Fase contrarreloj (2026-11-17): reaparecer no regala tiempo. El reloj ha
	# seguido corriendo durante la animación de muerte y la espera.
	_time_left = _timer.remaining
	_update_timer_label()
	_update_progress_bar()
	_update_medal_label()


func _on_checkpoint_activated(checkpoint: Checkpoint) -> void:
	_respawn_point = checkpoint.global_position
	SaveGame.set_level(level_variant)
	_show_checkpoint_banner()


## Aviso de descanso (2026-11-13): confirma que el control curó al jugador y
## que ese punto será la nueva reaparición.
func _show_checkpoint_banner() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	var banner := Label.new()
	banner.name = "CheckpointBanner"
	banner.text = "CONTROL ACTIVADO\nDESCANSO · VIDA RESTAURADA"
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 170.0
	banner.offset_bottom = 226.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_color_override("font_color", Color(0.62, 1.0, 0.78, 1.0))
	banner.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	banner.add_theme_constant_override("outline_size", 5)
	hud.add_child(banner)
	var tween := create_tween()
	tween.tween_interval(1.3)
	tween.tween_property(banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(banner.queue_free)


func _on_portal_reached() -> void:
	if _completed:
		return
	_completed = true
	_timer.stop()
	_time_left = _timer.remaining
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var elapsed := _timer.elapsed
	var medal := _current_medal()
	_account_time(elapsed)
	SaveGame.record_level_result(level_variant, elapsed, medal, _level_deaths)
	inventory_panel.visible = false
	completed_label.text = "%s COMPLETADO · MEDALLA %s" % [
		level_name,
		MedalRules.display(medal),
	]
	completed_label.visible = true

	var next_level := LevelRegistry.next_implemented_level(level_variant)
	if next_level == -1:
		SaveGame.finish_game()
	elif SaveGame.is_level_unlocked(next_level):
		SaveGame.set_level(next_level)

	await get_tree().create_timer(2.0).timeout
	await _fade_to_scene(RESULTS_PATH)


func _account_time(elapsed: float) -> void:
	## El tiempo de la expedición es el tiempo real invertido en el nivel; la
	## medalla usa el mismo valor. Ya no se deriva de la cuenta regresiva.
	SaveGame.add_time(maxf(0.0, elapsed))


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = 90
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.45)


func _fade_to_scene(path: String) -> void:
	# Transición (2026-11-12): imagen y música se funden a la vez antes de
	# cambiar de escena; el destino vuelve a entrar con fundido desde negro.
	Sfx.stop_music(0.45)
	if _fade_rect != null:
		_fade_rect.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.4)
		await tween.finished
	if path.is_empty():
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)


func _on_inventory_changed(_potions: int) -> void:
	_update_item_slots()
	_update_inventory_panel()


func _on_item_used(item_name: String) -> void:
	if item_name != "ration":
		return
	# La ración ya no regala tiempo: Player.apply_speed_boost() modify only
	# la velocidad, así el cronómetro y las medallas permanecen limpios.
	_update_timer_label()


func _update_item_slots() -> void:
	item_slots.text = "Q  %s    -    E  %s" % [
		player.inventory.slot_label(0),
		player.inventory.slot_label(1),
	]


func _update_inventory_panel() -> void:
	var usable_lines := PackedStringArray(["UTILIZABLES"])
	for item_id in player.inventory.usable_items():
		usable_lines.append("  %s x%d - %s" % [
			player.inventory.item_name(item_id),
			player.inventory.count(item_id),
			player.inventory.item_description(item_id),
		])
	if usable_lines.size() == 1:
		usable_lines.append("  (sin objetos utilizables)")
	potion_info.text = "\n".join(usable_lines)

	var permanent_lines := PackedStringArray(["PERMANENTES"])
	for item_id in player.inventory.permanent_items():
		permanent_lines.append("  %s - %s" % [
			player.inventory.item_name(item_id),
			player.inventory.item_description(item_id),
		])
	jumps_info.text = "\n".join(permanent_lines)

	meta_info.text = "RÁPIDOS:  Q %s   |   E %s" % [
		player.inventory.slot_label(0),
		player.inventory.slot_label(1),
	]


func is_run_over() -> bool:
	## Consulta del overlay de pausa: evita pausar tras morir, completar el
	## nivel o agotar el tiempo (las transiciones no deben congelarse).
	return _completed or _timer_expired or player.health.is_dead


func _update_meta_labels() -> void:
	bonus_info.text = "Nivel %d de %d · %d vidas. El reloj sigue corriendo al morir; la ración da velocidad." % [
		level_variant,
		SaveGame.LAST_LEVEL,
		MAX_LIVES,
	]
	_update_inventory_panel()
