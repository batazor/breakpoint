@tool
extends PanelContainer

const DEFAULT_PATH := "res://tile_sides.yaml"
const HexSideEditorScript = preload("res://addons/tile_sides_editor/hex_side_editor.gd")

var file_path_edit: LineEdit
var reload_button: Button
var save_button: Button
var tile_select: OptionButton
var type_select: OptionButton
var add_type_edit: LineEdit
var add_type_button: Button
var hex_editor: TileSidesHexEditor
var side_selects: Array = []
var status_label: Label
var direction_label: Label
var preview_path_edit: LineEdit
var preview_button: Button
var preview_set_button: Button
var preview_texture: TextureRect
var preview_dialog: EditorFileDialog
var previewer: EditorResourcePreview

var lines: PackedStringArray = PackedStringArray()
var tile_entries: Dictionary = {}
var tile_order: Array[String] = []
var side_types: Array[String] = []
var current_tile: String = ""
var dirty: bool = false


func _ready() -> void:
	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(root)

	var file_row := HBoxContainer.new()
	root.add_child(file_row)

	var file_label := Label.new()
	file_label.text = "Tile sides file:"
	file_row.add_child(file_label)

	file_path_edit = LineEdit.new()
	file_path_edit.text = DEFAULT_PATH
	file_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_row.add_child(file_path_edit)

	reload_button = Button.new()
	reload_button.text = "Reload"
	reload_button.pressed.connect(_on_reload_pressed)
	file_row.add_child(reload_button)

	save_button = Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_on_save_pressed)
	file_row.add_child(save_button)

	var tile_row := HBoxContainer.new()
	root.add_child(tile_row)

	var tile_label := Label.new()
	tile_label.text = "Tile:"
	tile_row.add_child(tile_label)

	tile_select = OptionButton.new()
	tile_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_select.item_selected.connect(_on_tile_selected)
	tile_row.add_child(tile_select)

	var type_row := HBoxContainer.new()
	root.add_child(type_row)

	var type_label := Label.new()
	type_label.text = "Side type:"
	type_row.add_child(type_label)

	type_select = OptionButton.new()
	type_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(type_select)

	add_type_edit = LineEdit.new()
	add_type_edit.placeholder_text = "Add type"
	add_type_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(add_type_edit)

	add_type_button = Button.new()
	add_type_button.text = "Add"
	add_type_button.pressed.connect(_on_add_type_pressed)
	type_row.add_child(add_type_button)

	var preview_row := HBoxContainer.new()
	root.add_child(preview_row)
	var preview_label := Label.new()
	preview_label.text = "GLB preview:"
	preview_row.add_child(preview_label)
	preview_path_edit = LineEdit.new()
	preview_path_edit.placeholder_text = "res://assets/tiles/..."
	preview_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(preview_path_edit)
	var pick_button := Button.new()
	pick_button.text = "Pick"
	pick_button.pressed.connect(_on_pick_preview_pressed)
	preview_row.add_child(pick_button)
	preview_button = Button.new()
	preview_button.text = "Preview"
	preview_button.pressed.connect(_on_preview_pressed)
	preview_row.add_child(preview_button)
	preview_set_button = Button.new()
	preview_set_button.text = "Set"
	preview_set_button.pressed.connect(_on_set_model_pressed)
	preview_row.add_child(preview_set_button)

	preview_texture = TextureRect.new()
	preview_texture.custom_minimum_size = Vector2(240, 240)
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(preview_texture)

	var side_list := VBoxContainer.new()
	root.add_child(side_list)
	for i in range(6):
		var row := HBoxContainer.new()
		side_list.add_child(row)
		var side_label := Label.new()
		side_label.text = "Side %d:" % i
		row.add_child(side_label)
		var select := OptionButton.new()
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.item_selected.connect(_on_side_option_selected.bind(i))
		row.add_child(select)
		side_selects.append(select)

	direction_label = Label.new()
	direction_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	direction_label.text = "Dir order: 0=(1,0) 1=(1,-1) 2=(0,-1) 3=(-1,0) 4=(-1,1) 5=(0,1)"
	root.add_child(direction_label)

	hex_editor = HexSideEditorScript.new()
	hex_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hex_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_editor.custom_minimum_size = Vector2(260, 260)
	hex_editor.side_clicked.connect(_on_side_clicked)
	root.add_child(hex_editor)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(status_label)

	preview_dialog = EditorFileDialog.new()
	preview_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	preview_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	preview_dialog.filters = PackedStringArray(["*.glb ; GLB", "*.gltf ; GLTF"])
	preview_dialog.file_selected.connect(_on_preview_file_selected)
	add_child(preview_dialog)

	_load_file(file_path_edit.text)


