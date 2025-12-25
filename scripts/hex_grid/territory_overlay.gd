extends Node
class_name TerritoryOverlay

## Visual overlay system for displaying faction territory influence on hex tiles.
## Similar to Civilization games, shows colored areas for each faction's influence.
## Optimized with MultiMesh batching and LOD for performance.

signal visibility_toggled(is_visible: bool)

@export var territory_system_path: NodePath
@export var faction_system_path: NodePath
@export var hex_grid_path: NodePath

## Visualization settings
@export var overlay_alpha: float = 0.3
@export var overlay_height_offset: float = 0.1
@export var enable_lod: bool = true
@export var lod_distance_near: float = 20.0
@export var lod_distance_far: float = 50.0
@export var update_interval: float = 0.5  # Update overlay every 0.5 seconds

## Faction colors (default palette)
var faction_colors: Dictionary = {
	# These will be populated from faction data
}

var _territory_system: FactionTerritorySystem
var _faction_system: FactionSystem
var _hex_grid: Node
var _overlay_visible: bool = false
var _multimesh_instances: Dictionary = {}  # faction_id -> MultiMeshInstance3D
var _update_timer: float = 0.0
var _cached_territories: Dictionary = {}  # Vector2i -> StringName
var _overlay_mesh: Mesh


func _ready() -> void:
	_resolve_nodes()
	_setup_overlay_mesh()
	_initialize_faction_colors()
	_connect_signals()


func _process(delta: float) -> void:
	if not _overlay_visible:
		return
	
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_overlay()


## Toggle overlay visibility
func toggle_visibility() -> void:
	set_overlay_visible(not _overlay_visible)


## Set overlay visibility
func set_overlay_visible(visible: bool) -> void:
	if _overlay_visible == visible:
		return
	
	_overlay_visible = visible
	
	if _overlay_visible:
		_update_overlay()
	else:
		_clear_overlay()
	
	emit_signal("visibility_toggled", _overlay_visible)


## Check if overlay is currently visible
func is_overlay_visible() -> bool:
	return _overlay_visible


## Force immediate overlay update
func force_update() -> void:
	if _overlay_visible:
		_update_overlay()


## Set custom color for a faction
func set_faction_color(faction_id: StringName, color: Color) -> void:
	faction_colors[faction_id] = color
	if _overlay_visible:
		_update_overlay()


func _resolve_nodes() -> void:
	if not territory_system_path.is_empty():
		_territory_system = get_node_or_null(territory_system_path) as FactionTerritorySystem
	else:
		_territory_system = get_tree().get_first_node_in_group("territory_system") as FactionTerritorySystem
	
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path) as FactionSystem
	else:
		_faction_system = get_tree().get_first_node_in_group("faction_system") as FactionSystem
	
	if not hex_grid_path.is_empty():
		_hex_grid = get_node_or_null(hex_grid_path)
	else:
		_hex_grid = get_tree().get_first_node_in_group("hex_grid")


func _setup_overlay_mesh() -> void:
	## Create a hexagonal overlay mesh
	var hex_mesh := _create_hex_mesh()
	_overlay_mesh = hex_mesh


func _create_hex_mesh() -> ArrayMesh:
	## Create a flat hexagonal mesh for territory overlay
	var hex_radius := 1.0
	if _hex_grid and _hex_grid.has("hex_radius"):
		hex_radius = _hex_grid.hex_radius
	
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	
	# Center vertex
	vertices.append(Vector3(0, 0, 0))
	uvs.append(Vector2(0.5, 0.5))
	
	# Hexagon vertices (6 points)
	for i in range(7):
		var angle := (PI / 3.0) * float(i)
		var x := hex_radius * cos(angle)
		var z := hex_radius * sin(angle)
		vertices.append(Vector3(x, 0, z))
		uvs.append(Vector2(0.5 + 0.5 * cos(angle), 0.5 + 0.5 * sin(angle)))
	
	# Create triangles (6 triangles from center)
	for i in range(6):
		indices.append(0)
		indices.append(i + 1)
		indices.append(i + 2)
	
	# Create mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh


