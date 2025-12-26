extends Node
class_name DialogManager

## Manages dialog state and flow

signal dialog_started(npc_id: StringName, dialog_tree: DialogTree)
signal dialog_line_changed(dialog_line: DialogLine)
signal dialog_ended()
signal response_selected(response: DialogResponse)

var current_npc_id: StringName = &""
var current_tree: DialogTree = null
var current_line: DialogLine = null
var dialog_history: Array[String] = []
var is_active: bool = false


func start_dialog(npc_id: StringName, dialog_tree: DialogTree) -> void:
	## Start a new dialog conversation
	if is_active:
		push_warning("Dialog already active, ending current dialog first")
		end_dialog()
	
	current_npc_id = npc_id
	current_tree = dialog_tree
	is_active = true
	dialog_history.clear()
	
	# Start with the first dialog line
	show_dialog(dialog_tree.start_dialog_id)
	
	dialog_started.emit(npc_id, dialog_tree)


func show_dialog(dialog_id: String) -> void:
	## Show a specific dialog line
	if not current_tree:
		push_error("No active dialog tree")
		return
	
	var dialog_line := current_tree.get_dialog(dialog_id)
	if not dialog_line:
		push_error("Dialog line not found: %s" % dialog_id)
		end_dialog()
		return
	
	current_line = dialog_line
	dialog_history.append(dialog_line.text)
	
	dialog_line_changed.emit(dialog_line)
	
	# Auto-advance if configured
	if dialog_line.auto_advance:
		if dialog_line.next_dialog_id.is_empty():
			# End dialog if no next line
			end_dialog()
		else:
			# Schedule next line
			await get_tree().create_timer(dialog_line.delay_seconds).timeout
			show_dialog(dialog_line.next_dialog_id)


func select_response(response: DialogResponse) -> void:
	## Player selects a response option
	if not is_active or not current_line:
		push_warning("No active dialog to respond to")
		return
	
	# Apply response effects
	_apply_response_effects(response)
	
	response_selected.emit(response)
	
	# Continue to next dialog or end
	if response.next_dialog_id.is_empty():
		end_dialog()
	else:
		show_dialog(response.next_dialog_id)


func advance_dialog() -> void:
	## Advance to next dialog line (for dialogs without response options)
	if not current_line:
		return
	
	if current_line.responses.size() > 0:
		# Has responses, player must choose
		return
	
	if current_line.next_dialog_id.is_empty():
		end_dialog()
	else:
		show_dialog(current_line.next_dialog_id)


func end_dialog() -> void:
	## End the current dialog
	if not is_active:
		return
	
	is_active = false
	current_npc_id = &""
	current_tree = null
	current_line = null
	
	dialog_ended.emit()


func _apply_response_effects(response: DialogResponse) -> void:
	## Apply effects from a dialog response
	if response.effect.is_empty():
		return
	
	# Parse and apply effects
	# Format: "effect_type:value"
	var parts := response.effect.split(":")
	if parts.size() < 2:
		return
	
	var effect_type := parts[0]
	var effect_value := parts[1]
	
	match effect_type:
		"add_gold":
			_apply_resource_effect("gold", effect_value.to_int())
		"add_food":
			_apply_resource_effect("food", effect_value.to_int())
		"add_coal":
			_apply_resource_effect("coal", effect_value.to_int())
		_:
			push_warning("Unknown effect type: %s" % effect_type)


func _apply_resource_effect(resource_id: String, amount: int) -> void:
	## Apply a resource change effect
	# Get player faction and add resources
	var faction_system := get_node_or_null("/root/Main/FactionSystem")
	if faction_system and faction_system.has_method("add_resource"):
		# Assuming player is faction 0
		faction_system.add_resource(&"player", StringName(resource_id), amount)
		print("Dialog effect: Added %d %s" % [amount, resource_id])
