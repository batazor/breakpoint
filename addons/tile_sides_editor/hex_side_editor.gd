@tool
extends Control
class_name TileSidesHexEditor

signal side_clicked(index: int)

const EDGE_CORNER_PAIRS: Array = [
	[5, 0], # dir 0
	[4, 5], # dir 1
	[3, 4], # dir 2
	[2, 3], # dir 3
	[1, 2], # dir 4
	[0, 1], # dir 5
]

const TYPE_COLORS := {
	"water": Color(0.12, 0.35, 0.85),
	"river": Color(0.20, 0.75, 0.95),
	"sand": Color(0.86, 0.78, 0.40),
	"plains": Color(0.32, 0.70, 0.32),
	"mountain": Color(0.55, 0.55, 0.55),
	"land": Color(0.35, 0.35, 0.35),
}

var side_values: Array = []
var selected_side := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	side_values.resize(6)
	queue_redraw()


func set_side_values(values: Array) -> void:
	side_values = values.duplicate()
	while side_values.size() < 6:
		side_values.append("land")
	for i in range(side_values.size()):
		var value: Variant = side_values[i]
		var value_str: String = value if value is String else String(value)
		if value_str.is_empty():
			value_str = "land"
		side_values[i] = value_str
	queue_redraw()


func set_side_value(index: int, value: String) -> void:
	if index < 0 or index >= 6:
		return
	if side_values.size() < 6:
		side_values.resize(6)
	side_values[index] = value
	queue_redraw()


func set_selected_side(index: int) -> void:
	selected_side = index
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.35
	var corners: Array[Vector2] = _hex_corners(center, radius)
	draw_colored_polygon(corners, Color(0.12, 0.12, 0.12, 0.08))
	for i in range(6):
		var pair: Array = EDGE_CORNER_PAIRS[i]
		var a: Vector2 = corners[pair[0]]
		var b: Vector2 = corners[pair[1]]
		var value: Variant = "land"
		if i < side_values.size():
			value = side_values[i]
		if not (value is String):
			value = String(value)
		if value.is_empty():
			value = "land"
		var color := TYPE_COLORS.get(value, Color(0.8, 0.8, 0.8))
		var width := 4.0
		if i == selected_side:
			width = 7.0
			color = color.lightened(0.2)
		draw_line(a, b, color, width, true)
	draw_polyline(corners + [corners[0]], Color(0.15, 0.15, 0.15), 2.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var side := _pick_side(event.position)
		if side >= 0:
			selected_side = side
			emit_signal("side_clicked", side)
			queue_redraw()


func _pick_side(pos: Vector2) -> int:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.35
	var corners: Array[Vector2] = _hex_corners(center, radius)
	var best := -1
	var best_dist: float = 9999.0
	for i in range(6):
		var pair: Array = EDGE_CORNER_PAIRS[i]
		var a: Vector2 = corners[pair[0]]
		var b: Vector2 = corners[pair[1]]
		var d := _dist_point_segment(pos, a, b)
		if d < best_dist:
			best_dist = d
			best = i
	if best_dist > 20.0:
		return -1
	return best


func _hex_corners(center: Vector2, radius: float) -> Array[Vector2]:
	var corners: Array[Vector2] = []
	for i in range(6):
		var angle := deg_to_rad(60.0 * i + 30.0)
		corners.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return corners


func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	var denom := ab.length_squared()
	if denom > 0.0:
		t = clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	var proj := a + ab * t
	return proj.distance_to(p)
