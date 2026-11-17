class_name Player
extends CharacterBody2D
## Controlador principal del personaje.
## Mantiene separadas las estadísticas (PlayerStats) y los datos de ataque
## (AttackData) para poder reutilizarlos con otros personajes y armas.

signal jumped
signal landed
signal attack_started(attack: AttackData)
signal attack_finished
signal died
signal inventory_changed(potions: int)
signal item_used(item_name: String)
signal weapon_range_changed(current_range: int)

const BASE_WEAPON_RANGE := 20
const RATION_SPEED_MULTIPLIER := 1.35
const RATION_SPEED_DURATION := 5.0

const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"
const ANIM_RUN := &"run"
const ANIM_JUMP := &"jump"
const ANIM_FALL := &"fall"
const ANIM_DEATH := &"death"

@export var stats: PlayerStats
@export var basic_attack: AttackData
@export_range(0, 9, 1) var starting_potions: int = 2
@export_range(0, 9, 1) var starting_rations: int = 1
@export_range(1, 999, 1) var potion_heal_amount: int = 30
@export_range(1, 999, 1) var weapon_range: int = BASE_WEAPON_RANGE
@export_range(0.5, 20.0, 0.1) var range_pixels_per_point: float = 2.3
@export var inverted_gravity: bool = false
@export var inverted_controls: bool = false

@onready var visual: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var visual_root: Node2D = $Visual
@onready var slash: Polygon2D = $Visual/Slash
@onready var attack_hitbox: AttackHitbox = $AttackHitbox
@onready var health: Health = $Health

var _facing: int = 1
var _is_running: bool = false
var _is_attacking: bool = false
var _attack_cooldown_left: float = 0.0
var _attack_time_left: float = 0.0
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _jump_hold_left: float = 0.0
var _jumps_used: int = 0
var _slash_tween: Tween
var _death_tween: Tween
var _squash_tween: Tween
var _dust: CPUParticles2D
var _fall_speed: float = 0.0
var _speed_boost_left: float = 0.0
var _speed_boost_multiplier: float = 1.0
var _gravity_sign: float = 1.0
var _invulnerability_left: float = 0.0
var _is_dead: bool = false
var inventory: Inventory = Inventory.new()
var potions: int:
	get:
		return inventory.count("potion") if inventory != null else 0


func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	if basic_attack == null:
		basic_attack = AttackData.new()

	configure_gravity()
	configure_controls()

	health.died.connect(_on_health_died)
	inventory.reset_starting_items(starting_potions, starting_rations)
	inventory.changed.connect(_on_inventory_changed)
	inventory_changed.emit(potions)
	visual.flip_h = _facing < 0
	_play_animation(ANIM_IDLE)
	landed.connect(_on_landed_fx)
	_dust = Fx.make_dust(self, Vector2(0.0, -22.0 if inverted_gravity else 22.0))

func configure_gravity() -> void:
	_gravity_sign = -1.0 if inverted_gravity else 1.0
	up_direction = Vector2.DOWN if inverted_gravity else Vector2.UP
	visual.scale.y = -1.0 if inverted_gravity else 1.0
	var shadow := get_node_or_null("Shadow") as Polygon2D
	if shadow != null:
		shadow.position.y = -24.0 if inverted_gravity else 24.0
	if _dust != null:
		_dust.position = Vector2(0.0, -22.0 if inverted_gravity else 22.0)

func configure_controls() -> void:
	## Nivel 8 (2026-11-16): invierte solo el eje horizontal, de modo que D y
	## flecha derecha mueven hacia la izquierda. El mando pasa por las mismas
	## acciones, así que también queda invertido.
	_facing = -1 if inverted_controls else 1
	visual.flip_h = inverted_controls


