extends Control
class_name DiplomacyPanel

const FactionSystemRes = preload("res://scripts/faction_system.gd")
const FactionRes = preload("res://scripts/faction.gd")
const BuildControllerRes = preload("res://scripts/build_controller.gd")

@export var faction_system_path: NodePath
@export var focus_selector_path: NodePath
@export var details_label_path: NodePath
@export var faction_tabs_path: NodePath
@export var buildings_list_path: NodePath
@export var units_list_path: NodePath

var faction_system: FactionSystemRes
var game_store: Node
var build_controller: BuildControllerRes
var focus_selector: OptionButton
var details_label: RichTextLabel
var faction_tabs: TabContainer
var buildings_list: RichTextLabel
var units_list: RichTextLabel


func _ready() -> void:
	focus_selector = get_node_or_null(focus_selector_path) as OptionButton
	details_label = get_node_or_null(details_label_path) as RichTextLabel
	faction_tabs = get_node_or_null(faction_tabs_path) as TabContainer
	buildings_list = get_node_or_null(buildings_list_path) as RichTextLabel
	units_list = get_node_or_null(units_list_path) as RichTextLabel
	_resolve_game_store()
	_resolve_faction_system()
	_resolve_build_controller()
	_connect_signals()
	_refresh_selector()
	if focus_selector != null:
		focus_selector.item_selected.connect(_on_focus_selected)
	if faction_tabs != null:
		faction_tabs.tab_changed.connect(_on_tab_changed)
	_render_all()


func _connect_signals() -> void:
	# Connect game store signals
	if game_store != null:
		UIUtils.safe_connect(game_store.factions_changed, _on_factions_changed)
		UIUtils.safe_connect(game_store.world_ready, _on_world_ready)
	
	# Connect faction system signals
	if faction_system != null:
		UIUtils.safe_connect(faction_system.factions_changed, _on_factions_changed)
		UIUtils.safe_connect(faction_system.resources_changed, _on_resources_changed)
		UIUtils.safe_connect(faction_system.building_transferred, _on_buildings_changed)


func _resolve_faction_system() -> void:
	faction_system = UIUtils.get_node_or_group(self, faction_system_path, "faction_system") as FactionSystemRes


func _resolve_build_controller() -> void:
	build_controller = get_tree().get_first_node_in_group("build_controller") as BuildControllerRes


func _refresh_selector() -> void:
	if focus_selector == null:
		return
	var ids: Array[StringName] = _faction_ids()
	UIUtils.populate_option_button(focus_selector, ids)


func _on_focus_selected(_index: int) -> void:
	_render_text()


func _focus_faction() -> StringName:
	return UIUtils.get_selected_text_as_string_name(focus_selector)


func _faction_ids() -> Array[StringName]:
	# Try game_store first
	if game_store != null and not game_store.factions.is_empty():
		return UIUtils.extract_string_name_ids(game_store.factions)
	
	# Fallback to faction_system
	if faction_system != null and not faction_system.factions.is_empty():
		return UIUtils.extract_string_name_ids(faction_system.factions)
	
	return []


func _relation_between(a: StringName, b: StringName) -> float:
	if faction_system == null:
		return 0.0
	var fa_val: Variant = faction_system.factions.get(a, null)
	var fa: FactionRes = fa_val as FactionRes
	if fa == null:
		return 0.0
	var rel_val_var: Variant = fa.relations.get(b, 0.0)
	var rel_val: float = float(rel_val_var)
	return float(rel_val)


func _relation_color(rel: float) -> Color:
	# Green positive, red negative
	var t: float = clamp((rel + 1.0) * 0.5, 0.0, 1.0)
	return Color(1.0 - t, t, 0.2)


func _resources_summary(fid: StringName) -> String:
	var source_faction: FactionRes = null
	if game_store != null:
		var fa_val: Variant = game_store.factions.get(fid, null)
		source_faction = fa_val as FactionRes
	if source_faction == null and faction_system != null:
		var fa_val: Variant = faction_system.factions.get(fid, null)
		source_faction = fa_val as FactionRes
	if source_faction == null:
		return "Resources: —"
	var f: FactionRes = source_faction
	if f == null or f.resources == null or f.resources.is_empty():
		return "Resources: —"
	var parts: Array[String] = []
	var resource_keys: Array = f.resources.keys()
	for i in range(resource_keys.size()):
		var key_val: Variant = resource_keys[i]
		var key_name: StringName = key_val as StringName
		var amt_val: Variant = f.resources[key_name]
		var amt: int = int(amt_val)
		parts.append("%s: %s" % [str(key_name), str(amt)])
	parts.sort()
	return "Resources: " + ", ".join(parts)


