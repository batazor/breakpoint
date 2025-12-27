extends Node
class_name EconomySystem

@export var day_night_cycle_path: NodePath
@export var faction_system_path: NodePath
@export var build_controller_path: NodePath
@export var building_yaml_path: String = "res://building.yaml"

var _day_night: DayNightCycle
var _faction_system: FactionSystem
var _build_controller: Node
var _deltas_by_type: Dictionary = {} # StringName -> Dictionary(resource_id -> int)
var _resources_by_type: Dictionary = {} # StringName -> GameResource


func _ready() -> void:
	_resolve_nodes()
	_load_resources_from_yaml(building_yaml_path)
	_deltas_by_type = _load_deltas_from_yaml(building_yaml_path)
	if _day_night != null and not _day_night.game_hour_passed.is_connected(_on_game_hour_passed):
		_day_night.game_hour_passed.connect(_on_game_hour_passed)


func _resolve_nodes() -> void:
	if not day_night_cycle_path.is_empty():
		_day_night = get_node_or_null(day_night_cycle_path) as DayNightCycle
	else:
		_day_night = get_tree().get_first_node_in_group("day_night_cycle") as DayNightCycle
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path) as FactionSystem
	else:
		_faction_system = get_tree().get_first_node_in_group("faction_system") as FactionSystem
	if not build_controller_path.is_empty():
		_build_controller = get_node_or_null(build_controller_path)
	else:
		_build_controller = get_tree().get_first_node_in_group("build_controller")


func _on_game_hour_passed(_day: int, _hour: int) -> void:
	if _faction_system == null:
		return
	_apply_hourly_deltas()


func _apply_hourly_deltas() -> void:
	# Accumulate per-faction resource changes for this hour, then apply.
	var totals: Dictionary = {} # faction_id -> Dictionary(resource_id -> int)

	# Buildings/structures
	for building_id in _faction_system.building_owner.keys():
		var owner: StringName = _faction_system.building_owner.get(building_id, StringName(""))
		if owner == StringName(""):
			continue
		var b_type: StringName = _faction_system.building_types.get(building_id, StringName(""))
		
		# Get building level and position
		var axial: Vector2i = _faction_system.building_positions.get(building_id, Vector2i(-1, -1))
		var level: int = 1
		if _build_controller != null and _build_controller.has_method("get_building_level") and axial != Vector2i(-1, -1):
			level = _build_controller.call("get_building_level", axial)
		
		_add_type_delta_with_level(totals, owner, b_type, level)

	# Units (characters)
	if "unit_owner" in _faction_system and "unit_types" in _faction_system:
		for unit_id in _faction_system.unit_owner.keys():
			var owner_u: StringName = _faction_system.unit_owner.get(unit_id, StringName(""))
			if owner_u == StringName(""):
				continue
			var u_type: StringName = _faction_system.unit_types.get(unit_id, StringName(""))
			_add_type_delta(totals, owner_u, u_type)

	for fid in totals.keys():
		var per_res: Dictionary = totals[fid]
		for res_id in per_res.keys():
			var amount: int = int(per_res[res_id])
			if amount == 0:
				continue
			_faction_system.add_resource(StringName(fid), StringName(res_id), amount)


func _add_type_delta(totals: Dictionary, faction_id: StringName, type_id: StringName) -> void:
	if type_id == StringName("") or not _deltas_by_type.has(type_id):
		return
	if not totals.has(faction_id):
		totals[faction_id] = {}
	var per_res: Dictionary = totals[faction_id]
	var delta_dict: Dictionary = _deltas_by_type[type_id]
	for res_key in delta_dict.keys():
		var delta: int = int(delta_dict[res_key])
		per_res[res_key] = int(per_res.get(res_key, 0)) + delta


func _add_type_delta_with_level(totals: Dictionary, faction_id: StringName, type_id: StringName, level: int) -> void:
	if type_id == StringName(""):
		return
	
	# Try to use GameResource with level-aware deltas
	if _resources_by_type.has(type_id):
		var resource: GameResource = _resources_by_type[type_id]
		var delta_dict: Dictionary = resource.get_resource_delta_at_level(level)
		
		if not totals.has(faction_id):
			totals[faction_id] = {}
		var per_res: Dictionary = totals[faction_id]
		
		for res_key in delta_dict.keys():
			var delta: int = int(delta_dict[res_key])
			per_res[res_key] = int(per_res.get(res_key, 0)) + delta
	else:
		# Fallback to basic delta without level
		_add_type_delta(totals, faction_id, type_id)


