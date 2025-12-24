extends Control
class_name DiplomacyPanel

const FactionSystemRes = preload("res://scripts/faction_system.gd")
const FactionRes = preload("res://scripts/faction.gd")
const BuildControllerRes = preload("res://scripts/build_controller.gd")

@export var faction_system_path: NodePath
@export var focus_selector_path: NodePath
@export var details_label_path: NodePath

var faction_system: FactionSystemRes
var game_store: Node
var build_controller: BuildControllerRes
var focus_selector: OptionButton
var details_label: RichTextLabel


func _ready() -> void:
	focus_selector = get_node_or_null(focus_selector_path) as OptionButton
	details_label = get_node_or_null(details_label_path) as RichTextLabel
	_resolve_game_store()
	_resolve_faction_system()
	_resolve_build_controller()
	if game_store != null:
		if not game_store.factions_changed.is_connected(_on_factions_changed):
			game_store.factions_changed.connect(_on_factions_changed)
		if not game_store.world_ready.is_connected(_on_world_ready):
			game_store.world_ready.connect(_on_world_ready)
	if game_store != null and not game_store.factions_changed.is_connected(_on_factions_changed):
		game_store.factions_changed.connect(_on_factions_changed)
	if faction_system != null and not faction_system.factions_changed.is_connected(_on_factions_changed):
		faction_system.factions_changed.connect(_on_factions_changed)
	if faction_system != null and not faction_system.resources_changed.is_connected(_on_resources_changed):
		faction_system.resources_changed.connect(_on_resources_changed)
	_refresh_selector()
	if focus_selector != null:
		focus_selector.item_selected.connect(_on_focus_selected)
	_render_text()


func _resolve_faction_system() -> void:
	if not faction_system_path.is_empty():
		faction_system = get_node_or_null(faction_system_path) as FactionSystem
	else:
		faction_system = get_tree().get_first_node_in_group("faction_system") as FactionSystem


func _resolve_build_controller() -> void:
	build_controller = get_tree().get_first_node_in_group("build_controller") as BuildControllerRes
	if build_controller == null:
		var nodes := get_tree().get_nodes_in_group("build_controller")
		if nodes.size() > 0:
			build_controller = nodes[0] as BuildControllerRes


func _refresh_selector() -> void:
	if focus_selector == null:
		return
	focus_selector.clear()
	var ids := _faction_ids()
	for i in range(ids.size()):
		focus_selector.add_item(str(ids[i]), i)
	if focus_selector.item_count > 0:
		focus_selector.select(0)


func _on_focus_selected(_index: int) -> void:
	_render_text()


func _focus_faction() -> StringName:
	if focus_selector == null:
		return StringName("")
	if focus_selector.item_count == 0:
		return StringName("")
	var idx := focus_selector.get_selected()
	if idx < 0 or idx >= focus_selector.item_count:
		return StringName("")
	return StringName(focus_selector.get_item_text(idx))


func _faction_ids() -> Array[StringName]:
	if game_store != null:
		var ids: Array[StringName] = []
		for k in game_store.factions.keys():
			if String(k) != "":
				ids.append(k)
		ids.sort()
		if not ids.is_empty():
			return ids
	if faction_system == null:
		return []
	var ids_fs: Array[StringName] = []
	for k in faction_system.factions.keys():
		if String(k) != "":
			ids_fs.append(k)
	ids_fs.sort()
	return ids_fs


func _relation_between(a: StringName, b: StringName) -> float:
	if faction_system == null:
		return 0.0
	var fa: FactionRes = faction_system.factions.get(a, null)
	if fa == null:
		return 0.0
	var rel_val: float = float(fa.relations.get(b, 0.0))
	return float(rel_val)


func _relation_color(rel: float) -> Color:
	# Green positive, red negative
	var t: float = clamp((rel + 1.0) * 0.5, 0.0, 1.0)
	return Color(1.0 - t, t, 0.2)


func _resources_summary(fid: StringName) -> String:
	var source_faction: FactionRes = null
	if game_store != null:
		source_faction = game_store.factions.get(fid, null)
	if source_faction == null and faction_system != null:
		source_faction = faction_system.factions.get(fid, null)
	if source_faction == null:
		return "Resources: —"
	var f: FactionRes = source_faction
	if f == null or f.resources == null or f.resources.is_empty():
		return "Resources: —"
	var parts: Array[String] = []
	for key in f.resources.keys():
		var amt: int = int(f.resources[key])
		parts.append("%s: %s" % [str(key), str(amt)])
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
	var ids := _faction_ids()
	if ids.is_empty():
		details_label.text = "No factions."
		return
	var focus := _focus_faction()
	if focus == StringName("") and ids.size() > 0:
		focus = ids[0]
	var focus_f := _faction_by_id(focus)
	var lines: Array[String] = []
	lines.append("Faction: %s" % str(focus))
	lines.append("")
	# Resources
	if focus_f == null or focus_f.resources == null or focus_f.resources.is_empty():
		lines.append("Resources: —")
	else:
		var res_parts: Array[String] = []
		for k in focus_f.resources.keys():
			res_parts.append("%s: %d" % [str(k), int(focus_f.resources[k])])
		res_parts.sort()
		lines.append("Resources: " + ", ".join(res_parts))
	lines.append("")
	# Build Queue
	if build_controller != null:
		var queue: Array = build_controller.get_build_queue_for_faction(focus)
		if queue.is_empty():
			lines.append("Build Queue: —")
		else:
			lines.append("Build Queue:")
			for entry in queue:
				var res_id: StringName = entry.get("res_id", StringName(""))
				var axial: Vector2i = entry.get("axial", Vector2i(-1, -1))
				var hours: int = int(entry.get("remaining_hours", 0))
				lines.append("  - %s at (%d,%d): %dh remaining" % [str(res_id), axial.x, axial.y, hours])
	lines.append("")
	# Relations
	lines.append("Relations:")
	for other in ids:
		if other == focus:
			continue
		var v: float = 0.0
		if focus_f != null:
			v = float(focus_f.relations.get(other, 0.0))
		lines.append("  - %s: %.2f" % [str(other), v])
	details_label.text = "\n".join(lines)


func _on_resources_changed(_fid: StringName, _res_id: StringName, _amt: int) -> void:
	_render_text()


func _on_factions_changed() -> void:
	_refresh_selector()
	_render_text()


func _on_world_ready() -> void:
	_refresh_selector()
	_render_text()


func _resolve_game_store() -> void:
	if game_store != null:
		return
	game_store = get_tree().get_first_node_in_group("game_store")
	if game_store == null:
		game_store = get_node_or_null("/root/GameStore")