func _faction_by_id(fid: StringName) -> FactionRes:
	if game_store != null and ("factions" in game_store):
		var f1: Variant = game_store.factions.get(fid, null)
		if f1 is FactionRes:
			return f1
	if faction_system != null:
		var f2: Variant = faction_system.factions.get(fid, null)
		if f2 is FactionRes:
			return f2
	return null


func _render_text() -> void:
	if details_label == null:
		return
	var ids: Array[StringName] = _faction_ids()
	if ids.is_empty():
		details_label.text = "No factions."
		return
	var focus: StringName = _focus_faction()
	if focus == StringName("") and ids.size() > 0:
		var first_id_val: Variant = ids[0]
		focus = first_id_val as StringName
	var focus_f: FactionRes = _faction_by_id(focus)
	var lines: Array[String] = []
	lines.append("Faction: %s" % str(focus))
	lines.append("")
	# Resources
	if focus_f == null or focus_f.resources == null or focus_f.resources.is_empty():
		lines.append("Resources: —")
	else:
		var res_parts: Array[String] = []
		var resource_keys: Array = focus_f.resources.keys()
		for i in range(resource_keys.size()):
			var k_val: Variant = resource_keys[i]
			var k_name: StringName = k_val as StringName
			var res_val: Variant = focus_f.resources[k_name]
			res_parts.append("%s: %d" % [str(k_name), int(res_val)])
		res_parts.sort()
		lines.append("Resources: " + ", ".join(res_parts))
	lines.append("")
	# Build Queue
	if build_controller != null:
		var queue: Array[Dictionary] = build_controller.get_build_queue_for_faction(focus)
		if queue.is_empty():
			lines.append("Build Queue: —")
		else:
			lines.append("Build Queue:")
			for i in range(queue.size()):
				var entry_dict_val: Variant = queue[i]
				var entry: Dictionary = entry_dict_val as Dictionary
				var res_id_val: Variant = entry.get("res_id", "")
				var res_id: StringName = StringName(str(res_id_val))
				var axial_val: Variant = entry.get("axial", Vector2i(-1, -1))
				var axial: Vector2i
				if axial_val is Vector2i:
					axial = axial_val as Vector2i
				elif axial_val is Vector2:
					var v2: Vector2 = axial_val as Vector2
					axial = Vector2i(int(floor(v2.x)), int(floor(v2.y)))
				else:
					axial = Vector2i(-1, -1)
				var hours_val: Variant = entry.get("remaining_hours", 0)
				var hours: int = int(floor(float(hours_val)))
				lines.append("  - %s at (%d,%d): %dh remaining" % [str(res_id), axial.x, axial.y, hours])
	lines.append("")
	# Relations
	lines.append("Relations:")
	for i in range(ids.size()):
		var other_val: Variant = ids[i]
		var other_name: StringName = other_val as StringName
		if other_name == focus:
			continue
		var v: float = 0.0
		if focus_f != null:
			var rel_val_var: Variant = focus_f.relations.get(other_name, 0.0)
			v = float(rel_val_var)
		lines.append("  - %s: %.2f" % [str(other_name), v])
	details_label.text = "\n".join(lines)


func _on_resources_changed(_fid: StringName, _res_id: StringName, _amt: int) -> void:
	_render_all()


func _on_factions_changed() -> void:
	_refresh_selector()
	_render_all()


func _on_world_ready() -> void:
	_refresh_selector()
	_render_all()


func _on_buildings_changed(_building_id: StringName, _new_owner: StringName) -> void:
	_render_all()


func _on_tab_changed(_tab: int) -> void:
	_render_all()


func _render_all() -> void:
	_render_text()
	_render_buildings()
	_render_units()


func _resolve_game_store() -> void:
	if game_store != null:
		return
	game_store = get_tree().get_first_node_in_group("game_store")
	if game_store == null:
		game_store = get_node_or_null("/root/GameStore")


