extends "res://tests/support/test_case.gd"

const CommandProcessor = preload("res://src/application/commands/command_processor.gd")
const GameStateFactory = preload("res://src/domain/state/game_state_factory.gd")
const StateHasher = preload("res://src/domain/determinism/state_hasher.gd")

var _retained_candidate: Dictionary = {}
var _retained_event: Dictionary = {}


func run() -> void:
	var processor = CommandProcessor.new()
	processor.register_handler("test.advance", Callable(self, "_advance"))
	processor.register_handler("test.fail", Callable(self, "_mutate_then_fail"))
	processor.register_handler(
		"test.payload_fail",
		Callable(self, "_mutate_payload_then_fail")
	)
	processor.register_handler(
		"test.float_candidate",
		Callable(self, "_produce_float_candidate")
	)
	processor.register_handler(
		"test.missing_event_type",
		Callable(self, "_produce_missing_event_type")
	)
	processor.register_handler(
		"test.float_event",
		Callable(self, "_produce_float_event")
	)
	var initial: Dictionary = GameStateFactory.create(5, "content", "test")["state"]

	var accepted: Dictionary = processor.process(initial, {
		"sequence": 1,
		"type": "test.advance",
		"payload": {"ticks": 6},
	})
	assert_true(accepted["ok"], "valid command succeeds")
	assert_equal(
		accepted["state"]["campaign"]["elapsed_ticks"],
		6,
		"handler mutation commits"
	)
	assert_equal(
		accepted["state"]["campaign"]["command_sequence"],
		1,
		"sequence commits last"
	)
	assert_equal(
		initial["campaign"]["elapsed_ticks"],
		0,
		"input state remains immutable"
	)
	var expected_events: Array = [
		{"type": "time_advanced", "ticks": 6},
		{"type": "advance_recorded", "ticks": 6},
	]
	assert_equal(
		accepted["events"],
		expected_events,
		"accepted events preserve exact values and order"
	)
	_retained_candidate["campaign"]["elapsed_ticks"] = 777
	_retained_event["ticks"] = 777
	assert_equal(
		accepted["state"]["campaign"]["elapsed_ticks"],
		6,
		"retained handler candidate cannot mutate committed state"
	)
	assert_equal(
		accepted["events"],
		expected_events,
		"retained handler event cannot mutate committed events"
	)

	var initial_hash: String = StateHasher.hash_state(initial)["hash"]
	var bad_sequence: Dictionary = processor.process(initial, {
		"sequence": 2,
		"type": "test.advance",
		"payload": {"ticks": 1},
	})
	assert_true(not bad_sequence["ok"], "sequence gap is rejected")
	assert_equal(
		StateHasher.hash_state(initial)["hash"],
		initial_hash,
		"validation rejection preserves hash"
	)

	var injected_failure: Dictionary = processor.process(initial, {
		"sequence": 1,
		"type": "test.fail",
		"payload": {},
	})
	assert_true(not injected_failure["ok"], "handler failure is rejected")
	assert_equal(
		StateHasher.hash_state(initial)["hash"],
		initial_hash,
		"resolution failure preserves hash"
	)

	var payload_alias_failure: Dictionary = processor.process(initial, {
		"sequence": 1,
		"type": "test.payload_fail",
		"payload": initial["campaign"],
	})
	assert_true(
		not payload_alias_failure["ok"],
		"payload mutation followed by failure is rejected"
	)
	assert_equal(
		StateHasher.hash_state(initial)["hash"],
		initial_hash,
		"aliased caller payload cannot mutate input state"
	)

	var float_candidate: Dictionary = processor.process(initial, {
		"sequence": 1,
		"type": "test.float_candidate",
		"payload": {},
	})
	assert_true(not float_candidate["ok"], "noncanonical successful candidate is rejected")
	assert_equal(
		StateHasher.hash_state(initial)["hash"],
		initial_hash,
		"noncanonical candidate rejection preserves input hash"
	)

	var missing_event_type: Dictionary = processor.process(initial, {
		"sequence": 1,
		"type": "test.missing_event_type",
		"payload": {},
	})
	assert_true(
		not missing_event_type["ok"],
		"event without a nonempty string type is rejected"
	)

	var float_event: Dictionary = processor.process(initial, {
		"sequence": 1,
		"type": "test.float_event",
		"payload": {},
	})
	assert_true(not float_event["ok"], "noncanonical event is rejected")

	var negative_sequence_state: Dictionary = initial.duplicate(true)
	negative_sequence_state["campaign"]["command_sequence"] = -1
	var negative_sequence: Dictionary = processor.process(
		negative_sequence_state,
		{
			"sequence": 1,
			"type": "test.advance",
			"payload": {"ticks": 1},
		}
	)
	assert_true(not negative_sequence["ok"], "negative stored command sequence is rejected")

	var exhausted_sequence_state: Dictionary = initial.duplicate(true)
	exhausted_sequence_state["campaign"]["command_sequence"] = CommandProcessor.MAX_COMMAND_SEQUENCE
	var exhausted_sequence: Dictionary = processor.process(
		exhausted_sequence_state,
		{
			"sequence": CommandProcessor.MAX_COMMAND_SEQUENCE,
			"type": "test.advance",
			"payload": {"ticks": 1},
		}
	)
	assert_true(
		not exhausted_sequence["ok"],
		"maximum stored command sequence is rejected before addition"
	)

	var float_payload: Dictionary = processor.process(initial, {
		"sequence": 1,
		"type": "test.advance",
		"payload": {"ticks": 1.5},
	})
	assert_true(not float_payload["ok"], "noncanonical payload is rejected")

	var cyclic_state: Dictionary = initial.duplicate(true)
	cyclic_state["cycle"] = cyclic_state
	var cyclic_state_result: Dictionary = processor.process(cyclic_state, {
		"sequence": 1,
		"type": "test.advance",
		"payload": {"ticks": 1},
	})
	assert_true(
		not cyclic_state_result["ok"],
		"cyclic state is rejected before deep copy"
	)


func _advance(candidate: Dictionary, payload: Dictionary) -> Dictionary:
	var ticks := int(payload.get("ticks", 0))
	if ticks <= 0:
		return {"ok": false, "error": "ticks must be positive"}
	candidate["campaign"]["elapsed_ticks"] += ticks
	var time_event: Dictionary = {"type": "time_advanced", "ticks": ticks}
	var record_event: Dictionary = {"type": "advance_recorded", "ticks": ticks}
	_retained_candidate = candidate
	_retained_event = time_event
	return {"ok": true, "events": [time_event, record_event]}


func _mutate_then_fail(candidate: Dictionary, _payload: Dictionary) -> Dictionary:
	candidate["campaign"]["elapsed_ticks"] = 999
	return {"ok": false, "error": "injected failure"}


func _mutate_payload_then_fail(
	_candidate: Dictionary,
	payload: Dictionary
) -> Dictionary:
	payload["elapsed_ticks"] = 999
	return {"ok": false, "error": "injected payload failure"}


func _produce_float_candidate(
	candidate: Dictionary,
	_payload: Dictionary
) -> Dictionary:
	candidate["campaign"]["elapsed_ticks"] = 1.5
	return {"ok": true, "events": []}


func _produce_missing_event_type(
	_candidate: Dictionary,
	_payload: Dictionary
) -> Dictionary:
	return {"ok": true, "events": [{"value": 1}]}


func _produce_float_event(
	_candidate: Dictionary,
	_payload: Dictionary
) -> Dictionary:
	return {"ok": true, "events": [{"type": "bad_event", "value": 1.5}]}
