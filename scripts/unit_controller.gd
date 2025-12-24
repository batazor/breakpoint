extends Node
class_name UnitController

## Handles unit selection and movement commands
## Manages unit state and pathfinding

signal unit_selected(unit: Node3D, axial: Vector2i)
signal unit_deselected()
signal unit_move_commanded(unit: Node3D, from: Vector2i, to: Vector2i)

var selected_unit: Node3D = null
var selected_unit_tile: Vector2i = Vector2i(-1, -1)
var hex_grid: Node3D = null


func _ready() -> void:
	# Find hex grid reference
	hex_grid = get_node_or_null("/root/Main/HexGrid")
	if hex_grid == null:
		push_warning("UnitController: HexGrid not found")


func select_unit_at_tile(tile: Vector2i) -> bool:
	"""Try to select a unit at the given tile position"""
	if hex_grid == null:
		return false
	
	# Check if there's a unit/character at this tile
	var unit := _find_unit_at_tile(tile)
	if unit == null:
		return false
	
	# Select the unit
	_set_selected_unit(unit, tile)
	return true


func deselect_unit() -> void:
	"""Deselect the currently selected unit"""
	if selected_unit != null:
		_clear_selection_visual(selected_unit)
		selected_unit = null
		selected_unit_tile = Vector2i(-1, -1)
		emit_signal("unit_deselected")


func command_move_to_tile(target_tile: Vector2i) -> bool:
	"""Command selected unit to move to target tile"""
	if selected_unit == null:
		return false
	
	if target_tile == selected_unit_tile:
		return false
	
	# Check if target tile is valid and not occupied
	if not _is_tile_valid_for_movement(target_tile):
		return false
	
	# Emit signal for movement
	emit_signal("unit_move_commanded", selected_unit, selected_unit_tile, target_tile)
	
	# Execute movement
	_execute_movement(selected_unit, selected_unit_tile, target_tile)
	
	return true


func get_selected_unit() -> Node3D:
	"""Get the currently selected unit"""
	return selected_unit


func has_selected_unit() -> bool:
	"""Check if a unit is currently selected"""
	return selected_unit != null


func _set_selected_unit(unit: Node3D, tile: Vector2i) -> void:
	"""Internal: Set the selected unit"""
	# Deselect previous unit
	if selected_unit != null:
		_clear_selection_visual(selected_unit)
	
	selected_unit = unit
	selected_unit_tile = tile
	
	# Add selection visual
	_add_selection_visual(unit)
	
	emit_signal("unit_selected", unit, tile)
	print("Unit selected at tile q=%d r=%d" % [tile.x, tile.y])


func _find_unit_at_tile(tile: Vector2i) -> Node3D:
	"""Internal: Find a unit/character at the given tile"""
	# Check if hex_grid tracks character occupancy
	if hex_grid and hex_grid.has_method("is_character_tile_occupied"):
		if hex_grid.is_character_tile_occupied(tile):
			# Try to find the actual character node
			return _find_character_node_at_tile(tile)
	
	return null


func _find_character_node_at_tile(tile: Vector2i) -> Node3D:
	"""Internal: Find the character Node3D at given tile"""
	# Look for characters in the scene tree
	var characters_node := get_node_or_null("/root/Main/Characters")
	if characters_node == null:
		return null
	
	# Find character at this position
	for child in characters_node.get_children():
		if child is Node3D:
			var char_brain := child.get_node_or_null("CharacterBrain")
			if char_brain and char_brain is CharacterBrain:
				# Check if character is at this tile
				var wander := char_brain.get("wander")
				if wander and wander.has_method("get_current_tile"):
					var char_tile: Vector2i = wander.get_current_tile()
					if char_tile == tile:
						return child
	
	return null


func _is_tile_valid_for_movement(tile: Vector2i) -> bool:
	"""Internal: Check if tile is valid for movement"""
	if hex_grid == null:
		return false
	
	# Check tile is within bounds
	var map_width := hex_grid.get("map_width")
	var map_height := hex_grid.get("map_height")
	if tile.x < 0 or tile.y < 0 or tile.x >= map_width or tile.y >= map_height:
		return false
	
	# Check if tile is water (not walkable)
	if hex_grid.has_method("get_tile_biome_name"):
		var biome: String = hex_grid.get_tile_biome_name(tile)
		if biome == "water":
			return false
	
	# Check if tile is already occupied by another character
	if hex_grid.has_method("is_character_tile_occupied"):
		if hex_grid.is_character_tile_occupied(tile):
			return false
	
	return true


func _execute_movement(unit: Node3D, from_tile: Vector2i, to_tile: Vector2i) -> void:
	"""Internal: Execute unit movement"""
	if unit == null or hex_grid == null:
		return
	
	# Get target position in world space
	var target_pos: Vector3 = hex_grid.get_tile_surface_position(to_tile)
	
	# Update hex grid occupancy
	if hex_grid.has_method("vacate_character_tile"):
		var unit_id := unit.get_instance_id()
		hex_grid.vacate_character_tile(from_tile, unit_id)
	
	if hex_grid.has_method("request_character_occupy"):
		var unit_id := unit.get_instance_id()
		hex_grid.request_character_occupy(to_tile, unit_id)
	
	# Move the unit (simple linear movement for now)
	# TODO: Implement pathfinding for complex paths
	var tween := create_tween()
	tween.tween_property(unit, "global_position", target_pos, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Update wander component if present
	var char_brain := unit.get_node_or_null("CharacterBrain")
	if char_brain and char_brain is CharacterBrain:
		var wander := char_brain.get("wander")
		if wander and wander.has_method("set_current_tile"):
			wander.set_current_tile(to_tile)
	
	# Update selected tile
	selected_unit_tile = to_tile
	
	print("Unit moving from q=%d r=%d to q=%d r=%d" % [from_tile.x, from_tile.y, to_tile.x, to_tile.y])


func _add_selection_visual(unit: Node3D) -> void:
	"""Internal: Add visual indicator for selected unit"""
	if unit == null:
		return
	
	# Create a simple selection indicator (ring or highlight)
	var indicator := MeshInstance3D.new()
	indicator.name = "SelectionIndicator"
	
	# Create a cylinder mesh for the ring
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.6
	mesh.bottom_radius = 0.6
	mesh.height = 0.05
	mesh.radial_segments = 16
	mesh.rings = 1
	
	indicator.mesh = mesh
	
	# Set material with emission for visibility
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.8)  # Yellow
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	indicator.mesh.surface_set_material(0, mat)
	
	# Position at unit's feet
	indicator.position = Vector3(0, 0.05, 0)
	
	unit.add_child(indicator)


func _clear_selection_visual(unit: Node3D) -> void:
	"""Internal: Remove selection visual from unit"""
	if unit == null:
		return
	
	var indicator := unit.get_node_or_null("SelectionIndicator")
	if indicator:
		indicator.queue_free()
