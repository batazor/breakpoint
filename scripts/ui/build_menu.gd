extends CanvasLayer
class_name BuildMenu

signal resource_selected(resource: GameResource)
signal build_requested(resource: GameResource)

@export var resource_card_scene: PackedScene
@export var resources: Array[GameResource] = []
@export var resources_yaml_path: String = "res://resources.yaml"

@onready var resources_grid: GridContainer = %ResourcesGrid


func _ready() -> void:
	if _resources_are_empty():
		_load_resources_from_yaml()
	_rebuild_resource_cards()


func _rebuild_resource_cards() -> void:
	if resources_grid == null:
		return
	for child in resources_grid.get_children():
		child.queue_free()
	if resource_card_scene == null:
		push_warning("Resource card scene is not set.")
		return
	for res in resources:
		if res == null:
			continue
		var card := resource_card_scene.instantiate() as ResourceCard
		if card == null:
			continue
		resources_grid.add_child(card)
		card.setup(res)
		card.resource_selected.connect(_on_card_selected)
		card.build_pressed.connect(_on_build_pressed)
	if resources_grid.get_child_count() == 0:
		push_warning("Build menu has no resources to display.")


func _on_card_selected(resource: GameResource) -> void:
	emit_signal("resource_selected", resource)


func _on_build_pressed(resource: GameResource) -> void:
	emit_signal("build_requested", resource)


func _resources_are_empty() -> bool:
	if resources.is_empty():
		return true
	for res in resources:
		if res != null:
			return false
	return true


func _load_resources_from_yaml() -> void:
	if resources_yaml_path.is_empty():
		return
	var file := FileAccess.open(resources_yaml_path, FileAccess.READ)
	if file == null:
		push_warning("Resources yaml not found: %s" % resources_yaml_path)
		return
	var text := file.get_as_text()
	file.close()

	var entries := _parse_resources_yaml(text)
	if entries.is_empty():
		push_warning("No resources found in yaml: %s" % resources_yaml_path)
		return

	resources.clear()
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
			res.set_meta("buildable_tiles", entry["buildable_tiles"])

		resources.append(res)


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