func _physics_process(delta: float) -> void:
	if _is_dead:
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, stats.deceleration * delta)
		move_and_slide()
		return

	var was_on_floor := is_on_floor()

	_tick_timers(delta)
	_update_jump_windows(delta)
	_handle_horizontal_movement(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_items()

	# Velocidad de caída justo antes del impacto: alimenta el squash y el
	# polvo al aterrizar.
	_fall_speed = velocity.y
	move_and_slide()

	# La señal permite añadir después partículas, sonido o sacudida de cámara.
	if not was_on_floor and is_on_floor():
		landed.emit()

	_update_animation()


func _tick_timers(delta: float) -> void:
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_speed_boost_left = maxf(0.0, _speed_boost_left - delta)
	if is_zero_approx(_speed_boost_left):
		_speed_boost_multiplier = 1.0

	if _invulnerability_left > 0.0:
		_invulnerability_left = maxf(0.0, _invulnerability_left - delta)
		visual.modulate.a = 0.45 if fmod(_invulnerability_left * 14.0, 2.0) > 1.0 else 1.0
		if _invulnerability_left <= 0.0:
			visual.modulate = Color.WHITE

	if _is_attacking:
		_attack_time_left -= delta
		if _attack_time_left <= 0.0:
			_finish_attack()


func _update_jump_windows(delta: float) -> void:
	if is_on_floor():
		_coyote_left = stats.coyote_time
		_jumps_used = 0
		_jump_hold_left = 0.0
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)

		# Si se cayó de una plataforma sin saltar, se consume el salto de suelo
		# al terminar el tiempo de coyote. Deja la puerta abierta al doble salto.
		if _coyote_left <= 0.0 and _jumps_used == 0:
			_jumps_used = 1

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = stats.jump_buffer_time
	else:
		_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	# Soltar el botón durante el ascenso recorta la altura del salto.
	if Input.is_action_just_released("jump"):
		_jump_hold_left = 0.0
		if velocity.y * _gravity_sign < 0.0:
			velocity.y *= stats.jump_cut_multiplier