func _load_resources_from_yaml(path: String) -> void:
	_resources_by_type.clear()
	
	if path.is_empty():
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("EconomySystem: yaml not found: %s" % path)
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	# Use simplified YAML parser similar to city_screen.gd
	var entries := _parse_resources_yaml(content)
	
	for entry in entries:
		var res := GameResource.new()
		res.id = StringName(entry.get("id", entry.get("key", "")))
		
		# Parse resource delta
		var delta_dict = entry.get("resource_delta_per_hour", {})
		if delta_dict is Dictionary:
			for res_key in delta_dict.keys():
				var value = delta_dict[res_key]
				res.resource_delta_per_hour[str(res_key)] = int(value) if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) else 0
		
		# Parse max_level
		var max_level_value = entry.get("max_level", 1)
		res.max_level = int(max_level_value) if (typeof(max_level_value) == TYPE_INT or typeof(max_level_value) == TYPE_FLOAT) else 1
		
		# Parse upgrade_levels
		var upgrade_levels_array = entry.get("upgrade_levels", [])
		if upgrade_levels_array is Array:
			for upgrade_entry in upgrade_levels_array:
				if upgrade_entry is Dictionary:
					var upgrade_data: Dictionary = {}
					
					upgrade_data["level"] = int(upgrade_entry.get("level", 1))
					
					# Parse upgrade_cost
					var upgrade_cost_dict = upgrade_entry.get("upgrade_cost", {})
					if upgrade_cost_dict is Dictionary:
						var cost_dict: Dictionary = {}
						for cost_key in upgrade_cost_dict.keys():
							var cost_value = upgrade_cost_dict[cost_key]
							cost_dict[str(cost_key)] = int(cost_value) if (typeof(cost_value) == TYPE_INT or typeof(cost_value) == TYPE_FLOAT) else 0
						upgrade_data["upgrade_cost"] = cost_dict
					
					# Parse upgrade_time_hours
					var upgrade_time_value = upgrade_entry.get("upgrade_time_hours", 0)
					upgrade_data["upgrade_time_hours"] = int(upgrade_time_value) if (typeof(upgrade_time_value) == TYPE_INT or typeof(upgrade_time_value) == TYPE_FLOAT) else 0
					
					# Parse resource_delta_bonus
					var bonus_dict = upgrade_entry.get("resource_delta_bonus", {})
					if bonus_dict is Dictionary:
						var delta_bonus: Dictionary = {}
						for bonus_key in bonus_dict.keys():
							var bonus_value = bonus_dict[bonus_key]
							delta_bonus[str(bonus_key)] = int(bonus_value) if (typeof(bonus_value) == TYPE_INT or typeof(bonus_value) == TYPE_FLOAT) else 0
						upgrade_data["resource_delta_bonus"] = delta_bonus
					
					res.upgrade_levels.append(upgrade_data)
		
		_resources_by_type[res.id] = res


