extends CanvasLayer
class_name PauseMenu

## In-game pause menu overlay

signal resume_requested
signal main_menu_requested

@onready var panel: Panel = %Panel
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton
@onready var panel_container: Control = %PanelContainer

@export var settings_menu_scene: PackedScene

var is_paused: bool = false


func _ready() -> void:
	# Hide by default
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_paused:
			_on_resume_pressed()
		else:
			show_pause_menu()
		get_viewport().set_input_as_handled()


func show_pause_menu() -> void:
	visible = true
	is_paused = true
	get_tree().paused = true
	resume_button.grab_focus()


func hide_pause_menu() -> void:
	visible = false
	is_paused = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	hide_pause_menu()
	resume_requested.emit()


func _on_settings_pressed() -> void:
	if settings_menu_scene:
		var menu := settings_menu_scene.instantiate()
		panel_container.add_child(menu)
		menu.closed.connect(func(): menu.queue_free())


func _on_save_pressed() -> void:
	var save_system := get_node_or_null("/root/SaveLoadSystem")
	if save_system and save_system.has_method("quick_save"):
		save_system.quick_save()
		print("Game saved")
	else:
		print("Save system not available")


func _on_load_pressed() -> void:
	var save_system := get_node_or_null("/root/SaveLoadSystem")
	if save_system and save_system.has_method("quick_load"):
		hide_pause_menu()
		save_system.quick_load()
	else:
		print("Save system not available")


func _on_main_menu_pressed() -> void:
	# Show confirmation dialog
	var dialog := _create_confirmation_dialog(
		"Return to Main Menu?",
		"Any unsaved progress will be lost.",
		func(): 
			hide_pause_menu()
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	panel_container.add_child(dialog)


func _on_quit_pressed() -> void:
	# Show confirmation dialog
	var dialog := _create_confirmation_dialog(
		"Quit Game?",
		"Any unsaved progress will be lost.",
		func(): get_tree().quit()
	)
	panel_container.add_child(dialog)


func _create_confirmation_dialog(title: String, message: String, on_confirm: Callable) -> AcceptDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.confirmed.connect(on_confirm)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	dialog.popup_centered()
	return dialog
