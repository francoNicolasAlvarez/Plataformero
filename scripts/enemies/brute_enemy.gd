class_name BruteEnemy
extends TrainingDummy
## Bruto lanzarrocas (2026-11-17), enemigo nuevo del nivel 9: una persona
## fornida con ropa roja, un 30 % más alta que el resto de enemigos. No se
## mueve; se queda de pie junto a una pila de rocas y lanza un peñasco rápido
## a 45 grados que dibuja una parábola. Calcula la velocidad para que la roca
## caiga donde está el jugador (la gravedad del proyectil y el ángulo son
## fijos); el peñasco mide 1,5 veces el modelo del jugador (ver ThrownBoulder).


const HEIGHT_FACTOR := 1.3
const BASE_VISUAL_SCALE := 1.25
const LAUNCH_ANGLE_DEG := 45.0
const MIN_SPEED := 480.0
const MAX_SPEED := 950.0
const FALLBACK_SPEED := 700.0

@export_range(100.0, 900.0, 10.0) var throw_range: float = 560.0
@export_range(60.0, 400.0, 10.0) var min_range: float = 120.0
@export_range(0.5, 6.0, 0.05) var throw_interval: float = 2.2
@export_range(0.0, 3000.0, 10.0) var gravity: float = 1400.0
@export var boulder_gravity: float = 1200.0

var _cooldown: float = 1.0


func _ready() -> void:
	_build_visual()
	super._ready()
	visual.scale = Vector2(BASE_VISUAL_SCALE * HEIGHT_FACTOR, BASE_VISUAL_SCALE * HEIGHT_FACTOR)
	# Los pies de la silueta quedan en +24 (arte de 48 px); la colisión llega a
	# +31,2, así que el visual sube lo que falta.
	_visual_base_y = 31.2 - 24.0 * visual.scale.y


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if not is_on_floor():
		velocity.y += gravity * _gravity_sign * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	move_and_slide()
	_check_contact_damage()


func _process(delta: float) -> void:
	super._process(delta)
	if _is_dead:
		return
	_cooldown -= delta
	var target := get_tree().get_first_node_in_group("player") as Node2D
	if target == null:
		return
	var offset := target.global_position - global_position
	var direction := 1.0 if offset.x >= 0.0 else -1.0
	visual.scale.x = direction * absf(visual.scale.y)
	if absf(offset.x) > throw_range or absf(offset.x) < min_range or absf(offset.y) > 260.0:
		return
	if _cooldown > 0.0:
		return
	throw_boulder(target.global_position)
	_cooldown = throw_interval


func launch_origin(direction: float) -> Vector2:
	return global_position + Vector2(direction * 34.0, -30.0 * _gravity_sign)


func compute_launch_speed(origin: Vector2, target_position: Vector2) -> float:
	## Velocidad inicial para que, saliendo a 45 grados, la roca pase por el
	## objetivo: v² = g·d² / (dy + d), con dy positivo hacia abajo.
	var distance := absf(target_position.x - origin.x)
	var drop := target_position.y - origin.y
	if distance < 1.0 or drop + distance <= 1.0:
		return FALLBACK_SPEED
	var speed := sqrt(boulder_gravity * distance * distance / (drop + distance))
	return clampf(speed, MIN_SPEED, MAX_SPEED)


func throw_boulder(target_position: Vector2) -> Node:
	var direction := 1.0 if target_position.x >= global_position.x else -1.0
	var origin := launch_origin(direction)
	var speed := compute_launch_speed(origin, target_position)
	var angle := deg_to_rad(LAUNCH_ANGLE_DEG)
	var boulder := ThrownBoulder.new()
	boulder.name = "ThrownBoulder"
	boulder.fall_gravity = boulder_gravity
	boulder.velocity = Vector2(direction * cos(angle), -sin(angle) * _gravity_sign) * speed
	get_parent().add_child(boulder)
	boulder.global_position = origin
	Sfx.play("bomb", -14.0)
	return boulder


func _build_visual() -> void:
	## Silueta de 48 px de alto en coordenadas locales (pies en +24): piernas,
	## torso ancho rojo, brazos gruesos, cabeza con barba y cinta roja.
	var red := Color("#c62828")
	var red_dark := Color("#8e1c1c")
	var skin := Color("#d9a077")
	var boots := Color("#2e1c14")
	_rect("LegLeft", Rect2(-14, 10, 12, 14), Color("#7a1a1a"))
	_rect("LegRight", Rect2(2, 10, 12, 14), Color("#7a1a1a"))
	_rect("BootLeft", Rect2(-15, 20, 14, 4), boots)
	_rect("BootRight", Rect2(1, 20, 14, 4), boots)
	_rect("ArmLeft", Rect2(-29, -8, 10, 16), red)
	_rect("ArmRight", Rect2(19, -8, 10, 16), red)
	_rect("HandLeft", Rect2(-29, 8, 10, 6), skin)
	_rect("HandRight", Rect2(19, 8, 10, 6), skin)
	_rect("Torso", Rect2(-19, -9, 38, 20), red)
	_rect("TorsoShade", Rect2(4, -9, 15, 20), red_dark)
	_rect("Belt", Rect2(-19, 6, 38, 5), Color("#3a2416"))
	_rect("Buckle", Rect2(-3, 6, 6, 5), Color("#e0b341"))
	_rect("Neck", Rect2(-5, -12, 10, 4), skin)
	_rect("Head", Rect2(-9, -24, 18, 14), skin)
	_rect("Headband", Rect2(-9, -22, 18, 3), red)
	_rect("Beard", Rect2(-9, -14, 18, 5), Color("#2b1a12"))
	_rect("EyeLeft", Rect2(-6, -19, 4, 3), Color.BLACK)
	_rect("EyeRight", Rect2(2, -19, 4, 3), Color.BLACK)
	_rect("BrowLeft", Rect2(-7, -21, 6, 2), Color("#2b1a12"))
	_rect("BrowRight", Rect2(1, -21, 6, 2), Color("#2b1a12"))


func _rect(node_name: String, rect: Rect2, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.color = color
	polygon.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	$Visual.add_child(polygon)
