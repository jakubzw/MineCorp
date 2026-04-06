extends Node3D

# ──────────────────────────────────────────
#  CameraRig — Mine_Corp
#  Perspektywa 3D (Anno-style)
#  Funkcje: ruch WASD, przeciąganie MMB,
#           zoom scroll, obrót RMB, granice mapy
# ──────────────────────────────────────────

# --- Eksportowane ustawienia (edytowalne w Inspektorze) ---

## Prędkość ruchu klawiaturą
@export var move_speed: float = 20.0
## Mnożnik prędkości przy wciśniętym Shift
@export var move_speed_fast_multiplier: float = 2.5
## Wygładzenie ruchu (im niżej, tym "śliziej")
@export var move_smoothing: float = 10.0

## Minimalna odległość zoomu (kamera blisko ziemi)
@export var zoom_min: float = 5.0
## Maksymalna odległość zoomu (kamera daleko)
@export var zoom_max: float = 60.0
## Prędkość zoomu
@export var zoom_speed: float = 5.0
## Wygładzenie zoomu
@export var zoom_smoothing: float = 8.0

## Prędkość obrotu myszą (RMB)
@export var rotation_speed: float = 0.3
## Wygładzenie obrotu
@export var rotation_smoothing: float = 10.0
## Minimalny kąt nachylenia kamery (stopnie)
@export var pitch_min: float = 15.0
## Maksymalny kąt nachylenia kamery (stopnie)
@export var pitch_max: float = 75.0

## Granice mapy — kamera nie wyjdzie poza ten prostokąt
@export var map_bounds: Rect2 = Rect2(-100, -100, 200, 200)
## Czy stosować granice mapy
@export var use_map_bounds: bool = true

# --- Węzły wewnętrzne ---
@onready var _pivot: Node3D = $Pivot          # Obrót poziomy (yaw)
@onready var _arm: Node3D = $Pivot/Arm        # Obrót pionowy (pitch)
@onready var _camera: Camera3D = $Pivot/Arm/Camera3D

# --- Stan wewnętrzny ---
var _target_position: Vector3       # Cel ruchu (wygładzony)
var _target_zoom: float             # Cel zoomu
var _target_yaw: float              # Cel obrotu poziomego
var _target_pitch: float            # Cel nachylenia

var _is_rotating: bool = false      # Czy RMB wciśnięty
var _is_panning: bool = false       # Czy MMB wciśnięty
var _last_mouse_pos: Vector2        # Poprzednia pozycja myszy


func _ready() -> void:
	_target_position = global_position
	_target_yaw = 0.0
	_target_zoom = 30.0
	_target_pitch = -45.0

	# Wymuś pozycję i rotację startową natychmiast
	_pivot.rotation_degrees.y = 0.0
	_arm.rotation_degrees.x = -45.0
	_camera.position = Vector3(0, 0, 30.0)
	# Kamera musi patrzeć na pivot (origin Arm)
	_camera.look_at(_arm.global_position, Vector3.UP)

	_clamp_pitch()


func _unhandled_input(event: InputEvent) -> void:
	# ── Zoom (scroll wheel) ──
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_zoom -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_zoom += zoom_speed
		_target_zoom = clamp(_target_zoom, zoom_min, zoom_max)

		# ── Obrót (PPM) ──
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating = event.pressed
			_last_mouse_pos = event.position

		# ── Przeciąganie (MMB) ──
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			_last_mouse_pos = event.position

	# ── Ruch myszy ──
	if event is InputEventMouseMotion:
		if _is_rotating:
			_handle_rotation(event.relative)
		elif _is_panning:
			_handle_pan(event.relative)


func _process(delta: float) -> void:
	_handle_keyboard_move(delta)
	_apply_smoothing(delta)


