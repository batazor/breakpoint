extends Control
class_name CityScreen

## City Screen UI for managing buildings within a settlement
## Shows available city buildings, construction queue, and city info

signal city_screen_closed()
signal building_queued(building_id: StringName)

@export var resource_card_scene: PackedScene
@export var buildings_yaml_path: String = "res://building.yaml"
@export var faction_system_path: NodePath
@export var build_controller_path: NodePath
@export var economy_system_path: NodePath

@onready var panel_container: PanelContainer = %PanelContainer
@onready var city_name_label: Label = %CityNameLabel
@onready var city_info_label: Label = %CityInfoLabel
@onready var buildings_grid: GridContainer = %BuildingsGrid
@onready var queue_list: VBoxContainer = %QueueList
@onready var close_button: Button = %CloseButton
@onready var resource_display: HBoxContainer = %ResourceDisplay

var _faction_system: Node
var _build_controller: Node
var _economy_system: Node
var _current_city_axial: Vector2i = Vector2i(-1, -1)
var _current_faction: StringName = &"kingdom"
var _is_visible: bool = false
var _city_buildings: Array[GameResource] = []
var _construction_queue: Array = [] # Array of {building_id: StringName, remaining_hours: float}


func _ready() -> void:
	_resolve_systems()
	_load_city_buildings()
	_setup_ui()
	hide_screen()
	
	# Connect to input
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_city_screen"):
		if _is_visible:
			hide_screen()
		else:
			# Try to open for selected fortress/city
			show_screen()
		get_viewport().set_input_as_handled()


func _resolve_systems() -> void:
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path)
	if _faction_system == null:
		_faction_system = get_tree().get_first_node_in_group("faction_system")
	
	if not build_controller_path.is_empty():
		_build_controller = get_node_or_null(build_controller_path)
	if _build_controller == null:
		_build_controller = get_tree().get_first_node_in_group("build_controller")
	
	if not economy_system_path.is_empty():
		_economy_system = get_node_or_null(economy_system_path)
	if _economy_system == null:
		_economy_system = get_tree().get_first_node_in_group("economy_system")


func _setup_ui() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	_rebuild_buildings_grid()
	_update_resource_display()


