extends Control
class_name Minimap

## Minimap showing world overview in bottom-right corner
## Displays terrain, territory, buildings, and units

signal camera_jump_requested(world_position: Vector3)

@export var hex_grid_path: NodePath
@export var faction_system_path: NodePath
@export var territory_system_path: NodePath
@export var minimap_size: Vector2 = Vector2(200, 200)
@export var update_interval: float = 0.5

@onready var texture_rect: TextureRect = %MinimapTexture

var _hex_grid: Node
var _faction_system: Node
var _territory_system: Node
var _update_timer: float = 0.0
var _minimap_image: Image
var _minimap_texture: ImageTexture


func _ready() -> void:
	_resolve_systems()
	_setup_minimap()
	_update_minimap()


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_minimap()


func _resolve_systems() -> void:
	if not hex_grid_path.is_empty():
		_hex_grid = get_node_or_null(hex_grid_path)
	if _hex_grid == null:
		_hex_grid = get_tree().get_first_node_in_group("hex_grid")
	
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path)
	if _faction_system == null:
		_faction_system = get_tree().get_first_node_in_group("faction_system")
	
	if not territory_system_path.is_empty():
		_territory_system = get_node_or_null(territory_system_path)
	if _territory_system == null:
		_territory_system = get_tree().get_first_node_in_group("territory_system")


func _setup_minimap() -> void:
	_minimap_image = Image.create(int(minimap_size.x), int(minimap_size.y), false, Image.FORMAT_RGBA8)
	_minimap_texture = ImageTexture.create_from_image(_minimap_image)
	
	if texture_rect != null:
		texture_rect.texture = _minimap_texture
		texture_rect.custom_minimum_size = minimap_size
		texture_rect.gui_input.connect(_on_minimap_clicked)


func _update_minimap() -> void:
	if _minimap_image == null or _hex_grid == null:
		return
	
	# Get map dimensions
	var map_width := 20
	var map_height := 20
	
	if _hex_grid.has_method("get_map_width"):
		map_width = _hex_grid.call("get_map_width")
	if _hex_grid.has_method("get_map_height"):
		map_height = _hex_grid.call("get_map_height")
	
	# Clear image
	_minimap_image.fill(Color(0.1, 0.1, 0.15, 1.0))
	
	# Draw terrain and territory
	for y in range(map_height):
		for x in range(map_width):
			var tile_pos := Vector2i(x, y)
			var color := _get_tile_color(tile_pos, map_width, map_height)
			_draw_tile_on_minimap(tile_pos, color, map_width, map_height)
	
	# Update texture
	_minimap_texture.update(_minimap_image)


func _get_tile_color(tile_pos: Vector2i, map_width: int, map_height: int) -> Color:
	# Get territory owner
	var owner := StringName("")
	if _territory_system != null and _territory_system.has_method("get_tile_owner"):
		owner = _territory_system.call("get_tile_owner", tile_pos)
	
	# If tile has owner, use faction color
	if owner != StringName(""):
		return _get_faction_color(owner)
	
	# Otherwise use terrain color
	return _get_terrain_color(tile_pos)


func _get_terrain_color(tile_pos: Vector2i) -> Color:
	# Get terrain type from hex grid if available
	if _hex_grid != null and _hex_grid.has_method("get_tile_type"):
		var tile_type = _hex_grid.call("get_tile_type", tile_pos)
		match tile_type:
			"water":
				return Color(0.2, 0.4, 0.8, 1.0)
			"mountain":
				return Color(0.5, 0.5, 0.5, 1.0)
			"forest":
				return Color(0.2, 0.6, 0.2, 1.0)
			_:
				return Color(0.4, 0.6, 0.3, 1.0)  # grass
	
	# Default grass color
	return Color(0.4, 0.6, 0.3, 1.0)


func _get_faction_color(faction_id: StringName) -> Color:
	# Get faction color from faction system
	if _faction_system != null and _faction_system.has_method("get_faction_color"):
		return _faction_system.call("get_faction_color", faction_id)
	
	# Default colors by faction name
	match str(faction_id):
		"kingdom":
			return Color(0.3, 0.3, 1.0, 0.7)
		"barbarians":
			return Color(1.0, 0.3, 0.3, 0.7)
		"merchants":
			return Color(1.0, 0.8, 0.2, 0.7)
		_:
			return Color(0.7, 0.7, 0.7, 0.7)


func _draw_tile_on_minimap(tile_pos: Vector2i, color: Color, map_width: int, map_height: int) -> void:
	# Calculate pixel position on minimap
	var pixel_x := int(float(tile_pos.x) / float(map_width) * minimap_size.x)
	var pixel_y := int(float(tile_pos.y) / float(map_height) * minimap_size.y)
	
	# Draw a small rectangle for the tile
	var tile_size_x := max(1, int(minimap_size.x / float(map_width)))
	var tile_size_y := max(1, int(minimap_size.y / float(map_height)))
	
	for dy in range(tile_size_y):
		for dx in range(tile_size_x):
			var px := pixel_x + dx
			var py := pixel_y + dy
			if px >= 0 and px < minimap_size.x and py >= 0 and py < minimap_size.y:
				_minimap_image.set_pixel(px, py, color)


func _on_minimap_clicked(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# Convert minimap click to world position
	var local_pos := texture_rect.get_local_mouse_position()
	var map_width := 20
	var map_height := 20
	
	if _hex_grid != null:
		if _hex_grid.has_method("get_map_width"):
			map_width = _hex_grid.call("get_map_width")
		if _hex_grid.has_method("get_map_height"):
			map_height = _hex_grid.call("get_map_height")
	
	# Calculate tile position
	var tile_x := int(local_pos.x / minimap_size.x * float(map_width))
	var tile_y := int(local_pos.y / minimap_size.y * float(map_height))
	
	# Get world position for this tile
	var world_pos := Vector3(float(tile_x), 0.0, float(tile_y))
	if _hex_grid != null and _hex_grid.has_method("get_tile_world_position"):
		world_pos = _hex_grid.call("get_tile_world_position", Vector2i(tile_x, tile_y))
	
	emit_signal("camera_jump_requested", world_pos)
