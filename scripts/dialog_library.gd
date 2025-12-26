extends Node
class_name DialogLibrary

## Library of dialog trees for NPCs

static func get_npc_dialog(npc: NPC, relationship: float = 0.5) -> DialogTree:
	## Get appropriate dialog tree for an NPC based on relationship
	var tree := DialogTree.new()
	tree.id = "npc_dialog_%s" % npc.id
	tree.title = "Conversation with %s" % (npc.title if not npc.title.is_empty() else String(npc.id))
	
	# Create dialog based on relationship
	if relationship >= 0.7:
		_create_friendly_dialog(tree, npc)
	elif relationship <= 0.3:
		_create_hostile_dialog(tree, npc)
	else:
		_create_neutral_dialog(tree, npc)
	
	return tree


static func _create_friendly_dialog(tree: DialogTree, npc: NPC) -> void:
	## Create friendly dialog options
	var greeting := DialogLine.new()
	greeting.speaker_name = npc.title if not npc.title.is_empty() else String(npc.id)
	greeting.text = "Greetings, friend! It's good to see you again. How can I help you today?"
	
	var response1 := DialogResponse.new()
	response1.text = "Tell me about yourself."
	response1.next_dialog_id = "about"
	
	var response2 := DialogResponse.new()
	response2.text = "Can you help me with resources?"
	response2.next_dialog_id = "help"
	
	var response3 := DialogResponse.new()
	response3.text = "Just saying hello. Goodbye!"
	response3.next_dialog_id = ""
	
	greeting.responses = [response1, response2, response3]
	tree.add_dialog("start", greeting)
	
	# About dialog
	var about := DialogLine.new()
	about.speaker_name = greeting.speaker_name
	about.text = "I am %s, loyal to %s. I serve my faction with honor and dedication." % [
		greeting.speaker_name,
		String(npc.faction_id)
	]
	about.next_dialog_id = "about_continue"
	tree.add_dialog("about", about)
	
	var about_continue := DialogLine.new()
	about_continue.speaker_name = greeting.speaker_name
	about_continue.text = "Is there anything else you'd like to know?"
	
	var response_back := DialogResponse.new()
	response_back.text = "No, that's all. Thank you."
	response_back.next_dialog_id = ""
	
	about_continue.responses = [response_back]
	tree.add_dialog("about_continue", about_continue)
	
	# Help dialog
	var help := DialogLine.new()
	help.speaker_name = greeting.speaker_name
	help.text = "Of course! As a friend of %s, I can spare some resources. Here, take this gold." % String(npc.faction_id)
	help.next_dialog_id = "help_given"
	tree.add_dialog("help", help)
	
	var help_given := DialogLine.new()
	help_given.speaker_name = greeting.speaker_name
	help_given.text = "I hope this helps you on your journey. Come back anytime!"
	
	var response_thanks := DialogResponse.new()
	response_thanks.text = "Thank you so much!"
	response_thanks.effect = "add_gold:5"
	response_thanks.relationship_change = 5
	response_thanks.next_dialog_id = ""
	
	help_given.responses = [response_thanks]
	tree.add_dialog("help_given", help_given)


static func _create_neutral_dialog(tree: DialogTree, npc: NPC) -> void:
	## Create neutral dialog options
	var greeting := DialogLine.new()
	greeting.speaker_name = npc.title if not npc.title.is_empty() else String(npc.id)
	greeting.text = "Hello. What brings you here?"
	
	var response1 := DialogResponse.new()
	response1.text = "Who are you?"
	response1.next_dialog_id = "identity"
	
	var response2 := DialogResponse.new()
	response2.text = "What is this place?"
	response2.next_dialog_id = "place"
	
	var response3 := DialogResponse.new()
	response3.text = "Nothing, just passing through."
	response3.next_dialog_id = ""
	
	greeting.responses = [response1, response2, response3]
	tree.add_dialog("start", greeting)
	
	# Identity dialog
	var identity := DialogLine.new()
	identity.speaker_name = greeting.speaker_name
	identity.text = "I am %s of the %s faction. I'm just doing my duty here." % [
		greeting.speaker_name,
		String(npc.faction_id)
	]
	
	var response_ok := DialogResponse.new()
	response_ok.text = "I see. Carry on."
	response_ok.next_dialog_id = ""
	
	identity.responses = [response_ok]
	tree.add_dialog("identity", identity)
	
	# Place dialog
	var place := DialogLine.new()
	place.speaker_name = greeting.speaker_name
	place.text = "This is territory controlled by %s. We work these lands and defend them." % String(npc.faction_id)
	
	var response_understand := DialogResponse.new()
	response_understand.text = "Understood. Farewell."
	response_understand.next_dialog_id = ""
	
	place.responses = [response_understand]
	tree.add_dialog("place", place)


static func _create_hostile_dialog(tree: DialogTree, npc: NPC) -> void:
	## Create hostile dialog options
	var greeting := DialogLine.new()
	greeting.speaker_name = npc.title if not npc.title.is_empty() else String(npc.id)
	greeting.text = "What do you want? You're not welcome here."
	
	var response1 := DialogResponse.new()
	response1.text = "I mean no harm."
	response1.next_dialog_id = "peace"
	
	var response2 := DialogResponse.new()
	response2.text = "I'm just leaving. (Leave)"
	response2.next_dialog_id = ""
	
	greeting.responses = [response1, response2]
	tree.add_dialog("start", greeting)
	
	# Peace attempt dialog
	var peace := DialogLine.new()
	peace.speaker_name = greeting.speaker_name
	peace.text = "Hmph. The %s faction doesn't trust outsiders easily. State your business quickly." % String(npc.faction_id)
	
	var response_gift := DialogResponse.new()
	response_gift.text = "Let me offer you some gold as a gesture of goodwill."
	response_gift.effect = "add_gold:-3"
	response_gift.relationship_change = 10
	response_gift.next_dialog_id = "gift_accepted"
	
	var response_leave := DialogResponse.new()
	response_leave.text = "I'll leave you alone then."
	response_leave.next_dialog_id = ""
	
	peace.responses = [response_gift, response_leave]
	tree.add_dialog("peace", peace)
	
	# Gift accepted dialog
	var gift := DialogLine.new()
	gift.speaker_name = greeting.speaker_name
	gift.text = "Well... that's unexpected. Perhaps I judged you too harshly. Safe travels."
	
	var response_thanks := DialogResponse.new()
	response_thanks.text = "Thank you for listening."
	response_thanks.next_dialog_id = ""
	
	gift.responses = [response_thanks]
	tree.add_dialog("gift_accepted", gift)
