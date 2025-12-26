extends Control
class_name SelectionInfoPanel

## Displays detailed information about selected buildings or units
## Context-sensitive panel that appears when objects are selected

signal action_requested(action_name: String)

@export var faction_system_path: NodePath

@onready var panel_container: PanelContainer = %PanelContainer
@onready var title_label: Label = %TitleLabel
@onready var type_label: Label = %TypeLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var info_list: VBoxContainer = %InfoList
@onready var actions_container: HBoxContainer = %ActionsContainer

var _faction_system: Node
var _selected_object: Node = null
var _update_timer: float = 0.0
var _update_interval: float = 0.5


func _ready() -> void:
	_resolve_systems()
	hide_panel()


func _process(delta: float) -> void:
	if _selected_object != null and panel_container.visible:
		_update_timer += delta
		if _update_timer >= _update_interval:
			_update_timer = 0.0
			_update_display()


func _resolve_systems() -> void:
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path)
	if _faction_system == null:
		_faction_system = get_tree().get_first_node_in_group("faction_system")


func show_building_info(building: Node) -> void:
	_selected_object = building
	_display_building(building)
	show_panel()


func show_unit_info(unit: Node) -> void:
	_selected_object = unit
	_display_unit(unit)
	show_panel()


func hide_panel() -> void:
	if panel_container != null:
		panel_container.visible = false
	_selected_object = null


func show_panel() -> void:
	if panel_container != null:
		panel_container.visible = true


func _display_building(building: Node) -> void:
	if building == null:
		return
	
	# Title
	var building_name := "Building"
	if building.has_method("get_building_name"):
		building_name = building.call("get_building_name")
	elif "building_name" in building:
		building_name = building.building_name
	
	if title_label != null:
		title_label.text = building_name
	
	if type_label != null:
		type_label.text = "Building"
	
	# Health
	_update_health_display(building)
	
	# Info
	_clear_info_list()
	
	# Production info
	if building.has_method("get_production_info"):
		var production = building.call("get_production_info")
		if production != null:
			_add_info_item("Production:", str(production))
	
	# Owner info
	if "faction_id" in building:
		_add_info_item("Owner:", str(building.faction_id).capitalize())
	
	# Actions
	_setup_building_actions(building)


func _display_unit(unit: Node) -> void:
	if unit == null:
		return
	
	# Title
	var unit_name := "Unit"
	if unit.has_method("get_unit_name"):
		unit_name = unit.call("get_unit_name")
	elif "unit_name" in unit:
		unit_name = unit.unit_name
	elif "character_name" in unit:
		unit_name = unit.character_name
	
	if title_label != null:
		title_label.text = unit_name
	
	# Type/Role
	var role := "Unknown"
	if unit.has_method("get_role"):
		role = unit.call("get_role")
	elif "role" in unit:
		role = unit.role
	
	if type_label != null:
		type_label.text = role.capitalize()
	
	# Health
	_update_health_display(unit)
	
	# Info
	_clear_info_list()
	
	# Current action
	if unit.has_method("get_current_action"):
		var action = unit.call("get_current_action")
		_add_info_item("Action:", str(action).capitalize() if action else "Idle")
	
	# Owner info
	if "faction_id" in unit:
		_add_info_item("Faction:", str(unit.faction_id).capitalize())
	
	# Actions
	_setup_unit_actions(unit)


func _update_display() -> void:
	if _selected_object == null:
		return
	
	if _is_building(_selected_object):
		_display_building(_selected_object)
	else:
		_display_unit(_selected_object)


func _update_health_display(obj: Node) -> void:
	var current_health := 100
	var max_health := 100
	
	if obj.has_method("get_health"):
		current_health = obj.call("get_health")
	elif "health" in obj:
		current_health = obj.health
	
	if obj.has_method("get_max_health"):
		max_health = obj.call("get_max_health")
	elif "max_health" in obj:
		max_health = obj.max_health
	
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	if health_label != null:
		health_label.text = "%d / %d HP" % [current_health, max_health]


func _clear_info_list() -> void:
	if info_list == null:
		return
	
	for child in info_list.get_children():
		child.queue_free()


func _add_info_item(label_text: String, value_text: String = "") -> void:
	if info_list == null:
		return
	
	var hbox := HBoxContainer.new()
	
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	if value_text != "":
		var value := Label.new()
		value.text = value_text
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(value)
	
	info_list.add_child(hbox)


func _setup_building_actions(building: Node) -> void:
	_clear_actions()
	
	# Add common building actions
	_add_action_button("Destroy", func() -> void: _on_action_destroy(building))


func _setup_unit_actions(unit: Node) -> void:
	_clear_actions()
	
	# Add common unit actions
	_add_action_button("Move", func() -> void: _on_action_move(unit))
	_add_action_button("Dismiss", func() -> void: _on_action_dismiss(unit))


func _clear_actions() -> void:
	if actions_container == null:
		return
	
	for child in actions_container.get_children():
		child.queue_free()


func _add_action_button(action_name: String, callback: Callable) -> void:
	if actions_container == null:
		return
	
	var button := Button.new()
	button.text = action_name
	button.pressed.connect(callback)
	actions_container.add_child(button)


func _on_action_destroy(building: Node) -> void:
	emit_signal("action_requested", "destroy")
	if building != null and building.has_method("destroy"):
		building.call("destroy")
	hide_panel()


func _on_action_move(unit: Node) -> void:
	emit_signal("action_requested", "move")
	# Movement would be handled by the player interaction system
	hide_panel()


func _on_action_dismiss(unit: Node) -> void:
	emit_signal("action_requested", "dismiss")
	if unit != null and unit.has_method("dismiss"):
		unit.call("dismiss")
	hide_panel()


func _is_building(obj: Node) -> bool:
	# Check if object is a building
	return obj.has_method("get_building_name") or "building_name" in obj
