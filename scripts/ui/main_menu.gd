extends Control
class_name MainMenu

## Main menu scene with game title and action buttons
## Entry point for the game

@export var game_scene_path: String = "res://scenes/main.tscn"
@export var new_game_panel_scene: PackedScene
@export var settings_menu_scene: PackedScene

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton
@onready var version_label: Label = %VersionLabel
@onready var panel_container: Control = %PanelContainer

var settings_manager: SettingsManager
var has_save_game: bool = false


func _ready() -> void:
	# Get settings manager from autoload
	settings_manager = get_node("/root/SettingsManager")
	
	# Check for existing save games
	has_save_game = _check_for_save_games()
	continue_button.disabled = not has_save_game
	
	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Set version
	var config := ConfigFile.new()
	config.load("res://project.godot")
	var game_name := config.get_value("application", "config/name", "Breakpoint")
	version_label.text = "v0.7.0-alpha"
	
	# Focus first button
	new_game_button.grab_focus()


func _check_for_save_games() -> bool:
	# Check if any save files exist
	var save_dir := "user://saves/"
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return false
	
	var files := dir.get_files()
	for file in files:
		if file.ends_with(".save"):
			return true
	
	return false


func _on_new_game_pressed() -> void:
	if new_game_panel_scene:
		# Show new game setup panel
		var panel := new_game_panel_scene.instantiate()
		panel_container.add_child(panel)
		panel.game_started.connect(_start_new_game)
		panel.cancelled.connect(func(): panel.queue_free())
	else:
		# Start game directly with default settings
		_start_new_game({})


func _start_new_game(options: Dictionary) -> void:
	# Store new game options in GameStore or similar
	if options.has("world_size"):
		print("Starting new game with world size: %s" % options.world_size)
	
	# Load game scene
	get_tree().change_scene_to_file(game_scene_path)


func _on_continue_pressed() -> void:
	if has_save_game:
		# Load most recent save
		var save_system := get_node_or_null("/root/SaveLoadSystem")
		if save_system and save_system.has_method("load_latest_game"):
			save_system.load_latest_game()
		else:
			# Fallback: just load the game scene
			get_tree().change_scene_to_file(game_scene_path)


func _on_settings_pressed() -> void:
	if settings_menu_scene:
		var menu := settings_menu_scene.instantiate()
		panel_container.add_child(menu)
		menu.closed.connect(func(): menu.queue_free())


func _on_credits_pressed() -> void:
	# Show credits panel
	print("Credits: Breakpoint - A strategy simulation game")
	# TODO: Implement credits screen


func _on_quit_pressed() -> void:
	get_tree().quit()
