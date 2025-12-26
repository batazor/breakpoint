extends CanvasLayer
class_name NpcInfoPanel

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var info_label: RichTextLabel = %InfoLabel


func _ready() -> void:
	clear()


func show_npc(npc: NPC, social: SocialSystem) -> void:
	if npc == null:
		clear()
		return
	var title: String = npc.title
	if title.is_empty():
		title = String(npc.id)
	if title_label != null:
		title_label.text = title

	var lines: Array[String] = []
	lines.append("ID: %s" % String(npc.id))
	lines.append("Faction: %s" % String(npc.faction_id))
	lines.append("Loyalty: %.2f" % npc.loyalty)
	lines.append("Health: %d" % npc.health)
	if not npc.description.is_empty():
		lines.append("Note: %s" % npc.description)
	
	# Display inventory
	if npc.inventory != null and not npc.inventory.is_empty():
		lines.append("")
		lines.append("Inventory:")
		var resource_ids: Array = npc.inventory.keys()
		resource_ids.sort()
		for res_id in resource_ids:
			var amount: int = int(npc.inventory[res_id])
			if amount > 0:
				lines.append("- %s: %d" % [String(res_id).capitalize(), amount])

	if social != null:
		var other_ids: Array = social.npcs.keys()
		other_ids.sort()
		if other_ids.size() > 1:
			lines.append("")
			lines.append("Relations:")
			for other in other_ids:
				var other_id: StringName = StringName(other)
				if other_id == npc.id:
					continue
				var trust: float = social.get_relation_value(npc.id, other_id, "trust")
				var hate: float = social.get_relation_value(npc.id, other_id, "hate")
				var fear: float = social.get_relation_value(npc.id, other_id, "fear")
				lines.append("- %s  T %.2f  H %.2f  F %.2f" % [
					String(other_id),
					trust,
					hate,
					fear,
				])

	if info_label != null:
		info_label.text = "\n".join(lines)
	_set_visible(true)


func clear() -> void:
	if title_label != null:
		title_label.text = ""
	if info_label != null:
		info_label.text = ""
	_set_visible(false)


func _set_visible(value: bool) -> void:
	if panel != null:
		panel.visible = value
	visible = value
