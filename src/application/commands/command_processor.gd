class_name CommandProcessor
extends RefCounted

const CanonicalJsonScript = preload("res://src/domain/determinism/canonical_json.gd")
const MAX_COMMAND_SEQUENCE: int = 9223372036854775807

var _handlers: Dictionary = {}


func register_handler(command_type: String, handler: Callable) -> void:
	assert(not command_type.is_empty())
	assert(handler.is_valid())
	assert(not _handlers.has(command_type))
	_handlers[command_type] = handler


func process(current_state: Dictionary, command: Dictionary) -> Dictionary:
	var validation_error := _validate_envelope(current_state, command)
	if not validation_error.is_empty():
		return _rejected(current_state, validation_error)

	var candidate: Dictionary = current_state.duplicate(true)
	var handler: Callable = _handlers[command["type"]]
	var payload: Dictionary = command["payload"].duplicate(true)
	var resolution_value: Variant = handler.call(candidate, payload)
	if typeof(resolution_value) != TYPE_DICTIONARY:
		return _rejected(current_state, "handler must return a dictionary")
	var resolution: Dictionary = resolution_value
	if typeof(resolution.get("ok")) != TYPE_BOOL:
		return _rejected(current_state, "handler result must contain a boolean ok")
	if not resolution["ok"]:
		return _rejected(
			current_state,
			str(resolution.get("error", "resolution failed"))
		)

	var events_value: Variant = resolution.get("events", [])
	if typeof(events_value) != TYPE_ARRAY:
		return _rejected(current_state, "handler events must be an array")
	if typeof(candidate.get("campaign")) != TYPE_DICTIONARY:
		return _rejected(current_state, "handler removed campaign state")

	candidate["campaign"]["command_sequence"] = int(command["sequence"])
	var candidate_error := _canonical_error(candidate, "handler candidate")
	if not candidate_error.is_empty():
		return _rejected(current_state, candidate_error)

	var events: Array = events_value
	for event_index in range(events.size()):
		var event_value: Variant = events[event_index]
		if typeof(event_value) != TYPE_DICTIONARY:
			return _rejected(
				current_state,
				"handler event %d must be a dictionary" % event_index
			)
		var event: Dictionary = event_value
		if (
			typeof(event.get("type")) != TYPE_STRING
			or event["type"].is_empty()
		):
			return _rejected(
				current_state,
				"handler event %d must contain a nonempty string type" % event_index
			)
		var event_error := _canonical_error(event, "handler event %d" % event_index)
		if not event_error.is_empty():
			return _rejected(current_state, event_error)

	return {
		"ok": true,
		"state": candidate.duplicate(true),
		"events": events.duplicate(true),
	}


func _validate_envelope(state: Dictionary, command: Dictionary) -> String:
	var state_error := _canonical_error(state, "state")
	if not state_error.is_empty():
		return state_error
	if typeof(state.get("campaign")) != TYPE_DICTIONARY:
		return "state campaign must be a dictionary"
	var campaign: Dictionary = state["campaign"]
	if typeof(campaign.get("command_sequence")) != TYPE_INT:
		return "state command sequence must be an integer"
	var stored_sequence: int = campaign["command_sequence"]
	if stored_sequence < 0:
		return "state command sequence must not be negative"
	if stored_sequence == MAX_COMMAND_SEQUENCE:
		return "state command sequence is exhausted"
	if not command.has("sequence") or typeof(command["sequence"]) != TYPE_INT:
		return "command sequence must be an integer"
	if command["sequence"] <= 0:
		return "command sequence must be positive"
	if not command.has("type") or typeof(command["type"]) != TYPE_STRING:
		return "command type must be a string"
	if not command.has("payload") or typeof(command["payload"]) != TYPE_DICTIONARY:
		return "command payload must be a dictionary"
	var payload_error := _canonical_error(command["payload"], "command payload")
	if not payload_error.is_empty():
		return payload_error
	if not _handlers.has(command["type"]):
		return "unknown command type: %s" % command["type"]
	var expected: int = stored_sequence + 1
	if command["sequence"] != expected:
		return "expected command sequence %d" % expected
	return ""


func _canonical_error(value: Variant, label: String) -> String:
	var encoding: Dictionary = CanonicalJsonScript.encode(value)
	if encoding["ok"]:
		return ""
	return "%s is not canonically encodable: %s" % [
		label,
		str(encoding.get("error", "encoding failed")),
	]


func _rejected(state: Dictionary, message: String) -> Dictionary:
	return {"ok": false, "state": state, "events": [], "error": message}
