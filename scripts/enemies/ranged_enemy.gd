class_name RangedEnemy
extends TrainingDummy
## Enemigo a distancia: mago azul con bastón que lanza bolas de fuego.
## Reutiliza vida, daño por contacto y muerte del enemigo base, y añade
## gravedad y disparos cuando detecta al jugador.
## Cambio 2026-11-11: ya no apunta al jugador; los proyectiles vuelan siempre
## en horizontal, hacia el lado en el que esté el jugador (se esquiva
## saltando o cambiando de altura).
## Cambio 2026-11-11 (visuales): cada disparo lanza 3 bolas de fuego en un
## abanico horizontal de ±10°.

const PROJECTILE_SCENE := preload("res://scenes/enemies/enemy_projectile.tscn")

const FIREBALL_COUNT := 3
const FIREBALL_SPREAD_DEG := 10.0

@export_range(60.0, 900.0, 10.0) var shoot_range: float = 430.0
@export_range(0.4, 6.0, 0.05) var shoot_interval: float = 1.7
@export_range(80.0, 600.0, 10.0) var projectile_speed: float = 240.0
@export_range(0.0, 3000.0, 10.0) var gravity: float = 1400.0
@export_range(0.0, 200.0, 5.0) var patrol_speed: float = 32.0
@export_range(10.0, 400.0, 5.0) var patrol_distance: float = 52.0
## Los guardias que viajan sobre plataformas móviles no deben moverse por su
## cuenta: el padre ya los desplaza y move_and_slide los desincronizaba.
@export var anchored: bool = false

@onready var line_of_sight: RayCast2D = $LineOfSight

var _shoot_cooldown: float = 0.8
var _origin_x: float = 0.0
var _direction: int = -1


func _ready() -> void:
	super._ready()
	_origin_x = global_position.x


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if anchored:
		_check_contact_damage()
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	velocity.x = float(_direction) * patrol_speed
	move_and_slide()

	if is_on_wall():
		_direction *= -1
	if absf(global_position.x - _origin_x) >= patrol_distance:
		_direction = -1 if global_position.x > _origin_x else 1

	_check_contact_damage()


func _process(delta: float) -> void:
	super._process(delta)
	if _is_dead:
		return

	_shoot_cooldown -= delta
	var target := get_tree().get_first_node_in_group("player") as Node2D
	if target == null:
		return

	var offset := target.global_position - global_position
	if absf(offset.x) > shoot_range or absf(offset.y) > 170.0:
		return

	var direction := 1.0 if offset.x >= 0.0 else -1.0
	visual.scale.x = direction

	if not _has_line_of_sight(target):
		return
	if _shoot_cooldown > 0.0:
		return

	_shoot(direction)
	_shoot_cooldown = shoot_interval


func _has_line_of_sight(target: Node2D) -> bool:
	if line_of_sight == null:
		return true
	line_of_sight.target_position = line_of_sight.to_local(target.global_position)
	line_of_sight.force_raycast_update()
	return not line_of_sight.is_colliding()


## Los proyectiles deben vivir en el mundo, no dentro de una plataforma móvil:
## si fueran hijos de ella, la plataforma los arrastraría al desplazarse.
func _projectile_parent() -> Node:
	var node := get_parent()
	while node != null and node.is_in_group("moving_platforms"):
		node = node.get_parent()
	return node if node != null else get_parent()


func _shoot(direction: float) -> void:
	## Tres bolas de fuego en abanico horizontal (2026-11-11): no persiguen al
	## jugador; salen hacia su lado a la altura del enemigo, así que se
	## esquivan saltando. Los ángulos son fijos alrededor de la horizontal.
	var aim := Vector2(direction, 0.0)
	var step := deg_to_rad(FIREBALL_SPREAD_DEG)
	var start_angle := -step * float(FIREBALL_COUNT - 1) * 0.5
	for i in FIREBALL_COUNT:
		var shot_velocity := aim.rotated(start_angle + step * float(i)) * projectile_speed
		var projectile := PROJECTILE_SCENE.instantiate()
		_projectile_parent().add_child(projectile)
		projectile.global_position = global_position + Vector2(direction * 30.0, -14.0)
		projectile.direction = direction
		projectile.speed = projectile_speed
		projectile.velocity = shot_velocity
		projectile.rotation = shot_velocity.angle()
	Sfx.play("shoot", -13.0)
