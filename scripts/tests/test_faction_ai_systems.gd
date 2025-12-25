extends SceneTree

## Comprehensive tests for Phase 2.2 Faction & AI Systems
## Tests faction relationships, territory, AI actions, and interactions

const Faction = preload("res://scripts/faction.gd")
const FactionSystem = preload("res://scripts/faction_system.gd")
const FactionRelationshipSystem = preload("res://scripts/faction_relationship_system.gd")
const FactionTerritorySystem = preload("res://scripts/faction_territory_system.gd")
const FactionInteractionSystem = preload("res://scripts/faction_interaction_system.gd")
const FactionAI = preload("res://scripts/ai/faction_ai.gd")
const FactionActionResourceGathering = preload("res://scripts/ai/faction_action_resource_gathering.gd")
const FactionActionExpansion = preload("res://scripts/ai/faction_action_expansion.gd")
const FactionActionDefense = preload("res://scripts/ai/faction_action_defense.gd")

var failures: int = 0
var tests_run: int = 0


func _initialize() -> void:
	print("=== Starting Phase 2.2 Faction & AI System Tests ===\n")
	
	# Test groups
	_test_faction_relationships()
	_test_faction_territory()
	_test_ai_actions()
	_test_faction_interactions()
	
	# Summary
	print("\n=== Test Summary ===")
	print("Tests run: %d" % tests_run)
	print("Failures: %d" % failures)
	
	if failures == 0:
		print("✅ All tests passed!")
		quit()
	else:
		push_error("❌ %d tests failed" % failures)
		quit(1)


func _test_faction_relationships() -> void:
	print("--- Testing Faction Relationships ---")
	
	var faction_system := FactionSystem.new()
	var rel_system := FactionRelationshipSystem.new()
	rel_system._faction_system = faction_system
	
	# Create test factions
	var faction_a := Faction.new()
	faction_a.id = &"faction_a"
	faction_a.relations = {}
	
	var faction_b := Faction.new()
	faction_b.id = &"faction_b"
	faction_b.relations = {}
	
	faction_system.factions[&"faction_a"] = faction_a
	faction_system.factions[&"faction_b"] = faction_b
	
	# Test 1: Default relationship is neutral
	_assert(rel_system.get_relationship_value(&"faction_a", &"faction_b") == 0.0,
		"Default relationship should be 0.0")
	_assert(rel_system.is_neutral(&"faction_a", &"faction_b"),
		"Default state should be neutral")
	
	# Test 2: Set hostile relationship
	rel_system.set_relationship(&"faction_a", &"faction_b", -50.0)
	_assert(rel_system.get_relationship_value(&"faction_a", &"faction_b") == -50.0,
		"Relationship should be -50.0")
	_assert(rel_system.is_hostile(&"faction_a", &"faction_b"),
		"State should be hostile")
	
	# Test 3: Set allied relationship
	rel_system.set_relationship(&"faction_a", &"faction_b", 60.0)
	_assert(rel_system.get_relationship_value(&"faction_a", &"faction_b") == 60.0,
		"Relationship should be 60.0")
	_assert(rel_system.is_allied(&"faction_a", &"faction_b"),
		"State should be allied")
	
	# Test 4: Modify relationship
	rel_system.set_relationship(&"faction_a", &"faction_b", 0.0)
	rel_system.modify_relationship(&"faction_a", &"faction_b", 15.0)
	_assert(rel_system.get_relationship_value(&"faction_a", &"faction_b") == 15.0,
		"Modified relationship should be 15.0")
	
	# Test 5: Clamping to bounds
	rel_system.set_relationship(&"faction_a", &"faction_b", 150.0)
	_assert(rel_system.get_relationship_value(&"faction_a", &"faction_b") == 100.0,
		"Relationship should clamp to 100.0")
	
	rel_system.set_relationship(&"faction_a", &"faction_b", -150.0)
	_assert(rel_system.get_relationship_value(&"faction_a", &"faction_b") == -100.0,
		"Relationship should clamp to -100.0")
	
	# Test 6: Symmetrical relationships
	rel_system.set_relationship(&"faction_a", &"faction_b", 25.0)
	_assert(rel_system.get_relationship_value(&"faction_b", &"faction_a") == 25.0,
		"Relationship should be symmetrical")
	
	print("Relationship tests completed\n")


