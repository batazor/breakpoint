extends CanvasLayer
class_name TimeControls

signal pause_toggled(paused: bool)
signal speed_selected(multiplier: float)
signal time_scrubbed(time_normalized: float)

@onready var pause_button: Button = %PauseButton
@onready var speed_1_button: Button = %Speed1Button
@onready var speed_2_button: Button = %Speed2Button
@onready var speed_5_button: Button = %Speed5Button
@onready var progress_slider: HSlider = %DayProgress
@onready var day_label: Label = %DayLabel

var paused: bool = false
var current_speed: float = 1.0
var current_day: int = 1

var _updating_slider: bool = false


# =========================
# Lifecycle
# =========================
func _ready() -> void:
	add_to_group("time_controls")
	
	# Signals
	pause_button.pressed.connect(_on_pause_pressed)
	speed_1_button.pressed.connect(func() -> void: _set_speed(1.0))
	speed_2_button.pressed.connect(func() -> void: _set_speed(2.0))
	speed_5_button.pressed.connect(func() -> void: _set_speed(5.0))
	progress_slider.value_changed.connect(_on_slider_changed)

	# Tooltips
	pause_button.tooltip_text = "Pause or resume the simulation."
	speed_1_button.tooltip_text = "Simulation speed: 1x"
	speed_2_button.tooltip_text = "Simulation speed: 2x"
	speed_5_button.tooltip_text = "Simulation speed: 5x"
	progress_slider.tooltip_text = "Scrub time of day (0 = dawn, 1 = end of day)."

	# Initial state
	_update_pause_label()
	_update_speed_buttons()
	set_day(current_day)


# =========================
# Public API (called by game)
# =========================
func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	_update_pause_label()


func set_time_progress(value: float) -> void:
	if progress_slider == null:
		# UI ещё не готов — запомним значение
		call_deferred("set_time_progress", value)
		return

	_updating_slider = true
	progress_slider.value = clampf(value, 0.0, 1.0)
	_updating_slider = false


func set_day(day: int) -> void:
	current_day = max(1, day)

	if day_label == null:
		call_deferred("set_day", current_day)
		return

	day_label.text = "Day %d" % current_day



func set_speed(multiplier: float) -> void:
	_set_speed(multiplier)


# =========================
# Internal handlers
# =========================
func _on_pause_pressed() -> void:
	paused = not paused
	_update_pause_label()
	emit_signal("pause_toggled", paused)


func _set_speed(multiplier: float) -> void:
	if is_equal_approx(current_speed, multiplier):
		return
	current_speed = multiplier
	_update_speed_buttons()
	emit_signal("speed_selected", multiplier)


func _on_slider_changed(value: float) -> void:
	if _updating_slider:
		return
	emit_signal("time_scrubbed", clampf(value, 0.0, 1.0))


# =========================
# UI updates
# =========================
func _update_pause_label() -> void:
	pause_button.text = "Resume" if paused else "Pause"


func _update_speed_buttons() -> void:
	_set_speed_button_state(speed_1_button, current_speed == 1.0)
	_set_speed_button_state(speed_2_button, current_speed == 2.0)
	_set_speed_button_state(speed_5_button, current_speed == 5.0)


func _set_speed_button_state(button: Button, active: bool) -> void:
	button.disabled = active
