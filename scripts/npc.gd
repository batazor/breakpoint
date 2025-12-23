extends Resource
class_name NPC

@export var id: StringName
@export var faction_id: StringName = ""
@export_range(0.0, 1.0) var loyalty: float = 1.0
@export var title: String = ""
@export var description: String = ""
@export var health: int = 100
@export var move_speed: float = 4.0
@export var icon: Texture2D
@export var scene: PackedScene
