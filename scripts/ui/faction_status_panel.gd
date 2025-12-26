extends Control
class_name FactionStatusPanel

## Detailed faction information panel that can be toggled with F key
## Shows faction stats, relationships, production summary, and territory info

signal panel_toggled(visible: bool)

@export var faction_system_path: NodePath
@export var territory_system_path: NodePath
@export var economy_system_path: NodePath

@onready var panel_container: PanelContainer = %PanelContainer
@onready var faction_name_label: Label = %FactionNameLabel
@onready var stats_grid: GridContainer = %StatsGrid
@onready var relationships_list: VBoxContainer = %RelationshipsList
@onready var production_list: VBoxContainer = %ProductionList

var _faction_system: Node
var _territory_system: Node
var _economy_system: Node
var _player_faction: StringName = &"kingdom"
var _is_visible: bool = false


func _ready() -> void:
	_resolve_systems()
	_setup_ui()
	hide_panel()
	
	# Connect to input
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_faction_panel"):
		toggle_panel()
		get_viewport().set_input_as_handled()


func _resolve_systems() -> void:
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path)
	if _faction_system == null:
		_faction_system = get_tree().get_first_node_in_group("faction_system")
	
	if not territory_system_path.is_empty():
		_territory_system = get_node_or_null(territory_system_path)
	if _territory_system == null:
		_territory_system = get_tree().get_first_node_in_group("territory_system")
	
	if not economy_system_path.is_empty():
		_economy_system = get_node_or_null(economy_system_path)
	if _economy_system == null:
		_economy_system = get_tree().get_first_node_in_group("economy_system")


func _setup_ui() -> void:
	if panel_container != null:
		panel_container.visible = false


func toggle_panel() -> void:
	_is_visible = not _is_visible
	if _is_visible:
		show_panel()
	else:
		hide_panel()


func show_panel() -> void:
	_is_visible = true
	if panel_container != null:
		panel_container.visible = true
		_update_display()
	emit_signal("panel_toggled", true)


func hide_panel() -> void:
	_is_visible = false
	if panel_container != null:
		panel_container.visible = false
	emit_signal("panel_toggled", false)


func _update_display() -> void:
	_update_faction_name()
	_update_stats()
	_update_relationships()
	_update_production()


func _update_faction_name() -> void:
	if faction_name_label == null:
		return
	
	faction_name_label.text = str(_player_faction).capitalize()


func _update_stats() -> void:
	if stats_grid == null or _faction_system == null:
		return
	
	# Clear existing stats
	for child in stats_grid.get_children():
		child.queue_free()
	
	# Get resources
	var food := _get_resource_amount("food")
	var coal := _get_resource_amount("coal")
	var gold := _get_resource_amount("gold")
	
	# Get territory count
	var territory := 0
	if _territory_system != null and _territory_system.has_method("get_faction_territory_count"):
		territory = _territory_system.call("get_faction_territory_count", _player_faction)
	
	# Get building count
	var buildings := _get_building_count()
	
	# Add stat rows
	_add_stat_row("Resources:")
	_add_stat_row("  🍎 Food:", str(food))
	_add_stat_row("  ⛏️ Coal:", str(coal))
	_add_stat_row("  💰 Gold:", str(gold))
	_add_stat_row("Territory:", str(territory) + " hexes")
	_add_stat_row("Buildings:", str(buildings))


func _update_relationships() -> void:
	if relationships_list == null or _faction_system == null:
		return
	
	# Clear existing relationships
	for child in relationships_list.get_children():
		child.queue_free()
	
	# Get all factions
	var all_factions := []
	if _faction_system.has_method("get_all_faction_ids"):
		all_factions = _faction_system.call("get_all_faction_ids")
	
	# Add relationship entries
	for faction_id in all_factions:
		if faction_id == _player_faction:
			continue
		
		var relationship := _get_relationship(faction_id)
		var status := _get_relationship_status(relationship)
		var color := _get_relationship_color(status)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		
		var name_label := Label.new()
		name_label.text = str(faction_id).capitalize()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)
		
		var status_label := Label.new()
		status_label.text = "%s (%d)" % [status, relationship]
		status_label.add_theme_color_override("font_color", color)
		hbox.add_child(status_label)
		
		relationships_list.add_child(hbox)


func _update_production() -> void:
	if production_list == null:
		return
	
	# Clear existing production info
	for child in production_list.get_children():
		child.queue_free()
	
	# Add production summary
	var production_label := Label.new()
	production_label.text = "Resource Production:"
	production_list.add_child(production_label)
	
	# This would be enhanced with actual production data
	var info_label := Label.new()
	info_label.text = "See resource rates in top HUD"
	info_label.add_theme_font_size_override("font_size", 12)
	production_list.add_child(info_label)


func _add_stat_row(label_text: String, value_text: String = "") -> void:
	var label := Label.new()
	label.text = label_text
	stats_grid.add_child(label)
	
	if value_text != "":
		var value := Label.new()
		value.text = value_text
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats_grid.add_child(value)


func _get_resource_amount(resource_id: String) -> int:
	if _faction_system == null or not _faction_system.has_method("resource_amount"):
		return 0
	return int(_faction_system.call("resource_amount", _player_faction, StringName(resource_id)))


func _get_building_count() -> int:
	if _faction_system == null or not _faction_system.has_method("get_faction_buildings"):
		return 0
	var buildings = _faction_system.call("get_faction_buildings", _player_faction)
	return buildings.size() if buildings != null else 0


func _get_relationship(faction_id: StringName) -> int:
	if _faction_system == null:
		return 0
	
	# Try to get relationship system
	var relationship_system = get_tree().get_first_node_in_group("faction_relationship_system")
	if relationship_system != null and relationship_system.has_method("get_relationship"):
		return relationship_system.call("get_relationship", _player_faction, faction_id)
	
	return 0


func _get_relationship_status(value: int) -> String:
	if value > 30:
		return "Allied"
	elif value < -30:
		return "Hostile"
	else:
		return "Neutral"


func _get_relationship_color(status: String) -> Color:
	match status:
		"Allied":
			return Color.GREEN
		"Hostile":
			return Color.RED
		"Neutral":
			return Color.YELLOW
		_:
			return Color.WHITE


func set_player_faction(faction_id: StringName) -> void:
	_player_faction = faction_id
	if _is_visible:
		_update_display()
