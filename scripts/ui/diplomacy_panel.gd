extends Control
class_name DiplomacyPanel

const FactionSystemRes = preload("res://scripts/faction_system.gd")
const FactionRes = preload("res://scripts/faction.gd")

@export var faction_system_path: NodePath
@export var graph_edit_path: NodePath
@export var focus_selector_path: NodePath

var faction_system: FactionSystemRes
var graph_edit: GraphEdit
var focus_selector: OptionButton


func _ready() -> void:
	graph_edit = get_node_or_null(graph_edit_path) as GraphEdit
	focus_selector = get_node_or_null(focus_selector_path) as OptionButton
	_resolve_faction_system()
	_refresh_selector()
	if focus_selector != null:
		focus_selector.item_selected.connect(_on_focus_selected)
	_rebuild_graph()


func _resolve_faction_system() -> void:
	if not faction_system_path.is_empty():
		faction_system = get_node_or_null(faction_system_path) as FactionSystem
	else:
		faction_system = get_tree().get_first_node_in_group("faction_system") as FactionSystem


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
	_rebuild_graph()


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
	if faction_system == null:
		return []
	var ids: Array[StringName] = []
	for k in faction_system.factions.keys():
		if String(k) != "":
			ids.append(k)
	ids.sort()
	return ids


func _rebuild_graph() -> void:
	if graph_edit == null:
		return
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		child.queue_free()

	var ids := _faction_ids()
	if ids.is_empty():
		return
	var focus := _focus_faction()
	if focus == StringName("") and ids.size() > 0:
		focus = ids[0]

	var radius := 220.0
	var center := Vector2(300, 220)
	for i in range(ids.size()):
		var fid := ids[i]
		var angle := TAU * float(i) / float(max(ids.size(), 1))
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		_add_node(fid, pos, focus)

	# Connect focus to others to visualize relations
	for fid in ids:
		if fid == focus:
			continue
		graph_edit.connect_node(str(focus), 0, str(fid), 0)


func _add_node(fid: StringName, pos: Vector2, focus: StringName) -> void:
	var node := GraphNode.new()
	node.name = str(fid)
	node.title = str(fid)
	node.draggable = true
	node.position_offset = pos
	var relation := _relation_between(fid, focus)
	var color := _relation_color(relation)
	node.set_slot(0, true, 0, color, true, 0, color, null, null)
	var label := Label.new()
	label.text = "Relation to %s: %.2f" % [str(focus), relation]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_child(label)
	graph_edit.add_child(node)


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
