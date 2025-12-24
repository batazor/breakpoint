extends "res://scripts/ai/faction_action.gd"
class_name FactionActionResourceGathering

## FactionAction that prioritizes resource gathering when faction resources are low.
## Evaluates faction resource levels and returns higher utility when resources are scarce.

@export var resource_type: StringName = &"food"
@export var low_threshold: int = 50
@export var critical_threshold: int = 20
@export var base_utility: float = 0.5


func evaluate(world_state: Dictionary) -> float:
	var faction_system = world_state.get("faction_system", null) as FactionSystem
	if faction_system == null:
		return 0.0
	
	var faction_id: StringName = world_state.get("faction_id", &"")
	if faction_id == StringName(""):
		return 0.0
	
	var current_amount := faction_system.resource_amount(faction_id, resource_type)
	
	# Higher utility when resources are lower
	if current_amount < critical_threshold:
		return base_utility * 2.0  # Critical need
	elif current_amount < low_threshold:
		return base_utility * 1.5  # High need
	elif current_amount < low_threshold * 2:
		return base_utility * 1.0  # Moderate need
	else:
		return base_utility * 0.3  # Low priority when resources are adequate
	
	return 0.0


func execute(world_state: Dictionary) -> void:
	super.execute(world_state)
	
	var faction_system = world_state.get("faction_system", null) as FactionSystem
	if faction_system == null:
		return
	
	var faction_id: StringName = world_state.get("faction_id", &"")
	if faction_id == StringName(""):
		return
	
	# AI could assign more NPCs to resource gathering roles
	# or prioritize building resource-producing structures
	print("[FactionActionResourceGathering] %s focusing on gathering %s" % [
		str(faction_id), 
		str(resource_type)
	])
	
	# Future: Actually assign NPCs to gathering tasks, build gatherer huts, etc.
	# For now, this marks the intent and logs the decision
