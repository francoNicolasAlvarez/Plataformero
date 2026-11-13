extends Area2D
## Sierra móvil que recorre una línea y gira sobre sí misma.

@export_range(1, 99, 1) var damage: int = 18
@export_range(0.0, 400.0, 5.0) var move_range: float = 120.0
@export_range(0.1, 6.0, 0.05) var move_speed: float = 1.6
@export_range(0.0, 30.0, 0.5) var spin_speed: float = 9.0
@export_range(0.0, 2.0, 0.05) var warmup_time: float = 0.6

@onready var visual: Node2D = $Visual

var _origin: Vector2
var _time: float = 0.0
var _warmup_left: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_origin = position
	_time = randf() * 10.0
	_warmup_left = warmup_time


func _physics_process(delta: float) -> void:
	if _warmup_left > 0.0:
		# Aviso (2026-11-12): la sierra parpadea un instante antes de empezar
		# a moverse para que el jugador pueda anticipar el peligro.
		_warmup_left = maxf(0.0, _warmup_left - delta)
		visual.modulate.a = 0.55 + 0.45 * absf(sin(_warmup_left * 22.0))
		if _warmup_left <= 0.0:
			visual.modulate.a = 1.0
		return

	_time += delta
	position.x = _origin.x + sin(_time * move_speed) * move_range
	visual.rotation += spin_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_damage(damage, self)
