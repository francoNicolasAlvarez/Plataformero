class_name LevelSixLayout
extends RefCounted
## Nivel 6 (2026-11-13): "FORTALEZA". Plataformas separadas por saltos largos
## que obligan a usar el doble salto. Los bordes de las plataformas tienen
## pinchos (el centro queda libre) y algunas plataformas estáticas llevan
## sierras patrullando. También hay plataformas giratorias del asset modular.

const PLATFORM_SCENE := preload("res://scenes/world/platform.tscn")
const SAW_SCENE := preload("res://scenes/world/saw_trap.tscn")
const FALL_ZONE_SCENE := preload("res://scenes/world/fall_zone.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/world/checkpoint.tscn")
const HERB_SCENE := preload("res://scenes/pickups/healing_herb.tscn")
const SUN_SCENE := preload("res://scenes/decor/sun.tscn")

const LEVEL_WIDTH := 13600.0
const GROUND_Y := 680.0
const GROUND_TOP := 640.0
const START_CENTER := 600.0
const END_CENTER := 12630.0
const PLAYER_START := Vector2(70.0, 600.0)
const ROUTE_START_X := 1500.0
const ROUTE_STEP := 740.0
const ROUTE_COUNT := 14
const PLATFORM_SIZE := Vector2(260.0, 24.0)
const ROUTE_Y := [550.0, 450.0]
const CHECKPOINT_INDEX := 6
const SAW_INDICES := [1, 5, 11]
const HERB_INDICES := [5, 13]


static func build(level: Node2D) -> void:
	var world := Node2D.new()
	world.name = "LevelSixGenerated"
	level.add_child(world)

	_build_sky(world)
	_build_terrain(world)
	_place_player(level)
	_build_route(world)
	_build_finish(level)


static func _place_player(level: Node2D) -> void:
	var player := level.get_node_or_null("Player") as Player
	if player != null:
		player.global_position = PLAYER_START


static func _build_sky(world: Node2D) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color("#2b1024"),
		Color("#4a1828"),
		Color("#160d1d"),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 16
	texture.height = 256
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)

	var sky := TextureRect.new()
	sky.texture = texture
	sky.size = Vector2(LEVEL_WIDTH, 720.0)
	sky.z_index = -30
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	world.add_child(sky)

	var moon := _spawn(SUN_SCENE, world, Vector2.ZERO)
	moon.set("screen_offset", Vector2(-360.0, -170.0))
	moon.modulate = Color(1.0, 0.55, 0.5, 0.9)
	moon.scale = Vector2.ONE * 0.75

	var hill_parallax := Parallax2D.new()
	hill_parallax.name = "HillParallax"
	hill_parallax.scroll_scale = Vector2(0.3, 1.0)
	world.add_child(hill_parallax)
	for i in 9:
		var hill := Polygon2D.new()
		hill.color = [Color("#321528"), Color("#431a2c"), Color("#241326")][i % 3]
		hill.position = Vector2(320.0 + float(i) * 760.0, 650.0)
		hill.polygon = PackedVector2Array([
			Vector2(-540, 0),
			Vector2(-120, -230),
			Vector2(240, 0),
		])
		hill.z_index = -22
		hill_parallax.add_child(hill)

	# Torres y columnas decorativas del fuerte.
	for i in 7:
		var tower := Polygon2D.new()
		tower.color = Color("#1d1424", 0.9)
		tower.position = Vector2(700.0 + float(i) * 1800.0, 640.0)
		tower.polygon = PackedVector2Array([
			Vector2(-44, 0), Vector2(-36, -250), Vector2(-20, -270),
			Vector2(-12, -250), Vector2(12, -250), Vector2(20, -270),
			Vector2(36, -250), Vector2(44, 0),
		])
		tower.z_index = -15
		world.add_child(tower)


static func _build_terrain(world: Node2D) -> void:
	_add_platform(
		world,
		Vector2(START_CENTER, GROUND_Y),
		Vector2(1200.0, 80.0),
		Color("#4a2a36")
	)
	_add_platform(
		world,
		Vector2(END_CENTER, GROUND_Y),
		Vector2(1800.0, 80.0),
		Color("#4a2a36")
	)
	var fall_zone := _spawn(FALL_ZONE_SCENE, world, Vector2(6800.0, 780.0))
	fall_zone.name = "FallZoneFortress"


static func _build_route(world: Node2D) -> void:
	var checkpoint_position := Vector2.ZERO
	for index in ROUTE_COUNT:
		var x := ROUTE_START_X + float(index) * ROUTE_STEP
		var y: float = ROUTE_Y[index % ROUTE_Y.size()]
		var platform := _add_platform(
			world,
			Vector2(x, y),
			PLATFORM_SIZE,
			[Color("#56323e"), Color("#6b3c46"), Color("#40262f")][index % 3]
		)
		platform.kind = _kind_for(index)
		if platform.kind == Platform.Kind.SPIKED:
			platform.spike_damage = 15
		elif platform.kind == Platform.Kind.ROTATING:
			platform.rotation_speed = 0.9

		if index == CHECKPOINT_INDEX:
			platform.kind = Platform.Kind.STATIC
			checkpoint_position = platform.position + Vector2(0.0, -60.0)
		if index in SAW_INDICES:
			platform.kind = Platform.Kind.STATIC
			var saw := _spawn(SAW_SCENE, world, platform.position + Vector2(0.0, -39.0))
			saw.set("move_range", 70.0)
			saw.set("move_speed", 1.8)
			saw.set("warmup_time", 0.6)
		if index in HERB_INDICES:
			_spawn(HERB_SCENE, world, platform.position + Vector2(0.0, -34.0))

	if checkpoint_position != Vector2.ZERO:
		_spawn(CHECKPOINT_SCENE, world, checkpoint_position)


static func _kind_for(index: int) -> Platform.Kind:
	return [
		Platform.Kind.SPIKED,
		Platform.Kind.STATIC,
		Platform.Kind.SPIKED,
		Platform.Kind.ROTATING,
		Platform.Kind.SPIKED,
		Platform.Kind.STATIC,
	][index % 6]


static func _build_finish(level: Node2D) -> void:
	var portal := level.get_node_or_null("ExitPortal")
	if portal != null:
		portal.position = Vector2(13200.0, 580.0)

	var camera := level.get_node_or_null("Camera") as Camera2D
	if camera != null:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(LEVEL_WIDTH)
		camera.limit_bottom = 720
		camera.snap_to_target()


static func _add_platform(world: Node2D, center: Vector2, size: Vector2, color: Color) -> Platform:
	var platform: Platform = PLATFORM_SCENE.instantiate()
	platform.platform_size = size
	platform.platform_color = color
	platform.position = center
	world.add_child(platform)
	return platform


static func _spawn(scene: PackedScene, parent: Node, position: Vector2) -> Node2D:
	var node := scene.instantiate() as Node2D
	node.position = position
	parent.add_child(node)
	return node
