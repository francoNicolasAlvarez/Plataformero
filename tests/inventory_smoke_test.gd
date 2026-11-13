extends SceneTree
## Comprueba el inventario real: categorías (utilizables/permanentes),
## espacios rápidos Q/E y el uso de pociones. Ejecutar con:
## godot --headless --path . --script res://tests/inventory_smoke_test.gd

const LEVEL_SCENE := preload("res://scenes/levels/test_level.tscn")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)

	var player: Player = level.get_node("Player")
	var item_slots: Label = level.get_node("HUD/ItemSlots")
	var jump_marker: Label = level.get_node_or_null("HUD/Resources")
	var potion_info: Label = level.get_node("HUD/InventoryPanel/PanelMargin/VBox/PotionInfo")
	var permanent_info: Label = level.get_node("HUD/InventoryPanel/PanelMargin/VBox/JumpsInfo")
	var quick_info: Label = level.get_node("HUD/InventoryPanel/PanelMargin/VBox/MetaInfo")
	var inventory_panel: PanelContainer = level.get_node("HUD/InventoryPanel")
	var inventory := player.inventory

	await _wait_physics(20)

	_check(player.potions == 2, "El jugador empieza con 2 pociones")
	_check(inventory.count("potion") == 2, "El inventario es la fuente de las pociones")
	_check(inventory.count("ration") == 1, "El jugador empieza con una ración")
	_check(inventory.category("ration") == Inventory.Category.USABLE, "La ración es un objeto utilizable")
	_check(inventory.category("potion") == Inventory.Category.USABLE, "La poción es un objeto utilizable")
	_check(
		inventory.category("double_jump") == Inventory.Category.PERMANENT,
		"El doble salto es una habilidad permanente"
	)
	_check(inventory.is_permanent_unlocked("double_jump"), "El doble salto está desbloqueado")
	_check(inventory.is_permanent_unlocked("fast_fall"), "La caída rápida está desbloqueada")
	_check(inventory.usable_items().size() == 2, "Hay dos objetos utilizables: poción y ración")
	_check(inventory.permanent_items().size() == 2, "Hay dos habilidades permanentes")
	_check(inventory.slot_item(0) == "potion", "La poción ocupa el espacio rápido Q")
	_check(inventory.slot_item(1) == "ration", "La ración ocupa el espacio rápido E")
	_check(not "bombs" in player, "El jugador ya no tiene bombas")
	_check(jump_marker == null, "El HUD ya no muestra cargas de salto")
	_check(not "double_jumps" in player, "El jugador no acumula cargas de salto")

	_check(item_slots.text.contains("Q") and item_slots.text.contains("Poción x2"),
		"El HUD muestra la poción equipada en Q")
	_check(item_slots.text.contains("E") and item_slots.text.contains("Ración x1"),
		"El HUD muestra la ración equipada en E")
	_check(potion_info.text.contains("UTILIZABLES") and potion_info.text.contains("Poción")
			and potion_info.text.contains("Ración"),
		"El panel separa los objetos utilizables")
	_check(
		permanent_info.text.contains("PERMANENTES")
			and permanent_info.text.contains("Doble salto")
			and permanent_info.text.contains("Caída rápida"),
		"El panel separa las habilidades permanentes"
	)
	_check(
		quick_info.text.contains("Q") and quick_info.text.contains("E"),
		"El panel muestra los dos espacios rápidos"
	)

	var toggle := InputEventAction.new()
	toggle.action = &"inventory"
	toggle.pressed = true
	level._unhandled_input(toggle)
	_check(inventory_panel.visible, "Tab abre el panel de inventario")
	level._unhandled_input(toggle)
	_check(not inventory_panel.visible, "Tab vuelve a cerrar el inventario")

	level._time_left = 50.0
	_check(player.use_quick_slot(1), "E usa la ración equipada")
	_check(level._time_left >= 54.0 and level._time_left <= 55.5, "La ración añade 5 segundos al nivel")
	_check(inventory.count("ration") == 0, "La ración se consume al usarla")
	_check(inventory.slot_item(1).is_empty(), "El espacio E queda vacío tras la ración")

	player.take_damage(20)
	await _wait_physics(2)
	_check(player.health.current_health == 1, "El primer golpe deja un único punto de vida")
	_check(player.use_quick_slot(0), "Q usa la poción equipada")
	_check(player.health.current_health == 2, "La poción recupera el golpe perdido")
	_check(player.potions == 1, "La poción consume una carga")
	_check(not player.use_quick_slot(0), "No se puede usar una poción con los 2 golpes llenos")
	_check(not player.use_quick_slot(1), "El espacio rápido vacío no hace nada")

	await _wait_physics(36)
	player.take_damage(20)
	await _wait_physics(2)
	_check(player.use_potion(), "Se puede usar la segunda poción")
	_check(player.health.current_health == 2, "La curación respeta el máximo de 2 golpes")
	_check(player.potions == 0, "La segunda poción agota la reserva")
	_check(inventory.slot_item(0).is_empty(), "Al agotarse la poción, el espacio rápido queda vacío")
	_check(item_slots.text.contains("Vacío"), "El HUD refleja el espacio rápido vacío")

	inventory.add_item("potion", 1)
	_check(inventory.slot_item(0) == "potion", "Añadir una poción la equipa en el primer espacio libre")
	_check(item_slots.text.contains("Poción x1"), "El HUD actualiza la nueva poción")

	_check(inventory.equip(1, "potion"), "La poción se puede equipar en el espacio E")
	_check(inventory.slot_item(0).is_empty(), "Equipar en E libera el duplicado de Q")
	_check(inventory.slot_item(1) == "potion", "El espacio E queda equipado")
	_check(
		item_slots.text.contains("Q  Vacío") and item_slots.text.contains("E  Poción x1"),
		"El HUD refleja el intercambio entre espacios rápidos"
	)

	print("")
	print("Comprobaciones: %d | Fallos: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _wait_physics(frames: int) -> void:
	for _frame in frames:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[OK]    ", message)
	else:
		_failures += 1
		print("[FALLO] ", message)
