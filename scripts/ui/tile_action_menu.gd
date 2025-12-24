extends PopupPanel
class_name TileActionMenu

## Context menu for tile actions
## Shows relevant actions based on tile state (has unit, buildable, etc.)

signal action_selected(action_name: String)

@onready var action_list: VBoxContainer = %ActionList

var _current_tile: Vector2i = Vector2i(-1, -1)
var _tile_biome: String = ""
var _has_unit: bool = false
var _available_actions: Array[Dictionary] = []


func _ready() -> void:
	# Hide by default
	hide()
	# Connect to handle clicks outside
	close_requested.connect(_on_close_requested)


func show_for_tile(tile: Vector2i, biome: String, has_unit: bool, screen_position: Vector2) -> void:
	"""Display action menu for the given tile"""
	_current_tile = tile
	_tile_biome = biome
	_has_unit = has_unit
	
	_build_action_list()
	
	if _available_actions.is_empty():
		hide()
		return
	
	# Position near cursor but ensure it stays on screen
	position = _calculate_menu_position(screen_position)
	popup()


func _build_action_list() -> void:
	"""Build the list of available actions for current tile state"""
	# Clear existing actions
	if action_list:
		for child in action_list.get_children():
			child.queue_free()
	
	_available_actions.clear()
	
	# Add actions based on tile state
	if _has_unit:
		_add_action("Move Unit", "move_unit", "Click destination to move")
		_add_action("Unit Info", "unit_info", "Show unit details")
	
	# Build action available on most tiles
	if _tile_biome != "water":
		_add_action("Build Here", "build", "Open build menu (B)")
	
	# Info action always available
	_add_action("Tile Info", "tile_info", "Show tile details (I)")
	
	# Create buttons for each action
	if action_list:
		for action in _available_actions:
			var button := Button.new()
			button.text = action["label"]
			button.tooltip_text = action["tooltip"]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(func() -> void: _on_action_pressed(action["id"]))
			action_list.add_child(button)


func _add_action(label: String, id: String, tooltip: String = "") -> void:
	"""Add an action to the available actions list"""
	_available_actions.append({
		"label": label,
		"id": id,
		"tooltip": tooltip
	})


func _on_action_pressed(action_id: String) -> void:
	"""Handle action button press"""
	emit_signal("action_selected", action_id)
	hide()


func _on_close_requested() -> void:
	"""Handle close request"""
	hide()


func _calculate_menu_position(screen_pos: Vector2) -> Vector2:
	"""Calculate menu position ensuring it stays on screen"""
	var viewport_size := get_viewport_rect().size
	var menu_size := size
	
	var pos := screen_pos
	
	# Ensure menu doesn't go off right edge
	if pos.x + menu_size.x > viewport_size.x:
		pos.x = viewport_size.x - menu_size.x - 10
	
	# Ensure menu doesn't go off bottom edge
	if pos.y + menu_size.y > viewport_size.y:
		pos.y = viewport_size.y - menu_size.y - 10
	
	# Ensure menu doesn't go off left/top edges
	pos.x = max(10, pos.x)
	pos.y = max(10, pos.y)
	
	return pos


func get_current_tile() -> Vector2i:
	"""Get the tile this menu is currently showing for"""
	return _current_tile
