extends SceneTree

## Tests for NPC inventory system
## Tests inventory management operations

const NPC = preload("res://scripts/npc.gd")

var failures: int = 0
var tests_run: int = 0


func _initialize() -> void:
	print("=== Starting NPC Inventory Tests ===\n")
	
	# Test groups
	_test_inventory_operations()
	_test_inventory_queries()
	
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


func _test_inventory_operations() -> void:
	print("--- Testing Inventory Operations ---")
	
	var npc := NPC.new()
	npc.id = &"test_npc"
	npc.inventory = {}
	
	# Test 1: Add items to inventory
	var added := npc.add_to_inventory(&"food", 10)
	_assert(added == true,
		"Should successfully add 10 food")
	_assert(npc.get_inventory_amount(&"food") == 10,
		"Should have 10 food after adding")
	_assert(npc.get_inventory_total() == 10,
		"Total inventory should be 10")
	
	# Test 2: Add more of the same resource
	added = npc.add_to_inventory(&"food", 5)
	_assert(added == true,
		"Should successfully add 5 more food")
	_assert(npc.get_inventory_amount(&"food") == 15,
		"Should have 15 food after adding 5 more")
	_assert(npc.get_inventory_total() == 15,
		"Total inventory should be 15")
	
	# Test 3: Add different resource
	added = npc.add_to_inventory(&"gold", 20)
	_assert(added == true,
		"Should successfully add 20 gold")
	_assert(npc.get_inventory_amount(&"gold") == 20,
		"Should have 20 gold after adding")
	_assert(npc.get_inventory_total() == 35,
		"Total inventory should be 35 (15 food + 20 gold)")
	
	# Test 4: Remove items from inventory
	var removed := npc.remove_from_inventory(&"food", 5)
	_assert(removed == true,
		"Should successfully remove 5 food")
	_assert(npc.get_inventory_amount(&"food") == 10,
		"Should have 10 food after removing 5")
	
	# Test 5: Try to remove more than available
	removed = npc.remove_from_inventory(&"food", 20)
	_assert(removed == false,
		"Should fail to remove 20 food (only 10 available)")
	_assert(npc.get_inventory_amount(&"food") == 10,
		"Should still have 10 food after failed removal")
	
	# Test 6: Remove all of a resource
	removed = npc.remove_from_inventory(&"food", 10)
	_assert(removed == true,
		"Should successfully remove all food")
	_assert(npc.get_inventory_amount(&"food") == 0,
		"Should have 0 food after removing all")
	_assert(not npc.inventory.has(&"food"),
		"Food should be removed from inventory dictionary")
	
	# Test 7: Try to add invalid amounts
	added = npc.add_to_inventory(&"coal", 0)
	_assert(added == false,
		"Should fail to add 0 amount")
	_assert(npc.get_inventory_amount(&"coal") == 0,
		"Should not add 0 amount")
	
	added = npc.add_to_inventory(&"coal", -5)
	_assert(added == false,
		"Should fail to add negative amount")
	_assert(npc.get_inventory_amount(&"coal") == 0,
		"Should not add negative amount")


func _test_inventory_queries() -> void:
	print("--- Testing Inventory Queries ---")
	
	var npc := NPC.new()
	npc.id = &"test_npc_2"
	npc.inventory = {}
	
	# Test 1: Empty inventory
	_assert(npc.is_inventory_empty() == true,
		"New inventory should be empty")
	_assert(npc.get_inventory_total() == 0,
		"Empty inventory total should be 0")
	
	# Test 2: Non-empty inventory
	var added := npc.add_to_inventory(&"wood", 5)
	_assert(added == true,
		"Should successfully add 5 wood")
	_assert(npc.is_inventory_empty() == false,
		"Inventory should not be empty after adding items")
	
	# Test 3: Get amount of non-existent resource
	_assert(npc.get_inventory_amount(&"nonexistent") == 0,
		"Non-existent resource should return 0")
	
	# Test 4: Multiple resources
	npc.add_to_inventory(&"food", 10)
	npc.add_to_inventory(&"gold", 15)
	_assert(npc.get_inventory_total() == 30,
		"Total should be sum of all resources (5 + 10 + 15)")


func _assert(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		failures += 1
		print("  ❌ FAIL: %s" % message)
	else:
		print("  ✅ PASS: %s" % message)
