class_name Events
extends RefCounted

# Event dictionary contract:
# {
#   "type": String,
#   "text": String,
#   "data": Dictionary
# }

static func make(event_type: String, text: String, data: Dictionary = {}) -> Dictionary:
	return {
		"type": event_type,
		"text": text,
		"data": data
	}
