extends PopupPanel
class_name TileActionMenu

## Context menu for tile actions
## Shows relevant actions based on tile state (has unit, buildable, etc.)

signal action_selected(action_name: String)

@onready var action_list: VBoxContainer = %ActionList

@export var build_controller_path: NodePath

var _build_controller: Node = null
var _current_tile: Vector2i = Vector2i(-1, -1)
var _tile_biome: String = ""
var _has_unit: bool = false
var _has_building: bool = false
var _can_upgrade_building: bool = false
var _available_actions: Array[Dictionary] = []


func _ready() -> void:
	# Hide by default
	hide()
	# Connect to handle clicks outside
	close_requested.connect(_on_close_requested)
	
	# Resolve build controller
	if not build_controller_path.is_empty():
		_build_controller = get_node_or_null(build_controller_path)
	else:
		call_deferred("_resolve_build_controller")


func _resolve_build_controller() -> void:
	_build_controller = get_tree().get_first_node_in_group("build_controller")


func show_for_tile(tile: Vector2i, biome: String, has_unit: bool, screen_position: Vector2) -> void:
	## Display action menu for the given tile
	_current_tile = tile
	_tile_biome = biome
	_has_unit = has_unit
	
	# Check for building at this tile
	_check_building_status()
	
	_build_action_list()
	
	if _available_actions.is_empty():
		hide()
		return
	
	# Position near cursor but ensure it stays on screen
	position = _calculate_menu_position(screen_position)
	popup()


func _check_building_status() -> void:
	## Check if there's a building at the current tile and if it can be upgraded
	_has_building = false
	_can_upgrade_building = false
	
	if _build_controller == null or _current_tile == Vector2i(-1, -1):
		return
	
	# Check if there's a building at this tile
	if _build_controller.has("building_at"):
		var building_at: Dictionary = _build_controller.get("building_at")
		_has_building = building_at.has(_current_tile)
		
		if _has_building:
			# Check if it can be upgraded
			var building_id: StringName = building_at.get(_current_tile, StringName(""))
			if not building_id.is_empty() and _build_controller.has_method("get_building_level"):
				var level: int = _build_controller.call("get_building_level", _current_tile)
				
				# Try to get the resource for this building to check max_level
				# We need to get the building type from building_id (e.g., "well_1" -> "well")
				var building_type := _extract_building_type(building_id)
				var resource := _find_resource_by_id(building_type)
				
				if resource != null and resource.max_level > level:
					_can_upgrade_building = true


func _extract_building_type(building_id: StringName) -> StringName:
	## Extract building type from building_id (e.g., "well_1" -> "well")
	var id_str := str(building_id)
	var parts := id_str.rsplit("_", false, 1)
	if parts.size() > 0:
		return StringName(parts[0])
	return building_id


func _find_resource_by_id(res_id: StringName) -> GameResource:
	## Find a GameResource by ID from build controller
	if _build_controller == null:
		return null
	
	if _build_controller.has_method("_find_resource_by_id"):
		return _build_controller.call("_find_resource_by_id", res_id)
	
	return null


func _build_action_list() -> void:
	## Build the list of available actions for current tile state
	# Clear existing actions
	if action_list:
		for child in action_list.get_children():
			action_list.remove_child(child)
			child.queue_free()
	
	_available_actions.clear()
	
	# Add actions based on tile state
	if _has_unit:
		_add_action("Move Unit", "move_unit", "Click destination to move")
		_add_action("Unit Info", "unit_info", "Show unit details")
	
	# Upgrade action if building is present and can be upgraded
	if _has_building:
		_add_action("Building Info", "building_info", "Show building details")
		if _can_upgrade_building:
			_add_action("Upgrade Building", "upgrade_building", "Upgrade this building to next level")
	
	# Build action available on most tiles
	if _tile_biome != "water" and not _has_building:
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
	## Add an action to the available actions list
	_available_actions.append({
		"label": label,
		"id": id,
		"tooltip": tooltip
	})


func _on_action_pressed(action_id: String) -> void:
	## Handle action button press
	action_selected.emit(action_id)
	hide()


func _on_close_requested() -> void:
	## Handle close request
	hide()


func _calculate_menu_position(screen_pos: Vector2) -> Vector2:
	## Calculate menu position ensuring it stays on screen
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
	## Get the tile this menu is currently showing for
	return _current_tile
