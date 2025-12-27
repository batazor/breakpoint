extends Resource
class_name DialogTree

## Represents a complete dialog conversation tree

@export var id: String = ""
@export var title: String = ""
@export var dialogs: Dictionary = {}  # dialog_id -> DialogLine
@export var start_dialog_id: String = "start"


func get_dialog(dialog_id: String) -> DialogLine:
	## Get a dialog line by ID
	if dialogs.has(dialog_id):
		return dialogs[dialog_id]
	return null


func add_dialog(dialog_id: String, dialog: DialogLine) -> void:
	## Add a dialog line to the tree
	dialogs[dialog_id] = dialog