func _on_reload_pressed() -> void:
	_load_file(file_path_edit.text)


func _on_save_pressed() -> void:
	_save_file(file_path_edit.text)


func _on_tile_selected(index: int) -> void:
	if index < 0 or index >= tile_order.size():
		return
	_set_current_tile(tile_order[index])


func _on_add_type_pressed() -> void:
	var value := add_type_edit.text.strip_edges()
	if value.is_empty():
		return
	if not side_types.has(value):
		side_types.append(value)
		side_types.sort()
		_refresh_type_list()
	add_type_edit.text = ""


func _on_side_clicked(index: int) -> void:
	if current_tile.is_empty():
		return
	if index < 0 or index >= 6:
		return
	var value := _selected_side_type()
	if value.is_empty():
		return
	_set_side_value(current_tile, index, value)
	hex_editor.set_side_value(index, value)
	_select_side_option(index, value)


func _on_side_option_selected(selected_index: int, side_idx: int) -> void:
	if current_tile.is_empty():
		return
	if side_idx < 0 or side_idx >= 6:
		return
	var select: OptionButton = null
	var item: Variant = side_selects[side_idx]
	if item is OptionButton:
		select = item
	if select == null:
		return
	var value: String = select.get_item_text(selected_index)
	_set_side_value(current_tile, side_idx, value)
	hex_editor.set_side_value(side_idx, value)


func _on_pick_preview_pressed() -> void:
	if preview_dialog != null:
		preview_dialog.popup_centered_ratio(0.6)


func _on_preview_file_selected(path: String) -> void:
	preview_path_edit.text = path
	_request_preview(path)


func _on_preview_pressed() -> void:
	_request_preview(preview_path_edit.text)


func _on_set_model_pressed() -> void:
	if current_tile.is_empty():
		return
	var path := preview_path_edit.text.strip_edges()
	if path.is_empty():
		_set_status("Model path is empty.")
		return
	_set_model_value(current_tile, path)
	_request_preview(path)


func _selected_side_type() -> String:
	if type_select.item_count == 0:
		return ""
	return type_select.get_item_text(type_select.selected)


func _load_file(path: String) -> void:
	dirty = false
	lines.clear()
	tile_entries.clear()
	tile_order.clear()
	side_types.clear()
	if path.is_empty():
		_set_status("No file path set.")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Failed to open: %s" % path)
		return
	var text := file.get_as_text()
	file.close()
	lines = text.split("\n")
	_parse_lines()
	_refresh_tile_list()
	_refresh_type_list()
	if tile_order.size() > 0:
		_set_current_tile(tile_order[0])
		tile_select.select(0)
		if status_label != null:
			_set_status("Loaded %d tiles from %s" % [tile_order.size(), path])
	else:
		if status_label != null:
			_set_status("No tiles found in %s" % path)


func _save_file(path: String) -> void:
	if path.is_empty():
		_set_status("No file path set.")
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("Failed to save: %s" % path)
		return
	file.store_string("\n".join(lines))
	file.close()
	dirty = false
	_set_status("Saved: %s" % path)


func _refresh_tile_list() -> void:
	tile_select.clear()
	for name in tile_order:
		tile_select.add_item(name)


