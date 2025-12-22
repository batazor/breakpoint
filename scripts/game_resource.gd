extends Resource
class_name GameResource

@export var id: StringName
@export var title: String
@export var icon: Texture2D
@export var scene: PackedScene
@export var buildable_tiles: Array = []
@export var category: String = "resource"


func can_build_on(biome_name: String) -> bool:
	if buildable_tiles.is_empty():
		return true
	for tile in buildable_tiles:
		if String(tile) == biome_name:
			return true
	return false
