extends Node
class_name SettingsManager

## Manages game settings persistence using ConfigFile
## Handles graphics, audio, and control settings

signal settings_changed
signal audio_settings_changed(master_volume: float, music_volume: float, sfx_volume: float)
signal graphics_settings_changed
signal control_settings_changed

const SETTINGS_PATH := "user://settings.cfg"

# Graphics settings
var fullscreen: bool = false
var vsync_enabled: bool = true
var resolution: Vector2i = Vector2i(1600, 900)
var quality_level: int = 1  # 0=Low, 1=Medium, 2=High
var shadow_quality: int = 1  # 0=Low, 1=Medium, 2=High

# Audio settings
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var audio_muted: bool = false

# Control settings
var mouse_sensitivity: float = 1.0
var camera_speed: float = 1.0
var edge_scrolling_enabled: bool = true

# Default values for reset
const DEFAULT_SETTINGS := {
	"graphics": {
		"fullscreen": false,
		"vsync_enabled": true,
		"resolution_x": 1600,
		"resolution_y": 900,
		"quality_level": 1,
		"shadow_quality": 1
	},
	"audio": {
		"master_volume": 1.0,
		"music_volume": 0.7,
		"sfx_volume": 0.8,
		"audio_muted": false
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"camera_speed": 1.0,
		"edge_scrolling_enabled": true
	}
}


func _ready() -> void:
	load_settings()


## Load settings from disk, or use defaults if file doesn't exist
func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	
	if err != OK:
		print("SettingsManager: No settings file found, using defaults")
		apply_default_settings()
		save_settings()
		return
	
	# Load graphics settings
	fullscreen = config.get_value("graphics", "fullscreen", DEFAULT_SETTINGS.graphics.fullscreen)
	vsync_enabled = config.get_value("graphics", "vsync_enabled", DEFAULT_SETTINGS.graphics.vsync_enabled)
	resolution.x = config.get_value("graphics", "resolution_x", DEFAULT_SETTINGS.graphics.resolution_x)
	resolution.y = config.get_value("graphics", "resolution_y", DEFAULT_SETTINGS.graphics.resolution_y)
	quality_level = config.get_value("graphics", "quality_level", DEFAULT_SETTINGS.graphics.quality_level)
	shadow_quality = config.get_value("graphics", "shadow_quality", DEFAULT_SETTINGS.graphics.shadow_quality)
	
	# Load audio settings
	master_volume = config.get_value("audio", "master_volume", DEFAULT_SETTINGS.audio.master_volume)
	music_volume = config.get_value("audio", "music_volume", DEFAULT_SETTINGS.audio.music_volume)
	sfx_volume = config.get_value("audio", "sfx_volume", DEFAULT_SETTINGS.audio.sfx_volume)
	audio_muted = config.get_value("audio", "audio_muted", DEFAULT_SETTINGS.audio.audio_muted)
	
	# Load control settings
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", DEFAULT_SETTINGS.controls.mouse_sensitivity)
	camera_speed = config.get_value("controls", "camera_speed", DEFAULT_SETTINGS.controls.camera_speed)
	edge_scrolling_enabled = config.get_value("controls", "edge_scrolling_enabled", DEFAULT_SETTINGS.controls.edge_scrolling_enabled)
	
	apply_settings()
	print("SettingsManager: Settings loaded successfully")


## Save current settings to disk
func save_settings() -> void:
	var config := ConfigFile.new()
	
	# Save graphics settings
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "vsync_enabled", vsync_enabled)
	config.set_value("graphics", "resolution_x", resolution.x)
	config.set_value("graphics", "resolution_y", resolution.y)
	config.set_value("graphics", "quality_level", quality_level)
	config.set_value("graphics", "shadow_quality", shadow_quality)
	
	# Save audio settings
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "audio_muted", audio_muted)
	
	# Save control settings
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "camera_speed", camera_speed)
	config.set_value("controls", "edge_scrolling_enabled", edge_scrolling_enabled)
	
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("SettingsManager: Failed to save settings: %d" % err)
	else:
		print("SettingsManager: Settings saved successfully")


## Apply settings to the engine
func apply_settings() -> void:
	apply_graphics_settings()
	apply_audio_settings()
	settings_changed.emit()


## Apply graphics settings
func apply_graphics_settings() -> void:
	# Fullscreen
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# Resolution
	if not fullscreen:
		DisplayServer.window_set_size(resolution)
	
	# VSync
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	graphics_settings_changed.emit()


## Apply audio settings
func apply_audio_settings() -> void:
	var master_bus_index := AudioServer.get_bus_index("Master")
	
	if audio_muted:
		AudioServer.set_bus_mute(master_bus_index, true)
	else:
		AudioServer.set_bus_mute(master_bus_index, false)
		
		# Convert 0-1 range to decibels (-80 to 0 dB)
		var master_db := linear_to_db(master_volume)
		AudioServer.set_bus_volume_db(master_bus_index, master_db)
	
	audio_settings_changed.emit(master_volume, music_volume, sfx_volume)


## Reset to default settings
func apply_default_settings() -> void:
	fullscreen = DEFAULT_SETTINGS.graphics.fullscreen
	vsync_enabled = DEFAULT_SETTINGS.graphics.vsync_enabled
	resolution.x = DEFAULT_SETTINGS.graphics.resolution_x
	resolution.y = DEFAULT_SETTINGS.graphics.resolution_y
	quality_level = DEFAULT_SETTINGS.graphics.quality_level
	shadow_quality = DEFAULT_SETTINGS.graphics.shadow_quality
	
	master_volume = DEFAULT_SETTINGS.audio.master_volume
	music_volume = DEFAULT_SETTINGS.audio.music_volume
	sfx_volume = DEFAULT_SETTINGS.audio.sfx_volume
	audio_muted = DEFAULT_SETTINGS.audio.audio_muted
	
	mouse_sensitivity = DEFAULT_SETTINGS.controls.mouse_sensitivity
	camera_speed = DEFAULT_SETTINGS.controls.camera_speed
	edge_scrolling_enabled = DEFAULT_SETTINGS.controls.edge_scrolling_enabled


## Convert linear volume (0-1) to decibels
func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


## Get available resolutions
func get_available_resolutions() -> Array[Vector2i]:
	return [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160)
	]


## Get quality level name
func get_quality_name(level: int) -> String:
	match level:
		0: return "Low"
		1: return "Medium"
		2: return "High"
		_: return "Unknown"
