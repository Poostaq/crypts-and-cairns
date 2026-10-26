class_name Pcg32
extends RefCounted

const MULTIPLIER: int = 6364136223846793005
const UINT32_MASK: int = 4294967295
const SCRIPT_PATH: String = "res://src/domain/determinism/pcg32.gd"

var _state: int = 0
var _increment: int = 1


static func seeded(seed: int, sequence: int):
	var generator = _new_instance()
	generator._state = 0
	generator._increment = (sequence << 1) | 1
	generator.next_u32()
	generator._state += seed
	generator.next_u32()
	return generator


static func from_snapshot(snapshot_data: Dictionary):
	if not snapshot_data.has("state") or not snapshot_data.has("increment"):
		return null
	if typeof(snapshot_data["state"]) != TYPE_INT:
		return null
	if typeof(snapshot_data["increment"]) != TYPE_INT:
		return null
	var increment := int(snapshot_data["increment"])
	if (increment & 1) == 0:
		return null

	var generator = _new_instance()
	generator._state = int(snapshot_data["state"])
	generator._increment = increment
	return generator


func next_u32() -> int:
	var old_state := _state
	_state = old_state * MULTIPLIER + _increment
	var xorshifted := _unsigned_right_shift(
		old_state ^ _unsigned_right_shift(old_state, 18),
		27
	) & UINT32_MASK
	var rotation := _unsigned_right_shift(old_state, 59) & 31
	return (
		_unsigned_right_shift(xorshifted, rotation)
		| (xorshifted << ((-rotation) & 31))
	) & UINT32_MASK


func snapshot() -> Dictionary:
	return {"state": _state, "increment": _increment}


static func _unsigned_right_shift(value: int, bits: int) -> int:
	if bits == 0:
		return value
	return (value >> bits) & ((1 << (64 - bits)) - 1)


static func _new_instance():
	var script: Script = load(SCRIPT_PATH)
	return script.new()
