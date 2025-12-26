extends Control
class_name ResourceHUD

## Displays faction resources in a top bar HUD

@export var faction_system_path: NodePath
@export var update_interval: float = 0.5
@export var track_production_rate: bool = true
@export var rate_sample_window: float = 10.0
@export var day_night_cycle_path: NodePath
@export var territory_system_path: NodePath

@onready var food_label: Label = %FoodLabel
@onready var coal_label: Label = %CoalLabel
@onready var gold_label: Label = %GoldLabel
@onready var food_rate_label: Label = %FoodRateLabel
@onready var coal_rate_label: Label = %CoalRateLabel
@onready var gold_rate_label: Label = %GoldRateLabel
@onready var time_label: Label = %TimeLabel
@onready var speed_label: Label = %SpeedLabel
@onready var faction_label: Label = %FactionLabel
@onready var territory_label: Label = %TerritoryLabel

var _faction_system: Node
var _day_night_cycle: Node
var _territory_system: Node
var _update_timer: float = 0.0
var _player_faction: StringName = &"kingdom"
var _resource_history: Dictionary = {} # resource_id -> Array[{time: float, amount: int}]
var _current_speed: float = 1.0


func _ready() -> void:
	_resolve_faction_system()
	_resolve_day_night_cycle()
	_resolve_territory_system()
	_init_resource_history()
	_update_display()
	_connect_signals()


func _connect_signals() -> void:
	# Connect to day-night cycle updates
	if _day_night_cycle != null:
		if _day_night_cycle.has_signal("day_changed"):
			_day_night_cycle.day_changed.connect(_on_day_changed)
		if _day_night_cycle.has_signal("hour_changed"):
			_day_night_cycle.hour_changed.connect(_on_hour_changed)
	
	# Connect to time controls if available
	var time_controls = get_tree().get_first_node_in_group("time_controls")
	if time_controls != null:
		if time_controls.has_signal("speed_selected"):
			time_controls.speed_selected.connect(_on_speed_changed)
		if time_controls.has_signal("pause_toggled"):
			time_controls.pause_toggled.connect(_on_pause_toggled)


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_display()


func _resolve_faction_system() -> void:
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path)
	if _faction_system == null:
		_faction_system = get_tree().get_first_node_in_group("faction_system")


func _resolve_day_night_cycle() -> void:
	if not day_night_cycle_path.is_empty():
		_day_night_cycle = get_node_or_null(day_night_cycle_path)
	if _day_night_cycle == null:
		_day_night_cycle = get_tree().get_first_node_in_group("day_night_cycle")


func _resolve_territory_system() -> void:
	if not territory_system_path.is_empty():
		_territory_system = get_node_or_null(territory_system_path)
	if _territory_system == null:
		_territory_system = get_tree().get_first_node_in_group("territory_system")


func _init_resource_history() -> void:
	_resource_history["food"] = []
	_resource_history["coal"] = []
	_resource_history["gold"] = []


func _update_display() -> void:
	if _faction_system == null:
		return
	
	var current_time := Time.get_ticks_msec() / 1000.0
	
	# Get current resource amounts
	var food := _get_resource_amount("food")
	var coal := _get_resource_amount("coal")
	var gold := _get_resource_amount("gold")
	
	# Update labels
	if food_label != null:
		food_label.text = str(food)
	if coal_label != null:
		coal_label.text = str(coal)
	if gold_label != null:
		gold_label.text = str(gold)
	
	# Track history and calculate rates
	if track_production_rate:
		_record_resource_sample("food", food, current_time)
		_record_resource_sample("coal", coal, current_time)
		_record_resource_sample("gold", gold, current_time)
		
		_update_rate_label(food_rate_label, "food", current_time)
		_update_rate_label(coal_rate_label, "coal", current_time)
		_update_rate_label(gold_rate_label, "gold", current_time)
	
	# Update time and faction info
	_update_time_display()
	_update_faction_display()
	_update_territory_display()


func _get_resource_amount(resource_id: String) -> int:
	if _faction_system == null or not _faction_system.has_method("resource_amount"):
		return 0
	return int(_faction_system.call("resource_amount", _player_faction, StringName(resource_id)))


func _record_resource_sample(resource_id: String, amount: int, time: float) -> void:
	if not _resource_history.has(resource_id):
		_resource_history[resource_id] = []
	
	var history: Array = _resource_history[resource_id]
	history.append({"time": time, "amount": amount})
	
	# Remove old samples outside the window
	var cutoff_time := time - rate_sample_window
	while history.size() > 0 and history[0]["time"] < cutoff_time:
		history.pop_front()


func _update_rate_label(label: Label, resource_id: String, current_time: float) -> void:
	if label == null:
		return
	
	var rate := _calculate_production_rate(resource_id, current_time)
	
	if absf(rate) < 0.01:
		label.text = ""
		return
	
	var sign := "+" if rate >= 0 else ""
	var color := Color.GREEN if rate >= 0 else Color.RED
	label.text = "%s%.1f/s" % [sign, rate]
	label.add_theme_color_override("font_color", color)


func _calculate_production_rate(resource_id: String, current_time: float) -> float:
	if not _resource_history.has(resource_id):
		return 0.0
	
	var history: Array = _resource_history[resource_id]
	if history.size() < 2:
		return 0.0
	
	var oldest_sample: Dictionary = history[0]
	var newest_sample: Dictionary = history[history.size() - 1]
	
	var time_diff := newest_sample["time"] - oldest_sample["time"]
	if time_diff < 0.1:
		return 0.0
	
	var amount_diff := float(newest_sample["amount"] - oldest_sample["amount"])
	return amount_diff / time_diff


func set_player_faction(faction_id: StringName) -> void:
	_player_faction = faction_id
	_init_resource_history()
	_update_display()


func _update_time_display() -> void:
	if time_label == null or _day_night_cycle == null:
		return
	
	var day := 1
	var hour := 0
	var minute := 0
	
	if _day_night_cycle.has_method("get_current_day"):
		day = _day_night_cycle.call("get_current_day")
	if _day_night_cycle.has_method("get_current_hour"):
		hour = _day_night_cycle.call("get_current_hour")
	if _day_night_cycle.has_method("get_current_minute"):
		minute = _day_night_cycle.call("get_current_minute")
	
	time_label.text = "Day %d - %02d:%02d" % [day, hour, minute]


func _update_faction_display() -> void:
	if faction_label == null:
		return
	
	# Get faction name - capitalize first letter
	var faction_name := str(_player_faction).capitalize()
	faction_label.text = faction_name


func _update_territory_display() -> void:
	if territory_label == null:
		return
	
	var territory_count := 0
	if _territory_system != null and _territory_system.has_method("get_faction_territory_count"):
		territory_count = _territory_system.call("get_faction_territory_count", _player_faction)
	
	territory_label.text = "Territory: %d" % territory_count


func _on_day_changed(day: int) -> void:
	_update_time_display()


func _on_hour_changed(hour: int) -> void:
	_update_time_display()


func _on_speed_changed(speed: float) -> void:
	_current_speed = speed
	if speed_label != null:
		speed_label.text = "Speed: %.0fx" % speed


func _on_pause_toggled(paused: bool) -> void:
	if speed_label != null:
		speed_label.text = "PAUSED" if paused else "Speed: %.0fx" % _current_speed
