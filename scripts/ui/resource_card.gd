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
var _selected_stylebox: StyleBoxFlat
var _selected: bool = false


func _ready() -> void:
	build_button.pressed.connect(_on_build_pressed)
	_selected_stylebox = _make_selected_stylebox()


func setup(res: GameResource) -> void:
	resource = res
	if resource == null:
		return
	title_label.text = resource.title
	icon_rect.texture = resource.icon
	_set_tooltip()
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


func _set_tooltip() -> void:
	if resource == null:
		return
	var lines: Array[String] = []
	if not String(resource.description).is_empty():
		lines.append(resource.description)
	if resource.resource_delta_per_hour.size() > 0:
		var parts: Array[String] = []
		for key in resource.resource_delta_per_hour.keys():
			var amount: int = int(resource.resource_delta_per_hour[key])
			var sign := "+" if amount >= 0 else ""
			parts.append("%s%s/hr %s" % [sign, str(amount), str(key)])
		parts.sort()
		lines.append("Per hour: %s" % ", ".join(parts))
	if resource.build_cost.size() > 0:
		var cost_parts: Array[String] = []
		for key in resource.build_cost.keys():
			var amount: int = int(resource.build_cost[key])
			cost_parts.append("%s: %d" % [str(key), amount])
		cost_parts.sort()
		lines.append("Cost: %s" % ", ".join(cost_parts))
	if int(resource.build_time_hours) > 0:
		lines.append("Build time: %dh" % int(resource.build_time_hours))
	if resource.buildable_tiles.is_empty():
		lines.append("Buildable on any tile.")
	else:
		var tiles_text := ", ".join(resource.buildable_tiles)
		lines.append("Buildable on: %s" % tiles_text)
	var tooltip := "\n".join(lines)
	tooltip_text = tooltip
	if build_button != null:
		build_button.tooltip_text = tooltip


func set_selected(value: bool) -> void:
	_selected = value
	if _selected:
		if _selected_stylebox != null:
			add_theme_stylebox_override("panel", _selected_stylebox)
	else:
		remove_theme_stylebox_override("panel")


func _make_selected_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.8, 0.4, 0.08)
	sb.border_color = Color(1.0, 0.65, 0.2, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	return sb
