extends Node3D
# ──────────────────────────────────────────
#  GridCursor — ghost podgląd + lokalna siatka
#
#  Scena:
#  GridCursor (Node3D) ← ten skrypt
#  ├── GhostRoot (Node3D)
#  └── LocalGridMesh (MeshInstance3D)
# ──────────────────────────────────────────

@export var local_grid_radius: float = 8.0
@export var color_local_grid: Color = Color(0.4, 1.0, 0.6, 0.5)
@export var color_object_grid: Color = Color(1.0, 0.6, 0.2, 0.6)
@export var color_ghost_valid: Color = Color(0.3, 1.0, 0.4, 0.5)
@export var color_ghost_invalid: Color = Color(1.0, 0.2, 0.2, 0.5)

@onready var _ghost_root: Node3D = $GhostRoot
@onready var _local_grid_mesh: MeshInstance3D = $LocalGridMesh

var _gs: Node  # referencja do Autoloada GridSystem
var _ghost_instance: Node3D = null
var _current_data: BuildingData = null
var _cursor_world_pos: Vector3 = Vector3.ZERO
var _snapped_pos: Vector3 = Vector3.ZERO
var _local_immediate: ImmediateMesh
var _local_material: StandardMaterial3D
var _ground_plane: Plane = Plane(Vector3.UP, 0.0)

func _ready() -> void:
	_setup_local_grid_mesh()
	visible = false
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	_gs = get_node_or_null("/root/GridSystem")
	if _gs == null:
		push_error("GridCursor: nie znaleziono Autoloada GridSystem")
		return
	BuildManager.building_selected.connect(_on_building_selected)
	BuildManager.building_cancelled.connect(_on_building_cancelled)
	_gs.grid_mode_changed.connect(_on_mode_changed)


func _process(_delta: float) -> void:
	if _gs == null or not BuildManager.is_building:
		return
	_update_cursor_position()
	_update_ghost()
	_update_local_grid()


func _unhandled_input(event: InputEvent) -> void:
	if not BuildManager.is_building:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_place()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			BuildManager.cancel_building()

	if event.is_action_pressed("cancel_action"):
		BuildManager.cancel_building()

	if event.is_action_pressed("grid_cycle"):
		_gs.cycle_mode()


# ──────────────────────────────────────────
#  Pozycja kursora (raycast na Y=0)
# ──────────────────────────────────────────
func _update_cursor_position() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)
	var intersection = _ground_plane.intersects_ray(ray_origin, ray_dir)
	if intersection:
		_cursor_world_pos = intersection
		_snapped_pos = _gs.snap_position(_cursor_world_pos)


# ──────────────────────────────────────────
#  Ghost obiektu
# ──────────────────────────────────────────
func _update_ghost() -> void:
	if _ghost_instance == null:
		return
	_ghost_instance.global_position = _snapped_pos


func _spawn_ghost(data: BuildingData) -> void:
	_clear_ghost()
	if data.scene == null:
		return
	_ghost_instance = data.scene.instantiate()
	_ghost_root.add_child(_ghost_instance)
	_set_ghost_material(_ghost_instance, color_ghost_valid)


func _clear_ghost() -> void:
	for child in _ghost_root.get_children():
		child.queue_free()
	_ghost_instance = null


func _set_ghost_material(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = mat
	for child in node.get_children():
		_set_ghost_material(child, color)


# ──────────────────────────────────────────
#  Lokalna siatka
# ──────────────────────────────────────────
func _setup_local_grid_mesh() -> void:
	_local_immediate = ImmediateMesh.new()
	_local_material = StandardMaterial3D.new()
	_local_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_local_material.vertex_color_use_as_albedo = true
	_local_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_local_grid_mesh.mesh = _local_immediate
	_local_grid_mesh.material_override = _local_material


func _update_local_grid() -> void:
	_local_immediate.clear_surfaces()

	var current_mode: int = _gs.mode
	if current_mode == 0:  # FREE — tylko siatki przy obiektach
		_draw_nearby_object_grids()
		return

	# Lokalna siatka wokół kursora
	var rot: float = _gs.get_active_angle()
	_draw_local_grid_at(_cursor_world_pos, rot, color_local_grid, local_grid_radius)
	_draw_nearby_object_grids()


func _draw_nearby_object_grids() -> void:
	var nearby: Array = _gs.get_nearby_objects(_cursor_world_pos, local_grid_radius * 2.0)
	for obj in nearby:
		if obj is Node3D:
			var obj_rot: float = obj.rotation.y
			var obj_size: float = 2.0
			if obj.get("object_size") != null:
				obj_size = obj.object_size.x
			_draw_local_grid_at(obj.global_position, obj_rot, color_object_grid, obj_size * 2.0)


func _draw_local_grid_at(center: Vector3, rotation_rad: float, color: Color, radius: float) -> void:
	var cell: float = _gs.cell_size
	var steps: int = int(radius / cell) + 1
	var cos_r: float = cos(rotation_rad)
	var sin_r: float = sin(rotation_rad)

	_local_immediate.surface_begin(Mesh.PRIMITIVE_LINES)

	for i: int in range(-steps, steps + 1):
		var t: float = i * cell
		var p1 := center + _rot(Vector3(-radius, 0.01, t), cos_r, sin_r)
		var p2 := center + _rot(Vector3( radius, 0.01, t), cos_r, sin_r)
		_immediate_line(p1, p2, color)
		var p3 := center + _rot(Vector3(t, 0.01, -radius), cos_r, sin_r)
		var p4 := center + _rot(Vector3(t, 0.01,  radius), cos_r, sin_r)
		_immediate_line(p3, p4, color)

	_local_immediate.surface_end()


func _immediate_line(a: Vector3, b: Vector3, color: Color) -> void:
	_local_immediate.surface_set_color(color)
	_local_immediate.surface_add_vertex(a)
	_local_immediate.surface_set_color(color)
	_local_immediate.surface_add_vertex(b)


func _rot(p: Vector3, cos_r: float, sin_r: float) -> Vector3:
	return Vector3(p.x * cos_r - p.z * sin_r, p.y, p.x * sin_r + p.z * cos_r)


# ──────────────────────────────────────────
#  Stawianie obiektu
# ──────────────────────────────────────────
func _try_place() -> void:
	if _current_data == null:
		return
	var instance: Node3D = _current_data.scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = _snapped_pos

	if instance.get("building_data") != null:
		instance.building_data = _current_data

	BuildManager.confirm_placement(Vector2i(
		int(_snapped_pos.x / _gs.cell_size),
		int(_snapped_pos.z / _gs.cell_size)
	))


# ──────────────────────────────────────────
#  Callbacki
# ──────────────────────────────────────────
func _on_building_selected(data: BuildingData) -> void:
	_current_data = data
	_spawn_ghost(data)
	visible = true


func _on_building_cancelled() -> void:
	_current_data = null
	_clear_ghost()
	_local_immediate.clear_surfaces()
	visible = false


func _on_mode_changed(_mode: int) -> void:
	pass