func _test_faction_territory() -> void:
	print("--- Testing Faction Territory ---")
	
	var faction_system := FactionSystem.new()
	var territory_system := FactionTerritorySystem.new()
	territory_system._faction_system = faction_system
	territory_system.base_influence = 100.0
	
	# Create test faction
	var faction := Faction.new()
	faction.id = &"test_faction"
	faction_system.factions[&"test_faction"] = faction
	
	# Register a building at position
	var building_pos := Vector2i(5, 5)
	faction_system.register_building(&"building_1", &"test_faction", &"fortress", [], building_pos)
	
	# Test 1: Calculate influence from building
	territory_system._calculate_influence_from_building(building_pos, &"test_faction")
	var center_influence := territory_system.get_tile_influence(building_pos, &"test_faction")
	_assert(center_influence > 0.0,
		"Building center should have influence")
	
	# Test 2: Influence decreases with distance
	var adjacent_pos := Vector2i(6, 5)
	var adjacent_influence := territory_system.get_tile_influence(adjacent_pos, &"test_faction")
	_assert(adjacent_influence > 0.0 and adjacent_influence < center_influence,
		"Adjacent tile should have less influence than center")
	
	# Test 3: Hex ring generation
	var ring_0 := territory_system._get_hex_ring(Vector2i(0, 0), 0)
	_assert(ring_0.size() == 1,
		"Ring 0 should have 1 tile")
	
	var ring_1 := territory_system._get_hex_ring(Vector2i(0, 0), 1)
	_assert(ring_1.size() == 6,
		"Ring 1 should have 6 tiles")
	
	# Test 4: Territory ownership
	territory_system.recalculate_all_territory()
	var owner := territory_system.get_tile_owner(building_pos)
	_assert(owner == &"test_faction",
		"Building position should be owned by faction")
	
	# Test 5: Territory count
	var territory_count := territory_system.get_faction_territory_count(&"test_faction")
	_assert(territory_count > 0,
		"Faction should control some territory")
	
	print("Territory tests completed\n")


func _test_ai_actions() -> void:
	print("--- Testing AI Actions ---")
	
	var faction_system := FactionSystem.new()
	
	# Create test faction
	var faction := Faction.new()
	faction.id = &"ai_faction"
	faction.resources = {
		"food": 20,  # Low food (critical)
		"coal": 100,
		"gold": 50
	}
	faction_system.factions[&"ai_faction"] = faction
	
	var world_state := {
		"faction_id": &"ai_faction",
		"faction_system": faction_system,
		"now": 0.0
	}
	
	# Test 1: Resource Gathering Action evaluates correctly
	var resource_action := FactionActionResourceGathering.new()
	resource_action.resource_type = &"food"
	resource_action.critical_threshold = 20
	resource_action.low_threshold = 50
	resource_action.base_utility = 0.5
	
	var utility := resource_action.evaluate(world_state)
	_assert(utility > 0.5,
		"Resource gathering should have high utility when food is critical")
	
	# Test with adequate resources
	faction.resources["food"] = 150
	var utility_adequate := resource_action.evaluate(world_state)
	_assert(utility_adequate < utility,
		"Resource gathering utility should be lower when resources are adequate")
	
	# Test 2: Expansion Action
	faction.resources["food"] = 100
	faction.resources["coal"] = 100
	faction.resources["gold"] = 100
	
	var expansion_action := FactionActionExpansion.new()
	expansion_action.min_buildings_threshold = 3
	expansion_action.resource_reserve_threshold = 100
	expansion_action.base_utility = 0.6
	
	# With no buildings and good resources
	var expansion_utility := expansion_action.evaluate(world_state)
	_assert(expansion_utility > 0.6,
		"Expansion should have high utility with few buildings and good resources")
	
	# Add some buildings
	faction_system.register_building(&"b1", &"ai_faction", &"fortress")
	faction_system.register_building(&"b2", &"ai_faction", &"fortress")
	faction_system.register_building(&"b3", &"ai_faction", &"fortress")
	
	var expansion_utility_with_buildings := expansion_action.evaluate(world_state)
	_assert(expansion_utility_with_buildings < expansion_utility,
		"Expansion utility should decrease with more buildings")
	
	# Test 3: Defense Action
	faction.relations = {
		&"enemy_faction": -60.0,  # Hostile
		&"neutral_faction": 0.0
	}
	
	var defense_action := FactionActionDefense.new()
	defense_action.base_utility = 0.4
	defense_action.hostile_multiplier = 2.0
	
	var defense_utility := defense_action.evaluate(world_state)
	_assert(defense_utility > 0.4,
		"Defense should have high utility with hostile neighbors")
	
	# Test 4: Cooldown factor
	resource_action.cooldown = 10.0
	resource_action.last_executed = -INF
	var cooldown_factor_fresh := resource_action.cooldown_factor(0.0)
	_assert(cooldown_factor_fresh == 1.0,
		"Fresh action should have cooldown factor of 1.0")
	
	resource_action.last_executed = 0.0
	var cooldown_factor_recent := resource_action.cooldown_factor(5.0)
	_assert(cooldown_factor_recent < 1.0,
		"Recently executed action should have reduced cooldown factor")
	
	# Test 5: Inertia factor
	resource_action.id = &"gather"
	resource_action.inertia_bias = 0.15
	var inertia_same := resource_action.inertia_factor(&"gather")
	_assert(inertia_same == 1.0,
		"Same action should have inertia factor of 1.0")
	
	var inertia_different := resource_action.inertia_factor(&"expand")
	_assert(inertia_different < 1.0,
		"Different action should have reduced inertia factor")
	
	print("AI action tests completed\n")