# ──────────────────────────────────────────
#  Ruch klawiaturą (WASD / strzałki)
# ──────────────────────────────────────────
func _handle_keyboard_move(delta: float) -> void:
	var direction := Vector3.ZERO

	# Kierunek względem obrotu kamery (yaw)
	var yaw_rad := deg_to_rad(_target_yaw)
	var forward := Vector3(-sin(yaw_rad), 0, -cos(yaw_rad))
	var right   := Vector3(cos(yaw_rad),  0, -sin(yaw_rad))

	if Input.is_action_pressed("move_forward"):
		direction += forward
	if Input.is_action_pressed("move_backward"):
		direction -= forward
	if Input.is_action_pressed("move_left"):
		direction -= right
	if Input.is_action_pressed("move_right"):
		direction += right

	if direction == Vector3.ZERO:
		return

	direction = direction.normalized()
	var speed := move_speed
	if Input.is_action_pressed("move_fast"):
		speed *= move_speed_fast_multiplier

	_target_position += direction * speed * delta
	_apply_map_bounds()


# ──────────────────────────────────────────
#  Obrót myszą (PPM)
# ──────────────────────────────────────────
func _handle_rotation(mouse_delta: Vector2) -> void:
	_target_yaw   -= mouse_delta.x * rotation_speed
	_target_pitch -= mouse_delta.y * rotation_speed
	_clamp_pitch()


# ──────────────────────────────────────────
#  Przeciąganie mapy (MMB)
# ──────────────────────────────────────────
func _handle_pan(mouse_delta: Vector2) -> void:
	var yaw_rad := deg_to_rad(_target_yaw)
	var right   := Vector3(cos(yaw_rad), 0, -sin(yaw_rad))
	var forward := Vector3(-sin(yaw_rad), 0, -cos(yaw_rad))

	# Skalowanie prędkości przeciągania względem zoomu
	var pan_scale := _target_zoom * 0.001

	_target_position -= right   * mouse_delta.x * pan_scale * 100.0
	_target_position += forward * mouse_delta.y * pan_scale * 100.0
	_apply_map_bounds()


# ──────────────────────────────────────────
#  Wygładzanie (lerp)
# ──────────────────────────────────────────
func _apply_smoothing(delta: float) -> void:
	# Pozycja
	global_position = global_position.lerp(
		_target_position,
		clamp(move_smoothing * delta, 0.0, 1.0)
	)

	# Zoom — przesunięcie kamery wzdłuż jej lokalnej osi Z
	var current_zoom: float = _camera.position.z
	var new_zoom: float = lerp(current_zoom, _target_zoom, clamp(zoom_smoothing * delta, 0.0, 1.0))
	_camera.position.z = new_zoom

	# Obrót poziomy (yaw)
	_pivot.rotation_degrees.y = lerp_angle(
		_pivot.rotation_degrees.y,
		_target_yaw,
		clamp(rotation_smoothing * delta, 0.0, 1.0)
	)

	# Nachylenie (pitch)
	_arm.rotation_degrees.x = lerp_angle(
		_arm.rotation_degrees.x,
		_target_pitch,
		clamp(rotation_smoothing * delta, 0.0, 1.0)
	)

# ──────────────────────────────────────────
#  Helpery
# ──────────────────────────────────────────
func _clamp_pitch() -> void:
	_target_pitch = clamp(_target_pitch, -pitch_max, -pitch_min)


func _apply_map_bounds() -> void:
	if not use_map_bounds:
		return
	_target_position.x = clamp(_target_position.x, map_bounds.position.x, map_bounds.end.x)
	_target_position.z = clamp(_target_position.z, map_bounds.position.y, map_bounds.end.y)


# ──────────────────────────────────────────
#  API publiczne
# ──────────────────────────────────────────

## Teleportuje kamerę natychmiast do pozycji (bez wygładzania)
func teleport_to(pos: Vector3) -> void:
	_target_position = pos
	global_position = pos


## Ustawia docelową pozycję (z wygładzaniem)
func move_to(pos: Vector3) -> void:
	_target_position = pos
	_apply_map_bounds()


## Ustawia zoom natychmiast
func set_zoom(value: float) -> void:
	_target_zoom = clamp(value, zoom_min, zoom_max)
