extends Resource
class_name Faction

@export var id: StringName
@export var ideology: Dictionary = {}
@export var relations: Dictionary = {} # FactionId -> float
@export var assets_buildings: Array[StringName] = []
@export var assets_cells: Array[Vector2i] = []

