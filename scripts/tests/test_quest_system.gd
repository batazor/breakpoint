extends SceneTree

## Test script for Quest System Classes
## Run with: godot --headless --script scripts/tests/test_quest_system.gd

func _initialize() -> void:
	print("\n=== Quest System Classes Test ===\n")
	
	var passed := 0
	var failed := 0
	
	# Test 1: QuestObjective creation and progress tracking
	print("Test 1: QuestObjective creation and progress tracking")
	var result := test_quest_objective_creation()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 2: QuestObjective completion for different types
	print("\nTest 2: QuestObjective completion for different types")
	result = test_quest_objective_types()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 3: Quest creation and state management
	print("\nTest 3: Quest creation and state management")
	result = test_quest_creation()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 4: Quest progress calculation
	print("\nTest 4: Quest progress calculation")
	result = test_quest_progress()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 5: Quest completion with multiple objectives
	print("\nTest 5: Quest completion with multiple objectives")
	result = test_quest_completion()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 6: Quest requirements and can_start
	print("\nTest 6: Quest requirements and can_start")
	result = test_quest_requirements()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 7: Quest time limit
	print("\nTest 7: Quest time limit")
	result = test_quest_time_limit()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 8: Optional objectives
	print("\nTest 8: Optional objectives")
	result = test_optional_objectives()
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
		quit(0)
	else:
		print("\n✗ Some tests failed!")
		quit(1)


func test_quest_objective_creation() -> bool:
	## Test basic QuestObjective creation and properties
	var obj := QuestObjective.new()
	obj.id = "test_build_1"
	obj.description = "Build a fortress"
	obj.type = "build"
	obj.target = "fortress"
	obj.count = 2
	obj.current = 0
	
	# Test initial state
	if obj.is_completed():
		print("    ERROR: Objective should not be completed initially")
		return false
	
	if obj.get_progress() != 0.0:
		print("    ERROR: Initial progress should be 0.0")
		return false
	
	# Test increment
	obj.increment()
	if obj.current != 1:
		print("    ERROR: Current should be 1 after increment")
		return false
	
	if obj.get_progress() != 0.5:
		print("    ERROR: Progress should be 0.5 (1/2)")
		return false
	
	# Test completion
	obj.increment()
	if not obj.is_completed():
		print("    ERROR: Objective should be completed")
		return false
	
	if obj.get_progress() != 1.0:
		print("    ERROR: Progress should be 1.0 when completed")
		return false
	
	return true


func test_quest_objective_types() -> bool:
	## Test different objective types
	
	# Test build type
	var build_obj := QuestObjective.new()
	build_obj.type = "build"
	build_obj.count = 3
	build_obj.current = 2
	if build_obj.is_completed():
		print("    ERROR: Build objective should not be completed (2/3)")
		return false
	build_obj.current = 3
	if not build_obj.is_completed():
		print("    ERROR: Build objective should be completed (3/3)")
		return false
	
	# Test gather type
	var gather_obj := QuestObjective.new()
	gather_obj.type = "gather"
	gather_obj.count = 100
	gather_obj.current = 100
	if not gather_obj.is_completed():
		print("    ERROR: Gather objective should be completed")
		return false
	
	# Test relationship type
	var rel_obj := QuestObjective.new()
	rel_obj.type = "relationship"
	rel_obj.value = 50.0
	rel_obj.current = 30
	if rel_obj.is_completed():
		print("    ERROR: Relationship objective should not be completed (30/50)")
		return false
	if abs(rel_obj.get_progress() - 0.6) > 0.01:
		print("    ERROR: Relationship progress should be 0.6 (30/50)")
		return false
	rel_obj.current = 50
	if not rel_obj.is_completed():
		print("    ERROR: Relationship objective should be completed (50/50)")
		return false
	
	# Test survive type
	var survive_obj := QuestObjective.new()
	survive_obj.type = "survive"
	survive_obj.value = 24.0  # 24 hours
	survive_obj.current = 12
	if survive_obj.is_completed():
		print("    ERROR: Survive objective should not be completed (12/24 hours)")
		return false
	if abs(survive_obj.get_progress() - 0.5) > 0.01:
		print("    ERROR: Survive progress should be 0.5 (12/24)")
		return false
	
	return true


func test_quest_creation() -> bool:
	## Test Quest creation and basic properties
	var quest := Quest.new()
	quest.id = StringName("test_quest_1")
	quest.title = "Test Quest"
	quest.description = "A test quest"
	quest.category = "tutorial"
	
	# Test initial state
	if quest.state != Quest.QuestState.NOT_STARTED:
		print("    ERROR: Initial state should be NOT_STARTED")
		return false
	
	if quest.is_completed():
		print("    ERROR: Quest without objectives should not be completed")
		return false
	
	# Test state enum values
	if Quest.QuestState.NOT_STARTED != 0:
		print("    ERROR: NOT_STARTED should be 0")
		return false
	
	if Quest.QuestState.ACTIVE != 1:
		print("    ERROR: ACTIVE should be 1")
		return false
	
	if Quest.QuestState.COMPLETED != 2:
		print("    ERROR: COMPLETED should be 2")
		return false
	
	return true


