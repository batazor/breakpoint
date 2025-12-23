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
var _updating_slider: bool = false
var current_day: int = 1


func _ready() -> void:
	_resolve_buttons()
	if pause_button == null or speed_1_button == null or speed_2_button == null or speed_5_button == null or progress_slider == null or day_label == null:
		push_warning("TimeControls: UI controls not found. Check the scene tree paths or unique names.")
		return
	pause_button.pressed.connect(_on_pause_pressed)
	speed_1_button.pressed.connect(func() -> void: _emit_speed(1.0))
	speed_2_button.pressed.connect(func() -> void: _emit_speed(2.0))
	speed_5_button.pressed.connect(func() -> void: _emit_speed(5.0))
	progress_slider.value_changed.connect(_on_slider_changed)
	pause_button.tooltip_text = "Pause or resume the day/night cycle."
	speed_1_button.tooltip_text = "Set simulation speed to 1x."
	speed_2_button.tooltip_text = "Set simulation speed to 2x."
	speed_5_button.tooltip_text = "Set simulation speed to 5x."
	progress_slider.tooltip_text = "Scrub time of day (0 = dawn, 1 = end of day)."
	_update_pause_label()
	set_day(current_day)


func set_paused(value: bool) -> void:
	paused = value
	_update_pause_label()


func set_time_progress(value: float) -> void:
	if progress_slider == null:
		return
	_updating_slider = true
	progress_slider.value = clampf(value, 0.0, 1.0)
	_updating_slider = false


func set_day(day: int) -> void:
	current_day = max(1, day)
	if day_label != null:
		day_label.text = "Day %d" % current_day


func _on_pause_pressed() -> void:
	paused = not paused
	_update_pause_label()
	emit_signal("pause_toggled", paused)


func _emit_speed(multiplier: float) -> void:
	emit_signal("speed_selected", multiplier)


func _on_slider_changed(value: float) -> void:
	if _updating_slider:
		return
	emit_signal("time_scrubbed", clampf(value, 0.0, 1.0))


func _update_pause_label() -> void:
	if pause_button == null:
		return
	pause_button.text = "Resume" if paused else "Pause"


func _resolve_buttons() -> void:
	if pause_button == null:
		pause_button = get_node_or_null("Panel/Margin/VBox/HBox/PauseButton") as Button
	if speed_1_button == null:
		speed_1_button = get_node_or_null("Panel/Margin/VBox/HBox/Speed1Button") as Button
	if speed_2_button == null:
		speed_2_button = get_node_or_null("Panel/Margin/VBox/HBox/Speed2Button") as Button
	if speed_5_button == null:
		speed_5_button = get_node_or_null("Panel/Margin/VBox/HBox/Speed5Button") as Button
	if progress_slider == null:
		progress_slider = get_node_or_null("Panel/Margin/VBox/DayProgress") as HSlider
	if day_label == null:
		day_label = get_node_or_null("Panel/Margin/VBox/DayLabel") as Label
