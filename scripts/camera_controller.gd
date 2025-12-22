extends Node3D

@export var grid_path: NodePath = NodePath("../HexGrid")
@export var move_speed: float = 18.0
@export var zoom_speed: float = 16.0
@export var min_zoom: float = 10.0
@export var max_zoom: float = 120.0
@export var start_zoom: float = 38.0
@export var camera_rotation_degrees: Vector3 = Vector3(-55.0, 45.0, 0.0)
@export var clamp_margin: float = 6.0
@export var rotate_speed: float = 360.0  # degrees per second for Q/E yaw
@export var distance_lerp_speed: float = 16.0
@export var yaw_lerp_speed: float = 60.0
@export var min_pitch_degrees: float = -89.0
@export var max_pitch_degrees: float = -25.0

var grid: Node
var camera: Camera3D
var target_distance: float
var current_distance: float
var target_yaw: float = 0.0
var current_yaw: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # ensure we tick even if the tree is paused
	_ensure_input_actions()

	camera = $Camera3D
	if camera:
		camera.current = true

	grid = null if grid_path.is_empty() else get_node_or_null(grid_path)
	target_distance = clampf(start_zoom, min_zoom, max_zoom)
	current_distance = target_distance

	_center_on_grid()
	_apply_camera_pose()


func _physics_process(delta: float) -> void:
	_handle_rotate(delta)
	_handle_move(delta)
	_handle_zoom(delta)
	_update_camera_smooth(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_delta(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_delta(1.0)
	elif event is InputEventPanGesture:
		# Mac touchpad scroll arrives as a pan gesture; use vertical delta for zoom.
		_zoom_delta(event.delta.y * 0.1)
	elif event is InputEventMagnifyGesture:
		# Pinch gesture on touchpad; factor > 1 means zoom-in gesture.
		var mag: float = event.factor
		_zoom_delta((1.0 - mag) * 10.0)


func _handle_move(delta: float) -> void:
	if camera == null:
		return

	var dir := Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)

	# Allow arrow keys/ui_* as a fallback if custom actions are missing.
	if dir == Vector3.ZERO:
		dir = Vector3(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			0.0,
			Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
		)

	if dir.length() <= 0.0:
		return

	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var move_vec := (right * dir.x + forward * dir.z).normalized() * move_speed * delta
	global_position.x += move_vec.x
	global_position.z += move_vec.z
	_clamp_to_bounds()
	_apply_camera_pose()


func _handle_zoom(delta: float) -> void:
	var zoom_axis := Input.get_action_strength("zoom_out") - Input.get_action_strength("zoom_in")
	if zoom_axis != 0.0:
		_zoom_delta(zoom_axis * delta * zoom_speed)


func _handle_rotate(delta: float) -> void:
	var rot_dir := Input.get_action_strength("rotate_left") - Input.get_action_strength("rotate_right")
	if rot_dir == 0.0:
		return
	target_yaw += rot_dir * rotate_speed * delta


func _zoom_delta(amount: float) -> void:
	target_distance = clampf(target_distance + amount, min_zoom, max_zoom)


func _apply_camera_pose() -> void:
	if camera == null:
		return

	var t := clampf(inverse_lerp(min_zoom, max_zoom, current_distance), 0.0, 1.0)
	# Ease so that pitch change is stronger when getting higher.
	t = pow(t, 1.6)
	var pitch := lerp_angle(max_pitch_degrees, min_pitch_degrees, t)
	camera.rotation_degrees = Vector3(
		pitch,
		camera_rotation_degrees.y + current_yaw,
		camera_rotation_degrees.z
	)
	var forward := -camera.transform.basis.z
	if forward.length() == 0.0:
		forward = Vector3.FORWARD

	# Place camera back along its forward vector so it looks toward the grid.
	camera.position = -forward.normalized() * current_distance


func _center_on_grid() -> void:
	if grid and grid.has_method("get_map_center"):
		var center: Vector3 = grid.get_map_center()
		global_position.x = center.x
		global_position.z = center.z
		_clamp_to_bounds()


func _clamp_to_bounds() -> void:
	if grid == null or not grid.has_method("get_bounds_rect"):
		return

	var rect: Rect2 = grid.get_bounds_rect()
	global_position.x = clampf(global_position.x, rect.position.x - clamp_margin, rect.position.x + rect.size.x + clamp_margin)
	global_position.z = clampf(global_position.z, rect.position.y - clamp_margin, rect.position.y + rect.size.y + clamp_margin)


func _ensure_input_actions() -> void:
	# Ensure required actions exist (helpful if project settings were not imported).
	var make_key := func(code: int) -> InputEventKey:
		var e := InputEventKey.new()
		e.physical_keycode = code
		return e

	var make_wheel := func(button: int) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = button
		return e

	var actions := {
		"move_forward": [make_key.call(KEY_W)],
		"move_back": [make_key.call(KEY_S)],
		"move_left": [make_key.call(KEY_A)],
		"move_right": [make_key.call(KEY_D)],
		"zoom_in": [make_wheel.call(MOUSE_BUTTON_WHEEL_UP)],
		"zoom_out": [make_wheel.call(MOUSE_BUTTON_WHEEL_DOWN)],
		"rotate_left": [make_key.call(KEY_Q)],
		"rotate_right": [make_key.call(KEY_E)],
	}

	for action in actions.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for ev in actions[action]:
				InputMap.action_add_event(action, ev)


func _update_camera_smooth(delta: float) -> void:
	# Smoothly approach target distance and yaw.
	current_distance = lerp(current_distance, target_distance, 1.0 - exp(-distance_lerp_speed * delta))
	current_yaw = lerp_angle(current_yaw, target_yaw, 1.0 - exp(-yaw_lerp_speed * delta))
	_apply_camera_pose()
