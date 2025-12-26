extends CanvasLayer
class_name BuildMenu

signal resource_selected(resource: GameResource)
signal build_requested(resource: GameResource)

var _ui_ready: bool = false

@export var resource_card_scene: PackedScene
@export var resources: Array[GameResource] = []
@export var buildings: Array[GameResource] = []
@export var characters: Array[GameResource] = []
@export var resources_yaml_path: String = "res://building.yaml"
@export var use_yaml_resources: bool = true

@onready var resources_grid: GridContainer = %ResourcesGrid
@onready var buildings_grid: GridContainer = %BuildingsGrid
@onready var characters_grid: GridContainer = %CharactersGrid
@onready var tabs: TabContainer = %Tabs
@onready var resources_scroll: ScrollContainer = %ResourcesScroll
@onready var buildings_scroll: ScrollContainer = %BuildingsScroll
@onready var characters_scroll: ScrollContainer = %CharactersScroll
@onready var hint_label: Label = %HintLabel
@onready var collapse_button: Button = %ToggleButton
@onready var build_panel: PanelContainer = $"BuildPanel"

var _selected_card: ResourceCard
var _scroll_positions: Dictionary = {"resources": 0, "buildings": 0, "characters": 0}
var _active_tab_key: String = "resources"
var _collapsed: bool = false


func _ready() -> void:
	if use_yaml_resources:
		var yaml_resources := _load_resources_from_yaml()
		if not yaml_resources.is_empty():
			_merge_resources(yaml_resources)
	if tabs != null:
		_active_tab_key = _get_tab_key(tabs.current_tab)
		tabs.tab_changed.connect(_on_tab_changed)
	if collapse_button != null:
		collapse_button.pressed.connect(_on_toggle_pressed)
	_rebuild_cards()
	_restore_scroll_position(_active_tab_key)


func _rebuild_cards() -> void:
	_store_scroll_position("resources")
	_store_scroll_position("buildings")
	_store_scroll_position("characters")
	_selected_card = null
	_rebuild_cards_for_grid(resources_grid, resources, "resources")
	_rebuild_cards_for_grid(buildings_grid, buildings, "buildings")
	_rebuild_cards_for_grid(characters_grid, characters, "characters")
	_restore_scroll_position("resources")
	_restore_scroll_position("buildings")
	_restore_scroll_position("characters")


func _rebuild_cards_for_grid(grid: GridContainer, list: Array[GameResource], label: String) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	if resource_card_scene == null:
		push_warning("Resource card scene is not set.")
		return
	for res in list:
		if res == null:
			continue
		var card := resource_card_scene.instantiate() as ResourceCard
		if card == null:
			continue
		grid.add_child(card)
		card.setup(res)
		card.resource_selected.connect(func(r: GameResource) -> void:
			_handle_card_selected(card, r)
		)
		card.build_requested.connect(func(r: GameResource) -> void:
			_handle_card_selected(card, r)
			_on_build_pressed(r)
		)
	if grid.get_child_count() == 0:
		push_warning("Build menu has no %s to display." % label)


func _handle_card_selected(card: ResourceCard, resource: GameResource) -> void:
	_set_selected_card(card)
	emit_signal("resource_selected", resource)


func _on_build_pressed(resource: GameResource) -> void:
	emit_signal("build_requested", resource)


