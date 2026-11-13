extends Area2D
## Zona de caída. Elimina al jugador si cae fuera del nivel.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).health.take_damage(9999)
