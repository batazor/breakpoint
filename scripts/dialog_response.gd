extends Resource
class_name DialogResponse

## Represents a player response option in dialog

@export var text: String = ""
@export var next_dialog_id: String = ""
@export var effect: String = ""  # Optional effect when chosen (e.g., "add_gold:10")
@export var relationship_change: int = 0  # Change to NPC relationship
