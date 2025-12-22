extends PanelContainer
class_name ResourceCard

signal resource_selected(resource: GameResource)
signal build_pressed(resource: GameResource)

@onready var icon_rect: TextureRect = %Icon
@onready var title_label: Label = %Title
@onready var build_button: Button = %BuildButton

var resource: GameResource
@export var buildable_tint: Color = Color(0.75, 1.0, 0.75, 1.0)
@export var blocked_tint: Color = Color(1.0, 0.75, 0.75, 1.0)
@export var neutral_tint: Color = Color(1.0, 1.0, 1.0, 1.0)


func _ready() -> void:
	build_button.pressed.connect(_on_build_pressed)


func setup(res: GameResource) -> void:
	resource = res
	if resource == null:
		return
	title_label.text = resource.title
	icon_rect.texture = resource.icon
	set_buildable_state(true, false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if resource == null:
			return
		emit_signal("resource_selected", resource)
		accept_event()


func _on_build_pressed() -> void:
	if resource == null:
		return
	emit_signal("resource_selected", resource)
	emit_signal("build_pressed", resource)


func set_buildable_state(can_build: bool, has_selection: bool) -> void:
	if not has_selection:
		self_modulate = neutral_tint
		return
	self_modulate = buildable_tint if can_build else blocked_tint
