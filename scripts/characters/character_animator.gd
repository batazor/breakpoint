extends Node3D
class_name CharacterAnimator

# Runtime importer that attaches an AnimationPlayer to a character model and
# merges animations from external GLB packs.

@export var model_scene: PackedScene
@export var model_path: NodePath
@export var animation_sources: Array[String] = []
@export var default_animation: StringName = "Idle"
@export var play_on_ready: bool = true

var model: Node = null
var animation_player: AnimationPlayer = null


func _ready() -> void:
	_attach_model_if_needed()
	model = _resolve_model()
	if model == null:
		push_warning("CharacterAnimator: model not found; set model_scene or model_path.")
		return

	animation_player = _find_animation_player(model)
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		model.add_child(animation_player)

	_merge_animation_sources()
	if play_on_ready:
		_play_default()


func _attach_model_if_needed() -> void:
	if model_scene == null:
		return
	if model != null:
		return
	var inst := model_scene.instantiate()
	if inst == null:
		push_warning("CharacterAnimator: failed to instance model_scene.")
		return
	add_child(inst)
	model = inst


func _resolve_model() -> Node:
	if model != null:
		return model
	if model_path.is_empty():
		return null
	return get_node_or_null(model_path)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _merge_animation_sources() -> void:
	for src_path in animation_sources:
		if typeof(src_path) != TYPE_STRING:
			continue
		if String(src_path).is_empty():
			continue
		var packed: PackedScene = load(src_path)
		if packed == null:
			push_warning("CharacterAnimator: animation source not found: %s" % src_path)
			continue
		var inst := packed.instantiate()
		if inst == null:
			push_warning("CharacterAnimator: failed to instance %s" % src_path)
			continue
		var src_player := _find_animation_player(inst)
		if src_player == null:
			continue
		_add_library_for_source(src_path, src_player)
		inst.queue_free()


func _add_library_for_source(src_path: String, src_player: AnimationPlayer) -> void:
	if animation_player == null or src_player == null:
		return
	var lib := AnimationLibrary.new()
	for anim_name in src_player.get_animation_list():
		var anim := src_player.get_animation(anim_name)
		if anim == null:
			continue
		lib.add_animation(anim_name, anim.duplicate(true))
	var lib_name := _library_name(src_path)
	if lib.get_animation_list().is_empty():
		return
	animation_player.add_animation_library(lib_name, lib)


func _library_name(path: String) -> StringName:
	var parts := path.get_file().split(".")
	if parts.size() > 0:
		return StringName(parts[0])
	return StringName(path)


func _play_default() -> void:
	if animation_player == null:
		return
	var names := animation_player.get_animation_list()
	var chosen: StringName = default_animation
	if not names.has(chosen):
		if names.size() > 0:
			chosen = names[0]
		else:
			return
	animation_player.play(chosen)

