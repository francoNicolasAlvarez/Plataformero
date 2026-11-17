class_name WorldConfig
extends Resource
## Configuración de uno de los ocho mundos de la expedición (2026-11-17).
## Cada mundo agrupa cinco niveles y se usa en los selectores de la fase 3.

@export var number: int = 0
@export var display_name: String = ""
@export var accent: Color = Color.WHITE
@export var levels: Array[LevelConfig] = []


func level(index_in_world: int) -> LevelConfig:
	if index_in_world < 1 or index_in_world > levels.size():
		return null
	return levels[index_in_world - 1]


func implemented_count() -> int:
	var count := 0
	for config in levels:
		if config != null and config.is_implemented():
			count += 1
	return count
