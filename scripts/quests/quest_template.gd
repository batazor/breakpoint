extends Resource
class_name QuestTemplate

## Template for generating quests with context
## Supports procedural quest creation from patterns and game state

@export var title_pattern: String = ""
@export var description_pattern: String = ""
@export var objective_type: String = ""
@export var reward_scale: float = 1.0
@export var category: String = "side"
@export var faction_id: StringName = &""

var config: Dictionary = {}


func _init(initial_config: Dictionary = {}) -> void:
	config = initial_config
	if config.has("title_pattern"):
		title_pattern = config["title_pattern"]
	if config.has("description_pattern"):
		description_pattern = config["description_pattern"]
	if config.has("objective_type"):
		objective_type = config["objective_type"]
	if config.has("reward_scale"):
		reward_scale = config["reward_scale"]
	if config.has("category"):
		category = config["category"]
	if config.has("faction_id"):
		faction_id = config["faction_id"]


func instantiate(context: Dictionary) -> Quest:
	## Create a quest instance from this template with given context
	var quest = Quest.new()
	quest.id = StringName("dynamic_%d" % Time.get_ticks_msec())
	quest.category = category
	
	# Fill in template placeholders with context
	quest.title = _fill_pattern(title_pattern, context)
	quest.description = _fill_pattern(description_pattern, context)
	
	# Generate objectives based on type and context
	var objective = QuestObjective.new()
	objective.type = objective_type
	objective.id = "%s_obj_1" % quest.id
	
	match objective_type:
		"gather":
			objective.target = context.get("resource_id", "gold")
			objective.count = context.get("target_amount", 100)
			objective.description = "Gather %d %s" % [objective.count, objective.target]
		
		"build":
			objective.target = context.get("building_id", "fortress")
			objective.count = 1
			objective.description = "Build 1 %s" % objective.target
		
		"relationship":
			objective.target = context.get("faction2", "")
			objective.value = context.get("target_relationship", 50.0)
			objective.description = "Achieve relationship %d with %s" % [int(objective.value), objective.target]
		
		"talk":
			objective.target = context.get("npc_id", "")
			objective.count = 1
			objective.description = "Talk to %s" % objective.target
		
		"explore":
			objective.target = context.get("location_type", "any")
			objective.count = context.get("location_count", 1)
			objective.description = "Explore %d %s location(s)" % [objective.count, objective.target]
	
	quest.objectives.append(objective)
	
	# Calculate rewards based on difficulty and context
	quest.rewards = _calculate_rewards(context, reward_scale)
	quest.faction_id = context.get("faction_id", &"kingdom")
	
	return quest


func _fill_pattern(pattern: String, context: Dictionary) -> String:
	## Replace {placeholder} with values from context
	var result = pattern
	for key in context:
		var placeholder = "{%s}" % key
		if result.contains(placeholder):
			result = result.replace(placeholder, str(context[key]))
	return result


func _calculate_rewards(context: Dictionary, scale: float) -> Dictionary:
	## Calculate appropriate rewards based on quest difficulty
	var base_gold = 50
	var rewards = {}
	
	# Scale rewards based on context
	if context.has("target_amount"):
		rewards["gold"] = int(base_gold * scale * (context["target_amount"] / 100.0))
	else:
		rewards["gold"] = int(base_gold * scale)
	
	# Ensure minimum reward
	if rewards["gold"] < 10:
		rewards["gold"] = 10
	
	return rewards
