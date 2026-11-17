class_name EnemyProjectile
extends Area2D
## Proyectil enemigo. Viaja en horizontal, daña al jugador una vez y
## desaparece al impactar o al agotar su tiempo de vida.
## Rediseno 2026-11-11: dos estilos visuales - FIRE (orbe de energia azul con
## estela magica y estallido azul al impactar, lanzado por el mago, 3 por
## disparo) y BOLT (flecha del arquero, una por disparo, algo más rápida y
## sin estela; mantiene la rotación fija que le dio el disparador).

enum Style { FIRE, BOLT }

const FIREBALL_TEXTURE := preload("res://assets/enemies/fireball.svg")
const BOLT_TEXTURE := preload("res://assets/enemies/crossbow_bolt.svg")

@export var style: Style = Style.FIRE
@export_range(50.0, 600.0, 5.0) var speed: float = 230.0
@export_range(1, 99, 1) var damage: int = 15
@export_range(0.2, 10.0, 0.1) var lifetime: float = 3.0

var direction: float = 1.0
var vertical_speed: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var _life_left: float = 0.0
var _spin_rate: float = 4.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow: Sprite2D = $Glow


func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)
	apply_style()


func use_fire_style() -> void:
	## Cambia el proyectil a bola de fuego (estilo del mago azul).
	style = Style.FIRE
	apply_style()


func use_bolt_style() -> void:
	## Cambia el proyectil a flecha (estilo del arquero).
	style = Style.BOLT
	apply_style()


func apply_style() -> void:
	## Aplica el aspecto del estilo actual; idempotente y seguro de rellamar.
	if sprite == null:
		return  # Aún no entró en escena; _ready aplicará el estilo.
	var trail := get_node_or_null("FlameTrail") as CPUParticles2D
	if style == Style.BOLT:
		sprite.texture = BOLT_TEXTURE
		glow.visible = false
		_spin_rate = 0.0
		if trail != null:
			trail.queue_free()
		return
	sprite.texture = FIREBALL_TEXTURE
	glow.visible = true
	_spin_rate = 4.0
	if trail == null:
		Fx.make_fire_trail(self)


func _physics_process(delta: float) -> void:
	if not velocity.is_zero_approx():
		position += velocity * delta
	else:
		position.x += speed * direction * delta
		position.y += vertical_speed * delta
	rotation += _spin_rate * delta * direction
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and not body.is_in_group("enemies"):
		body.take_damage(_damage_against(body), self)
	if style == Style.FIRE:
		# La bola de fuego estalla; la flecha se clava sin ruido.
		var impact_parent := get_parent() as Node2D
		if impact_parent != null:
			Fx.make_burst(impact_parent, position, Color(0.35, 0.8, 1.0, 0.9))
	queue_free()


func _damage_against(body: Node2D) -> int:
	if body is Player:
		var player := body as Player
		return maxi(1, ceili(float(player.health.current_health) / 3.0))
	return damage
