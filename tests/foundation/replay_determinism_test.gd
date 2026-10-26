extends "res://tests/support/test_case.gd"

const CanonicalJson = preload(
	"res://src/domain/determinism/canonical_json.gd"
)
const CommandProcessor = preload(
	"res://src/application/commands/command_processor.gd"
)
const FoundationProbeHandler = preload(
	"res://tests/foundation/foundation_probe_handler.gd"
)
const GameStateFactory = preload(
	"res://src/domain/state/game_state_factory.gd"
)
const JsonIntegerNormalizer = preload(
	"res://src/platform/json/json_integer_normalizer.gd"
)
const JsonContentRepository = preload(
	"res://src/platform/content/json_content_repository.gd"
)
const ReplayRunner = preload(
	"res://src/application/replay/replay_runner.gd"
)
const StateHasher = preload(
	"res://src/domain/determinism/state_hasher.gd"
)

var _handler_refs: Array[RefCounted] = []


func run() -> void:
	var fixture_result: Dictionary = (
		JsonIntegerNormalizer.parse_and_normalize(
			FileAccess.get_file_as_string(
				"res://tests/fixtures/foundation_replay.json"
			)
		)
	)
	assert_true(
		fixture_result["ok"],
		"fixture contains exact integral JSON numbers"
	)
	if not fixture_result["ok"]:
		return

	var fixture: Dictionary = fixture_result["value"]
	var commands: Array = fixture["commands"]
	var loaded_content: Dictionary = JsonContentRepository.load_catalog(
		"res://content/manifest.json"
	)
	assert_true(
		loaded_content["ok"],
		"foundation catalog loads for replay"
	)
	if not loaded_content["ok"]:
		return
	var initial: Dictionary = GameStateFactory.create(
		8675309,
		loaded_content["content_hash"],
		"test"
	)["state"]
	assert_equal(
		initial["meta"]["content_hash"],
		loaded_content["content_hash"],
		"replay state is bound to authoritative foundation content"
	)
	var initial_hash: String = StateHasher.hash_state(initial)["hash"]

	var first_recording: Dictionary = ReplayRunner.record(
		initial,
		commands,
		_make_processor()
	)
	assert_true(first_recording["ok"], "fixture records successfully")
	if not first_recording["ok"]:
		return

	assert_equal(
		first_recording["replay"]["hashes"].size(),
		commands.size() + 1,
		"recording includes initial and post-command hashes"
	)
	assert_equal(
		first_recording["replay"]["hashes"][0],
		initial_hash,
		"first replay hash represents the initial state"
	)
	assert_equal(
		first_recording["final_state"]["campaign"]["elapsed_ticks"],
		23,
		"recorded commands produce their expected state"
	)
	assert_equal(
		first_recording["final_state"]["campaign"]["command_sequence"],
		3,
		"recording processes every command in sequence"
	)
	assert_equal(
		initial["campaign"]["command_sequence"],
		0,
		"recording does not mutate initial sequence"
	)
	assert_equal(
		initial["campaign"]["elapsed_ticks"],
		0,
		"recording does not mutate initial elapsed time"
	)

	var second_recording: Dictionary = ReplayRunner.record(
		initial,
		commands,
		_make_processor()
	)
	assert_true(
		second_recording["ok"],
		"fixture records independently a second time"
	)
	if not second_recording["ok"]:
		return
	assert_equal(
		second_recording["replay"]["hashes"],
		first_recording["replay"]["hashes"],
		"independent recordings produce identical hash chains"
	)
	assert_equal(
		second_recording["final_state"],
		first_recording["final_state"],
		"independent recordings produce identical final state"
	)

	var verification: Dictionary = ReplayRunner.verify(
		initial,
		first_recording["replay"],
		_make_processor()
	)
	assert_true(verification["ok"], "recorded replay verifies")
	if verification["ok"]:
		assert_equal(
			verification["final_hash"],
			first_recording["replay"]["hashes"][-1],
			"verification returns the recorded final hash"
		)

	var recorded_ticks: int = (
		first_recording["replay"]["commands"][0]["payload"]["ticks"]
	)
	commands[0]["payload"]["ticks"] = 999
	assert_equal(
		first_recording["replay"]["commands"][0]["payload"]["ticks"],
		recorded_ticks,
		"recording owns its command snapshot"
	)
	commands[0]["payload"]["ticks"] = recorded_ticks

	var divergent: Dictionary = first_recording["replay"].duplicate(true)
	divergent["hashes"][2] = (
		"0000000000000000000000000000000000000000000000000000000000000000"
	)
	var divergence: Dictionary = ReplayRunner.verify(
		initial,
		divergent,
		_make_processor()
	)
	assert_true(not divergence["ok"], "changed hash is rejected")
	assert_true(
		str(divergence.get("error", "")).contains("hash index 2"),
		"divergence reports the first mismatched hash index"
	)

	var wrong_count: Dictionary = first_recording["replay"].duplicate(true)
	wrong_count["hashes"].pop_back()
	var count_result: Dictionary = ReplayRunner.verify(
		initial,
		wrong_count,
		_make_processor()
	)
	assert_true(
		not count_result["ok"],
		"wrong replay hash count is rejected"
	)

	var malformed_hashes: Dictionary = (
		first_recording["replay"].duplicate(true)
	)
	var malformed_hash_list: Array = []
	for hash_value: Variant in malformed_hashes["hashes"]:
		malformed_hash_list.append(hash_value)
	malformed_hash_list[0] = 7
	malformed_hashes["hashes"] = malformed_hash_list
	var malformed_hash_result: Dictionary = ReplayRunner.verify(
		initial,
		malformed_hashes,
		_make_processor()
	)
	assert_true(
		not malformed_hash_result["ok"],
		"non-string replay hash is rejected"
	)

	var invalid_hash_format: Dictionary = (
		first_recording["replay"].duplicate(true)
	)
	invalid_hash_format["hashes"][0] = "not-a-sha256-hash"
	var invalid_hash_result: Dictionary = ReplayRunner.verify(
		initial,
		invalid_hash_format,
		_make_processor()
	)
	assert_true(
		not invalid_hash_result["ok"],
		"invalid replay hash format is rejected"
	)

	var missing_commands_result: Dictionary = ReplayRunner.verify(
		initial,
		{"hashes": [initial_hash]},
		_make_processor()
	)
	assert_true(
		not missing_commands_result["ok"],
		"missing replay commands are rejected"
	)

	var malformed_command_result: Dictionary = ReplayRunner.record(
		initial,
		[1],
		_make_processor()
	)
	assert_true(
		not malformed_command_result["ok"],
		"non-dictionary command is rejected"
	)

	var noncanonical_result: Dictionary = ReplayRunner.record(
		initial,
		[{
			"sequence": 1,
			"type": "test.advance",
			"payload": {"ticks": 5, "stream_id": "world"},
			"debug_weight": 1.5,
		}],
		_make_processor()
	)
	assert_true(
		not noncanonical_result["ok"],
		"noncanonical command data is rejected"
	)

	var rejected_result: Dictionary = ReplayRunner.record(
		initial,
		[{
			"sequence": 1,
			"type": "test.advance",
			"payload": {"ticks": 0, "stream_id": "world"},
		}],
		_make_processor()
	)
	assert_true(
		not rejected_result["ok"],
		"command rejection aborts recording"
	)
	assert_true(
		str(rejected_result.get("error", "")).contains(
			"ticks must be positive"
		),
		"recording preserves the command rejection reason"
	)

	var cyclic_state: Dictionary = initial.duplicate(true)
	cyclic_state["cycle"] = cyclic_state
	var cyclic_result: Dictionary = ReplayRunner.record(
		cyclic_state,
		[],
		_make_processor()
	)
	assert_true(
		not cyclic_result["ok"],
		"cyclic initial state is rejected before duplication"
	)

	var replay_encoding: Dictionary = CanonicalJson.encode(
		first_recording["replay"]
	)
	assert_true(
		replay_encoding["ok"],
		"recorded replay is canonically encodable"
	)


func _make_processor():
	var processor = CommandProcessor.new()
	var handler = FoundationProbeHandler.new()
	_handler_refs.append(handler)
	handler.install(processor)
	return processor
