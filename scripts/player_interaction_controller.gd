extends Node
class_name PlayerInteractionController

## Main controller for player interaction & controls
## Handles keyboard shortcuts, action menu, unit selection, and movement

signal build_mode_toggled(enabled: bool)
signal tile_info_requested(tile: Vector2i)
signal game_paused_toggled(paused: bool)

@export var hex_grid_path: NodePath
@export var tile_action_menu_path: NodePath
@export var build_menu_path: NodePath

var hex_grid: Node3D = null
var tile_action_menu: PopupPanel = null
var build_menu: CanvasLayer = null
var unit_controller: UnitController = null

var _build_mode_active: bool = false
var _game_paused: bool = false
var _awaiting_move_destination: bool = false


func _ready() -> void:
	# Get node references
	hex_grid = get_node_or_null(hex_grid_path)
	tile_action_menu = get_node_or_null(tile_action_menu_path)
	build_menu = get_node_or_null(build_menu_path)
	
	if hex_grid == null:
		push_warning("PlayerInteractionController: HexGrid not found")
		return
	
	# Create and add unit controller
	unit_controller = UnitController.new()
	unit_controller.name = "UnitController"
	add_child(unit_controller)
	
	# Connect signals
	_connect_signals()
	
	print("PlayerInteractionController initialized")


func _connect_signals() -> void:
	## Connect all necessary signals
	if hex_grid:
		hex_grid.tile_selected.connect(_on_tile_selected)
	
	if tile_action_menu:
		tile_action_menu.action_selected.connect(_on_action_menu_selected)
	
	if unit_controller:
		unit_controller.unit_selected.connect(_on_unit_selected)
		unit_controller.unit_deselected.connect(_on_unit_deselected)


func _input(event: InputEvent) -> void:
	# Handle keyboard shortcuts
	if event.is_action_pressed("toggle_build_mode"):
		_toggle_build_mode()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("show_tile_info"):
		_show_tile_info()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("toggle_pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("cancel_action"):
		_cancel_current_action()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("open_action_menu"):
		_open_action_menu_at_cursor()
		get_viewport().set_input_as_handled()


func _on_tile_selected(axial: Vector2i, biome_name: String, surface_pos: Vector3) -> void:
	## Handle tile selection from hex grid
	print("Tile selected: q=%d r=%d biome=%s" % [axial.x, axial.y, biome_name])
	
	# If awaiting move destination, command unit to move
	if _awaiting_move_destination and unit_controller and unit_controller.has_selected_unit():
		if unit_controller.command_move_to_tile(axial):
			print("Unit commanded to move to tile")
			_awaiting_move_destination = false
		else:
			print("Cannot move to that tile")
		return
	
	# Check if there's a unit at this tile
	if unit_controller and unit_controller.select_unit_at_tile(axial):
		# Unit selected
		return
	
	# No unit, deselect if any was selected
	if unit_controller and unit_controller.has_selected_unit():
		unit_controller.deselect_unit()


func _open_action_menu_at_cursor() -> void:
	## Open action menu at current tile under cursor
	if tile_action_menu == null or hex_grid == null:
		return
	
	var selected_tile := hex_grid.get_selected_axial()
	if selected_tile == Vector2i(-1, -1):
		return
	
	var biome := hex_grid.get_tile_biome_name(selected_tile)
	var has_unit := false
	if unit_controller:
		has_unit = unit_controller.get_selected_unit() != null
	
	var mouse_pos := get_viewport().get_mouse_position()
	tile_action_menu.show_for_tile(selected_tile, biome, has_unit, mouse_pos)


func _on_action_menu_selected(action_id: String) -> void:
	## Handle action selection from context menu
	print("Action selected: %s" % action_id)
	
	match action_id:
		"build":
			_toggle_build_mode()
		"tile_info":
			_show_tile_info()
		"unit_info":
			_show_unit_info()
		"move_unit":
			_start_unit_movement()


func _toggle_build_mode() -> void:
	## Toggle build mode on/off
	_build_mode_active = not _build_mode_active
	print("Build mode: %s" % ("ON" if _build_mode_active else "OFF"))
	
	# Show/hide build menu
	if build_menu:
		build_menu.visible = _build_mode_active
	
	emit_signal("build_mode_toggled", _build_mode_active)


func _show_tile_info() -> void:
	## Show information about selected tile
	if hex_grid == null:
		return
	
	var selected_tile := hex_grid.get_selected_axial()
	if selected_tile == Vector2i(-1, -1):
		print("No tile selected")
		return
	
	var biome := hex_grid.get_tile_biome_name(selected_tile)
	var surface_pos := hex_grid.get_tile_surface_position(selected_tile)
	
	print("=== Tile Info ===")
	print("Position: q=%d r=%d" % [selected_tile.x, selected_tile.y])
	print("Biome: %s" % biome)
	print("World Position: %v" % surface_pos)
	print("================")
	
	emit_signal("tile_info_requested", selected_tile)


func _show_unit_info() -> void:
	## Show information about selected unit
	if unit_controller == null or not unit_controller.has_selected_unit():
		print("No unit selected")
		return
	
	var unit := unit_controller.get_selected_unit()
	print("=== Unit Info ===")
	print("Unit: %s" % unit.name)
	print("Position: %v" % unit.global_position)
	
	# Get character brain info if available
	var brain := unit.get_node_or_null("CharacterBrain")
	if brain:
		print("Has CharacterBrain")
	
	print("================")


func _start_unit_movement() -> void:
	## Start waiting for movement destination
	if unit_controller == null or not unit_controller.has_selected_unit():
		print("No unit selected to move")
		return
	
	_awaiting_move_destination = true
	print("Click a destination tile to move unit")


func _toggle_pause() -> void:
	## Toggle game pause
	_game_paused = not _game_paused
	get_tree().paused = _game_paused
	print("Game paused: %s" % _game_paused)
	emit_signal("game_paused_toggled", _game_paused)


func _cancel_current_action() -> void:
	## Cancel current action (close menus, deselect, etc.)
	print("Cancel action")
	
	# Hide action menu
	if tile_action_menu and tile_action_menu.visible:
		tile_action_menu.hide()
	
	# Deselect unit
	if unit_controller and unit_controller.has_selected_unit():
		unit_controller.deselect_unit()
	
	# Exit build mode
	if _build_mode_active:
		_toggle_build_mode()
	
	# Cancel movement waiting
	if _awaiting_move_destination:
		_awaiting_move_destination = false
		print("Movement cancelled")


func _on_unit_selected(unit: Node3D, tile: Vector2i) -> void:
	## Handle unit selection
	print("Unit selected signal received")


func _on_unit_deselected() -> void:
	## Handle unit deselection
	print("Unit deselected signal received")
	_awaiting_move_destination = false
