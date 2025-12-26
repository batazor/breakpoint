extends Object
class_name UIUtils
## Utility functions for common UI operations
## Provides helper methods to reduce code duplication across UI scripts

## Gets a node from a NodePath or searches by group name as fallback
## Returns the node or null if not found
static func get_node_or_group(root: Node, node_path: NodePath, group_name: String) -> Node:
	var node: Node = null
	
	# Try NodePath first
	if not node_path.is_empty():
		node = root.get_node_or_null(node_path)
		if node != null:
			return node
	
	# Fallback to group search
	if not group_name.is_empty():
		node = root.get_tree().get_first_node_in_group(group_name)
	
	return node


## Safely connects a signal if not already connected
## Prevents duplicate connections and handles null checks
static func safe_connect(sig: Signal, callable: Callable) -> void:
	if sig == null or callable == null:
		return
	if not sig.is_connected(callable):
		sig.connect(callable)


## Safely disconnects a signal if connected
## Handles null checks and connection verification
static func safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig == null or callable == null:
		return
	if sig.is_connected(callable):
		sig.disconnect(callable)


## Extracts StringName IDs from a dictionary, filtering out empty strings
## Used for faction and resource ID extraction
static func extract_string_name_ids(dict: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	var keys: Array = dict.keys()
	
	for key_variant in keys:
		var key_name := key_variant as StringName
		if not String(key_name).is_empty():
			ids.append(key_name)
	
	ids.sort()
	return ids


## Clears and populates an OptionButton with items
## Each item's text is the StringName converted to String
static func populate_option_button(option_button: OptionButton, items: Array[StringName]) -> void:
	if option_button == null:
		return
	
	option_button.clear()
	for i in range(items.size()):
		option_button.add_item(str(items[i]), i)
	
	if option_button.item_count > 0:
		option_button.select(0)


## Gets the selected item text from an OptionButton as StringName
## Returns empty StringName if nothing is selected or invalid index
static func get_selected_text_as_string_name(option_button: OptionButton) -> StringName:
	if option_button == null or option_button.item_count == 0:
		return StringName("")
	
	var idx: int = option_button.get_selected()
	if idx < 0 or idx >= option_button.item_count:
		return StringName("")
	
	return StringName(option_button.get_item_text(idx))


## Deferred call helper - calls a method with arguments after a frame
## Useful for UI updates that need to wait for _ready() completion
## Supports unlimited number of arguments using callv
static func call_deferred_with_args(obj: Object, method: String, args: Array) -> void:
	if obj == null or method.is_empty():
		return
	
	# Use callv for flexible argument handling
	obj.call_deferred("callv", method, args)


## Updates children of a container based on a predicate function
## Predicate receives the child node and should return true to keep it visible
static func filter_children(container: Node, predicate: Callable) -> void:
	if container == null:
		return
	
	for child in container.get_children():
		var should_show: bool = predicate.call(child)
		if child is Control:
			child.visible = should_show


## Stores scroll position from a ScrollContainer into a dictionary
## Key is used to identify which scroll container's position to store
static func store_scroll_position(scroll_container: ScrollContainer, storage: Dictionary, key: String) -> void:
	if scroll_container == null or key.is_empty():
		return
	storage[key] = scroll_container.scroll_vertical


## Restores scroll position to a ScrollContainer from a dictionary
## Key is used to identify which scroll container's position to restore
static func restore_scroll_position(scroll_container: ScrollContainer, storage: Dictionary, key: String) -> void:
	if scroll_container == null or key.is_empty():
		return
	scroll_container.scroll_vertical = int(storage.get(key, 0))


## Clears all children from a container and queues them for deletion
static func clear_container_children(container: Node) -> void:
	if container == null:
		return
	
	for child in container.get_children():
		child.queue_free()


## Creates a simple label with text and adds it to a parent
## Returns the created label
static func create_label(parent: Node, text: String, custom_theme: Theme = null) -> Label:
	if parent == null:
		return null
	
	var label := Label.new()
	label.text = text
	if custom_theme != null:
		label.theme = custom_theme
	parent.add_child(label)
	return label


## Formats a number with thousand separators for better readability
## Examples: 1000 -> "1,000", 1234567 -> "1,234,567"
static func format_number(value: int) -> String:
	var str_value := str(abs(value))
	var formatted := ""
	var count := 0
	
	for i in range(str_value.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted = "," + formatted
		formatted = str_value[i] + formatted
		count += 1
	
	if value < 0:
		formatted = "-" + formatted
	
	return formatted


## Formats a resource delta for display with +/- prefix and color
## Returns a dictionary with "text" and "color" keys
static func format_resource_delta(delta: float, per_unit: String = "/s") -> Dictionary:
	var color := Color.WHITE
	var prefix := ""
	
	if delta > 0:
		prefix = "+"
		color = Color.GREEN
	elif delta < 0:
		color = Color.RED
	
	var text := "%s%.1f%s" % [prefix, delta, per_unit]
	
	return {"text": text, "color": color}
