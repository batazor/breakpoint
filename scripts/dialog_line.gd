extends Resource
class_name DialogLine

## Represents a single line of dialog in a conversation

@export var speaker_name: String = ""
@export_multiline var text: String = ""
@export var responses: Array[DialogResponse] = []
@export var next_dialog_id: String = ""
@export var auto_advance: bool = false
@export var delay_seconds: float = 0.0