func _refresh_type_list() -> void:
	type_select.clear()
	side_types.sort()
	for value in side_types:
		type_select.add_item(value)
	_refresh_side_selects()


func _set_current_tile(tile_name: String) -> void:
	current_tile = tile_name
	var tile_index := tile_order.find(tile_name)
	if tile_index >= 0:
		tile_select.select(tile_index)
	var entry: Dictionary = tile_entries.get(tile_name, {})
	var sides_raw: Array = entry.get("side", [])
	var sides := _to_string_array(sides_raw)
	hex_editor.set_side_values(sides)
	hex_editor.set_selected_side(-1)
	_set_side_select_values(sides)
	var model_path: String = String(entry.get("model", ""))
	preview_path_edit.text = model_path
	if not model_path.is_empty():
		_request_preview(model_path)
	_set_status("Editing: %s%s" % [tile_name, " (unsaved)" if dirty else ""])


func _set_side_value(tile_name: String, index: int, value: String) -> void:
	if not tile_entries.has(tile_name):
		return
	var entry: Dictionary = tile_entries[tile_name]
	var sides: Array = entry.get("side", [])
	if sides.size() < 6:
		sides.resize(6)
	sides[index] = value
	entry["side"] = sides
	tile_entries[tile_name] = entry

	var line_indices: Array = entry.get("lines", [])
	if line_indices.size() == 6:
		var line_idx: int = line_indices[index]
		if line_idx >= 0 and line_idx < lines.size():
			var indent := _line_indent(lines[line_idx])
			lines[line_idx] = indent + "- " + value
	dirty = true
	_set_status("Editing: %s (unsaved)" % tile_name)
	_select_side_option(index, value)


func _parse_lines() -> void:
	var type_set: Dictionary = {}
	var i := 0
	while i < lines.size():
		var line := lines[i]
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			i += 1
			continue
		if _is_tile_line(line, trimmed):
			var tile_name := trimmed.substr(0, trimmed.length() - 1)
			tile_order.append(tile_name)
			var entry := {
				"side": [],
				"lines": [],
				"line": i,
				"model": "",
				"model_line": -1,
				"side_header": -1,
			}
			var j := i + 1
			while j < lines.size():
				var l := lines[j]
				var t := l.strip_edges()
				if _is_tile_line(l, t):
					break
				if t.begins_with("model:"):
					var model_path := t.substr(6, t.length()).strip_edges()
					var hash_idx := model_path.find("#")
					if hash_idx >= 0:
						model_path = model_path.substr(0, hash_idx).strip_edges()
					entry["model"] = model_path
					entry["model_line"] = j
				if t.begins_with("side:"):
					entry["side_header"] = j
					var k := j + 1
					while k < lines.size():
						var kl := lines[k]
						var kt := kl.strip_edges()
						if _is_tile_line(kl, kt):
							break
						if kt.begins_with("-"):
							var val := kt.substr(1, kt.length()).strip_edges()
							entry["side"].append(val)
							entry["lines"].append(k)
							type_set[val] = true
							if entry["side"].size() >= 6:
								break
						k += 1
				j += 1
			tile_entries[tile_name] = entry
			i = j
			continue
		i += 1
	side_types.clear()
	for key in type_set.keys():
		side_types.append(String(key))
	if side_types.is_empty():
		side_types = ["water", "land", "river", "sand", "plains", "mountain"]


func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result


func _set_model_value(tile_name: String, path: String) -> void:
	if not tile_entries.has(tile_name):
		return
	var entry: Dictionary = tile_entries[tile_name]
	var model_line: int = int(entry.get("model_line", -1))
	var indent := _child_indent(entry)
	if model_line >= 0 and model_line < lines.size():
		lines[model_line] = indent + "model: " + path
	else:
		var insert_at: int = int(entry.get("side_header", -1))
		if insert_at < 0:
			insert_at = int(entry.get("line", 0)) + 1
		lines.insert(insert_at, indent + "model: " + path)
		_shift_line_indices(insert_at, 1)
		entry["model_line"] = insert_at
	entry["model"] = path
	tile_entries[tile_name] = entry
	dirty = true
	_set_status("Editing: %s (unsaved)" % tile_name)


