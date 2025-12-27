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
var auto_advance_timer: Timer = null  # Track auto-advance timer to cancel it if needed


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
	
	# Cancel any pending auto-advance timer
	_cancel_auto_advance()
	
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
			_schedule_auto_advance_end(dialog_line.delay_seconds)
		else:
			# Schedule next line
			_schedule_auto_advance(dialog_line.next_dialog_id, dialog_line.delay_seconds)


func _schedule_auto_advance(next_dialog_id: String, delay: float) -> void:
	## Schedule auto-advance to next dialog
	_cancel_auto_advance()
	
	auto_advance_timer = Timer.new()
	auto_advance_timer.one_shot = true
	auto_advance_timer.wait_time = delay
	auto_advance_timer.timeout.connect(_on_auto_advance_timeout.bind(next_dialog_id))
	add_child(auto_advance_timer)
	auto_advance_timer.start()


func _schedule_auto_advance_end(delay: float) -> void:
	## Schedule auto-advance to end dialog
	_cancel_auto_advance()
	
	auto_advance_timer = Timer.new()
	auto_advance_timer.one_shot = true
	auto_advance_timer.wait_time = delay
	auto_advance_timer.timeout.connect(end_dialog)
	add_child(auto_advance_timer)
	auto_advance_timer.start()


func _on_auto_advance_timeout(next_dialog_id: String) -> void:
	## Handle auto-advance timer timeout
	if is_active:
		show_dialog(next_dialog_id)


func _cancel_auto_advance() -> void:
	## Cancel any pending auto-advance timer
	if auto_advance_timer and is_instance_valid(auto_advance_timer):
		auto_advance_timer.stop()
		auto_advance_timer.queue_free()
		auto_advance_timer = null


func select_response(response: DialogResponse) -> void:
	## Player selects a response option
	if not is_active or not current_line:
		push_warning("No active dialog to respond to")
		return
	
	# Cancel any pending auto-advance
	_cancel_auto_advance()
	
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
	
	# Cancel any pending auto-advance
	_cancel_auto_advance()
	
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
	
	# Cancel any pending auto-advance
	_cancel_auto_advance()
	
	is_active = false
	current_npc_id = &""
	current_tree = null
	current_line = null
	
	dialog_ended.emit()


func _apply_response_effects(response: DialogResponse) -> void:
	## Apply effects from a dialog response
	# Apply relationship change if specified
	if response.relationship_change != 0:
		# TODO: Apply relationship change to social system
		print("Dialog effect: Relationship change %d (not yet implemented)" % response.relationship_change)
	
	if response.effect.is_empty():
		return
	
	# Parse and apply effects
	# Expected format: "effect_type:value"
	var effect_str := response.effect.strip_edges()
	if effect_str.is_empty():
		return
	
	var sep_index := effect_str.find(":")
	if sep_index == -1:
		# No separator found; cannot parse effect
		push_warning("Invalid effect format (no separator): '%s'" % response.effect)
		return
	
	var effect_type := effect_str.left(sep_index).strip_edges()
	var effect_value_str := effect_str.substr(sep_index + 1, effect_str.length() - sep_index - 1).strip_edges()
	
	if effect_type.is_empty() or effect_value_str.is_empty():
		push_warning("Invalid effect format: '%s'" % response.effect)
		return
	
	if not effect_value_str.is_valid_int():
		push_warning("Invalid effect value for %s: '%s'" % [effect_type, effect_value_str])
		return
	
	var effect_value := effect_value_str.to_int()
	
	match effect_type:
		"add_gold":
			_apply_resource_effect("gold", effect_value)
		"add_food":
			_apply_resource_effect("food", effect_value)
		"add_coal":
			_apply_resource_effect("coal", effect_value)
		_:
			push_warning("Unknown effect type: %s" % effect_type)


func _apply_resource_effect(resource_id: String, amount: int) -> void:
	## Apply a resource change effect
	# Get player faction and add resources
	var faction_system := get_node_or_null("/root/Main/FactionSystem")
	if not faction_system or not faction_system.has_method("add_resource"):
		push_warning("FactionSystem or add_resource method not available; cannot apply resource effect.")
		return
	
	# TODO: Get actual player faction ID from game configuration instead of hardcoded value
	var faction_id := &"kingdom"  # Using 'kingdom' as the default player faction
	
	# Prevent resource values from going negative when applying costs (negative amounts)
	if amount < 0:
		var resource_name := StringName(resource_id)
		
		if faction_system.has_method("resource_amount"):
			var current_amount = faction_system.resource_amount(faction_id, resource_name)
			if current_amount < -amount:
				# Not enough resources to pay this cost; skip applying the effect
				push_warning("Insufficient %s to apply dialog cost %d (current: %d)." % [resource_id, -amount, current_amount])
				return
		else:
			# Without a way to query current resources, avoid applying negative changes to prevent negative totals
			push_warning("Cannot validate negative resource effect for %s (no resource_amount method); skipping effect." % resource_id)
			return
	
	# At this point either amount is positive, or we verified that the player has enough to cover the cost
	var resource_name_to_apply := StringName(resource_id)
	faction_system.add_resource(faction_id, resource_name_to_apply, amount)
	print("Dialog effect: Applied %d %s" % [amount, resource_id])
