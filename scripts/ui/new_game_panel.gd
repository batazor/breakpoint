extends Panel
class_name NewGamePanel

## New game setup screen with configuration options

signal game_started(options: Dictionary)
signal cancelled

@onready var world_size_option: OptionButton = %WorldSizeOption
@onready var difficulty_option: OptionButton = %DifficultyOption
@onready var faction_option: OptionButton = %FactionOption
@onready var start_button: Button = %StartButton
@onready var cancel_button: Button = %CancelButton

var selected_world_size: String = "Medium"
var selected_difficulty: String = "Normal"
var selected_faction: int = 0


func _ready() -> void:
	# Setup world size options
	world_size_option.clear()
	world_size_option.add_item("Small (20x20)")
	world_size_option.add_item("Medium (30x30)")
	world_size_option.add_item("Large (40x40)")
	world_size_option.selected = 1  # Default to Medium
	
	# Setup difficulty options
	difficulty_option.clear()
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Normal")
	difficulty_option.add_item("Hard")
	difficulty_option.selected = 1  # Default to Normal
	
	# Setup faction options
	faction_option.clear()
	faction_option.add_item("Red Faction (Aggressive)")
	faction_option.add_item("Blue Faction (Diplomatic)")
	faction_option.add_item("Green Faction (Economic)")
	faction_option.selected = 0  # Default to Red
	
	# Connect signals
	world_size_option.item_selected.connect(_on_world_size_selected)
	difficulty_option.item_selected.connect(_on_difficulty_selected)
	faction_option.item_selected.connect(_on_faction_selected)
	start_button.pressed.connect(_on_start_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Focus start button
	start_button.grab_focus()


func _on_world_size_selected(index: int) -> void:
	match index:
		0: selected_world_size = "Small"
		1: selected_world_size = "Medium"
		2: selected_world_size = "Large"


func _on_difficulty_selected(index: int) -> void:
	match index:
		0: selected_difficulty = "Easy"
		1: selected_difficulty = "Normal"
		2: selected_difficulty = "Hard"


func _on_faction_selected(index: int) -> void:
	selected_faction = index


func _on_start_pressed() -> void:
	var options := {
		"world_size": selected_world_size,
		"difficulty": selected_difficulty,
		"faction": selected_faction
	}
	game_started.emit(options)


func _on_cancel_pressed() -> void:
	cancelled.emit()
