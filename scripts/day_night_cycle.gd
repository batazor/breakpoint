extends Node3D
class_name DayNightCycle

signal time_updated(time_normalized: float)
signal day_changed(day: int)

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var time_ui_path: NodePath

@export_range(0.0, 1.0, 0.001) var time_normalized: float = 0.25
@export var day_length_seconds: float = 120.0
@export var time_speed: float = 1.0
@export var paused: bool = false
@export var start_day: int = 1

@export var sun_yaw_degrees: float = -45.0
@export var day_light_color: Color = Color(1.0, 0.98, 0.9)
@export var sunset_light_color: Color = Color(1.0, 0.6, 0.35)
@export var night_light_color: Color = Color(0.55, 0.6, 0.75)
@export var day_light_energy: float = 1.5
@export var night_light_energy: float = 0.6

@export var ambient_day_color: Color = Color(0.6, 0.7, 0.8)
@export var ambient_night_color: Color = Color(0.25, 0.3, 0.4)
@export var ambient_day_energy: float = 1.0
@export var ambient_night_energy: float = 0.65

var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var time_controls: TimeControls
var current_day: int = 1


func _ready() -> void:
	sun = get_node_or_null(sun_path) as DirectionalLight3D
	world_environment = get_node_or_null(environment_path) as WorldEnvironment
	time_controls = get_node_or_null(time_ui_path) as TimeControls
	current_day = max(start_day, 1)
	if time_controls != null:
		time_controls.pause_toggled.connect(_on_pause_toggled)
		time_controls.speed_selected.connect(_on_speed_selected)
		time_controls.time_scrubbed.connect(_on_time_scrubbed)
		time_controls.set_paused(paused)
		time_controls.set_time_progress(time_normalized)
		time_controls.set_day(current_day)
	_apply_lighting()


func _process(delta: float) -> void:
	if paused:
		return
	if day_length_seconds <= 0.0:
		return
	if time_speed <= 0.0:
		return
	var step: float = (delta / day_length_seconds) * time_speed
	var raw_time: float = time_normalized + step
	var days_passed: int = int(floor(raw_time))
	time_normalized = fposmod(raw_time, 1.0)
	if days_passed > 0:
		_advance_days(days_passed)
	_apply_lighting()
	emit_signal("time_updated", time_normalized)


func set_paused(value: bool) -> void:
	paused = value
	if time_controls != null:
		time_controls.set_paused(paused)


func toggle_paused() -> void:
	set_paused(not paused)


func set_speed_multiplier(multiplier: float) -> void:
	time_speed = maxf(multiplier, 0.0)


func set_time_normalized(value: float) -> void:
	time_normalized = fposmod(value, 1.0)
	_apply_lighting()
	if time_controls != null:
		time_controls.set_paused(paused)
		time_controls.set_time_progress(time_normalized)


func _advance_days(count: int) -> void:
	if count <= 0:
		return
	current_day += count
	if time_controls != null:
		time_controls.set_day(current_day)
	emit_signal("day_changed", current_day)


func _on_pause_toggled(value: bool) -> void:
	set_paused(value)


func _on_speed_selected(multiplier: float) -> void:
	set_speed_multiplier(multiplier)


func _on_time_scrubbed(value: float) -> void:
	set_time_normalized(value)


func _apply_lighting() -> void:
	if sun == null:
		return

	var angle_deg: float = time_normalized * 360.0 - 90.0
	sun.rotation_degrees = Vector3(angle_deg, sun_yaw_degrees, 0.0)

	var daylight: float = clampf(sin(deg_to_rad(angle_deg)), 0.0, 1.0)
	var sunrise: float = _smoothstep(0.0, 0.2, daylight)
	var day: float = _smoothstep(0.2, 0.6, daylight)

	var light_color: Color = night_light_color.lerp(sunset_light_color, sunrise)
	light_color = light_color.lerp(day_light_color, day)
	var energy_t: float = _smoothstep(0.0, 0.35, daylight)
	var light_energy: float = lerp(night_light_energy, day_light_energy, energy_t)

	sun.light_color = light_color
	sun.light_energy = light_energy

	if world_environment != null and world_environment.environment != null:
		var env: Environment = world_environment.environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = ambient_night_color.lerp(ambient_day_color, energy_t)
		env.ambient_light_energy = lerp(ambient_night_energy, ambient_day_energy, energy_t)

	if time_controls != null:
		time_controls.set_time_progress(time_normalized)


func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 0.0
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
