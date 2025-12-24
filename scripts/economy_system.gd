extends Node
class_name EconomySystem

@export var day_night_cycle_path: NodePath
@export var faction_system_path: NodePath
@export var building_yaml_path: String = "res://building.yaml"

var _day_night: DayNightCycle
var _faction_system: FactionSystem
var _deltas_by_type: Dictionary = {} # StringName -> Dictionary(resource_id -> int)


func _ready() -> void:
	_resolve_nodes()
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
		_add_type_delta(totals, owner, b_type)

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


