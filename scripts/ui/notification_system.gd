extends Control
class_name NotificationSystem

## Toast-style notification system for game events
## Displays up to 3 notifications simultaneously in the top-right corner

signal notification_clicked(notification_data: Dictionary)

@export var max_visible_notifications: int = 3
@export var notification_duration: float = 5.0
@export var notification_spacing: float = 8.0
@export var slide_in_duration: float = 0.3

enum NotificationType {
	INFO,
	WARNING,
	ERROR,
	SUCCESS
}

# Notification data structure:
# {
#   "id": int,
#   "type": NotificationType,
#   "title": String,
#   "message": String,
#   "icon": String (emoji or texture path),
#   "location": Vector2i (optional, for click-to-navigate)
# }

var _notification_queue: Array[Dictionary] = []
var _active_notifications: Array[Dictionary] = []
var _next_id: int = 0


func _ready() -> void:
	add_to_group("notification_system")


func show_notification(title: String, message: String, type: NotificationType = NotificationType.INFO, icon: String = "", location: Variant = null) -> int:
	var notification := {
		"id": _next_id,
		"type": type,
		"title": title,
		"message": message,
		"icon": icon if icon != "" else _get_default_icon(type),
		"location": location,
		"time_remaining": notification_duration
	}
	
	_next_id += 1
	_notification_queue.append(notification)
	_update_notifications()
	
	return notification["id"]


func dismiss_notification(notification_id: int) -> void:
	# Remove from active notifications
	for i in range(_active_notifications.size() - 1, -1, -1):
		if _active_notifications[i]["id"] == notification_id:
			_remove_notification_panel(_active_notifications[i])
			_active_notifications.remove_at(i)
			break
	
	# Remove from queue
	for i in range(_notification_queue.size() - 1, -1, -1):
		if _notification_queue[i]["id"] == notification_id:
			_notification_queue.remove_at(i)
			break
	
	_update_notifications()


func clear_all() -> void:
	for notification in _active_notifications:
		_remove_notification_panel(notification)
	_active_notifications.clear()
	_notification_queue.clear()


func _process(delta: float) -> void:
	# Update timers for active notifications
	for i in range(_active_notifications.size() - 1, -1, -1):
		var notification := _active_notifications[i]
		notification["time_remaining"] -= delta
		
		if notification["time_remaining"] <= 0:
			_remove_notification_panel(notification)
			_active_notifications.remove_at(i)
	
	# Check if we can show more notifications
	_update_notifications()


func _update_notifications() -> void:
	while _active_notifications.size() < max_visible_notifications and _notification_queue.size() > 0:
		var notification := _notification_queue.pop_front()
		_active_notifications.append(notification)
		_create_notification_panel(notification)
	
	# Reposition existing notifications
	_reposition_notifications()


func _create_notification_panel(notification: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "Notification_%d" % notification["id"]
	panel.custom_minimum_size = Vector2(300, 80)
	
	# Store reference in notification data
	notification["panel"] = panel
	
	# Create content
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)
	
	# Icon
	var icon_label := Label.new()
	icon_label.text = notification["icon"]
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)
	
	# Content
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var title_label := Label.new()
	title_label.text = notification["title"]
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", _get_type_color(notification["type"]))
	vbox.add_child(title_label)
	
	var message_label := Label.new()
	message_label.text = notification["message"]
	message_label.add_theme_font_size_override("font_size", 12)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(message_label)
	
	# Close button
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.pressed.connect(func() -> void: dismiss_notification(notification["id"]))
	hbox.add_child(close_button)
	
	# Click handler for navigation
	if notification.get("location") != null:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				emit_signal("notification_clicked", notification)
		)
	
	# Add to scene
	add_child(panel)
	
	# Animate slide in
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, slide_in_duration)
	tween.tween_property(panel, "position:x", get_viewport_rect().size.x - panel.custom_minimum_size.x - 16, slide_in_duration).from(get_viewport_rect().size.x)


func _remove_notification_panel(notification: Dictionary) -> void:
	if not notification.has("panel"):
		return
	
	var panel: Control = notification["panel"]
	if panel == null or not is_instance_valid(panel):
		return
	
	# Animate slide out
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, slide_in_duration)
	tween.tween_callback(panel.queue_free)


func _reposition_notifications() -> void:
	var viewport_size := get_viewport_rect().size
	var y_offset := 16.0
	
	for notification in _active_notifications:
		if not notification.has("panel"):
			continue
		
		var panel: Control = notification["panel"]
		if panel == null or not is_instance_valid(panel):
			continue
		
		var target_pos := Vector2(viewport_size.x - panel.custom_minimum_size.x - 16, y_offset)
		
		# Smooth reposition
		var tween := create_tween()
		tween.tween_property(panel, "position", target_pos, 0.2)
		
		y_offset += panel.custom_minimum_size.y + notification_spacing


func _get_default_icon(type: NotificationType) -> String:
	match type:
		NotificationType.INFO:
			return "ℹ️"
		NotificationType.WARNING:
			return "⚠️"
		NotificationType.ERROR:
			return "❌"
		NotificationType.SUCCESS:
			return "✅"
		_:
			return "📢"


func _get_type_color(type: NotificationType) -> Color:
	match type:
		NotificationType.INFO:
			return Color(0.4, 0.7, 1.0)
		NotificationType.WARNING:
			return Color(1.0, 0.8, 0.2)
		NotificationType.ERROR:
			return Color(1.0, 0.3, 0.3)
		NotificationType.SUCCESS:
			return Color(0.3, 1.0, 0.3)
		_:
			return Color.WHITE


# Convenience methods for common notification types
func show_info(title: String, message: String, location: Variant = null) -> int:
	return show_notification(title, message, NotificationType.INFO, "", location)


func show_warning(title: String, message: String, location: Variant = null) -> int:
	return show_notification(title, message, NotificationType.WARNING, "", location)


func show_error(title: String, message: String, location: Variant = null) -> int:
	return show_notification(title, message, NotificationType.ERROR, "", location)


func show_success(title: String, message: String, location: Variant = null) -> int:
	return show_notification(title, message, NotificationType.SUCCESS, "", location)
