extends "res://scripts/ai/faction_action.gd"
class_name FactionActionDefense

## FactionAction that prioritizes defense when faction has hostile relationships
## or when territory is threatened.

@export var base_utility: float = 0.4
@export var hostile_multiplier: float = 2.0


func evaluate(world_state: Dictionary) -> float:
	var faction_system = world_state.get("faction_system", null) as FactionSystem
	if faction_system == null:
		return 0.0
	
	var faction_id: StringName = world_state.get("faction_id", &"")
	if faction_id == StringName(""):
		return 0.0
	
	# Check if faction has hostile relationships
	var faction = faction_system.factions.get(faction_id, null)
	if faction == null:
		return 0.0
	
	var hostile_count := 0
	var total_relations := 0
	
	for other_faction_id in faction.relations.keys():
		total_relations += 1
		var relation_value: float = faction.relations.get(other_faction_id, 0.0)
		if relation_value < -30.0:  # Hostile threshold
			hostile_count += 1
	
	# Higher utility when we have hostile neighbors
	if hostile_count > 0:
		return base_utility * hostile_multiplier * float(hostile_count)
	elif total_relations > 0:
		return base_utility * 0.5  # Some defensive posture always needed
	else:
		return base_utility * 0.3  # Minimal defense when isolated
	
	return 0.0


func execute(world_state: Dictionary) -> void:
	super.execute(world_state)
	
	var faction_id: StringName = world_state.get("faction_id", &"")
	if faction_id == StringName(""):
		return
	
	print("[FactionActionDefense] %s strengthening defenses" % str(faction_id))
	
	# Future: Build defensive structures, position units strategically
	# For now, marks defensive intent
