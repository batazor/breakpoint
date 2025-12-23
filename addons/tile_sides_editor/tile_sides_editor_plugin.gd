@tool
extends EditorPlugin

const TileSidesEditorDock = preload("res://addons/tile_sides_editor/tile_sides_editor_dock.gd")

var dock: Control


func _enter_tree() -> void:
	dock = TileSidesEditorDock.new()
	dock.name = "Tile Sides"
	dock.set_resource_previewer(get_editor_interface().get_resource_previewer())
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	if dock == null:
		return
	remove_control_from_docks(dock)
	dock.queue_free()
	dock = null