func test_quest_progress() -> bool:
	## Test quest progress calculation
	var quest := Quest.new()
	quest.id = StringName("test_progress")
	
	# Add objectives
	var obj1 := QuestObjective.new()
	obj1.type = "build"
	obj1.count = 2
	obj1.current = 0
	
	var obj2 := QuestObjective.new()
	obj2.type = "gather"
	obj2.count = 100
	obj2.current = 50
	
	quest.objectives = [obj1, obj2]
	
	# Test progress calculation
	# obj1: 0/2 = 0.0, obj2: 50/100 = 0.5, average = 0.25
	var expected_progress := 0.25
	var actual_progress := quest.get_progress()
	if abs(actual_progress - expected_progress) > 0.01:
		print("    ERROR: Expected progress %f, got %f" % [expected_progress, actual_progress])
		return false
	
	# Update progress
	obj1.current = 2  # Complete obj1
	expected_progress = 0.75  # (1.0 + 0.5) / 2
	actual_progress = quest.get_progress()
	if abs(actual_progress - expected_progress) > 0.01:
		print("    ERROR: Expected progress %f, got %f" % [expected_progress, actual_progress])
		return false
	
	return true


func test_quest_completion() -> bool:
	## Test quest completion with multiple objectives
	var quest := Quest.new()
	quest.id = StringName("test_completion")
	
	# Add objectives
	var obj1 := QuestObjective.new()
	obj1.type = "build"
	obj1.count = 1
	obj1.current = 0
	
	var obj2 := QuestObjective.new()
	obj2.type = "gather"
	obj2.count = 50
	obj2.current = 0
	
	quest.objectives = [obj1, obj2]
	
	# Quest should not be completed initially
	if quest.is_completed():
		print("    ERROR: Quest should not be completed initially")
		return false
	
	# Complete first objective
	obj1.current = 1
	if quest.is_completed():
		print("    ERROR: Quest should not be completed with only one objective done")
		return false
	
	# Complete second objective
	obj2.current = 50
	if not quest.is_completed():
		print("    ERROR: Quest should be completed when all objectives are done")
		return false
	
	return true


func test_quest_requirements() -> bool:
	## Test quest requirements and can_start method
	var quest := Quest.new()
	quest.id = StringName("test_requirements")
	quest.state = Quest.QuestState.NOT_STARTED
	
	# Test without requirements
	if not quest.can_start(&"kingdom"):
		print("    ERROR: Quest should be startable without requirements")
		return false
	
	# Test with faction requirement
	quest.requirements = {"faction": &"horde"}
	if quest.can_start(&"kingdom"):
		print("    ERROR: Quest should not be startable for wrong faction")
		return false
	
	if not quest.can_start(&"horde"):
		print("    ERROR: Quest should be startable for correct faction")
		return false
	
	# Test repeatable quest
	quest.repeatable = true
	quest.state = Quest.QuestState.COMPLETED
	if not quest.can_start(&"horde"):
		print("    ERROR: Repeatable quest should be startable even when completed")
		return false
	
	# Test non-repeatable quest
	quest.repeatable = false
	if quest.can_start(&"horde"):
		print("    ERROR: Non-repeatable quest should not be startable when completed")
		return false
	
	# Test active quest
	quest.state = Quest.QuestState.ACTIVE
	if quest.can_start(&"horde"):
		print("    ERROR: Active quest should not be startable again")
		return false
	
	return true


func test_quest_time_limit() -> bool:
	## Test quest time limit functionality
	var quest := Quest.new()
	quest.id = StringName("test_time_limit")
	quest.time_limit_hours = 10.0
	
	# Test before quest starts
	if quest.get_time_remaining() != 10.0:
		print("    ERROR: Time remaining should be 10.0 before start")
		return false
	
	if quest.is_time_expired():
		print("    ERROR: Quest should not be expired before start")
		return false
	
	# Test with no time limit
	var quest2 := Quest.new()
	quest2.id = StringName("test_no_limit")
	quest2.time_limit_hours = 0.0
	
	if quest2.get_time_remaining() != -1.0:
		print("    ERROR: Quest without time limit should return -1.0")
		return false
	
	if quest2.is_time_expired():
		print("    ERROR: Quest without time limit should never expire")
		return false
	
	return true


func test_optional_objectives() -> bool:
	## Test optional objectives behavior
	var quest := Quest.new()
	quest.id = StringName("test_optional")
	
	# Add required objective
	var obj1 := QuestObjective.new()
	obj1.type = "build"
	obj1.count = 1
	obj1.current = 1
	obj1.optional = false
	
	# Add optional objective (not completed)
	var obj2 := QuestObjective.new()
	obj2.type = "gather"
	obj2.count = 100
	obj2.current = 0
	obj2.optional = true
	
	quest.objectives = [obj1, obj2]
	
	# Quest should be completed even though optional objective is not done
	if not quest.is_completed():
		print("    ERROR: Quest should be completed when all required objectives are done")
		return false
	
	# Progress should only count required objectives
	var progress := quest.get_progress()
	if abs(progress - 1.0) > 0.01:
		print("    ERROR: Progress should be 1.0 (only counting required objectives), got %f" % progress)
		return false
	
	return true
