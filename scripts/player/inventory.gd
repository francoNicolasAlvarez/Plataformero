class_name Inventory
extends RefCounted
## Inventario real del jugador (2026-11-12): separa objetos utilizables de
## habilidades permanentes y mantiene dos espacios rápidos (Q/E). Es la única
## fuente de verdad de las cantidades; el HUD solo lee su estado.

signal changed

enum Category { PERMANENT, USABLE }

const SLOT_COUNT := 2
const SLOT_ACTIONS := ["item_1", "item_2"]
const ITEMS := {
	"potion": {
		"name": "Poción",
		"category": Category.USABLE,
		"description": "Recupera 1 golpe de vida (máximo 2).",
	},
	"ration": {
		"name": "Ración",
		"category": Category.USABLE,
		"description": "Aumenta la velocidad durante 5 s (no altera el reloj).",
	},
	"double_jump": {
		"name": "Doble salto",
		"category": Category.PERMANENT,
		"description": "Un salto extra siempre disponible en el aire.",
	},
	"fast_fall": {
		"name": "Caída rápida",
		"category": Category.PERMANENT,
		"description": "Abajo/S acelera la caída mientras estás en el aire.",
	},
}

var _counts: Dictionary = {}
var _permanents: Dictionary = {}
var _quick_slots: Array[String] = ["", ""]


func reset_starting_items(potions: int, rations: int = 1) -> void:
	## Estado inicial de una partida: pociones, raciones y habilidades permanentes.
	_counts.clear()
	_permanents.clear()
	_quick_slots = ["", ""]
	add_item("potion", potions, false)
	add_item("ration", rations, false)
	unlock_permanent("double_jump", false)
	unlock_permanent("fast_fall", false)
	equip(0, "potion", false)
	changed.emit()


func add_item(item_id: String, amount: int = 1, notify: bool = true) -> void:
	if amount <= 0 or not ITEMS.has(item_id) or category(item_id) != Category.USABLE:
		return
	_counts[item_id] = count(item_id) + amount
	_auto_equip(item_id)
	if notify:
		changed.emit()


func consume(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	_counts[item_id] = count(item_id) - amount
	if count(item_id) <= 0:
		_counts.erase(item_id)
		for slot in SLOT_COUNT:
			if _quick_slots[slot] == item_id:
				_quick_slots[slot] = ""
	changed.emit()
	return true


func count(item_id: String) -> int:
	return int(_counts.get(item_id, 0))


func has_item(item_id: String) -> bool:
	return count(item_id) > 0


func item_name(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return item_id
	return str(ITEMS[item_id].get("name", item_id))


func item_description(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return ""
	return str(ITEMS[item_id].get("description", ""))


func category(item_id: String) -> int:
	if not ITEMS.has(item_id):
		return Category.USABLE
	return int(ITEMS[item_id].get("category", Category.USABLE))


func usable_items() -> Array[String]:
	var result: Array[String] = []
	for item_id in _counts.keys():
		if category(str(item_id)) == Category.USABLE:
			result.append(str(item_id))
	return result


func unlock_permanent(item_id: String, notify: bool = true) -> void:
	if not ITEMS.has(item_id) or category(item_id) != Category.PERMANENT:
		return
	_permanents[item_id] = true
	if notify:
		changed.emit()


func is_permanent_unlocked(item_id: String) -> bool:
	return bool(_permanents.get(item_id, false))


func permanent_items() -> Array[String]:
	var result: Array[String] = []
	for item_id in _permanents.keys():
		if is_permanent_unlocked(str(item_id)):
			result.append(str(item_id))
	return result


func equip(slot_index: int, item_id: String, notify: bool = true) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if item_id.is_empty():
		_quick_slots[slot_index] = ""
		if notify:
			changed.emit()
		return true
	if category(item_id) != Category.USABLE or not has_item(item_id):
		return false
	for other in SLOT_COUNT:
		if other != slot_index and _quick_slots[other] == item_id:
			_quick_slots[other] = ""
	_quick_slots[slot_index] = item_id
	if notify:
		changed.emit()
	return true


func slot_item(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return ""
	return _quick_slots[slot_index]


func slot_label(slot_index: int) -> String:
	var item_id := slot_item(slot_index)
	if item_id.is_empty() or not has_item(item_id):
		return "Vacío"
	return "%s x%d" % [item_name(item_id), count(item_id)]


func _auto_equip(item_id: String) -> void:
	for slot in SLOT_COUNT:
		if _quick_slots[slot] == item_id:
			return
	for slot in SLOT_COUNT:
		if _quick_slots[slot].is_empty():
			_quick_slots[slot] = item_id
			return
