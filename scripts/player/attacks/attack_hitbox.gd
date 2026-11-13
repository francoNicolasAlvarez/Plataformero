class_name AttackHitbox
extends Area2D
## Hitbox reutilizable para ataques cuerpo a cuerpo.
## Cualquier cuerpo con take_damage() recibe el golpe automáticamente.

signal hit_detected(body: Node2D, damage: int)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _damage: int = 0
var _active: bool = false


func _ready() -> void:
	monitoring = false
	collision_shape.disabled = true
	body_entered.connect(_on_body_entered)


## Activa la hitbox delante del personaje según su orientación.
func activate(attack: AttackData, facing: int) -> void:
	_damage = attack.damage
	position = Vector2(absf(attack.hitbox_offset.x) * facing, attack.hitbox_offset.y)

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
	else:
		rectangle = rectangle.duplicate()
	rectangle.size = attack.hitbox_size
	collision_shape.shape = rectangle

	collision_shape.disabled = false
	monitoring = true
	_active = true


func deactivate() -> void:
	_active = false
	set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return

	if body.has_method("take_damage"):
		body.take_damage(_damage, self)
		hit_detected.emit(body, _damage)