func _parse_resources_yaml(text: String) -> Array:
	# Simplified YAML parser similar to city_screen
	var entries: Array = []
	var lines := text.split("\n")
	var in_resources := false
	var current: Dictionary = {}
	var collecting_list := false
	var collecting_dict := false
	var current_dict_key := ""
	var current_list_key := ""
	var current_upgrade: Dictionary = {}
	var in_upgrade_list := false
	
	for line in lines:
		var trimmed := line.strip_edges()
		
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		
		if not in_resources:
			if trimmed == "resources:":
				in_resources = true
			continue
		
		# New resource entry: "  well:"
		if line.begins_with("  ") and not line.begins_with("    "):
			if not current.is_empty():
				entries.append(current.duplicate())
			var res_id := trimmed.rstrip(":")
			current = {"id": res_id, "key": res_id}
			collecting_list = false
			collecting_dict = false
			in_upgrade_list = false
			current_upgrade = {}
			continue
		
		# Resource property: "    title: Well"
		if line.begins_with("    ") and not line.begins_with("      "):
			var parts := trimmed.split(":", false, 1)
			if parts.size() < 2:
				# Check for list/dict keys
				if trimmed.ends_with(":"):
					var key := trimmed.rstrip(":")
					if key == "buildable_tiles" or key == "roles":
						collecting_list = true
						collecting_dict = false
						current_list_key = key
						current[key] = []
					elif key == "resource_delta_per_hour" or key == "build_cost":
						collecting_dict = true
						collecting_list = false
						current_dict_key = key
						current[key] = {}
					elif key == "upgrade_levels":
						in_upgrade_list = true
						collecting_list = false
						collecting_dict = false
						current[key] = []
				continue
			
			var key := parts[0].strip_edges()
			var value_str := parts[1].strip_edges()
			collecting_list = false
			collecting_dict = false
			in_upgrade_list = false
			
			if value_str.is_valid_int():
				current[key] = value_str.to_int()
			elif value_str.is_valid_float():
				current[key] = value_str.to_float()
			else:
				current[key] = value_str
			continue
		
		# List/Dict item or upgrade entry: "      - plains" or "      food: 10" or "      - level: 2"
		if line.begins_with("      "):
			if in_upgrade_list:
				# Check if starting a new upgrade entry
				if trimmed.begins_with("- level:"):
					if not current_upgrade.is_empty():
						current.get("upgrade_levels", []).append(current_upgrade.duplicate())
					current_upgrade = {}
					var parts := trimmed.lstrip("- ").split(":", false, 1)
					if parts.size() == 2:
						current_upgrade["level"] = parts[1].strip_edges().to_int()
				continue
			
			if collecting_list:
				if trimmed.begins_with("- "):
					var value := trimmed.lstrip("- ")
					current.get(current_list_key, []).append(value)
			elif collecting_dict:
				var parts := trimmed.split(":", false, 1)
				if parts.size() == 2:
					var key := parts[0].strip_edges()
					var value_str := parts[1].strip_edges()
					if value_str.is_valid_int():
						current.get(current_dict_key, {})[key] = value_str.to_int()
					elif value_str.is_valid_float():
						current.get(current_dict_key, {})[key] = value_str.to_float()
					else:
						current.get(current_dict_key, {})[key] = value_str
			continue
		
		# Upgrade property or nested dict: "        upgrade_cost:" or "          food: 10"
		if line.begins_with("        "):
			if in_upgrade_list and not current_upgrade.is_empty():
				var parts := trimmed.split(":", false, 1)
				if parts.size() == 1 and trimmed.ends_with(":"):
					# Starting a nested dict like "upgrade_cost:"
					current_dict_key = trimmed.rstrip(":")
					current_upgrade[current_dict_key] = {}
				elif parts.size() == 2:
					var key := parts[0].strip_edges()
					var value_str := parts[1].strip_edges()
					
					# Check if we're in a nested dict
					if current_dict_key in current_upgrade:
						if value_str.is_valid_int():
							current_upgrade[current_dict_key][key] = value_str.to_int()
						elif value_str.is_valid_float():
							current_upgrade[current_dict_key][key] = value_str.to_float()
						else:
							current_upgrade[current_dict_key][key] = value_str
					else:
						# Direct property
						if value_str.is_valid_int():
							current_upgrade[key] = value_str.to_int()
						elif value_str.is_valid_float():
							current_upgrade[key] = value_str.to_float()
						else:
							current_upgrade[key] = value_str
			continue
	
	# Add last upgrade if any
	if in_upgrade_list and not current_upgrade.is_empty():
		current.get("upgrade_levels", []).append(current_upgrade.duplicate())
	
	# Add last resource
	if not current.is_empty():
		entries.append(current)
	
	return entries


func _load_deltas_from_yaml(path: String) -> Dictionary:
	var out: Dictionary = {}
	if path.is_empty():
		return out
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("EconomySystem: yaml not found: %s" % path)
		return out
	var text := file.get_as_text()
	file.close()

	var lines := text.split("\n")
	var in_resources := false
	var current_id := ""
	var in_delta := false
	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		if not in_resources:
			if trimmed == "resources:":
				in_resources = true
			continue

		# New top-level entry: "  well:"
		if line.begins_with("  ") and not line.begins_with("    "):
			current_id = trimmed.rstrip(":")
			in_delta = false
			continue

		if current_id.is_empty():
			continue

		# Enter delta section
		if trimmed == "resource_delta_per_hour:":
			in_delta = true
			out[StringName(current_id)] = {}
			continue

		# Parse delta entries: "      food: 10" (6 spaces in file, but we rely on strip)
		if in_delta:
			# Stop when indentation falls back to normal fields (e.g. "    buildable_tiles:")
			if trimmed.find(":") < 0:
				continue
			# If we're at a normal field like "title:" etc, exit delta section.
			if line.begins_with("    ") and not line.begins_with("      "):
				in_delta = false
				continue
			var sep := trimmed.find(":")
			if sep < 0:
				continue
			var k := trimmed.substr(0, sep).strip_edges()
			var v := trimmed.substr(sep + 1, trimmed.length()).strip_edges()
			var val: int = int(v)
			out[StringName(current_id)][StringName(k)] = val
	return out


