extends CanvasLayer
class_name BuildMenu

signal resource_selected(resource: GameResource)
signal build_requested(resource: GameResource)

@export var resource_card_scene: PackedScene
@export var resources: Array[GameResource] = []
@export var buildings: Array[GameResource] = []
@export var resources_yaml_path: String = "res://resources.yaml"
@export var use_yaml_resources: bool = true

@onready var resources_grid: GridContainer = %ResourcesGrid
@onready var buildings_grid: GridContainer = %BuildingsGrid


func _ready() -> void:
	if use_yaml_resources:
		var yaml_resources := _load_resources_from_yaml()
		if not yaml_resources.is_empty():
			_merge_resources(yaml_resources)
	_rebuild_cards()


func _rebuild_cards() -> void:
	_rebuild_cards_for_grid(resources_grid, resources, "resources")
	_rebuild_cards_for_grid(buildings_grid, buildings, "buildings")


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
		card.resource_selected.connect(_on_card_selected)
		card.build_pressed.connect(_on_build_pressed)
	if grid.get_child_count() == 0:
		push_warning("Build menu has no %s to display." % label)


func _on_card_selected(resource: GameResource) -> void:
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

		res.category = String(entry.get("category", "resource")).to_lower()
		parsed.append(res)
	return parsed


func _merge_resources(additional: Array[GameResource]) -> void:
	var seen: Dictionary = {}
	for res in resources:
		if res == null:
			continue
		var res_id := String(res.id)
		if not res_id.is_empty():
			seen[res_id] = true
	for res in buildings:
		if res == null:
			continue
		var res_id := String(res.id)
		if not res_id.is_empty():
			seen[res_id] = true

	for res in additional:
		if res == null:
			continue
		var res_id := String(res.id)
		if res_id.is_empty() or seen.has(res_id):
			continue
		if res.category == "building":
			buildings.append(res)
		else:
			resources.append(res)
		seen[res_id] = true


func set_tile_context(biome_name: String, has_selection: bool) -> void:
	_update_card_states(resources_grid, biome_name, has_selection)
	_update_card_states(buildings_grid, biome_name, has_selection)


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
	return combined


func _parse_resources_yaml(text: String) -> Array:
	var entries: Array = []
	var lines := text.split("\n")
	var in_resources := false
	var current: Dictionary = {}
	var collecting_list := false

	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue

		if not in_resources:
			if trimmed == "resources:":
				in_resources = true
			continue

		if line.begins_with("  ") and not line.begins_with("    "):
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

		if collecting_list and trimmed.begins_with("-"):
			var val := trimmed.substr(1, trimmed.length()).strip_edges()
			current["buildable_tiles"].append(val)
			continue

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
