class_name ReplayRunner
extends RefCounted

const CanonicalJsonScript = preload(
	"res://src/domain/determinism/canonical_json.gd"
)
const StateHasherScript = preload(
	"res://src/domain/determinism/state_hasher.gd"
)
const SHA256_HEX_LENGTH: int = 64


static func record(
	initial_state: Dictionary,
	commands: Array,
	processor
) -> Dictionary:
	if processor == null:
		return _error("command processor is required")

	var initial_hash: Dictionary = StateHasherScript.hash_state(initial_state)
	if not initial_hash["ok"]:
		return _error(
			"initial state cannot be hashed: %s" %
				str(initial_hash.get("error", "encoding failed"))
		)

	var command_encoding: Dictionary = CanonicalJsonScript.encode(commands)
	if not command_encoding["ok"]:
		return _error(
			"commands are not canonically encodable: %s" %
				str(command_encoding.get("error", "encoding failed"))
		)

	var state: Dictionary = initial_state.duplicate(true)
	var recorded_commands: Array = commands.duplicate(true)
	var hashes: Array[String] = [initial_hash["hash"]]

	for command_index: int in range(recorded_commands.size()):
		var command_value: Variant = recorded_commands[command_index]
		if typeof(command_value) != TYPE_DICTIONARY:
			return _error(
				"command %d must be a dictionary" % command_index
			)

		var command: Dictionary = command_value
		var result: Dictionary = processor.process(state, command)
		if not result["ok"]:
			return _error(
				"command %d rejected: %s" % [
					command_index,
					str(result.get("error", "resolution failed")),
				]
			)

		state = result["state"]
		var state_hash: Dictionary = StateHasherScript.hash_state(state)
		if not state_hash["ok"]:
			return _error(
				"state after command %d cannot be hashed: %s" % [
					command_index,
					str(state_hash.get("error", "encoding failed")),
				]
			)
		hashes.append(state_hash["hash"])

	return {
		"ok": true,
		"final_state": state.duplicate(true),
		"replay": {
			"commands": recorded_commands,
			"hashes": hashes,
		},
	}


static func verify(
	initial_state: Dictionary,
	replay: Dictionary,
	processor
) -> Dictionary:
	if processor == null:
		return _error("command processor is required")

	var replay_encoding: Dictionary = CanonicalJsonScript.encode(replay)
	if not replay_encoding["ok"]:
		return _error(
			"replay is not canonically encodable: %s" %
				str(replay_encoding.get("error", "encoding failed"))
		)

	var commands_value: Variant = replay.get("commands")
	if typeof(commands_value) != TYPE_ARRAY:
		return _error("replay commands must be an array")
	var hashes_value: Variant = replay.get("hashes")
	if typeof(hashes_value) != TYPE_ARRAY:
		return _error("replay hashes must be an array")

	var commands: Array = commands_value
	var expected_hashes: Array = hashes_value
	if expected_hashes.size() != commands.size() + 1:
		return _error("replay hash count differs")
	for hash_index: int in range(expected_hashes.size()):
		var hash_value: Variant = expected_hashes[hash_index]
		if (
			typeof(hash_value) != TYPE_STRING
			or not _is_sha256_hash(hash_value)
		):
			return _error(
				"replay hash %d must be a lowercase SHA-256 value" %
					hash_index
			)

	var recorded: Dictionary = record(
		initial_state,
		commands,
		processor
	)
	if not recorded["ok"]:
		return recorded

	var actual_hashes: Array = recorded["replay"]["hashes"]
	for hash_index: int in range(actual_hashes.size()):
		if actual_hashes[hash_index] != expected_hashes[hash_index]:
			return _error(
				"replay diverged at hash index %d" % hash_index
			)

	return {
		"ok": true,
		"final_state": recorded["final_state"].duplicate(true),
		"final_hash": actual_hashes[-1],
	}


static func _is_sha256_hash(value: String) -> bool:
	if value.length() != SHA256_HEX_LENGTH:
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_lower_hex := code >= 97 and code <= 102
		if not is_digit and not is_lower_hex:
			return false
	return true


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
