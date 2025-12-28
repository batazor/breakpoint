extends SceneTree

## Test script for Quest Manager
## Run with: godot --headless --script scripts/tests/test_quest_manager.gd

func _initialize() -> void:
	print("\n=== Quest Manager Test ===\n")
	
	var passed := 0
	var failed := 0
	
	# Test 1: QuestManager initialization
	print("Test 1: QuestManager initialization")
	var result := test_quest_manager_init()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 2: Quest registration
	print("\nTest 2: Quest registration")
	result = test_quest_registration()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 3: Quest start
	print("\nTest 3: Quest start")
	result = test_quest_start()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 4: Quest completion
	print("\nTest 4: Quest completion")
	result = test_quest_completion()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 5: Quest failure
	print("\nTest 5: Quest failure")
	result = test_quest_failure()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 6: QuestTemplate instantiation
	print("\nTest 6: QuestTemplate instantiation")
	result = test_quest_template()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 7: QuestGenerator templates
	print("\nTest 7: QuestGenerator templates")
	result = test_quest_generator()
	if result:
		passed += 1
		print("  ✓ PASSED")
	else:
		failed += 1
		print("  ✗ FAILED")
	
	# Test 8: QuestLibrary tutorial quests
	print("\nTest 8: QuestLibrary tutorial quests")
	result = test_quest_library()
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
		print("\n✅ All tests passed!")
		quit(0)
	else:
		print("\n✗ Some tests failed!")
		quit(1)


func test_quest_manager_init() -> bool:
	## Test QuestManager initialization
	var quest_manager = QuestManager.new()
	
	if quest_manager.active_quests == null:
		print("    ERROR: active_quests should be initialized")
		return false
	
	if quest_manager.completed_quests == null:
		print("    ERROR: completed_quests should be initialized")
		return false
	
	if quest_manager.available_quests == null:
		print("    ERROR: available_quests should be initialized")
		return false
	
	return true


func test_quest_registration() -> bool:
	## Test quest registration
	var quest_manager = QuestManager.new()
	var quest = Quest.new()
	quest.id = StringName("test_quest_1")
	quest.title = "Test Quest"
	
	quest_manager.register_quest(quest)
	
	if not quest_manager.available_quests.has(quest.id):
		print("    ERROR: Quest should be registered")
		return false
	
	if quest_manager.available_quests[quest.id] != quest:
		print("    ERROR: Registered quest should match original")
		return false
	
	return true


func test_quest_start() -> bool:
	## Test quest start
	var quest_manager = QuestManager.new()
	var quest = Quest.new()
	quest.id = StringName("test_quest_start")
	quest.title = "Test Quest Start"
	quest.state = Quest.QuestState.NOT_STARTED
	
	quest_manager.register_quest(quest)
	
	var started = quest_manager.start_quest(quest.id, &"kingdom")
	if not started:
		print("    ERROR: Quest should start successfully")
		return false
	
	if quest.state != Quest.QuestState.ACTIVE:
		print("    ERROR: Quest state should be ACTIVE")
		return false
	
	if not quest_manager.active_quests.has(quest):
		print("    ERROR: Quest should be in active_quests")
		return false
	
	if quest.start_time <= 0.0:
		print("    ERROR: Quest start_time should be set")
		return false
	
	return true


func test_quest_completion() -> bool:
	## Test quest completion
	var quest_manager = QuestManager.new()
	var quest = Quest.new()
	quest.id = StringName("test_quest_complete")
	quest.title = "Test Quest Complete"
	
	var obj = QuestObjective.new()
	obj.type = "build"
	obj.count = 1
	obj.current = 1
	quest.objectives.append(obj)
	
	quest_manager.register_quest(quest)
	quest_manager.start_quest(quest.id, &"kingdom")
	
	# Complete the quest
	quest_manager.complete_quest(quest.id)
	
	if quest.state != Quest.QuestState.COMPLETED:
		print("    ERROR: Quest state should be COMPLETED")
		return false
	
	if quest_manager.active_quests.has(quest):
		print("    ERROR: Quest should not be in active_quests")
		return false
	
	if not quest_manager.is_quest_completed(quest.id):
		print("    ERROR: Quest should be marked as completed")
		return false
	
	if quest.completion_time <= 0.0:
		print("    ERROR: Quest completion_time should be set")
		return false
	
	return true


