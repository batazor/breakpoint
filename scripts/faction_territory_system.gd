extends Node
class_name FactionTerritorySystem

## Manages faction territory and influence over hex tiles.
## Calculates influence using distance decay formula from faction buildings.
## The faction with highest influence on a tile claims that territory.

signal territory_changed(tile_position: Vector2i, new_owner: StringName, influence: float)

@export var faction_system_path: NodePath
@export var hex_grid_path: NodePath
@export var base_influence: float = 100.0
@export var recalculation_interval: float = 5.0  # Recalculate every 5 seconds

var _faction_system: FactionSystem
var _hex_grid: Node
var _tile_ownership: Dictionary = {}  # Vector2i -> StringName (faction_id)
var _tile_influence: Dictionary = {}  # Vector2i -> Dictionary{faction_id: influence_value}
var _accum: float = 0.0


func _ready() -> void:
	_resolve_nodes()
	_connect_signals()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= recalculation_interval:
		_accum = 0.0
		recalculate_all_territory()


func get_tile_owner(tile_position: Vector2i) -> StringName:
	return _tile_ownership.get(tile_position, StringName(""))


func get_tile_influence(tile_position: Vector2i, faction_id: StringName) -> float:
	var influences: Dictionary = _tile_influence.get(tile_position, {})
	return influences.get(faction_id, 0.0)


func get_faction_territory_count(faction_id: StringName) -> int:
	var count := 0
	for owner in _tile_ownership.values():
		if owner == faction_id:
			count += 1
	return count


func recalculate_all_territory() -> void:
	if _faction_system == null:
		return
	
	# Clear previous calculations
	_tile_influence.clear()
	var previous_ownership := _tile_ownership.duplicate()
	_tile_ownership.clear()
	
	# Calculate influence from all faction buildings
	for building_id in _faction_system.building_owner.keys():
		var owner: StringName = _faction_system.building_owner.get(building_id, StringName(""))
		if owner == StringName(""):
			continue
		
		var building_pos: Vector2i = _faction_system.axial_of(building_id)
		if building_pos == Vector2i(-1, -1):
			continue
		
		_calculate_influence_from_building(building_pos, owner)
	
	# Determine ownership based on highest influence
	for tile_pos in _tile_influence.keys():
		var influences: Dictionary = _tile_influence[tile_pos]
		var max_influence := 0.0
		var dominant_faction := StringName("")
		
		for faction_id in influences.keys():
			var influence: float = influences[faction_id]
			if influence > max_influence:
				max_influence = influence
				dominant_faction = faction_id
		
		if max_influence > 0.0 and dominant_faction != StringName(""):
			_tile_ownership[tile_pos] = dominant_faction
			
			# Emit signal if ownership changed
			var previous_owner: StringName = previous_ownership.get(tile_pos, StringName(""))
			if previous_owner != dominant_faction:
				emit_signal("territory_changed", tile_pos, dominant_faction, max_influence)


func _calculate_influence_from_building(building_pos: Vector2i, faction_id: StringName) -> void:
	## Calculate influence using distance decay: influence = base_value / (distance + 1)
	## Influence radiates out from building position
	
	var max_radius := 10  # Maximum influence range
	
	for radius in range(max_radius + 1):
		var tiles_at_distance := _get_hex_ring(building_pos, radius)
		
		for tile_pos in tiles_at_distance:
			var distance := radius
			var influence := base_influence / (float(distance) + 1.0)
			
			if influence < 1.0:
				break  # Influence too weak, stop expanding
			
			# Add this influence to the tile
			if not _tile_influence.has(tile_pos):
				_tile_influence[tile_pos] = {}
			
			var tile_influences: Dictionary = _tile_influence[tile_pos]
			var current_influence: float = tile_influences.get(faction_id, 0.0)
			tile_influences[faction_id] = current_influence + influence


func _get_hex_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	## Returns all hex tiles at exactly 'radius' distance from center
	var result: Array[Vector2i] = []
	
	if radius == 0:
		result.append(center)
		return result
	
	# Hex direction vectors (cube coordinates)
	var directions := [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	
	# Start at one corner of the ring
	var current := center + directions[4] * radius
	
	# Walk around the ring
	for direction_idx in range(6):
		for _step in range(radius):
			result.append(current)
			current = current + directions[direction_idx]
	
	return result


func _on_building_registered(_building_id: StringName) -> void:
	# Trigger recalculation when buildings are added/removed
	recalculate_all_territory()


func _on_building_deregistered(_building_id: StringName) -> void:
	recalculate_all_territory()


func _resolve_nodes() -> void:
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path) as FactionSystem
	else:
		_faction_system = get_tree().get_first_node_in_group("faction_system") as FactionSystem
	
	if not hex_grid_path.is_empty():
		_hex_grid = get_node_or_null(hex_grid_path)
	else:
		_hex_grid = get_tree().get_first_node_in_group("hex_grid")


func _connect_signals() -> void:
	# Note: FactionSystem doesn't have building_registered signal, 
	# so we'll rely on periodic recalculation for now
	pass
