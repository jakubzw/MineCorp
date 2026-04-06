extends Node3D
class_name PlacementController
# ──────────────────────────────────────────
#  PlacementController
#  Obsługuje:
#  - Raycast kursora na płaszczyznę terenu
#  - Ghost preview wybranego budynku
#  - Potwierdzenie / anulowanie stawiania
#  - Przełączanie trybu siatki (klawisz Tab + opcjonalnie przez HUD)
# ──────────────────────────────────────────

## Referencja do GridSystem w scenie
@export var grid_system_path: NodePath
## Referencja do GridRenderer w scenie
@export var grid_renderer_path: NodePath
## Warstwa kolizji terenu (Layer number, nie bitmask)
@export var terrain_collision_layer: int = 1
## Kolor ghosta gdy pozycja jest wolna
@export var ghost_color_valid: Color = Color(0.2, 1.0, 0.4, 0.5)
## Kolor ghosta gdy pozycja jest zajęta (na przyszłość)
@export var ghost_color_invalid: Color = Color(1.0, 0.2, 0.2, 0.5)

var _grid_sys: GridSystem
var _grid_renderer: GridRenderer
var _ghost_instance: Node3D = null
var _ghost_material: StandardMaterial3D
var _current_world_pos: Vector3 = Vector3.ZERO
var _is_placement_valid: bool = true


func _ready() -> void:
	_grid_sys = get_node(grid_system_path) as GridSystem
	_grid_renderer = get_node(grid_renderer_path) as GridRenderer

	# Materiał ghosta
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = ghost_color_valid
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Podłącz sygnały BuildManagera
	BuildManager.building_selected.connect(_on_building_selected)
	BuildManager.building_cancelled.connect(_on_building_cancelled)


func _unhandled_input(event: InputEvent) -> void:
	# Przełączanie trybu siatki — klawisz Tab
	if event.is_action_pressed("grid_cycle"):
		_grid_sys.cycle_mode()

	# Anulowanie — Escape
	if event.is_action_pressed("cancel_action"):
		BuildManager.cancel_building()

	# Potwierdzenie — LPM
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if BuildManager.is_building and _is_placement_valid:
				_place_building()


func _process(_delta: float) -> void:
	if not BuildManager.is_building:
		return

	# Raycast na teren
	var world_pos := _raycast_terrain()
	if world_pos == Vector3.INF:
		return

	# Snap
	var snapped_pos := _grid_sys.snap_position(world_pos)
	_current_world_pos = snapped_pos

	# Aktualizuj ghost
	if _ghost_instance != null:
		_ghost_instance.global_position = snapped_pos

	# Aktualizuj renderer siatki
	_grid_renderer.update_cursor(world_pos)


# ──────────────────────────────────────────
#  Raycast na płaszczyznę terenu
# ──────────────────────────────────────────
func _raycast_terrain() -> Vector3:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return Vector3.INF

	var mouse_pos := viewport.get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	# Intersect z płaszczyzną Y=0 (teren)
	if abs(ray_dir.y) < 0.001:
		return Vector3.INF

	var t: float = -ray_origin.y / ray_dir.y
	if t < 0:
		return Vector3.INF

	return ray_origin + ray_dir * t


# ──────────────────────────────────────────
#  Ghost preview
# ──────────────────────────────────────────
func _spawn_ghost(data: BuildingData) -> void:
	_destroy_ghost()

	if data.scene == null:
		return

	_ghost_instance = data.scene.instantiate() as Node3D
	if _ghost_instance == null:
		return

	# Ustaw metadane rozmiaru dla snapa
	_ghost_instance.set_meta("grid_size",
		Vector2(data.grid_size.x * _grid_sys.cell_size,
				data.grid_size.y * _grid_sys.cell_size))

	# Nałóż materiał ghosta na wszystkie MeshInstance3D w scenie
	_apply_ghost_material(_ghost_instance)

	add_child(_ghost_instance)


func _apply_ghost_material(node: Node3D) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for i: int in mesh_inst.get_surface_override_material_count():
			mesh_inst.set_surface_override_material(i, _ghost_material)
	for child in node.get_children():
		if child is Node3D:
			_apply_ghost_material(child as Node3D)


func _destroy_ghost() -> void:
	if _ghost_instance != null:
		_ghost_instance.queue_free()
		_ghost_instance = null


# ──────────────────────────────────────────
#  Stawianie budynku
# ──────────────────────────────────────────
func _place_building() -> void:
	var data: BuildingData = BuildManager.current_building
	if data == null or data.scene == null:
		return

	# Utwórz właściwą instancję budynku
	var instance := data.scene.instantiate() as Node3D
	instance.global_position = _current_world_pos
	instance.set_meta("grid_size",
		Vector2(data.grid_size.x * _grid_sys.cell_size,
				data.grid_size.y * _grid_sys.cell_size))

	# Dodaj do sceny świata (rodzic PlacementControllera)
	get_parent().add_child(instance)

	# Zarejestruj w GridSystem dla lokalnego snapa
	_grid_sys.register_object(instance)

	# Poinformuj BuildManager
	# Konwertuj pozycję na współrzędne siatki (opcjonalne)
	var grid_pos := Vector2i(
		int(round(_current_world_pos.x / _grid_sys.cell_size)),
		int(round(_current_world_pos.z / _grid_sys.cell_size))
	)
	BuildManager.confirm_placement(grid_pos)


# ──────────────────────────────────────────
#  Callbacki BuildManager
# ──────────────────────────────────────────
func _on_building_selected(data: BuildingData) -> void:
	_spawn_ghost(data)


func _on_building_cancelled() -> void:
	_destroy_ghost()
	_grid_renderer.update_cursor(Vector3.ZERO)