func _shift_line_indices(start_index: int, delta: int) -> void:
	for key in tile_entries.keys():
		var entry: Dictionary = tile_entries[key]
		if entry.has("line") and int(entry["line"]) >= start_index:
			entry["line"] = int(entry["line"]) + delta
		if entry.has("model_line") and int(entry["model_line"]) >= start_index:
			entry["model_line"] = int(entry["model_line"]) + delta
		if entry.has("side_header") and int(entry["side_header"]) >= start_index:
			entry["side_header"] = int(entry["side_header"]) + delta
		var line_indices: Array = entry.get("lines", [])
		if line_indices.size() > 0:
			for i in range(line_indices.size()):
				var li: int = int(line_indices[i])
				if li >= start_index:
					line_indices[i] = li + delta
			entry["lines"] = line_indices
		tile_entries[key] = entry


func _child_indent(entry: Dictionary) -> String:
	var model_line: int = int(entry.get("model_line", -1))
	if model_line >= 0 and model_line < lines.size():
		return _line_indent_prefix(lines[model_line])
	var side_header: int = int(entry.get("side_header", -1))
	if side_header >= 0 and side_header < lines.size():
		return _line_indent_prefix(lines[side_header])
	return "    "


func _refresh_side_selects() -> void:
	for raw in side_selects:
		var select: OptionButton = null
		var item: Variant = raw
		if item is OptionButton:
			select = item
		if select == null:
			continue
		var current: String = ""
		if select.item_count > 0 and select.selected >= 0:
			current = select.get_item_text(select.selected)
		select.clear()
		for value in side_types:
			select.add_item(value)
		if not current.is_empty():
			var idx := side_types.find(current)
			if idx >= 0:
				select.select(idx)


func _set_side_select_values(sides: Array) -> void:
	_refresh_side_selects()
	for i in range(side_selects.size()):
		var select: OptionButton = null
		var item: Variant = side_selects[i]
		if item is OptionButton:
			select = item
		if select == null:
			continue
		var value: String = "land"
		if i < sides.size():
			value = String(sides[i])
		var idx := side_types.find(value)
		if idx < 0:
			idx = 0
		select.select(idx)


func _select_side_option(index: int, value: String) -> void:
	if index < 0 or index >= side_selects.size():
		return
	var select: OptionButton = null
	var item: Variant = side_selects[index]
	if item is OptionButton:
		select = item
	if select == null:
		return
	var idx := side_types.find(value)
	if idx >= 0:
		select.select(idx)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func set_resource_previewer(value: EditorResourcePreview) -> void:
	previewer = value


func _request_preview(path: String) -> void:
	if path.is_empty():
		return
	if previewer == null:
		_set_status("Previewer not available.")
		return
	if not ResourceLoader.exists(path):
		_set_status("Preview path not found: %s" % path)
		return
	previewer.queue_resource_preview(path, self, "_on_preview_ready", null)


func _on_preview_ready(path: String, preview: Texture2D, thumbnail: Texture2D, userdata: Variant) -> void:
	if preview_texture == null:
		return
	preview_texture.texture = preview if preview != null else thumbnail


func _is_tile_line(line: String, trimmed: String) -> bool:
	return line.begins_with("  ") and not line.begins_with("    ") and trimmed.ends_with(":") and not trimmed.begins_with("#")


func _line_indent(line: String) -> String:
	var dash_idx := line.find("-")
	if dash_idx <= 0:
		return "      "
	return line.substr(0, dash_idx)


func _line_indent_prefix(line: String) -> String:
	var idx := 0
	while idx < line.length():
		var ch := line[idx]
		if ch != " " and ch != "\t":
			break
		idx += 1
	if idx <= 0:
		return "    "
	return line.substr(0, idx)
