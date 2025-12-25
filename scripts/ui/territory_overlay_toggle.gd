extends HBoxContainer

## UI control for toggling territory influence overlay visualization

@export var territory_overlay_path: NodePath

var _territory_overlay: Node
var _toggle_button: Button


func _ready() -> void:
	_setup_ui()
	_resolve_nodes()
	_connect_signals()


func _setup_ui() -> void:
	# Create toggle button
	_toggle_button = Button.new()
	_toggle_button.text = "Show Territory"
	_toggle_button.toggle_mode = true
	_toggle_button.tooltip_text = "Toggle faction territory influence visualization (T)"
	
	add_child(_toggle_button)


func _resolve_nodes() -> void:
	if not territory_overlay_path.is_empty():
		_territory_overlay = get_node_or_null(territory_overlay_path)
	else:
		_territory_overlay = get_tree().get_first_node_in_group("territory_overlay")


func _connect_signals() -> void:
	if _toggle_button:
		_toggle_button.toggled.connect(_on_toggle_button_toggled)
	
	if _territory_overlay and _territory_overlay.has_signal("visibility_toggled"):
		_territory_overlay.visibility_toggled.connect(_on_overlay_visibility_changed)


func _input(event: InputEvent) -> void:
	# Handle hotkey (T) for toggling
	# Note: Using _input for global hotkey. If conflicts arise, consider _unhandled_input
	if event.is_action_pressed("toggle_territory_overlay"):
		if _toggle_button:
			_toggle_button.button_pressed = not _toggle_button.button_pressed


func _on_toggle_button_toggled(pressed: bool) -> void:
	if _territory_overlay and _territory_overlay.has_method("set_overlay_visible"):
		_territory_overlay.set_overlay_visible(pressed)


func _on_overlay_visibility_changed(is_visible: bool) -> void:
	if _toggle_button and _toggle_button.button_pressed != is_visible:
		_toggle_button.button_pressed = is_visible
		_toggle_button.text = "Hide Territory" if is_visible else "Show Territory"
