extends CanvasLayer
class_name DialogPanel

## UI for displaying NPC dialog

@onready var panel_container: PanelContainer = %PanelContainer
@onready var speaker_label: Label = %SpeakerLabel
@onready var dialog_label: RichTextLabel = %DialogLabel
@onready var response_container: VBoxContainer = %ResponseContainer
@onready var continue_button: Button = %ContinueButton

var dialog_manager: DialogManager = null
var typewriter_active: bool = false
var full_text: String = ""
var current_char_index: int = 0
var typewriter_speed: float = 0.05  # seconds per character


func _ready() -> void:
	hide_panel()
	
	# Find or create dialog manager
	dialog_manager = get_node_or_null("/root/Main/DialogManager")
	if not dialog_manager:
		dialog_manager = DialogManager.new()
		dialog_manager.name = "DialogManager"
		get_node("/root/Main").add_child(dialog_manager)
	
	# Connect signals
	if dialog_manager:
		dialog_manager.dialog_started.connect(_on_dialog_started)
		dialog_manager.dialog_line_changed.connect(_on_dialog_line_changed)
		dialog_manager.dialog_ended.connect(_on_dialog_ended)
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)


func show_panel() -> void:
	## Show the dialog panel
	if panel_container:
		panel_container.visible = true
	visible = true


func hide_panel() -> void:
	## Hide the dialog panel
	if panel_container:
		panel_container.visible = false
	visible = false


func _on_dialog_started(npc_id: StringName, dialog_tree: DialogTree) -> void:
	## Handle dialog start
	show_panel()


func _on_dialog_line_changed(dialog_line: DialogLine) -> void:
	## Update UI with new dialog line
	if not dialog_line:
		return
	
	# Set speaker name
	if speaker_label:
		speaker_label.text = dialog_line.speaker_name
	
	# Show dialog text with typewriter effect
	full_text = dialog_line.text
	current_char_index = 0
	typewriter_active = true
	
	if dialog_label:
		dialog_label.text = ""
	
	_start_typewriter()
	
	# Clear previous responses
	_clear_responses()
	
	# Show continue button or responses
	if dialog_line.responses.size() == 0:
		# No responses, show continue button
		if continue_button:
			continue_button.visible = true
	else:
		# Has responses, hide continue button and show response options
		if continue_button:
			continue_button.visible = false
		_show_responses(dialog_line.responses)


func _on_dialog_ended() -> void:
	## Handle dialog end
	hide_panel()
	typewriter_active = false


func _start_typewriter() -> void:
	## Start typewriter effect for dialog text
	if not typewriter_active:
		return
	
	if current_char_index < full_text.length():
		if dialog_label:
			dialog_label.text = full_text.left(current_char_index + 1)
		current_char_index += 1
		
		# Schedule next character
		await get_tree().create_timer(typewriter_speed).timeout
		_start_typewriter()
	else:
		typewriter_active = false


func _clear_responses() -> void:
	## Clear all response buttons
	if not response_container:
		return
	
	for child in response_container.get_children():
		if child is Button:
			child.disabled = true
		child.queue_free()


func _show_responses(responses: Array[DialogResponse]) -> void:
	## Create buttons for dialog responses
	if not response_container:
		return
	
	for response in responses:
		var button := Button.new()
		button.text = response.text
		button.pressed.connect(_on_response_selected.bind(response))
		response_container.add_child(button)


func _on_response_selected(response: DialogResponse) -> void:
	## Handle response button click
	if dialog_manager:
		dialog_manager.select_response(response)


func _on_continue_pressed() -> void:
	## Handle continue button click
	if typewriter_active:
		# Skip typewriter effect
		typewriter_active = false
		if dialog_label:
			dialog_label.text = full_text
		current_char_index = full_text.length()
	else:
		# Advance dialog
		if dialog_manager:
			dialog_manager.advance_dialog()


func _input(event: InputEvent) -> void:
	## Handle input for dialog
	if not visible:
		return
	
	# Skip typewriter or advance on space/enter
	if event.is_action_pressed("ui_accept"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()
