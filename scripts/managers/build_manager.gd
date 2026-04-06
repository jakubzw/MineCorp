extends Node
# ──────────────────────────────────────────
#  BuildManager — Autoload
#  Zarządza trybem budowania, przechowuje
#  aktualnie wybrany budynek
# ──────────────────────────────────────────

## Emitowany gdy gracz wybiera budynek z menu
signal building_selected(data: BuildingData)
## Emitowany gdy gracz anuluje tryb budowania
signal building_cancelled
## Emitowany gdy budynek zostanie postawiony
signal building_placed(data: BuildingData, grid_pos: Vector2i)

## Aktualnie wybrany budynek (null = tryb normalny)
var current_building: BuildingData = null

## Czy jesteśmy w trybie budowania
var is_building: bool = false


func select_building(data: BuildingData) -> void:
	current_building = data
	is_building = true
	emit_signal("building_selected", data)


func cancel_building() -> void:
	current_building = null
	is_building = false
	emit_signal("building_cancelled")


func confirm_placement(grid_pos: Vector2i) -> void:
	if current_building == null:
		return
	emit_signal("building_placed", current_building, grid_pos)
	# Po postawieniu zostajemy w trybie budowania (jak w Anno/Factorio)
	# Jeśli chcesz wyjść po jednym postawieniu, odkomentuj poniższe:
	# cancel_building()