func _load_resources_from_yaml() -> Array[GameResource]:
	var parsed: Array[GameResource] = []
	if resources_yaml_path.is_empty():
		return parsed
	var file := FileAccess.open(resources_yaml_path, FileAccess.READ)
	if file == null:
		push_warning("Resources yaml not found: %s" % resources_yaml_path)
		return parsed
	var text := file.get_as_text()
	file.close()

	var entries := _parse_resources_yaml(text)
	if entries.is_empty():
		push_warning("No resources found in yaml: %s" % resources_yaml_path)
		return parsed

	for entry in entries:
		var res := GameResource.new()
		var id_val := String(entry.get("id", entry.get("key", "")))
		if id_val.is_empty():
			continue
		res.id = StringName(id_val)
		res.title = String(entry.get("title", id_val))
		res.description = String(entry.get("description", ""))

		var icon_path := String(entry.get("icon", ""))
		if not icon_path.is_empty():
			var icon_res := load(icon_path)
			if icon_res is Texture2D:
				res.icon = icon_res
			else:
				push_warning("Icon is not a Texture2D: %s" % icon_path)

		var scene_path := String(entry.get("scene", ""))
		if not scene_path.is_empty():
			var scene_res := load(scene_path)
			if scene_res is PackedScene:
				res.scene = scene_res
			else:
				push_warning("Scene is not a PackedScene: %s" % scene_path)

		if entry.has("buildable_tiles"):
			res.buildable_tiles = entry["buildable_tiles"]

		if entry.has("roles") and entry["roles"] is Array:
			res.roles = entry["roles"]
		if entry.has("resource_delta_per_hour") and entry["resource_delta_per_hour"] is Dictionary:
			res.resource_delta_per_hour = entry["resource_delta_per_hour"]
		if entry.has("build_cost") and entry["build_cost"] is Dictionary:
			res.build_cost = entry["build_cost"]
		res.build_time_hours = int(entry.get("build_time_hours", 0))

		res.category = String(entry.get("category", "resource")).to_lower()
		parsed.append(res)
	return parsed


func _merge_resources(additional: Array[GameResource]) -> void:
	var seen: Dictionary = {}
	
	# Mark all existing resources as seen
	_mark_resources_as_seen(resources, seen)
	_mark_resources_as_seen(buildings, seen)
	_mark_resources_as_seen(characters, seen)
	
	# Add new resources that haven't been seen
	for res in additional:
		if res == null:
			continue
		var res_id := String(res.id)
		if res_id.is_empty() or seen.has(res_id):
			continue
		
		# Categorize and add
		match res.category:
			"building":
				buildings.append(res)
			"character":
				characters.append(res)
			_:
				resources.append(res)
		
		seen[res_id] = true


func _mark_resources_as_seen(res_array: Array[GameResource], seen: Dictionary) -> void:
	for res in res_array:
		if res == null:
			continue
		var res_id := String(res.id)
		if not res_id.is_empty():
			seen[res_id] = true


func set_tile_context(biome_name: String, has_selection: bool) -> void:
	if not _ui_ready:
		call_deferred("set_tile_context", biome_name, has_selection)
		return

	clear_hint()
	_update_card_states(resources_grid, biome_name, has_selection)
	_update_card_states(buildings_grid, biome_name, has_selection)
	_update_card_states(characters_grid, biome_name, has_selection)


func _update_card_states(grid: GridContainer, biome_name: String, has_selection: bool) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		var card := child as ResourceCard
		if card == null or card.resource == null:
			continue
		var can_build := card.resource.can_build_on(biome_name)
		card.set_buildable_state(can_build, has_selection)


func get_all_resources() -> Array[GameResource]:
	var combined: Array[GameResource] = []
	combined.append_array(resources)
	combined.append_array(buildings)
	combined.append_array(characters)
	return combined


func show_hint(text: String) -> void:
	if not _ui_ready:
		call_deferred("show_hint", text)
		return
	hint_label.text = text
	hint_label.visible = not text.is_empty()


func clear_hint() -> void:
	if not _ui_ready:
		call_deferred("clear_hint")
		return
	hint_label.visible = false


func _set_selected_card(card: ResourceCard) -> void:
	if _selected_card != null and is_instance_valid(_selected_card):
		_selected_card.set_selected(false)
	_selected_card = card
	if _selected_card != null and is_instance_valid(_selected_card):
		_selected_card.set_selected(true)


func _store_scroll_position(key: String) -> void:
	match key:
		"resources":
			UIUtils.store_scroll_position(resources_scroll, _scroll_positions, "resources")
		"buildings":
			UIUtils.store_scroll_position(buildings_scroll, _scroll_positions, "buildings")
		"characters":
			UIUtils.store_scroll_position(characters_scroll, _scroll_positions, "characters")


func _restore_scroll_position(key: String) -> void:
	match key:
		"resources":
			UIUtils.restore_scroll_position(resources_scroll, _scroll_positions, "resources")
		"buildings":
			UIUtils.restore_scroll_position(buildings_scroll, _scroll_positions, "buildings")
		"characters":
			UIUtils.restore_scroll_position(characters_scroll, _scroll_positions, "characters")


func _on_tab_changed(tab: int) -> void:
	_store_scroll_position(_active_tab_key)
	_active_tab_key = _get_tab_key(tab)
	_restore_scroll_position(_active_tab_key)