func _handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if inverted_controls:
		direction = -direction
	_is_running = Input.is_action_pressed("run") and not is_zero_approx(direction)

	if not is_zero_approx(direction):
		_facing = 1 if direction > 0.0 else -1
		visual.flip_h = _facing < 0

	var target_speed := 0.0
	if not is_zero_approx(direction):
		var speed := stats.run_speed if _is_running else stats.max_speed
		if _speed_boost_left > 0.0:
			speed *= _speed_boost_multiplier
		target_speed = direction * speed

	var current_acceleration := stats.acceleration
	if not is_on_floor():
		current_acceleration = stats.air_acceleration

	if is_zero_approx(direction):
		current_acceleration = stats.deceleration if is_on_floor() else stats.air_deceleration
	elif not is_zero_approx(velocity.x) and signf(velocity.x) != signf(direction):
		current_acceleration = stats.turn_acceleration

	velocity.x = move_toward(velocity.x, target_speed, current_acceleration * delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = _gravity_sign * maxf(velocity.y * _gravity_sign, 0.0)
		return

	var fast_falling := Input.is_action_pressed("move_down")
	var falling_speed := velocity.y * _gravity_sign

	if not fast_falling and falling_speed < 0.0 and _jump_hold_left > 0.0 \
			and Input.is_action_pressed("jump"):
		velocity.y -= _gravity_sign * stats.jump_hold_acceleration * delta
		_jump_hold_left = maxf(0.0, _jump_hold_left - delta)
		falling_speed = velocity.y * _gravity_sign

	var current_gravity := stats.gravity
	if falling_speed > 0.0:
		current_gravity *= stats.fall_gravity_multiplier

	falling_speed = minf(falling_speed + current_gravity * delta, stats.max_fall_speed)
	velocity.y = _gravity_sign * falling_speed

	if fast_falling:
		velocity.y = _gravity_sign * maxf(falling_speed, stats.fast_fall_speed)
		_jump_hold_left = 0.0


func _handle_jump() -> void:
	if _jump_buffer_left <= 0.0:
		return

	var on_ground := is_on_floor() or _coyote_left > 0.0

	if on_ground and _jumps_used == 0:
		_jump()
		_jumps_used = 1
	elif not on_ground and _jumps_used < 2:
		# El doble salto es una habilidad permanente (2026-11-12): siempre
		# hay un impulso aéreo disponible por cada salto desde el suelo.
		_jump()
		_jumps_used = 2


func _jump() -> void:
	# v = sqrt(2 * g * h) permite configurar la altura en lugar de la velocidad.
	velocity.y = -_gravity_sign * sqrt(2.0 * stats.gravity * stats.jump_height)
	_jump_buffer_left = 0.0
	_jump_hold_left = stats.jump_hold_time
	_squash(Vector2(0.84, 1.18), 0.14)
	_dust.restart()
	Sfx.play("jump", -12.0)
	jumped.emit()


func _squash(target_scale: Vector2, duration: float) -> void:
	## Squash & stretch (2026-11-11): estira el cuerpo al saltar y lo
	## comprime al aterrizar; la escala siempre regresa a (1, 1).
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	visual_root.scale = target_scale
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual_root, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_landed_fx() -> void:
	## Aterrizar comprime el cuerpo según la velocidad de caída y levanta
	## polvo en los pies.
	var impact := clampf(absf(_fall_speed) / 900.0, 0.25, 1.0)
	_squash(Vector2(1.0 + 0.28 * impact, 1.0 - 0.28 * impact), 0.16 + 0.1 * impact)
	_dust.restart()


func take_damage(amount: int, source: Node = null) -> void:
	if _is_dead or _invulnerability_left > 0.0 or amount <= 0:
		return

	# Cualquier golpe normal consume uno de los tres impactos permitidos.
	# Los valores enormes (pozos/cronómetro) siguen siendo letales al instante.
	var applied_damage := health.max_health if amount >= 9999 else 1
	health.take_damage(applied_damage, source)
	if health.is_dead:
		return

	_invulnerability_left = stats.invulnerability_time
	visual.modulate = Color(1.0, 0.55, 0.55, 1.0)
	Sfx.play("hit", -5.0)
	_apply_knockback(source)


func _apply_knockback(source: Node) -> void:
	var direction := -_facing
	if source is Node2D:
		direction = signi((source as Node2D).global_position.x - global_position.x)
		if direction == 0:
			direction = -_facing

	velocity.x = float(direction) * stats.knockback_force
	velocity.y = -_gravity_sign * stats.knockback_up_force


func _handle_items() -> void:
	for slot in Inventory.SLOT_COUNT:
		if Input.is_action_just_pressed(Inventory.SLOT_ACTIONS[slot]):
			use_quick_slot(slot)


func apply_speed_boost(duration: float = RATION_SPEED_DURATION, multiplier: float = RATION_SPEED_MULTIPLIER) -> void:
	## Fase contrarreloj: la ración sustituye el bonus de tiempo por una subida
	## temporal de velocidad que no altera las medallas.
	_speed_boost_left = maxf(_speed_boost_left, duration)
	_speed_boost_multiplier = maxf(1.0, multiplier)


func is_speed_boosted() -> bool:
	return _speed_boost_left > 0.0


func use_quick_slot(slot_index: int) -> bool:
	## Usa el objeto equipado en un espacio rápido (Q = 0, E = 1).
	var item_id := inventory.slot_item(slot_index)
	if item_id.is_empty():
		return false
	if item_id == "potion":
		return use_potion()
	if item_id == "ration":
		inventory.consume("ration")
		apply_speed_boost()
		Sfx.play("ui", -8.0)
		item_used.emit("ration")
		return true
	return false


func use_potion() -> bool:
	if not inventory.has_item("potion") or health.is_dead \
			or health.current_health >= health.max_health:
		return false

	inventory.consume("potion")
	health.heal(potion_heal_amount)
	Sfx.play("heal", -6.0)
	item_used.emit("potion")
	return true


func _on_inventory_changed() -> void:
	inventory_changed.emit(potions)


func _on_health_died() -> void:
	_is_dead = true
	attack_hitbox.deactivate()
	slash.visible = false
	velocity = Vector2.ZERO
	visual.play(ANIM_DEATH)
	visual.modulate = Color(1.0, 0.55, 0.55, 1.0)
	Sfx.play("death", -3.0)

	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	visual_root.scale = Vector2.ONE

	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()

	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(
		visual,
		"rotation",
		-PI * 0.42 * float(_facing) * _gravity_sign,
		0.45
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_death_tween.tween_property(visual, "position", Vector2(0.0, 20.0 * _gravity_sign), 0.45)
	_death_tween.tween_property(
		visual,
		"modulate",
		Color(0.65, 0.28, 0.28, 0.0),
		0.9
	).set_delay(0.35)

	died.emit()


func revive(spawn_position: Vector2) -> void:
	## Reaparición en un checkpoint (2026-11-12) sin recargar la escena:
	## restaura la vida y devuelve el cuerpo y la animación a su estado normal.
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()

	_is_dead = false
	health.reset()
	global_position = spawn_position
	velocity = Vector2.ZERO
	_jumps_used = 0
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	_invulnerability_left = stats.invulnerability_time
	_speed_boost_left = 0.0
	_speed_boost_multiplier = 1.0
	visual.modulate = Color.WHITE
	visual.rotation = 0.0
	visual.position = Vector2.ZERO
	visual_root.scale = Vector2.ONE
	_play_animation(ANIM_IDLE)
	set_physics_process(true)


func _handle_attack() -> void:
	if not Input.is_action_just_pressed("attack"):
		return
	if _is_attacking or _attack_cooldown_left > 0.0:
		return

	_start_attack()


func _start_attack() -> void:
	_is_attacking = true
	_attack_time_left = basic_attack.duration
	_attack_cooldown_left = basic_attack.cooldown

	var attack := build_attack_data()
	Sfx.play("attack", -11.0)
	visual.play(attack.animation_name)
	attack_hitbox.activate(attack, _facing)
	_show_slash(attack)
	attack_started.emit(attack)


func add_weapon_range(amount: int) -> void:
	if amount <= 0:
		return
	weapon_range += amount
	weapon_range_changed.emit(weapon_range)


func build_attack_data() -> AttackData:
	var extra_range := maxi(0, weapon_range - BASE_WEAPON_RANGE)
	if extra_range == 0:
		return basic_attack

	var width := basic_attack.hitbox_size.x + float(extra_range) * range_pixels_per_point
	var width_scale := width / basic_attack.hitbox_size.x
	var attack := basic_attack.duplicate(true) as AttackData
	attack.hitbox_size.x = width
	attack.hitbox_offset.x = basic_attack.hitbox_offset.x * width_scale
	return attack


func _finish_attack() -> void:
	_is_attacking = false
	attack_hitbox.deactivate()
	attack_finished.emit()
	_update_animation()


func _show_slash(attack: AttackData) -> void:
	if _slash_tween != null and _slash_tween.is_valid():
		_slash_tween.kill()

	var width_scale := attack.hitbox_size.x / basic_attack.hitbox_size.x
	slash.visible = true
	slash.modulate.a = 1.0
	slash.position = Vector2(attack.hitbox_offset.x * float(_facing), -2.0)
	slash.scale = Vector2(float(_facing) * width_scale, 1.0)
	slash.rotation = -0.15 * float(_facing)

	_slash_tween = create_tween()
	_slash_tween.tween_property(slash, "modulate:a", 0.0, attack.duration)
	_slash_tween.parallel().tween_property(
		slash,
		"scale",
		Vector2(float(_facing) * width_scale * 1.35, 1.35),
		attack.duration
	)
	_slash_tween.tween_callback(_hide_slash)


func _hide_slash() -> void:
	slash.visible = false
	slash.scale = Vector2.ONE


func _update_animation() -> void:
	if _is_attacking:
		return

	var next_animation := ANIM_IDLE

	if not is_on_floor():
		next_animation = ANIM_JUMP if velocity.y * _gravity_sign < 0.0 else ANIM_FALL
	elif absf(velocity.x) > 8.0:
		next_animation = ANIM_RUN if _is_running else ANIM_WALK

	_play_animation(next_animation)


func _play_animation(animation_name: StringName) -> void:
	if visual.animation == animation_name and visual.is_playing():
		return
	visual.play(animation_name)