func _test_faction_interactions() -> void:
	print("--- Testing Faction Interactions ---")
	
	var faction_system := FactionSystem.new()
	var rel_system := FactionRelationshipSystem.new()
	rel_system._faction_system = faction_system
	
	var interaction_system := FactionInteractionSystem.new()
	interaction_system._faction_system = faction_system
	interaction_system._relationship_system = rel_system
	
	# Create test factions
	var faction_a := Faction.new()
	faction_a.id = &"trader_a"
	faction_a.resources = {
		"food": 100,
		"coal": 50,
		"gold": 200
	}
	faction_a.relations = {}
	
	var faction_b := Faction.new()
	faction_b.id = &"trader_b"
	faction_b.resources = {
		"food": 50,
		"coal": 200,
		"gold": 100
	}
	faction_b.relations = {}
	
	faction_system.factions[&"trader_a"] = faction_a
	faction_system.factions[&"trader_b"] = faction_b
	
	# Set neutral relationship
	rel_system.set_relationship(&"trader_a", &"trader_b", 0.0)
	
	# Test 1: Trade with fair exchange
	var offer := {"food": 20}
	var request := {"coal": 20}
	var trade_result := interaction_system.propose_trade(&"trader_a", &"trader_b", offer, request)
	_assert(trade_result,
		"Fair trade should be accepted")
	_assert(faction_system.resource_amount(&"trader_a", &"food") == 80,
		"Trader A should have less food after trade")
	_assert(faction_system.resource_amount(&"trader_b", &"food") == 70,
		"Trader B should have more food after trade")
	
	# Test 2: Trade with hostile faction should fail
	rel_system.set_relationship(&"trader_a", &"trader_b", -50.0)
	var hostile_trade := interaction_system.propose_trade(&"trader_a", &"trader_b", offer, request)
	_assert(not hostile_trade,
		"Trade with hostile faction should fail")
	
	# Test 3: Alliance proposal
	rel_system.set_relationship(&"trader_a", &"trader_b", 10.0)
	var alliance_result := interaction_system.propose_alliance(&"trader_a", &"trader_b")
	_assert(alliance_result,
		"Alliance with positive relations should succeed")
	_assert(rel_system.is_allied(&"trader_a", &"trader_b"),
		"Factions should be allied after successful proposal")
	
	# Test 4: Resource valuation
	var resources := {"food": 10, "coal": 20, "gold": 5}
	var value := interaction_system._calculate_resource_value(resources)
	_assert(value == 35,
		"Resource value should be sum of all resources")
	
	# Test 5: Peace offering
	rel_system.set_relationship(&"trader_a", &"trader_b", -40.0)
	var peace_offering := {"gold": 50}
	var initial_gold := faction_system.resource_amount(&"trader_a", &"gold")
	var peace_result := interaction_system.offer_peace(&"trader_a", &"trader_b", peace_offering)
	_assert(peace_result,
		"Peace offering should succeed")
	_assert(faction_system.resource_amount(&"trader_a", &"gold") < initial_gold,
		"Peace offering should cost resources")
	var improved_relation := rel_system.get_relationship_value(&"trader_a", &"trader_b")
	_assert(improved_relation > -40.0,
		"Peace offering should improve relationship")
	
	# Test 6: Territory dispute
	rel_system.set_relationship(&"trader_a", &"trader_b", 0.0)
	interaction_system.raise_territory_dispute(&"trader_a", &"trader_b", Vector2i(10, 10))
	var disputed_relation := rel_system.get_relationship_value(&"trader_a", &"trader_b")
	_assert(disputed_relation < 0.0,
		"Territory dispute should worsen relationship")
	
	print("Faction interaction tests completed\n")


func _assert(condition: bool, message: String) -> void:
	tests_run += 1
	if condition:
		print("  ✓ %s" % message)
	else:
		failures += 1
		print("  ✗ FAILED: %s" % message)
		push_error(message)
