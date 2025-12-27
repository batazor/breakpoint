extends Control
class_name BuildingUpgradePanel

## Simple panel for testing building upgrades
## Shows upgrade options for a selected building

signal upgrade_requested(axial: Vector2i, building_id: StringName)

@export var build_controller_path: NodePath
@export var faction_system_path: NodePath

var _build_controller: Node
var _faction_system: Node
var _current_axial: Vector2i = Vector2i(-1, -1)
var _current_building_id: StringName = StringName("")
var _current_resource: GameResource = null

@onready var panel: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var level_label: Label = $PanelContainer/VBoxContainer/LevelLabel
@onready var production_label: Label = $PanelContainer/VBoxContainer/ProductionLabel
@onready var upgrade_button: Button = $PanelContainer/VBoxContainer/UpgradeButton
@onready var cost_label: Label = $PanelContainer/VBoxContainer/CostLabel
@onready var time_label: Label = $PanelContainer/VBoxContainer/TimeLabel
@onready var close_button: Button = $PanelContainer/VBoxContainer/CloseButton


func _ready() -> void:
	_resolve_systems()
	hide_panel()
	
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	if close_button:
		close_button.pressed.connect(hide_panel)


func _resolve_systems() -> void:
	if not build_controller_path.is_empty():
		_build_controller = get_node_or_null(build_controller_path)
	else:
		_build_controller = get_tree().get_first_node_in_group("build_controller")
	
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path)
	else:
		_faction_system = get_tree().get_first_node_in_group("faction_system")


func show_for_building(axial: Vector2i, building_id: StringName, resource: GameResource) -> void:
	if resource == null or _build_controller == null:
		return
	
	_current_axial = axial
	_current_building_id = building_id
	_current_resource = resource
	
	var level := 1
	if _build_controller.has_method("get_building_level"):
		level = _build_controller.call("get_building_level", axial)
	
	_update_display(level)
	show_panel()


func show_panel() -> void:
	visible = true


func hide_panel() -> void:
	visible = false
	_current_axial = Vector2i(-1, -1)
	_current_building_id = StringName("")
	_current_resource = null


func _update_display(level: int) -> void:
	if _current_resource == null:
		return
	
	# Title
	if title_label:
		title_label.text = _current_resource.title
	
	# Level
	if level_label:
		level_label.text = "Level: %d / %d" % [level, _current_resource.max_level]
	
	# Current production
	if production_label:
		var delta := _current_resource.get_resource_delta_at_level(level)
		var parts: Array[String] = []
		for res_key in delta.keys():
			var amount: int = int(delta[res_key])
			var sign: String = "+" if amount >= 0 else ""
			parts.append("%s%d %s/hr" % [sign, amount, str(res_key)])
		production_label.text = "Production: " + ", ".join(parts)
	
	# Upgrade info
	var can_upgrade: bool = _current_resource.can_upgrade(level)
	
	if can_upgrade:
		var upgrade_cost := _current_resource.get_upgrade_cost(level)
		var upgrade_time := _current_resource.get_upgrade_time(level)
		
		# Cost
		if cost_label:
			var cost_parts: Array[String] = []
			for res_key in upgrade_cost.keys():
				var amount: int = int(upgrade_cost[res_key])
				cost_parts.append("%d %s" % [amount, str(res_key)])
			cost_label.text = "Cost: " + ", ".join(cost_parts)
			cost_label.visible = true
		
		# Time
		if time_label:
			time_label.text = "Time: %d hours" % upgrade_time
			time_label.visible = true
		
		# Next level production
		var next_delta := _current_resource.get_resource_delta_at_level(level + 1)
		var next_parts: Array[String] = []
		for res_key in next_delta.keys():
			var amount: int = int(next_delta[res_key])
			var sign: String = "+" if amount >= 0 else ""
			next_parts.append("%s%d %s/hr" % [sign, amount, str(res_key)])
		
		if upgrade_button:
			upgrade_button.text = "Upgrade to Level %d" % (level + 1)
			upgrade_button.disabled = false
			upgrade_button.tooltip_text = "After upgrade: " + ", ".join(next_parts)
	else:
		if cost_label:
			cost_label.visible = false
		if time_label:
			time_label.visible = false
		if upgrade_button:
			upgrade_button.text = "Max Level"
			upgrade_button.disabled = true
			upgrade_button.tooltip_text = "This building is already at maximum level"


func _on_upgrade_pressed() -> void:
	if _current_axial == Vector2i(-1, -1) or _current_resource == null:
		return
	
	if _build_controller == null or _faction_system == null:
		push_warning("Systems not available for upgrade")
		return
	
	# Get player faction
	var faction_id: StringName = StringName("kingdom")
	if _build_controller.has("faction_player"):
		faction_id = _build_controller.get("faction_player")
	
	# Try to upgrade
	var success: bool = false
	if _build_controller.has_method("upgrade_building"):
		success = _build_controller.call("upgrade_building", _current_axial, _current_resource, faction_id)
	
	if success:
		emit_signal("upgrade_requested", _current_axial, _current_building_id)
		print("Upgrade started for %s at %s" % [_current_resource.title, str(_current_axial)])
		hide_panel()
	else:
		print("Cannot upgrade: insufficient resources or already upgrading")
		# TODO: Show error message in UI
