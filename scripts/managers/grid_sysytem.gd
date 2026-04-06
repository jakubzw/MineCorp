extends Node
# ──────────────────────────────────────────
#  GridSystem — logika siatek
#
#  Dwie siatki obrócone o 45° względem siebie:
#    Siatka A: obrót   0° (wyrównana ze światem)
#    Siatka B: obrót  45° (diament)
#  Tryb swobodny: brak snapa do siatki globalnej,
#                 snap tylko do pobliskich obiektów
# ──────────────────────────────────────────

## Emitowany przy zmianie trybu siatki
signal grid_mode_changed(mode: GridMode)

enum GridMode { FREE, GRID_A, GRID_B }

## Rozmiar jednego oczka siatki (jednostki Godota)
@export var cell_size: float = 2.0
## Promień wykrywania pobliskich obiektów do lokalnego snapa
@export var local_snap_radius: float = 6.0
## Próg odległości snapa do narożnika/krawędzi obiektu
@export var snap_threshold: float = 1.5

## Aktualny tryb siatki
var mode: GridMode = GridMode.GRID_A :
	set(value):
		mode = value
		emit_signal("grid_mode_changed", mode)

# Kąty obrotu siatek w radianach
const _ANGLE_A: float = 0.0
const _ANGLE_B: float = PI / 4.0  # 45°

# Referencja do obiektów na scenie (wypełniana przez PlacementController)
var _placed_objects: Array[Node3D] = []


# ──────────────────────────────────────────
#  Publiczne API
# ──────────────────────────────────────────

## Snapuje pozycję world_pos do aktywnej siatki lub pobliskiego obiektu
func snap_position(world_pos: Vector3) -> Vector3:
	# Najpierw sprawdź snap do pobliskich obiektów (priorytet)
	var object_snap := _try_snap_to_objects(world_pos)
	if object_snap != Vector3.INF:
		return object_snap

	# Potem snap do aktywnej siatki
	match mode:
		GridMode.GRID_A:
			return _snap_to_grid(world_pos, _ANGLE_A)
		GridMode.GRID_B:
			return _snap_to_grid(world_pos, _ANGLE_B)
		GridMode.FREE:
			return world_pos

	return world_pos


## Przełącza tryb siatki cyklicznie: A → B → FREE → A
func cycle_mode() -> void:
	match mode:
		GridMode.GRID_A:  mode = GridMode.GRID_B
		GridMode.GRID_B:  mode = GridMode.FREE
		GridMode.FREE:    mode = GridMode.GRID_A


## Ustawia konkretny tryb
func set_mode(new_mode: GridMode) -> void:
	mode = new_mode


## Rejestruje postawiony obiekt (dla lokalnego snapa)
func register_object(obj: Node3D) -> void:
	if not _placed_objects.has(obj):
		_placed_objects.append(obj)


## Wyrejestrowuje obiekt (np. po usunięciu)
func unregister_object(obj: Node3D) -> void:
	_placed_objects.erase(obj)


## Zwraca punkty snapa pobliskich obiektów
## Używane przez GridRenderer do rysowania lokalnej siatki
func get_local_snap_points(world_pos: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for obj in _placed_objects:
		if obj == null:
			continue
		var dist: float = world_pos.distance_to(obj.global_position)
		if dist > local_snap_radius:
			continue
		points.append_array(_get_object_snap_points(obj))
	return points


## Zwraca obiekty w podanym promieniu od world_pos
func get_nearby_objects(world_pos: Vector3, radius: float) -> Array:
	var result: Array = []
	for obj in _placed_objects:
		if obj == null:
			continue
		if world_pos.distance_to(obj.global_position) <= radius:
			result.append(obj)
	return result


## Zwraca aktualny kąt aktywnej siatki (w radianach)
func get_active_angle() -> float:
	match mode:
		GridMode.GRID_A: return _ANGLE_A
		GridMode.GRID_B: return _ANGLE_B
		_: return _ANGLE_A


# ──────────────────────────────────────────
#  Snap do siatki
# ──────────────────────────────────────────
func _snap_to_grid(world_pos: Vector3, angle: float) -> Vector3:
	var cos_a: float = cos(-angle)
	var sin_a: float = sin(-angle)
	var local_x: float = world_pos.x * cos_a - world_pos.z * sin_a
	var local_z: float = world_pos.x * sin_a + world_pos.z * cos_a

	local_x = round(local_x / cell_size) * cell_size
	local_z = round(local_z / cell_size) * cell_size

	cos_a = cos(angle)
	sin_a = sin(angle)
	var world_x: float = local_x * cos_a - local_z * sin_a
	var world_z: float = local_x * sin_a + local_z * cos_a

	return Vector3(world_x, world_pos.y, world_z)


# ──────────────────────────────────────────
#  Snap do pobliskich obiektów
# ──────────────────────────────────────────
func _try_snap_to_objects(world_pos: Vector3) -> Vector3:
	var best_dist: float = snap_threshold
	var best_point: Vector3 = Vector3.INF

	for obj in _placed_objects:
		if obj == null:
			continue
		if world_pos.distance_to(obj.global_position) > local_snap_radius:
			continue

		var snap_points := _get_object_snap_points(obj)
		for pt: Vector3 in snap_points:
			var dist: float = Vector2(world_pos.x - pt.x, world_pos.z - pt.z).length()
			if dist < best_dist:
				best_dist = dist
				best_point = pt

	return best_point


func _get_object_snap_points(obj: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var pos: Vector3 = obj.global_position
	var angle: float = obj.rotation.y
	var size: Vector2 = obj.get_meta("grid_size", Vector2(cell_size, cell_size))
	var half_x: float = size.x / 2.0
	var half_z: float = size.y / 2.0

	var offsets: Array[Vector2] = [
		# Narożniki
		Vector2(-half_x, -half_z), Vector2(half_x, -half_z),
		Vector2(half_x,   half_z), Vector2(-half_x,  half_z),
		# Środki krawędzi
		Vector2(0, -half_z), Vector2(half_x, 0),
		Vector2(0,  half_z), Vector2(-half_x, 0),
	]

	for local_pt: Vector2 in offsets:
		var rotated := local_pt.rotated(angle)
		points.append(pos + Vector3(rotated.x, 0, rotated.y))

	return points
