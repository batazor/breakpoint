extends Node
class_name FactionInteractionSystem

## Manages faction-to-faction interactions including trade, diplomacy, and conflict.
## Provides AI with utilities to evaluate and execute faction interactions.

enum InteractionType {
	TRADE,
	ALLIANCE_PROPOSAL,
	TERRITORY_DISPUTE,
	PEACE_OFFERING
}

signal interaction_proposed(proposer: StringName, target: StringName, type: InteractionType, data: Dictionary)
signal interaction_accepted(proposer: StringName, target: StringName, type: InteractionType)
signal interaction_rejected(proposer: StringName, target: StringName, type: InteractionType)

@export var faction_system_path: NodePath
@export var relationship_system_path: NodePath

var _faction_system: FactionSystem
var _relationship_system: FactionRelationshipSystem


func _ready() -> void:
	_resolve_nodes()


## Trade: Simple resource exchange between factions
func propose_trade(proposer: StringName, target: StringName, offer: Dictionary, request: Dictionary) -> bool:
	if _faction_system == null or _relationship_system == null:
		return false
	
	# Check if factions are hostile (no trade with enemies)
	if _relationship_system.is_hostile(proposer, target):
		print("[FactionInteraction] Trade rejected: %s and %s are hostile" % [str(proposer), str(target)])
		return false
	
	# Calculate utility for target faction
	var utility := _calculate_trade_utility(target, offer, request)
	
	# AI acceptance threshold
	var acceptance_threshold := 0.6
	if _relationship_system.is_allied(proposer, target):
		acceptance_threshold = 0.4  # More lenient for allies
	
	if utility >= acceptance_threshold:
		_execute_trade(proposer, target, offer, request)
		emit_signal("interaction_accepted", proposer, target, InteractionType.TRADE)
		
		# Improve relationship slightly
		_relationship_system.modify_relationship(proposer, target, 5.0)
		return true
	else:
		emit_signal("interaction_rejected", proposer, target, InteractionType.TRADE)
		return false


## Alliance: Propose forming an alliance
func propose_alliance(proposer: StringName, target: StringName) -> bool:
	if _relationship_system == null:
		return false
	
	# Can't ally with hostile factions
	if _relationship_system.is_hostile(proposer, target):
		print("[FactionInteraction] Alliance rejected: hostile relationship")
		emit_signal("interaction_rejected", proposer, target, InteractionType.ALLIANCE_PROPOSAL)
		return false
	
	# Already allied
	if _relationship_system.is_allied(proposer, target):
		return true
	
	# AI evaluation: accept if neutral with positive trend or if facing common threats
	var current_relation := _relationship_system.get_relationship_value(proposer, target)
	var should_accept := current_relation > 0.0  # Positive relations increase chance
	
	# Check for common enemies (increases alliance utility)
	var common_enemies := _count_common_enemies(proposer, target)
	if common_enemies > 0:
		should_accept = true
	
	if should_accept:
		_relationship_system.set_relationship(proposer, target, 50.0)  # Set to allied
		emit_signal("interaction_accepted", proposer, target, InteractionType.ALLIANCE_PROPOSAL)
		print("[FactionInteraction] Alliance formed: %s <-> %s" % [str(proposer), str(target)])
		return true
	else:
		emit_signal("interaction_rejected", proposer, target, InteractionType.ALLIANCE_PROPOSAL)
		return false


## Territory Dispute: Trigger warning before potential conflict
func raise_territory_dispute(faction_a: StringName, faction_b: StringName, disputed_tile: Vector2i) -> void:
	emit_signal("interaction_proposed", faction_a, faction_b, InteractionType.TERRITORY_DISPUTE, {
		"tile": disputed_tile
	})
	
	# Worsen relationship
	_relationship_system.modify_relationship(faction_a, faction_b, -15.0)
	
	print("[FactionInteraction] Territory dispute: %s vs %s at %s" % [
		str(faction_a), 
		str(faction_b),
		str(disputed_tile)
	])


