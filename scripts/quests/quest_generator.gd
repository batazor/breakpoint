extends Node
class_name QuestGenerator

## Generates quests dynamically based on game events
## Implements event-driven quest generation for sandbox gameplay

signal quest_generated(quest: Quest)

var quest_templates: Dictionary = {}  # template_id -> QuestTemplate
var last_quest_time: float = 0.0
var min_quest_interval: float = 300.0  # 5 minutes between auto-generated quests


func _ready() -> void:
	_load_templates()
	_connect_to_game_events()


func _connect_to_game_events() -> void:
	## Connect to game systems to listen for quest-triggering events
	
	# Resource events
	var faction_system = get_node_or_null("/root/Main/FactionSystem")
	if faction_system:
		if faction_system.has_signal("resources_changed"):
			faction_system.resources_changed.connect(_on_resources_changed)
	
	# Building events
	var build_controller = get_node_or_null("/root/Main/BuildController")
	if build_controller:
		if build_controller.has_signal("building_placed"):
			build_controller.building_placed.connect(_on_building_placed)
		if build_controller.has_signal("building_destroyed"):
			build_controller.building_destroyed.connect(_on_building_destroyed)
	
	# Faction events (if available)
	var faction_relationship_system = get_node_or_null("/root/Main/FactionRelationshipSystem")
	if faction_relationship_system:
		if faction_relationship_system.has_signal("relationship_changed"):
			faction_relationship_system.relationship_changed.connect(_on_relationship_changed)
	
	# Time events (if available)
	var day_night_cycle = get_node_or_null("/root/Main/DayNightCycle")
	if day_night_cycle:
		if day_night_cycle.has_signal("hour_changed"):
			day_night_cycle.hour_changed.connect(_on_hour_changed)


func _on_resources_changed(faction_id: StringName, resource_id: StringName, amount: int) -> void:
	## Generate quests based on resource state
	var faction_system = get_node_or_null("/root/Main/FactionSystem")
	if not faction_system:
		return
	
	# Only generate quests for player faction
	if faction_id != &"kingdom":
		return
	
	if not faction_system.has_method("resource_amount"):
		return
	
	var current_amount = faction_system.resource_amount(faction_id, resource_id)
	
	# Resource scarcity quest - only if enough time has passed
	if current_amount < 50 and _can_generate_quest():
		var quest = _generate_from_template("resource_scarcity", {
			"resource_id": resource_id,
			"resource_name": resource_id.capitalize(),
			"target_amount": 100,
			"faction_id": faction_id
		})
		if quest:
			_mark_quest_generated()
			quest_generated.emit(quest)


func _on_building_placed(building_id: String, position: Vector2i) -> void:
	## Track building events for potential quest generation
	# Could generate expansion or upgrade quests in the future
	pass


func _on_building_destroyed(building_id: String, position: Vector2i, faction_id: StringName) -> void:
	## Generate rebuild quest when important buildings are destroyed
	if building_id in ["fortress", "mine", "well"]:
		var quest = _generate_from_template("rebuild_structure", {
			"building_id": building_id,
			"building_name": building_id.capitalize(),
			"position": position,
			"faction_id": faction_id
		})
		if quest:
			quest_generated.emit(quest)


func _on_relationship_changed(faction1: StringName, faction2: StringName, old_value: int, new_value: int) -> void:
	## Generate diplomacy quests based on relationship changes
	
	# Relationship improved significantly
	if new_value > old_value + 20 and new_value > 50:
		var quest = _generate_from_template("alliance_opportunity", {
			"faction1": faction1,
			"faction2": faction2,
			"faction_name": faction2.capitalize(),
			"relationship": new_value,
			"target_relationship": 75.0
		})
		if quest:
			quest_generated.emit(quest)
	
	# Relationship deteriorated significantly
	elif new_value < old_value - 20 and new_value < -50:
		var quest = _generate_from_template("conflict_resolution", {
			"faction1": faction1,
			"faction2": faction2,
			"faction_name": faction2.capitalize(),
			"relationship": new_value,
			"target_relationship": -25.0
		})
		if quest:
			quest_generated.emit(quest)


func _on_hour_changed(hour: int) -> void:
	## Handle time-based quest generation
	# Could be used for daily quests or time-sensitive events
	pass


func _generate_from_template(template_id: String, context: Dictionary) -> Quest:
	## Generate a quest instance from a template with given context
	if not quest_templates.has(template_id):
		push_error("Quest template not found: %s" % template_id)
		return null
	
	var template: QuestTemplate = quest_templates[template_id]
	return template.instantiate(context)


func _load_templates() -> void:
	## Load quest templates
	# Templates define quest structure with placeholders for context
	quest_templates["resource_scarcity"] = QuestTemplate.new({
		"title_pattern": "Gather {resource_name}",
		"description_pattern": "Your {resource_name} reserves are critically low. Gather {target_amount} {resource_name} to stabilize your economy.",
		"objective_type": "gather",
		"reward_scale": 1.5,
		"category": "dynamic"
	})
	
	quest_templates["rebuild_structure"] = QuestTemplate.new({
		"title_pattern": "Rebuild {building_name}",
		"description_pattern": "Your {building_name} has been destroyed. Rebuild it to restore production.",
		"objective_type": "build",
		"reward_scale": 1.0,
		"category": "dynamic"
	})
	
	quest_templates["alliance_opportunity"] = QuestTemplate.new({
		"title_pattern": "Strengthen Alliance with {faction_name}",
		"description_pattern": "Your improving relationship with {faction_name} opens opportunities for cooperation.",
		"objective_type": "relationship",
		"reward_scale": 2.0,
		"category": "faction"
	})
	
	quest_templates["conflict_resolution"] = QuestTemplate.new({
		"title_pattern": "Resolve Conflict with {faction_name}",
		"description_pattern": "Tensions with {faction_name} are escalating. Take action to prevent war.",
		"objective_type": "relationship",
		"reward_scale": 1.5,
		"category": "faction"
	})
	
	quest_templates["exploration_quest"] = QuestTemplate.new({
		"title_pattern": "Explore the Unknown",
		"description_pattern": "Venture into unexplored territories to expand your knowledge of the land.",
		"objective_type": "explore",
		"reward_scale": 1.2,
		"category": "dynamic"
	})


func _can_generate_quest() -> bool:
	## Check if enough time has passed since last quest generation
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - last_quest_time) >= min_quest_interval


func _mark_quest_generated() -> void:
	## Mark that a quest was generated
	last_quest_time = Time.get_ticks_msec() / 1000.0
