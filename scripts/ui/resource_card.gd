extends PanelContainer
class_name ResourceCard

signal resource_selected(resource: GameResource)
signal build_pressed(resource: GameResource)

@onready var icon_rect: TextureRect = %Icon
@onready var title_label: Label = %Title
@onready var build_button: Button = %BuildButton

var resource: GameResource


func _ready() -> void:
	build_button.pressed.connect(_on_build_pressed)


func setup(res: GameResource) -> void:
	resource = res
	if resource == null:
		return
	title_label.text = resource.title
	icon_rect.texture = resource.icon


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
