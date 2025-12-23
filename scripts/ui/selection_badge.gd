extends CanvasLayer
class_name SelectionBadge

@onready var info_label: Label = %InfoLabel


func update_tile(axial: Vector2i, biome_name: String, surface_pos: Vector3) -> void:
	if info_label == null:
		return
	var biome := biome_name.capitalize() if not biome_name.is_empty() else "Unknown"
	var world_x := surface_pos.x if surface_pos != null else 0.0
	var world_z := surface_pos.z if surface_pos != null else 0.0
	info_label.text = "Tile q=%d r=%d  |  Biome: %s  |  Pos: %.1f, %.1f" % [
		axial.x,
		axial.y,
		biome,
		world_x,
		world_z,
	]
	info_label.visible = true
	visible = true


func clear() -> void:
	if info_label == null:
		return
	info_label.text = ""
	info_label.visible = false
