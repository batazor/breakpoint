extends Node
class_name SaveLoadSystem

## Save/Load game system with serialization
## Manages save files and game state persistence

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(error: String)
signal load_failed(error: String)

const SAVE_DIR := "user://saves/"
const SAVE_FILE_EXTENSION := ".save"
const MAX_SAVE_SLOTS := 10
const AUTO_SAVE_SLOT := 0
const QUICK_SAVE_SLOT := 1

var current_save_slot: int = -1


func _ready() -> void:
	# Ensure save directory exists
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")


## Save game to specified slot
func save_game(slot: int = 1) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		push_error("SaveLoadSystem: Invalid save slot: %d" % slot)
		emit_signal("save_failed", "Invalid save slot")
		return false
	
	var save_data := _collect_save_data()
	if save_data.is_empty():
		push_error("SaveLoadSystem: Failed to collect save data")
		emit_signal("save_failed", "Failed to collect save data")
		return false
	
	var save_path := _get_save_path(slot)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("SaveLoadSystem: Failed to open save file for writing: %d" % error)
		emit_signal("save_failed", "Failed to open save file")
		return false
	
	# Add metadata
	save_data["metadata"] = {
		"version": "0.7.0",
		"timestamp": Time.get_unix_time_from_system(),
		"slot": slot
	}
	
	# Convert to JSON and save
	var json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	current_save_slot = slot
	print("SaveLoadSystem: Game saved to slot %d" % slot)
	emit_signal("save_completed", slot)
	return true


## Load game from specified slot
func load_game(slot: int = 1) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		push_error("SaveLoadSystem: Invalid load slot: %d" % slot)
		emit_signal("load_failed", "Invalid load slot")
		return false
	
	var save_path := _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		push_error("SaveLoadSystem: Save file does not exist: %s" % save_path)
		emit_signal("load_failed", "Save file does not exist")
		return false
	
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("SaveLoadSystem: Failed to open save file for reading: %d" % error)
		emit_signal("load_failed", "Failed to open save file")
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("SaveLoadSystem: Failed to parse save file JSON")
		emit_signal("load_failed", "Failed to parse save file")
		return false
	
	var save_data: Dictionary = json.data
	if not save_data.has("metadata"):
		push_error("SaveLoadSystem: Save file missing metadata")
		emit_signal("load_failed", "Invalid save file format")
		return false
	
	if not _restore_save_data(save_data):
		push_error("SaveLoadSystem: Failed to restore save data")
		emit_signal("load_failed", "Failed to restore save data")
		return false
	
	current_save_slot = slot
	print("SaveLoadSystem: Game loaded from slot %d" % slot)
	emit_signal("load_completed", slot)
	return true


## Quick save to dedicated slot
func quick_save() -> bool:
	return save_game(QUICK_SAVE_SLOT)


## Quick load from dedicated slot
func quick_load() -> bool:
	return load_game(QUICK_SAVE_SLOT)


## Auto save to dedicated slot
func auto_save() -> bool:
	return save_game(AUTO_SAVE_SLOT)


## Load most recent save file
func load_latest_game() -> bool:
	var latest_slot := _find_latest_save_slot()
	if latest_slot < 0:
		emit_signal("load_failed", "No save files found")
		return false
	return load_game(latest_slot)


## Check if save file exists in slot
func has_save_in_slot(slot: int) -> bool:
	var save_path := _get_save_path(slot)
	return FileAccess.file_exists(save_path)


## Get save file info for UI display
func get_save_info(slot: int) -> Dictionary:
	if not has_save_in_slot(slot):
		return {}
	
	var save_path := _get_save_path(slot)
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var save_data: Dictionary = json.data
	if not save_data.has("metadata"):
		return {}
	
	return save_data.metadata


## Delete save file from slot
func delete_save(slot: int) -> bool:
	var save_path := _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		return false
	
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	
	var err := dir.remove(save_path.get_file())
	return err == OK


## Get save file path for slot
func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_%d%s" % [slot, SAVE_FILE_EXTENSION]


## Find slot with most recent save
func _find_latest_save_slot() -> int:
	var latest_slot := -1
	var latest_time := 0.0
	
	for slot in range(MAX_SAVE_SLOTS):
		var info := get_save_info(slot)
		if info.has("timestamp"):
			var timestamp: float = info.timestamp
			if timestamp > latest_time:
				latest_time = timestamp
				latest_slot = slot
	
	return latest_slot


## Collect all game data for saving
func _collect_save_data() -> Dictionary:
	var data := {}
	
	# Get the main scene
	var world := get_tree().root.get_node_or_null("World")
	if world == null:
		return {}
	
	# Save hex grid state
	var hex_grid := world.get_node_or_null("HexGrid")
	if hex_grid and hex_grid.has_method("serialize"):
		data["hex_grid"] = hex_grid.serialize()
	
	# Save faction system state
	var faction_system := world.get_node_or_null("FactionSystem")
	if faction_system and faction_system.has_method("serialize"):
		data["factions"] = faction_system.serialize()
	
	# Save economy system state
	var economy_system := world.get_node_or_null("EconomySystem")
	if economy_system and economy_system.has_method("serialize"):
		data["economy"] = economy_system.serialize()
	
	# Save day/night cycle state
	var day_night_cycle := world.get_node_or_null("DayNightCycle")
	if day_night_cycle and day_night_cycle.has_method("serialize"):
		data["time"] = day_night_cycle.serialize()
	
	# Save camera position
	var camera_rig := world.get_node_or_null("CameraRig")
	if camera_rig:
		data["camera"] = {
			"position": camera_rig.global_position,
			"rotation": camera_rig.rotation
		}
	
	return data


## Restore game state from save data
func _restore_save_data(save_data: Dictionary) -> bool:
	# Get the main scene
	var world := get_tree().root.get_node_or_null("World")
	if world == null:
		return false
	
	# Restore hex grid
	if save_data.has("hex_grid"):
		var hex_grid := world.get_node_or_null("HexGrid")
		if hex_grid and hex_grid.has_method("deserialize"):
			hex_grid.deserialize(save_data.hex_grid)
	
	# Restore factions
	if save_data.has("factions"):
		var faction_system := world.get_node_or_null("FactionSystem")
		if faction_system and faction_system.has_method("deserialize"):
			faction_system.deserialize(save_data.factions)
	
	# Restore economy
	if save_data.has("economy"):
		var economy_system := world.get_node_or_null("EconomySystem")
		if economy_system and economy_system.has_method("deserialize"):
			economy_system.deserialize(save_data.economy)
	
	# Restore time
	if save_data.has("time"):
		var day_night_cycle := world.get_node_or_null("DayNightCycle")
		if day_night_cycle and day_night_cycle.has_method("deserialize"):
			day_night_cycle.deserialize(save_data.time)
	
	# Restore camera
	if save_data.has("camera"):
		var camera_rig := world.get_node_or_null("CameraRig")
		if camera_rig:
			var cam_data: Dictionary = save_data.camera
			if cam_data.has("position"):
				camera_rig.global_position = cam_data.position
			if cam_data.has("rotation"):
				camera_rig.rotation = cam_data.rotation
	
	return true