func _render_buildings() -> void:
	if buildings_list == null:
		return
	var ids: Array[StringName] = _faction_ids()
	if ids.is_empty():
		buildings_list.text = "No factions."
		return
	var focus: StringName = _focus_faction()
	if focus == StringName("") and ids.size() > 0:
		var first_id_val: Variant = ids[0]
		focus = first_id_val as StringName
	var lines: Array[String] = []
	lines.append("Buildings for %s:" % str(focus))
	lines.append("")
	if faction_system == null:
		buildings_list.text = "Faction system not found."
		return
	var building_count: int = 0
	var building_keys: Array = faction_system.building_owner.keys()
	for i in range(building_keys.size()):
		var building_id_val: Variant = building_keys[i]
		var building_id_key: StringName = building_id_val as StringName
		var owner_val: Variant = faction_system.building_owner.get(building_id_key, StringName(""))
		var owner: StringName = owner_val as StringName
		if owner != focus:
			continue
		building_count += 1
		var btype_val: Variant = faction_system.building_types.get(building_id_key, StringName("unknown"))
		var btype: StringName = btype_val as StringName
		var axial_val: Variant = faction_system.building_axial.get(building_id_key, Vector2i(-1, -1))
		var axial: Vector2i
		if axial_val is Vector2i:
			axial = axial_val as Vector2i
		elif axial_val is Vector2:
			var v2: Vector2 = axial_val as Vector2
			axial = Vector2i(int(floor(v2.x)), int(floor(v2.y)))
		else:
			axial = Vector2i(-1, -1)
		lines.append("%d. %s (ID: %s)" % [building_count, str(btype), str(building_id_key)])
		if axial != Vector2i(-1, -1):
			lines.append("   Location: (%d, %d)" % [axial.x, axial.y])
		lines.append("")
	if building_count == 0:
		lines.append("No buildings.")
	buildings_list.text = "\n".join(lines)


func _render_units() -> void:
	if units_list == null:
		return
	var ids: Array[StringName] = _faction_ids()
	if ids.is_empty():
		units_list.text = "No factions."
		return
	var focus: StringName = _focus_faction()
	if focus == StringName("") and ids.size() > 0:
		var first_id_val: Variant = ids[0]
		focus = first_id_val as StringName
	var lines: Array[String] = []
	lines.append("Units for %s:" % str(focus))
	lines.append("")
	if faction_system == null:
		units_list.text = "Faction system not found."
		return
	var unit_count: int = 0
	var units_by_type: Dictionary = {}
	var unit_owner_keys: Array = faction_system.unit_owner.keys()
	for i in range(unit_owner_keys.size()):
		var unit_id_val: Variant = unit_owner_keys[i]
		var unit_id_key: StringName = unit_id_val as StringName
		var owner_val: Variant = faction_system.unit_owner.get(unit_id_key, StringName(""))
		var owner: StringName = owner_val as StringName
		if owner != focus:
			continue
		var utype_val: Variant = faction_system.unit_types.get(unit_id_key, StringName("unknown"))
		var utype: StringName = utype_val as StringName
		var unit_list_val: Variant
		if not units_by_type.has(utype):
			var empty_list: Array[StringName] = []
			units_by_type[utype] = empty_list
			unit_list_val = empty_list
		else:
			var unit_list_get_val: Variant = units_by_type[utype]
			unit_list_val = unit_list_get_val
		var unit_list: Array[StringName] = unit_list_val as Array[StringName]
		unit_list.append(unit_id_key)
		units_by_type[utype] = unit_list
		unit_count += 1
	if unit_count == 0:
		lines.append("No units.")
	else:
		var sorted_types: Array[StringName] = []
		var type_keys: Array = units_by_type.keys()
		for i in range(type_keys.size()):
			var k_val: Variant = type_keys[i]
			var k_name: StringName = k_val as StringName
			sorted_types.append(k_name)
		sorted_types.sort()
		for i in range(sorted_types.size()):
			var utype_val: Variant = sorted_types[i]
			var utype_name: StringName = utype_val as StringName
			var unit_ids_val: Variant = units_by_type[utype_name]
			var unit_ids: Array[StringName] = unit_ids_val as Array[StringName]
			lines.append("%s: %d" % [str(utype_name), unit_ids.size()])
			for j in range(unit_ids.size()):
				var uid_val: Variant = unit_ids[j]
				var uid_name: StringName = uid_val as StringName
				lines.append("  - %s" % str(uid_name))
			lines.append("")
	units_list.text = "\n".join(lines)