func test_quest_failure() -> bool:
	## Test quest failure
	var quest_manager = QuestManager.new()
	var quest = Quest.new()
	quest.id = StringName("test_quest_fail")
	quest.title = "Test Quest Fail"
	
	quest_manager.register_quest(quest)
	quest_manager.start_quest(quest.id, &"kingdom")
	
	# Fail the quest
	quest_manager.fail_quest(quest.id)
	
	if quest.state != Quest.QuestState.FAILED:
		print("    ERROR: Quest state should be FAILED")
		return false
	
	if quest_manager.active_quests.has(quest):
		print("    ERROR: Failed quest should not be in active_quests")
		return false
	
	return true


func test_quest_template() -> bool:
	## Test QuestTemplate instantiation
	var template = QuestTemplate.new({
		"title_pattern": "Gather {resource_name}",
		"description_pattern": "Gather {target_amount} {resource_name}",
		"objective_type": "gather",
		"reward_scale": 1.5
	})
	
	var context = {
		"resource_name": "Gold",
		"target_amount": 100,
		"resource_id": "gold",
		"faction_id": &"kingdom"
	}
	
	var quest = template.instantiate(context)
	
	if quest.title != "Gather Gold":
		print("    ERROR: Quest title should be 'Gather Gold', got '%s'" % quest.title)
		return false
	
	if not quest.description.contains("100"):
		print("    ERROR: Quest description should contain target amount")
		return false
	
	if quest.objectives.is_empty():
		print("    ERROR: Quest should have objectives")
		return false
	
	var obj = quest.objectives[0]
	if obj.type != "gather":
		print("    ERROR: Objective type should be 'gather'")
		return false
	
	if obj.target != "gold":
		print("    ERROR: Objective target should be 'gold'")
		return false
	
	if obj.count != 100:
		print("    ERROR: Objective count should be 100")
		return false
	
	if not quest.rewards.has("gold"):
		print("    ERROR: Quest should have gold reward")
		return false
	
	return true


func test_quest_generator() -> bool:
	## Test QuestGenerator template loading
	var generator = QuestGenerator.new()
	generator._load_templates()
	
	if generator.quest_templates.is_empty():
		print("    ERROR: Quest templates should be loaded")
		return false
	
	if not generator.quest_templates.has("resource_scarcity"):
		print("    ERROR: Should have resource_scarcity template")
		return false
	
	if not generator.quest_templates.has("rebuild_structure"):
		print("    ERROR: Should have rebuild_structure template")
		return false
	
	# Test quest generation from template
	var quest = generator._generate_from_template("resource_scarcity", {
		"resource_id": "food",
		"resource_name": "Food",
		"target_amount": 100,
		"faction_id": &"kingdom"
	})
	
	if quest == null:
		print("    ERROR: Quest should be generated")
		return false
	
	if quest.title.is_empty():
		print("    ERROR: Generated quest should have title")
		return false
	
	if quest.objectives.is_empty():
		print("    ERROR: Generated quest should have objectives")
		return false
	
	return true


func test_quest_library() -> bool:
	## Test QuestLibrary tutorial quests
	var library = QuestLibrary.new()
	library._create_tutorial_quests()
	
	var tutorial_quests = library.get_tutorial_quests()
	
	if tutorial_quests.is_empty():
		print("    ERROR: Should have tutorial quests")
		return false
	
	var first_quest = tutorial_quests[0]
	if first_quest.id != StringName("tutorial_first_steps"):
		print("    ERROR: First tutorial quest should be 'tutorial_first_steps'")
		return false
	
	if first_quest.category != "tutorial":
		print("    ERROR: Quest category should be 'tutorial'")
		return false
	
	if first_quest.objectives.is_empty():
		print("    ERROR: Tutorial quest should have objectives")
		return false
	
	if first_quest.rewards.is_empty():
		print("    ERROR: Tutorial quest should have rewards")
		return false
	
	return true
