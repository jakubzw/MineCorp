extends Node3D
# ──────────────────────────────────────────
#  GridRenderer — wizualizacja siatki globalnej
# ──────────────────────────────────────────

@export var global_grid_half_size: int = 30
@export var color_grid_a: Color = Color(0.5, 0.8, 1.0, 0.25)
@export var color_grid_b: Color = Color(1.0, 0.8, 0.4, 0.25)
@export var color_snap_point: Color = Color(1.0, 0.9, 0.2, 0.9)

var _gs: Node  # referencja do Autoloada GridSystem
var _global_mesh: ImmediateMesh
var _local_mesh: ImmediateMesh
var _global_mi: MeshInstance3D
var _local_mi: MeshInstance3D
var _cursor_world_pos: Vector3 = Vector3.ZERO
var _show_local: bool = false


func _ready() -> void:
	_gs = get_node_or_null("/root/GridSystem")
	if _gs == null:
		push_error("GridRenderer: nie znaleziono Autoloada GridSystem")
		return

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_global_mesh = ImmediateMesh.new()
	_global_mi = MeshInstance3D.new()
	_global_mi.mesh = _global_mesh
	_global_mi.material_override = mat
	add_child(_global_mi)

	_local_mesh = ImmediateMesh.new()
	_local_mi = MeshInstance3D.new()
	_local_mi.mesh = _local_mesh
	_local_mi.material_override = mat.duplicate()
	add_child(_local_mi)

	_gs.grid_mode_changed.connect(func(_m: int) -> void: _draw_global_grid())


func _process(_delta: float) -> void:
	_draw_global_grid()
	_draw_local_grid()


func _draw_global_grid() -> void:
	_global_mesh.clear_surfaces()

	var current_mode: int = _gs.mode
	if current_mode == 0:  # FREE
		return

	var angle: float = _gs.get_active_angle()
	var cell: float = _gs.cell_size
	var half: int = global_grid_half_size
	var color: Color = color_grid_a if current_mode == 1 else color_grid_b

	var u_dir := Vector2(cos(angle), sin(angle))
	var v_dir := Vector2(-sin(angle), cos(angle))
	var extent: float = half * cell

	_global_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for i: int in range(-half, half + 1):
		var offset: float = i * cell

		var p1 := v_dir * offset - u_dir * extent
		var p2 := v_dir * offset + u_dir * extent
		_global_mesh.surface_set_color(color)
		_global_mesh.surface_add_vertex(Vector3(p1.x, 0.01, p1.y))
		_global_mesh.surface_set_color(color)
		_global_mesh.surface_add_vertex(Vector3(p2.x, 0.01, p2.y))

		var q1 := u_dir * offset - v_dir * extent
		var q2 := u_dir * offset + v_dir * extent
		_global_mesh.surface_set_color(color)
		_global_mesh.surface_add_vertex(Vector3(q1.x, 0.01, q1.y))
		_global_mesh.surface_set_color(color)
		_global_mesh.surface_add_vertex(Vector3(q2.x, 0.01, q2.y))

	_global_mesh.surface_end()


func _draw_local_grid() -> void:
	_local_mesh.clear_surfaces()

	if not _show_local:
		return

	var snap_points: Array = _gs.get_local_snap_points(_cursor_world_pos)
	if snap_points.is_empty():
		return

	_local_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var drawn: Array[Vector3] = []
	for pt: Vector3 in snap_points:
		var skip: bool = false
		for d: Vector3 in drawn:
			if pt.distance_to(d) < 0.1:
				skip = true
				break
		if skip:
			continue
		drawn.append(pt)

		var s: float = 0.35
		_local_mesh.surface_set_color(color_snap_point)
		_local_mesh.surface_add_vertex(pt + Vector3(-s, 0.02,  0))
		_local_mesh.surface_set_color(color_snap_point)
		_local_mesh.surface_add_vertex(pt + Vector3( s, 0.02,  0))
		_local_mesh.surface_set_color(color_snap_point)
		_local_mesh.surface_add_vertex(pt + Vector3( 0, 0.02, -s))
		_local_mesh.surface_set_color(color_snap_point)
		_local_mesh.surface_add_vertex(pt + Vector3( 0, 0.02,  s))

	_local_mesh.surface_end()


func update_cursor(world_pos: Vector3) -> void:
	_cursor_world_pos = world_pos
	var snap_points: Array = _gs.get_local_snap_points(world_pos)
	_show_local = not snap_points.is_empty()
