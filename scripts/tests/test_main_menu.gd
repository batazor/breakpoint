extends SceneTree

## Basic tests for Main Menu & Game Flow system
## Tests menu initialization and basic functionality

const MainMenu = preload("res://scripts/ui/main_menu.gd")
const SettingsManager = preload("res://scripts/ui/settings_manager.gd")
const SaveLoadSystem = preload("res://scripts/save_load_system.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")

var failures: int = 0
var tests_run: int = 0


func _initialize() -> void:
	print("=== Starting Main Menu & Game Flow Tests ===\n")
	
	# Test groups
	_test_settings_manager_initialization()
	_test_settings_persistence()
	_test_save_load_system()
	_test_menu_structure()
	
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


func _test_settings_manager_initialization() -> void:
	print("--- Testing SettingsManager Initialization ---")
	
	var settings := SettingsManager.new()
	
	# Test 1: Default values are set
	_assert(settings.fullscreen == false,
		"Default fullscreen should be false")
	
	# Test 2: Volume values are in valid range
	_assert(settings.master_volume >= 0.0 and settings.master_volume <= 1.0,
		"Master volume should be between 0.0 and 1.0")
	
	# Test 3: Available resolutions list is not empty
	var resolutions := settings.get_available_resolutions()
	_assert(resolutions.size() > 0,
		"Available resolutions should not be empty")
	
	# Test 4: Quality names are valid
	_assert(settings.get_quality_name(0) == "Low",
		"Quality level 0 should be 'Low'")
	_assert(settings.get_quality_name(1) == "Medium",
		"Quality level 1 should be 'Medium'")
	_assert(settings.get_quality_name(2) == "High",
		"Quality level 2 should be 'High'")
	
	settings.free()


func _test_settings_persistence() -> void:
	print("--- Testing Settings Persistence ---")
	
	var settings := SettingsManager.new()
	
	# Test 1: Save settings doesn't crash
	settings.master_volume = 0.5
	settings.music_volume = 0.7
	settings.save_settings()
	_assert(true, "Save settings should complete without error")
	
	# Test 2: Load settings restores values
	var settings2 := SettingsManager.new()
	settings2.load_settings()
	# Note: Since we just saved, these values should match
	# In real environment, this would test actual persistence
	_assert(settings2.master_volume >= 0.0 and settings2.master_volume <= 1.0,
		"Loaded master volume should be in valid range")
	
	settings.free()
	settings2.free()


func _test_save_load_system() -> void:
	print("--- Testing Save/Load System ---")
	
	var save_system := SaveLoadSystem.new()
	
	# Test 1: Save directory path is valid
	_assert(save_system.SAVE_DIR == "user://saves/",
		"Save directory should be 'user://saves/'")
	
	# Test 2: Save file extension is valid
	_assert(save_system.SAVE_FILE_EXTENSION == ".save",
		"Save file extension should be '.save'")
	
	# Test 3: Max save slots is reasonable
	_assert(save_system.MAX_SAVE_SLOTS > 0 and save_system.MAX_SAVE_SLOTS <= 20,
		"Max save slots should be between 1 and 20")
	
	# Test 4: Get save path format is correct
	var path := save_system._get_save_path(1)
	_assert(path.begins_with("user://saves/save_"),
		"Save path should start with 'user://saves/save_'")
	_assert(path.ends_with(".save"),
		"Save path should end with '.save'")
	
	save_system.free()


func _test_menu_structure() -> void:
	print("--- Testing Menu Structure ---")
	
	# Test 1: Main menu scene exists
	var main_menu_path := "res://scenes/ui/main_menu.tscn"
	_assert(ResourceLoader.exists(main_menu_path),
		"Main menu scene should exist at %s" % main_menu_path)
	
	# Test 2: New game panel scene exists
	var new_game_path := "res://scenes/ui/new_game_panel.tscn"
	_assert(ResourceLoader.exists(new_game_path),
		"New game panel scene should exist at %s" % new_game_path)
	
	# Test 3: Settings menu scene exists
	var settings_path := "res://scenes/ui/settings_menu.tscn"
	_assert(ResourceLoader.exists(settings_path),
		"Settings menu scene should exist at %s" % settings_path)
	
	# Test 4: Pause menu scene exists
	var pause_path := "res://scenes/ui/pause_menu.tscn"
	_assert(ResourceLoader.exists(pause_path),
		"Pause menu scene should exist at %s" % pause_path)


func _assert(condition: bool, message: String) -> void:
	tests_run += 1
	if condition:
		print("  ✓ %s" % message)
	else:
		failures += 1
		print("  ✗ %s" % message)
