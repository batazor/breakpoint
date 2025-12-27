extends Panel
class_name SettingsMenu

## Settings menu with tabs for graphics, audio, and controls

signal closed

@onready var graphics_tab: Control = %GraphicsTab
@onready var audio_tab: Control = %AudioTab
@onready var controls_tab: Control = %ControlsTab

# Graphics controls
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_check: CheckBox = %VsyncCheck
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var quality_option: OptionButton = %QualityOption

# Audio controls
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var mute_check: CheckBox = %MuteCheck
@onready var master_value_label: Label = %MasterValueLabel
@onready var music_value_label: Label = %MusicValueLabel
@onready var sfx_value_label: Label = %SfxValueLabel

# Controls
@onready var mouse_sensitivity_slider: HSlider = %MouseSensitivitySlider
@onready var camera_speed_slider: HSlider = %CameraSpeedSlider
@onready var edge_scroll_check: CheckBox = %EdgeScrollCheck
@onready var mouse_sens_label: Label = %MouseSensLabel
@onready var camera_speed_label: Label = %CameraSpeedLabel

# Buttons
@onready var apply_button: Button = %ApplyButton
@onready var cancel_button: Button = %CancelButton
@onready var defaults_button: Button = %DefaultsButton

var settings_manager: SettingsManager


func _ready() -> void:
	# Get settings manager from autoload
	settings_manager = get_node("/root/SettingsManager")
	
	# Load current settings
	_load_settings_to_ui()
	
	# Connect graphics controls
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	quality_option.item_selected.connect(_on_quality_selected)
	
	# Connect audio controls
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	mute_check.toggled.connect(_on_mute_toggled)
	
	# Connect controls
	mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	camera_speed_slider.value_changed.connect(_on_camera_speed_changed)
	edge_scroll_check.toggled.connect(_on_edge_scroll_toggled)
	
	# Connect buttons
	apply_button.pressed.connect(_on_apply_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	defaults_button.pressed.connect(_on_defaults_pressed)


func _load_settings_to_ui() -> void:
	# Graphics
	fullscreen_check.button_pressed = settings_manager.fullscreen
	vsync_check.button_pressed = settings_manager.vsync_enabled
	
	# Setup resolution options
	resolution_option.clear()
	var resolutions := settings_manager.get_available_resolutions()
	var current_res_index := 0
	for i in range(resolutions.size()):
		var res := resolutions[i]
		resolution_option.add_item("%dx%d" % [res.x, res.y])
		if res == settings_manager.resolution:
			current_res_index = i
	resolution_option.selected = current_res_index
	
	# Setup quality options
	quality_option.clear()
	quality_option.add_item("Low")
	quality_option.add_item("Medium")
	quality_option.add_item("High")
	quality_option.selected = settings_manager.quality_level
	
	# Audio
	master_volume_slider.value = settings_manager.master_volume
	music_volume_slider.value = settings_manager.music_volume
	sfx_volume_slider.value = settings_manager.sfx_volume
	mute_check.button_pressed = settings_manager.audio_muted
	_update_volume_labels()
	
	# Controls
	mouse_sensitivity_slider.value = settings_manager.mouse_sensitivity
	camera_speed_slider.value = settings_manager.camera_speed
	edge_scroll_check.button_pressed = settings_manager.edge_scrolling_enabled
	_update_control_labels()


func _update_volume_labels() -> void:
	master_value_label.text = "%d%%" % int(master_volume_slider.value * 100)
	music_value_label.text = "%d%%" % int(music_volume_slider.value * 100)
	sfx_value_label.text = "%d%%" % int(sfx_volume_slider.value * 100)


func _update_control_labels() -> void:
	mouse_sens_label.text = "%.1fx" % mouse_sensitivity_slider.value
	camera_speed_label.text = "%.1fx" % camera_speed_slider.value


# Graphics handlers
func _on_fullscreen_toggled(pressed: bool) -> void:
	settings_manager.fullscreen = pressed


func _on_vsync_toggled(pressed: bool) -> void:
	settings_manager.vsync_enabled = pressed


func _on_resolution_selected(index: int) -> void:
	var resolutions := settings_manager.get_available_resolutions()
	if index < resolutions.size():
		settings_manager.resolution = resolutions[index]


func _on_quality_selected(index: int) -> void:
	settings_manager.quality_level = index


# Audio handlers
func _on_master_volume_changed(value: float) -> void:
	settings_manager.master_volume = value
	_update_volume_labels()


func _on_music_volume_changed(value: float) -> void:
	settings_manager.music_volume = value
	_update_volume_labels()


func _on_sfx_volume_changed(value: float) -> void:
	settings_manager.sfx_volume = value
	_update_volume_labels()


func _on_mute_toggled(pressed: bool) -> void:
	settings_manager.audio_muted = pressed


# Controls handlers
func _on_mouse_sensitivity_changed(value: float) -> void:
	settings_manager.mouse_sensitivity = value
	_update_control_labels()


func _on_camera_speed_changed(value: float) -> void:
	settings_manager.camera_speed = value
	_update_control_labels()


func _on_edge_scroll_toggled(pressed: bool) -> void:
	settings_manager.edge_scrolling_enabled = pressed


# Button handlers
func _on_apply_pressed() -> void:
	settings_manager.save_settings()
	settings_manager.apply_settings()
	emit_signal("closed")


func _on_cancel_pressed() -> void:
	# Reload settings from file
	settings_manager.load_settings()
	emit_signal("closed")


func _on_defaults_pressed() -> void:
	settings_manager.apply_default_settings()
	_load_settings_to_ui()