## Peace Offering: Attempt to improve relations
func offer_peace(proposer: StringName, target: StringName, resource_offering: Dictionary) -> bool:
	if _faction_system == null or _relationship_system == null:
		return false
	
	# Check if we have the resources to offer
	for resource_id in resource_offering.keys():
		var amount: int = resource_offering[resource_id]
		var available := _faction_system.resource_amount(proposer, resource_id)
		if available < amount:
			return false  # Can't afford the offering
	
	# Transfer resources
	for resource_id in resource_offering.keys():
		var amount: int = resource_offering[resource_id]
		_faction_system.add_resource(proposer, resource_id, -amount)
		_faction_system.add_resource(target, resource_id, amount)
	
	# Improve relationship based on offering value
	var offering_value := _calculate_resource_value(resource_offering)
	var relation_improvement := minf(offering_value / 10.0, 30.0)
	_relationship_system.modify_relationship(proposer, target, relation_improvement)
	
	emit_signal("interaction_accepted", proposer, target, InteractionType.PEACE_OFFERING)
	print("[FactionInteraction] Peace offering: %s -> %s (value: %d)" % [
		str(proposer),
		str(target),
		offering_value
	])
	return true


func _execute_trade(proposer: StringName, target: StringName, offer: Dictionary, request: Dictionary) -> void:
	# Transfer offered resources from proposer to target
	for resource_id in offer.keys():
		var amount: int = offer[resource_id]
		_faction_system.add_resource(proposer, resource_id, -amount)
		_faction_system.add_resource(target, resource_id, amount)
	
	# Transfer requested resources from target to proposer
	for resource_id in request.keys():
		var amount: int = request[resource_id]
		_faction_system.add_resource(target, resource_id, -amount)
		_faction_system.add_resource(proposer, resource_id, amount)
	
	print("[FactionInteraction] Trade completed: %s <-> %s" % [str(proposer), str(target)])


func _calculate_trade_utility(faction_id: StringName, offer: Dictionary, request: Dictionary) -> float:
	## Calculate utility of a trade for the target faction
	## Returns value in [0, 1+] range
	
	var offer_value := _calculate_resource_value(offer)
	var request_value := _calculate_resource_value(request)
	
	# Check if faction can afford what's requested
	for resource_id in request.keys():
		var amount: int = request[resource_id]
		var available := _faction_system.resource_amount(faction_id, resource_id)
		if available < amount:
			return 0.0  # Can't afford, reject trade
	
	# Utility is the ratio of what we get vs what we give
	if request_value == 0:
		return 1.0  # Free resources, always accept
	
	return float(offer_value) / float(request_value)


func _calculate_resource_value(resources: Dictionary) -> int:
	## Simple resource valuation (could be made more sophisticated)
	var total_value := 0
	for resource_id in resources.keys():
		var amount: int = resources[resource_id]
		# Simple 1:1 valuation for now
		total_value += amount
	return total_value


func _count_common_enemies(faction_a: StringName, faction_b: StringName) -> int:
	if _relationship_system == null:
		return 0
	
	var count := 0
	var relations_a := _relationship_system.get_all_relationships_for_faction(faction_a)
	var relations_b := _relationship_system.get_all_relationships_for_faction(faction_b)
	
	for other_faction in relations_a.keys():
		if other_faction == faction_b:
			continue
		
		var rel_a: float = relations_a.get(other_faction, 0.0)
		var rel_b: float = relations_b.get(other_faction, 0.0)
		
		# Both factions are hostile to this third faction
		if rel_a < -30.0 and rel_b < -30.0:
			count += 1
	
	return count


func _resolve_nodes() -> void:
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path) as FactionSystem
	else:
		_faction_system = get_tree().get_first_node_in_group("faction_system") as FactionSystem
	
	if not relationship_system_path.is_empty():
		_relationship_system = get_node_or_null(relationship_system_path) as FactionRelationshipSystem
	else:
		_relationship_system = get_tree().get_first_node_in_group("faction_relationship_system") as FactionRelationshipSystem
