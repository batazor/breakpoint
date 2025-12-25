extends "res://scripts/ai/faction_action.gd"
class_name FactionActionExpansion

## FactionAction that evaluates and executes territorial expansion.
## Higher utility when faction has few buildings/territory but adequate resources.

@export var min_buildings_threshold: int = 3
@export var resource_reserve_threshold: int = 100
@export var base_utility: float = 0.6


func evaluate(world_state: Dictionary) -> float:
	var faction_system = world_state.get("faction_system", null) as FactionSystem
	if faction_system == null:
		return 0.0
	
	var faction_id: StringName = world_state.get("faction_id", &"")
	if faction_id == StringName(""):
		return 0.0
	
	# Count faction's buildings
	var building_count := 0
	for building_id in faction_system.building_owner.keys():
		if faction_system.building_owner[building_id] == faction_id:
			building_count += 1
	
	# Check if faction has adequate resources for expansion
	var food_amount := faction_system.resource_amount(faction_id, &"food")
	var coal_amount := faction_system.resource_amount(faction_id, &"coal")
	var gold_amount := faction_system.resource_amount(faction_id, &"gold")
	
	var total_resources := food_amount + coal_amount + gold_amount
	
	# Higher utility when we have few buildings but good resources
	if building_count < min_buildings_threshold and total_resources > resource_reserve_threshold:
		return base_utility * 2.0  # Strong expansion need
	elif building_count < min_buildings_threshold * 2 and total_resources > resource_reserve_threshold / 2:
		return base_utility * 1.3  # Moderate expansion
	elif total_resources > resource_reserve_threshold * 2:
		return base_utility * 1.0  # Have resources, can expand
	else:
		return base_utility * 0.2  # Low priority
	
	return 0.0


func execute(world_state: Dictionary) -> void:
	super.execute(world_state)
	
	var faction_id: StringName = world_state.get("faction_id", &"")
	if faction_id == StringName(""):
		return
	
	print("[FactionActionExpansion] %s planning territorial expansion" % str(faction_id))
	
	# Future: Actually search for good expansion sites, queue building construction
	# For now, this marks the expansion intent
