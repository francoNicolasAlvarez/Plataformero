class_name FlyingEnemy
extends TrainingDummy
## Enemigo volador (2026-11-13): cruza la pantalla de un extremo al otro sin
## perseguir al jugador y con un patrón ondulante vertical. El generador
## (FlyingSpawner) decide el lado, la altura y la frecuencia; este enemigo solo
## se mueve en horizontal y suma una onda senoidal sobre su altura de origen.
## No usa gravedad ni colisiones con el mundo: el daño es por contacto.

@export var horizontal_speed: float = 190.0
@export_range(0.0, 160.0, 1.0) var wave_amplitude: float = 42.0
@export_range(0.0, 6.0, 0.05) var wave_frequency: float = 2.2
@export_range(0.5, 30.0, 0.5) var lifetime: float = 12.0
@export var direction: int = 1

var _flight_time: float = 0.0
var _spawn_y: float = 0.0
var _wing_time: float = 0.0


func _ready() -> void:
	super._ready()
	_spawn_y = position.y
	direction = 1 if direction >= 0 else -1
	rotation = 0.0


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_flight_time += delta
	position.x += float(direction) * horizontal_speed * delta
	position.y = _spawn_y + sin(_flight_time * wave_frequency) * wave_amplitude
	_check_contact_damage()
	if _flight_time >= lifetime:
		queue_free()


func _process(delta: float) -> void:
	if _is_dead:
		return
	_wing_time += delta
	var flap := sin(_wing_time * 12.0) * 0.45
	var wing_left := get_node_or_null("Visual/WingLeft") as Node2D
	var wing_right := get_node_or_null("Visual/WingRight") as Node2D
	if wing_left != null:
		wing_left.rotation = flap
	if wing_right != null:
		wing_right.rotation = -flap
	visual.position.y = sin(_wing_time * 3.4) * 2.0
