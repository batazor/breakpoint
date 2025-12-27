extends Node

## Test script for building upgrade system
## Run with: godot --headless --script scripts/tests/test_building_upgrade.gd

func _ready() -> void:
	print("\n=== Building Upgrade System Test ===\n")
	
	var passed := 0
	var failed := 0
	
	# Test 1: GameResource upgrade methods
	print("Test 1: GameResource upgrade methods")
	var result := test_game_resource_upgrade()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 2: Upgrade cost calculation
	print("\nTest 2: Upgrade cost calculation")
	result = test_upgrade_cost_calculation()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 3: Resource delta at level
	print("\nTest 3: Resource delta at level")
	result = test_resource_delta_at_level()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	print("\n=== Test Results ===")
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)
	
	if failed == 0:
		print("\n✓ All tests passed!")
		get_tree().quit(0)
	else:
		print("\n✗ Some tests failed!")
		get_tree().quit(1)


func test_game_resource_upgrade() -> bool:
	var res := GameResource.new()
	res.id = StringName("test_well")
	res.title = "Test Well"
	res.max_level = 3
	res.resource_delta_per_hour = {"food": 10}
	
	# Add upgrade levels
	res.upgrade_levels = [
		{
			"level": 2,
			"upgrade_cost": {"coal": 10, "gold": 15},
			"upgrade_time_hours": 2,
			"resource_delta_bonus": {"food": 5}
		},
		{
			"level": 3,
			"upgrade_cost": {"coal": 20, "gold": 30},
			"upgrade_time_hours": 3,
			"resource_delta_bonus": {"food": 10}
		}
	]
	
	# Test can_upgrade
	if not res.can_upgrade(1):
		print("    ERROR: Should be able to upgrade from level 1")
		return false
	
	if not res.can_upgrade(2):
		print("    ERROR: Should be able to upgrade from level 2")
		return false
	
	if res.can_upgrade(3):
		print("    ERROR: Should not be able to upgrade from level 3 (max level)")
		return false
	
	return true


func test_upgrade_cost_calculation() -> bool:
	var res := GameResource.new()
	res.id = StringName("test_mine")
	res.max_level = 2
	res.upgrade_levels = [
		{
			"level": 2,
			"upgrade_cost": {"gold": 20, "food": 10},
			"upgrade_time_hours": 3,
			"resource_delta_bonus": {"coal": 3}
		}
	]
	
	# Test getting upgrade cost for level 1 -> 2
	var cost := res.get_upgrade_cost(1)
	if cost.get("gold", 0) != 20:
		print("    ERROR: Expected gold cost 20, got %d" % cost.get("gold", 0))
		return false
	
	if cost.get("food", 0) != 10:
		print("    ERROR: Expected food cost 10, got %d" % cost.get("food", 0))
		return false
	
	# Test getting upgrade time
	var time := res.get_upgrade_time(1)
	if time != 3:
		print("    ERROR: Expected upgrade time 3, got %d" % time)
		return false
	
	# Test invalid level
	var invalid_cost := res.get_upgrade_cost(2)
	if not invalid_cost.is_empty():
		print("    ERROR: Should return empty dict for max level")
		return false
	
	return true


func test_resource_delta_at_level() -> bool:
	var res := GameResource.new()
	res.id = StringName("test_market")
	res.resource_delta_per_hour = {"gold": 15}
	res.max_level = 3
	res.upgrade_levels = [
		{
			"level": 2,
			"upgrade_cost": {"food": 40, "coal": 35, "gold": 60},
			"upgrade_time_hours": 5,
			"resource_delta_bonus": {"gold": 10}
		},
		{
			"level": 3,
			"upgrade_cost": {"food": 60, "coal": 50, "gold": 90},
			"upgrade_time_hours": 7,
			"resource_delta_bonus": {"gold": 15}
		}
	]
	
	# Test level 1 (base)
	var delta1 := res.get_resource_delta_at_level(1)
	if delta1.get("gold", 0) != 15:
		print("    ERROR: Level 1 should have 15 gold/hr, got %d" % delta1.get("gold", 0))
		return false
	
	# Test level 2 (base + first bonus)
	var delta2 := res.get_resource_delta_at_level(2)
	if delta2.get("gold", 0) != 25:  # 15 + 10
		print("    ERROR: Level 2 should have 25 gold/hr, got %d" % delta2.get("gold", 0))
		return false
	
	# Test level 3 (base + both bonuses)
	var delta3 := res.get_resource_delta_at_level(3)
	if delta3.get("gold", 0) != 40:  # 15 + 10 + 15
		print("    ERROR: Level 3 should have 40 gold/hr, got %d" % delta3.get("gold", 0))
		return false
	
	return true
