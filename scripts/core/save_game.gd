class_name SaveGame
extends RefCounted
## Partida guardada del modo plataformas (2026-11-12): recuerda el último
## nivel alcanzado para continuar y acumula estadísticas de la expedición
## (tiempo total y muertes) que se muestran en la pantalla final.
##
## Sustituye a GameProgress tras abandonar el diseño roguelite. En modo
## headless no lee ni escribe el archivo para no interferir con las pruebas:
## las variables estáticas conservan los valores por defecto.

const SAVE_PATH := "user://save.cfg"
const FIRST_LEVEL := 1
const LAST_LEVEL := 6

static var level: int = FIRST_LEVEL
static var total_time: float = 0.0
static var deaths: int = 0
static var completed: bool = false
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if _is_headless():
		return

	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	level = clampi(
		int(config.get_value("run", "level", FIRST_LEVEL)),
		FIRST_LEVEL,
		LAST_LEVEL
	)
	total_time = maxf(0.0, float(config.get_value("run", "total_time", 0.0)))
	deaths = maxi(0, int(config.get_value("run", "deaths", 0)))
	completed = bool(config.get_value("run", "completed", false))


static func save() -> void:
	if _is_headless():
		return
	var config := ConfigFile.new()
	config.set_value("run", "level", level)
	config.set_value("run", "total_time", total_time)
	config.set_value("run", "deaths", deaths)
	config.set_value("run", "completed", completed)
	config.save(SAVE_PATH)


static func set_level(next_level: int) -> void:
	ensure_loaded()
	level = clampi(next_level, FIRST_LEVEL, LAST_LEVEL)
	save()


static func start_at_level(next_level: int) -> void:
	## Selección de nivel desde el menú: empieza una expedición limpia en ese
	## nivel sin conservar tiempo, muertes ni el estado de juego completado.
	ensure_loaded()
	level = clampi(next_level, FIRST_LEVEL, LAST_LEVEL)
	total_time = 0.0
	deaths = 0
	completed = false
	save()


static func add_time(seconds: float) -> void:
	if seconds > 0.0:
		total_time += seconds


static func register_death() -> void:
	ensure_loaded()
	deaths += 1
	save()


static func finish_game() -> void:
	## El juego se completó: la partida queda cerrada y el menú ofrecerá una
	## nueva expedición al pulsar Jugar.
	ensure_loaded()
	completed = true
	level = FIRST_LEVEL
	save()


static func begin_new_run() -> void:
	ensure_loaded()
	level = FIRST_LEVEL
	total_time = 0.0
	deaths = 0
	completed = false
	save()


static func format_time(seconds: float) -> String:
	var whole := int(round(maxf(0.0, seconds)))
	return "%02d:%02d" % [whole / 60, whole % 60]


static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
