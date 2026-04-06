extends Node3D
class_name PlacedObject
# ──────────────────────────────────────────
#  PlacedObject — klasa bazowa dla wszystkich
#  obiektów postawionych na mapie
#  Rejestruje się w GridSystem automatycznie
# ──────────────────────────────────────────

## Dane budynku przypisane przy tworzeniu
var building_data: BuildingData = null

## Rozmiar fizyczny obiektu w jednostkach świata
## (ustawiany automatycznie lub ręcznie w Inspektorze)
@export var object_size: Vector3 = Vector3(2.0, 2.0, 2.0)


func _ready() -> void:
	var gs := get_node_or_null("/root/GridSystem")
	if gs != null:
		gs.register_object(self)


func _exit_tree() -> void:
	var gs := get_node_or_null("/root/GridSystem")
	if gs != null:
		gs.unregister_object(self)


## Zwraca punkty snapowania: narożniki + środki krawędzi bounding boxa
func get_snap_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var half: Vector3 = object_size * 0.5
	var pos: Vector3 = global_position

	# 4 narożniki (na płaszczyźnie Y)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			points.append(pos + global_transform.basis * Vector3(half.x * sx, 0, half.z * sz))

	# 4 środki krawędzi
	points.append(pos + global_transform.basis * Vector3(half.x,  0, 0))
	points.append(pos + global_transform.basis * Vector3(-half.x, 0, 0))
	points.append(pos + global_transform.basis * Vector3(0, 0,  half.z))
	points.append(pos + global_transform.basis * Vector3(0, 0, -half.z))

	return points