func _load_city_buildings() -> void:
	_city_buildings.clear()
	
	var file := FileAccess.open(buildings_yaml_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open building.yaml")
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	# Use the YAML parser from build_menu
	var entries := _parse_resources_yaml(content)
	
	for entry in entries:
		if entry.get("category", "") == "city_building":
			var res := GameResource.new()
			res.id = StringName(entry.get("id", entry.get("key", "")))
			res.title = entry.get("title", str(res.id))
			res.description = entry.get("description", "")
			res.category = entry.get("category", "city_building")
			
			# Load icon
			var icon_path: String = entry.get("icon", "")
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
				res.icon = load(icon_path)
			
			# Load scene
			var scene_path: String = entry.get("scene", "")
			if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
				res.scene = load(scene_path)
			
			# Parse buildable tiles
			var buildable_array = entry.get("buildable_tiles", [])
			if buildable_array is Array:
				for tile in buildable_array:
					res.buildable_tiles.append(str(tile))
			
			# Parse resource delta
			var delta_dict = entry.get("resource_delta_per_hour", {})
			if delta_dict is Dictionary:
				for res_key in delta_dict.keys():
					res.resource_delta_per_hour[str(res_key)] = int(delta_dict[res_key])
			
			# Parse build cost
			var cost_dict = entry.get("build_cost", {})
			if cost_dict is Dictionary:
				for res_key in cost_dict.keys():
					res.build_cost[str(res_key)] = int(cost_dict[res_key])
			
			# Build time
			res.build_time_hours = float(entry.get("build_time_hours", 1))
			
			_city_buildings.append(res)


func _parse_resources_yaml(text: String) -> Array:
	# Simplified YAML parser for building.yaml structure
	var entries: Array = []
	var lines := text.split("\n")
	var in_resources := false
	var current: Dictionary = {}
	var collecting_list := false
	var collecting_dict := false
	var current_dict_key := ""
	
	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		
		if not in_resources:
			if trimmed == "resources:":
				in_resources = true
			continue
		
		# New resource entry (2 spaces indent)
		if line.begins_with("  ") and not line.begins_with("    ") and trimmed.ends_with(":"):
			_commit_resource_entry(entries, current)
			current = {"key": trimmed.rstrip(":")}
			collecting_list = false
			collecting_dict = false
			current_dict_key = ""
			continue
		
		# Property of a resource (4 spaces indent)
		if line.begins_with("    "):
			if trimmed == "buildable_tiles:":
				collecting_list = true
				current["buildable_tiles"] = []
				continue
			
			if trimmed == "resource_delta_per_hour:" or trimmed == "build_cost:":
				collecting_dict = true
				current_dict_key = trimmed.rstrip(":")
				current[current_dict_key] = {}
				continue
			
			if trimmed == "roles:":
				# Skip roles for now
				collecting_list = false
				collecting_dict = false
				continue
			
			if collecting_list and trimmed.begins_with("- "):
				var value := trimmed.substr(2).strip_edges()
				current["buildable_tiles"].append(value)
				continue
			
			if collecting_dict and line.begins_with("      ") and ":" in trimmed:
				var parts := trimmed.split(":", true, 1)
				if parts.size() == 2:
					var key := parts[0].strip_edges()
					var value := parts[1].strip_edges()
					current[current_dict_key][key] = int(value) if value.is_valid_int() else value
				continue
			
			if ":" in trimmed:
				var parts := trimmed.split(":", true, 1)
				if parts.size() == 2:
					var key := parts[0].strip_edges()
					var value := parts[1].strip_edges().trim_prefix('"').trim_suffix('"')
					current[key] = float(value) if value.is_valid_float() else value
					collecting_list = false
					collecting_dict = false
	
	# Don't forget the last entry
	_commit_resource_entry(entries, current)
	
	return entries


func _commit_resource_entry(entries: Array, current: Dictionary) -> void:
	if current.is_empty():
		return
	
	var key := current.get("key", "")
	if key.is_empty():
		return
	
	if not current.has("id"):
		current["id"] = key
	
	entries.append(current.duplicate())


func _rebuild_buildings_grid() -> void:
	if buildings_grid == null:
		return
	
	# Clear existing cards
	for child in buildings_grid.get_children():
		child.queue_free()
	
	if resource_card_scene == null:
		push_warning("Resource card scene is not set")
		return
	
	# Create cards for each city building
	for building in _city_buildings:
		var card := resource_card_scene.instantiate() as ResourceCard
		if card == null:
			continue
		
		buildings_grid.add_child(card)
		card.setup(building)
		
		card.build_requested.connect(func(res: GameResource) -> void:
			_on_building_selected(res)
		)


func _on_building_selected(building: GameResource) -> void:
	if building == null:
		return
	
	# Check if player can afford it
	if not _can_afford_building(building):
		_show_notification("Cannot afford " + building.title, "error")
		return
	
	# Add to construction queue
	_add_to_queue(building)
	_update_queue_display()
	_update_resource_display()
	
	emit_signal("building_queued", building.id)


func _can_afford_building(building: GameResource) -> bool:
	if _faction_system == null:
		return false
	
	for resource_key in building.build_cost.keys():
		var cost: int = building.build_cost[resource_key]
		var current_amount: int = 0
		
		if _faction_system.has_method("resource_amount"):
			current_amount = _faction_system.resource_amount(_current_faction, StringName(resource_key))
		
		if current_amount < cost:
			return false
	
	return true


func _add_to_queue(building: GameResource) -> void:
	# Deduct resources
	if _faction_system and _faction_system.has_method("add_resource"):
		for resource_key in building.build_cost.keys():
			var cost: int = building.build_cost[resource_key]
			_faction_system.add_resource(_current_faction, StringName(resource_key), -cost)
	
	# Add to queue
	var queue_item := {
		"building_id": building.id,
		"building_title": building.title,
		"remaining_hours": building.build_time_hours
	}
	_construction_queue.append(queue_item)


func _update_queue_display() -> void:
	if queue_list == null:
		return
	
	# Clear existing items
	for child in queue_list.get_children():
		child.queue_free()
	
	# Add queue items
	for i in range(_construction_queue.size()):
		var item: Dictionary = _construction_queue[i]
		var label := Label.new()
		
		var status: String = "Building" if i == 0 else "Queued"
		label.text = "%s: %s (%.1fh remaining)" % [status, item["building_title"], item["remaining_hours"]]
		
		queue_list.add_child(label)


func _update_resource_display() -> void:
	if resource_display == null or _faction_system == null:
		return
	
	# Clear existing displays
	for child in resource_display.get_children():
		child.queue_free()
	
	# Show food, coal, gold
	var resources := ["food", "coal", "gold"]
	for res_name in resources:
		var amount: int = 0
		if _faction_system.has_method("resource_amount"):
			amount = _faction_system.resource_amount(_current_faction, StringName(res_name))
		
		var label := Label.new()
		label.text = "%s: %d" % [res_name.capitalize(), amount]
		resource_display.add_child(label)


func _show_notification(message: String, type: String = "info") -> void:
	# Try to find notification system
	var notification_system = get_tree().get_first_node_in_group("notification_system")
	if notification_system and notification_system.has_method("show_notification"):
		notification_system.show_notification(message, type)
	else:
		print("[City Screen] ", message)


func show_screen() -> void:
	_is_visible = true
	visible = true
	
	_update_resource_display()
	_update_queue_display()
	_rebuild_buildings_grid()
	
	# Update city name
	if city_name_label:
		city_name_label.text = "City Management"
	
	if city_info_label:
		city_info_label.text = "Build and manage city buildings"


func hide_screen() -> void:
	_is_visible = false
	visible = false
	emit_signal("city_screen_closed")


func _on_close_pressed() -> void:
	hide_screen()


func set_city(axial: Vector2i, faction: StringName) -> void:
	_current_city_axial = axial
	_current_faction = faction
	
	if city_name_label:
		city_name_label.text = "City at (%d, %d)" % [axial.x, axial.y]
