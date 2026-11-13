class_name AttackData
extends Resource
## Define un ataque concreto. Al ser un Resource, se pueden crear nuevas
## armas/ataques (espada, martillo, proyectil...) sin modificar Player.

@export var id: StringName = &"basic"
@export var display_name: String = "Ataque básico"
@export var animation_name: StringName = &"attack"

@export_group("Tiempos")
@export_range(0.01, 2.0, 0.01) var duration: float = 0.22
@export_range(0.0, 5.0, 0.01) var cooldown: float = 0.35

@export_group("Impacto")
@export_range(0, 9999, 1) var damage: int = 10
@export var hitbox_offset: Vector2 = Vector2(34.0, 0.0)
@export var hitbox_size: Vector2 = Vector2(46.0, 34.0)