func _initialize_faction_colors() -> void:
	## Initialize default colors for factions
	if _faction_system == null:
		return
	
	# Default color palette (similar to Civilization)
	var default_colors := [
		Color(0.2, 0.4, 0.8, overlay_alpha),  # Blue
		Color(0.8, 0.2, 0.2, overlay_alpha),  # Red
		Color(0.2, 0.8, 0.2, overlay_alpha),  # Green
		Color(0.8, 0.8, 0.2, overlay_alpha),  # Yellow
		Color(0.6, 0.2, 0.8, overlay_alpha),  # Purple
		Color(0.8, 0.5, 0.2, overlay_alpha),  # Orange
	]
	
	var color_idx := 0
	for faction_id in _faction_system.factions.keys():
		if not faction_colors.has(faction_id):
			faction_colors[faction_id] = default_colors[color_idx % default_colors.size()]
			color_idx += 1


func _connect_signals() -> void:
	if _territory_system:
		if not _territory_system.territory_changed.is_connected(_on_territory_changed):
			_territory_system.territory_changed.connect(_on_territory_changed)


func _update_overlay() -> void:
	if _territory_system == null or _hex_grid == null:
		return
	
	# Clear old multimesh instances
	_clear_overlay()
	
	# Group tiles by faction for efficient batching
	var faction_tiles: Dictionary = {}  # faction_id -> Array[Vector2i]
	
	# Get map dimensions
	var map_width := 30  # Default
	var map_height := 30  # Default
	if _hex_grid.has("map_width"):
		map_width = _hex_grid.map_width
	if _hex_grid.has("map_height"):
		map_height = _hex_grid.map_height
	
	# Collect all territory tiles
	for q in range(map_width):
		for r in range(map_height):
			var tile_pos := Vector2i(q, r)
			var owner := _territory_system.get_tile_owner(tile_pos)
			
			if owner != StringName(""):
				if not faction_tiles.has(owner):
					faction_tiles[owner] = []
				faction_tiles[owner].append(tile_pos)
				_cached_territories[tile_pos] = owner
	
	# Create MultiMesh for each faction
	for faction_id in faction_tiles.keys():
		var tiles: Array = faction_tiles[faction_id]
		if tiles.is_empty():
			continue
		
		_create_faction_multimesh(faction_id, tiles)


func _create_faction_multimesh(faction_id: StringName, tiles: Array) -> void:
	## Create a MultiMeshInstance3D for a faction's territory tiles
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = tiles.size()
	multimesh.mesh = _overlay_mesh
	
	# Get faction color
	var faction_color := faction_colors.get(faction_id, Color(1, 1, 1, overlay_alpha))
	
	# Create material
	var material := StandardMaterial3D.new()
	material.albedo_color = faction_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	
	# Set instance transforms
	for i in range(tiles.size()):
		var tile_pos: Vector2i = tiles[i]
		var world_pos := _get_tile_world_position(tile_pos)
		
		if world_pos != Vector3.ZERO:
			var transform := Transform3D.IDENTITY
			transform.origin = world_pos + Vector3(0, overlay_height_offset, 0)
			multimesh.set_instance_transform(i, transform)
	
	# Create MultiMeshInstance3D node
	var instance := MultiMeshInstance3D.new()
	instance.name = "TerritoryOverlay_" + str(faction_id)
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(instance)
	_multimesh_instances[faction_id] = instance


func _get_tile_world_position(tile_pos: Vector2i) -> Vector3:
	## Get the world position of a hex tile
	if _hex_grid == null:
		return Vector3.ZERO
	
	# Try to get position from hex grid
	if _hex_grid.has_method("axial_to_world"):
		return _hex_grid.axial_to_world(tile_pos)
	
	# Fallback: calculate position using hex math
	var hex_radius := 1.0
	if _hex_grid.has("hex_radius"):
		hex_radius = _hex_grid.hex_radius
	
	var q := float(tile_pos.x)
	var r := float(tile_pos.y)
	var x := hex_radius * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
	var z := hex_radius * (3.0 / 2.0 * r)
	
	return Vector3(x, 0, z)


func _clear_overlay() -> void:
	## Remove all overlay multimesh instances
	for instance in _multimesh_instances.values():
		if instance and is_instance_valid(instance):
			instance.queue_free()
	
	_multimesh_instances.clear()


func _on_territory_changed(_tile_position: Vector2i, _new_owner: StringName, _influence: float) -> void:
	## Territory changed - update overlay if visible
	if _overlay_visible:
		# Schedule update on next process frame
		_update_timer = update_interval
