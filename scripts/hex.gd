extends Object
class_name HexUtils

# Utility helpers for flat-top axial hex coordinates.

const SQRT3 := 1.7320508075688772

static func axial_to_world(q: int, r: int, radius: float) -> Vector3:
	# Convert axial (q, r) to world space for a flat-top hex.
	var x := radius * (1.5 * q)
	var z := radius * (SQRT3 * (r + 0.5 * q))
	return Vector3(x, 0.0, z)


static func hex_corners(radius: float) -> Array[Vector3]:
	# Returns 6 corners for a flat-top hex centered at the origin.
	var corners: Array[Vector3] = []
	for i in range(6):
		var angle := deg_to_rad(60.0 * i + 30.0)  # 30 deg offset for flat-top
		corners.append(Vector3(radius * cos(angle), 0.0, radius * sin(angle)))
	return corners


static func bounds_for_rect(width: int, height: int, radius: float) -> Rect2:
	# Computes an axis-aligned 2D rect (x,z) that encloses the axial grid.
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF

	for r in range(height):
		for q in range(width):
			var pos := axial_to_world(q, r, radius)
			min_x = min(min_x, pos.x - radius)
			max_x = max(max_x, pos.x + radius)
			# z extent uses half the vertical span of a hex.
			var half_z := radius * SQRT3 * 0.5
			min_z = min(min_z, pos.z - half_z)
			max_z = max(max_z, pos.z + half_z)

	return Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))


static func center_of_rect(width: int, height: int, radius: float) -> Vector3:
	var rect := bounds_for_rect(width, height, radius)
	return Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)

