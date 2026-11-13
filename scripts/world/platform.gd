@tool
class_name Platform
extends StaticBody2D
## Plataforma provisional reutilizable. Permite cambiar tamaño y color desde
## el Inspector sin editar manualmente la colisión ni el polígono.

@export var platform_size: Vector2 = Vector2(200.0, 24.0):
	set(value):
		platform_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_refresh()

@export var platform_color: Color = Color("#355070"):
	set(value):
		platform_color = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D

	if visual != null:
		var half := platform_size * 0.5
		visual.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		])
		visual.color = platform_color

	# Vestido 2026-11-11: franja iluminada en el borde superior y sombra en la
	# base para que las plataformas lean como bloques con volumen.
	var top := get_node_or_null("TopHighlight") as Polygon2D
	if top == null:
		top = Polygon2D.new()
		top.name = "TopHighlight"
		add_child(top)
	var bottom := get_node_or_null("BottomShadow") as Polygon2D
	if bottom == null:
		bottom = Polygon2D.new()
		bottom.name = "BottomShadow"
		add_child(bottom)

	var half := platform_size * 0.5
	var top_height := clampf(platform_size.y * 0.22, 2.0, 5.0)
	top.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, -half.y + top_height),
		Vector2(-half.x, -half.y + top_height),
	])
	top.color = platform_color.lightened(0.22)

	var bottom_height := clampf(platform_size.y * 0.16, 2.0, 4.0)
	var base_dark := platform_color.darkened(0.45)
	bottom.polygon = PackedVector2Array([
		Vector2(-half.x, half.y - bottom_height),
		Vector2(half.x, half.y - bottom_height),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	bottom.color = Color(base_dark.r, base_dark.g, base_dark.b, 0.65)

	if collision != null:
		var shape := collision.shape as RectangleShape2D
		if shape == null:
			shape = RectangleShape2D.new()
			collision.shape = shape
		shape.size = platform_size
