class_name FallingRock
extends Area2D
## Roca que cae (2026-11-17). Primero muestra durante `WARNING_TIME` (1,5 s)
## un marcador rojo parpadeante sobre la superficie donde va a impactar; al
## terminar el aviso la roca aparece sobre el borde superior de la pantalla y
## cae muy rápido. Daña al jugador (un golpe) y se rompe contra el primer
## suelo o plataforma. Se construye entera por código, sin escena propia.

const WARNING_TIME := 1.5
const FALL_SPEED := 1500.0
const OVERSHOOT := 260.0

enum State { WARNING, FALLING, DONE }

@export var damage: int = 15

var target_y: float = 0.0
var start_y: float = 0.0
var state: State = State.WARNING

var _time: float = 0.0
var _marker: Node2D
var _rock: Node2D


func _ready() -> void:
	add_to_group("falling_rocks")
	collision_layer = 0
	collision_mask = 3
	set_deferred("monitoring", false)
	body_entered.connect(_on_body_entered)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)

	_rock = _build_rock()
	_rock.visible = false
	add_child(_rock)

	_marker = _build_marker()
	_marker.top_level = true
	add_child(_marker)
	_marker.global_position = Vector2(global_position.x, target_y)
	global_position.y = start_y


static func clear_rocks(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("falling_rocks"):
		node.queue_free()


func warning_left() -> float:
	return maxf(0.0, WARNING_TIME - _time) if state == State.WARNING else 0.0


func _physics_process(delta: float) -> void:
	match state:
		State.WARNING:
			_time += delta
			_update_marker()
			if _time >= WARNING_TIME:
				_start_falling()
		State.FALLING:
			global_position.y += FALL_SPEED * delta
			if global_position.y >= target_y + OVERSHOOT:
				_impact()


func _start_falling() -> void:
	state = State.FALLING
	_rock.visible = true
	monitoring = true
	_marker.modulate.a = 1.0


func _update_marker() -> void:
	# El parpadeo se acelera al acercarse el impacto.
	var progress := clampf(_time / WARNING_TIME, 0.0, 1.0)
	var blink := 0.5 + 0.5 * sin(_time * (8.0 + 22.0 * progress))
	_marker.modulate.a = 0.45 + 0.55 * blink
	_marker.scale = Vector2.ONE * (0.8 + 0.3 * progress)


func _on_body_entered(body: Node2D) -> void:
	if state != State.FALLING:
		return
	if body is Player:
		(body as Player).take_damage(damage, self)
	_impact()


func _impact() -> void:
	if state == State.DONE:
		return
	state = State.DONE
	set_deferred("monitoring", false)
	var parent := get_parent()
	if parent is Node2D:
		Fx.make_burst(parent, Vector2(global_position.x, minf(global_position.y, target_y)), Color(0.75, 0.62, 0.45, 0.9))
	Sfx.play("bomb", -16.0)
	queue_free()


func _build_marker() -> Node2D:
	var marker := Node2D.new()
	marker.name = "RockWarning"
	marker.z_index = 6
	marker.add_to_group("rock_warnings")
	var red := Color(1.0, 0.25, 0.2, 0.9)
	var ground := Polygon2D.new()
	var ring := PackedVector2Array()
	for step in 20:
		var angle := TAU * float(step) / 20.0
		ring.append(Vector2(cos(angle) * 36.0, sin(angle) * 7.0 - 2.0))
	ground.polygon = ring
	ground.color = Color(red.r, red.g, red.b, 0.55)
	marker.add_child(ground)
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-14, -50), Vector2(14, -50), Vector2(0, -22)])
	arrow.color = red
	marker.add_child(arrow)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(-14, -50), Vector2(14, -50), Vector2(0, -22)])
	outline.closed = true
	outline.width = 2.5
	outline.default_color = Color.BLACK
	marker.add_child(outline)
	return marker


func _build_rock() -> Node2D:
	var rock := Node2D.new()
	rock.name = "Rock"
	var points := PackedVector2Array()
	var radii := [22.0, 18.0, 23.0, 19.0, 22.0, 17.0, 23.0, 20.0]
	for index in radii.size():
		var angle := TAU * float(index) / float(radii.size())
		points.append(Vector2(cos(angle), sin(angle)) * float(radii[index]))
	var body := Polygon2D.new()
	body.polygon = points
	body.color = Color("#7d6d5c")
	rock.add_child(body)
	var shade := Polygon2D.new()
	shade.polygon = PackedVector2Array([Vector2(-6, -4), Vector2(14, -10), Vector2(20, 6), Vector2(2, 18), Vector2(-10, 10)])
	shade.color = Color("#5c4f42")
	rock.add_child(shade)
	var outline := Line2D.new()
	outline.points = points
	outline.closed = true
	outline.width = 3.0
	outline.default_color = Color.BLACK
	rock.add_child(outline)
	return rock