func _get_tab_key(tab: int) -> String:
	match tab:
		1:
			return "buildings"
		2:
			return "characters"
		_:
			return "resources"


func _on_toggle_pressed() -> void:
	_set_collapsed(not _collapsed)


func _set_collapsed(value: bool) -> void:
	_collapsed = value
	if build_panel != null:
		build_panel.visible = not _collapsed
	if collapse_button != null:
		collapse_button.text = "Show Menu" if _collapsed else "Hide Menu"


func _parse_resources_yaml(text: String) -> Array:
	var entries: Array = []
	var lines := text.split("\n")
	var in_resources := false
	var current: Dictionary = {}
	var collecting_list := false
	var collecting_roles := false
	var current_role: Dictionary = {}
	var collecting_dict := false
	var current_dict_key := ""

	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue

		if not in_resources:
			if trimmed == "resources:":
				in_resources = true
			continue

		if line.begins_with("  ") and not line.begins_with("    "):
			if collecting_roles:
				if not current_role.is_empty():
					if not current.has("roles"):
						current["roles"] = []
					current["roles"].append(current_role.duplicate())
				collecting_roles = false
				current_role = {}
			collecting_dict = false
			current_dict_key = ""
			_commit_resource_entry(entries, current)
			current = {"key": trimmed.rstrip(":")}
			collecting_list = false
			continue

		if not line.begins_with("    "):
			continue

		if trimmed == "buildable_tiles:":
			collecting_list = true
			current["buildable_tiles"] = []
			continue

		if trimmed == "resource_delta_per_hour:" or trimmed == "build_cost:":
			collecting_dict = true
			current_dict_key = trimmed.rstrip(":")
			current[current_dict_key] = {}
			continue

		if trimmed == "roles:":
			collecting_roles = true
			current_role = {}
			current["roles"] = []
			continue

		if collecting_roles:
			if trimmed.begins_with("-"):
				if not current_role.is_empty():
					current["roles"].append(current_role.duplicate())
				current_role = {}
				var after := trimmed.substr(1, trimmed.length()).strip_edges()
				var sep_role := after.find(":")
				if sep_role >= 0:
					var k := after.substr(0, sep_role).strip_edges()
					var v := after.substr(sep_role + 1, after.length()).strip_edges()
					current_role[k] = _parse_scalar(v)
				continue
			var sep_r := trimmed.find(":")
			if sep_r >= 0:
				var k2 := trimmed.substr(0, sep_r).strip_edges()
				var v2 := trimmed.substr(sep_r + 1, trimmed.length()).strip_edges()
				current_role[k2] = _parse_scalar(v2)
			continue

		if collecting_list and trimmed.begins_with("-"):
			var val := trimmed.substr(1, trimmed.length()).strip_edges()
			current["buildable_tiles"].append(val)
			continue

		if collecting_dict:
			if trimmed.find(":") >= 0:
				var sep_d := trimmed.find(":")
				var k_d := trimmed.substr(0, sep_d).strip_edges()
				var v_d := trimmed.substr(sep_d + 1, trimmed.length()).strip_edges()
				current[current_dict_key][k_d] = _parse_scalar(v_d)
				continue
			else:
				collecting_dict = false
				current_dict_key = ""

		collecting_list = false
		var sep := trimmed.find(":")
		if sep < 0:
			continue
		var key := trimmed.substr(0, sep).strip_edges()
		var value := trimmed.substr(sep + 1, trimmed.length()).strip_edges()
		if value.begins_with("\"") and value.ends_with("\""):
			value = value.substr(1, value.length() - 2)
		current[key] = value

	_commit_resource_entry(entries, current)
	return entries


func _commit_resource_entry(entries: Array, current: Dictionary) -> void:
	if current.is_empty():
		return
	if String(current.get("key", "")).is_empty() and String(current.get("id", "")).is_empty():
		return
	entries.append(current.duplicate())


func _parse_scalar(raw: String) -> Variant:
	if raw.is_empty():
		return ""
	if raw.begins_with("\"") and raw.ends_with("\""):
		return raw.substr(1, raw.length() - 2)
	if raw.is_valid_int():
		return int(raw)
	if raw.is_valid_float():
		return float(raw)
	if raw == "true":
		return true
	if raw == "false":
		return false
	return raw
