extends "res://tests/support/test_case.gd"

const GameStateFactory = preload("res://src/domain/state/game_state_factory.gd")
const RngStreams = preload("res://src/domain/determinism/rng_streams.gd")
const StreamSeeds = preload("res://src/domain/determinism/stream_seeds.gd")


func run() -> void:
	assert_equal(
		StreamSeeds.derive(91234, "loot:state"),
		2073785943294940656,
		"loot state seed derivation is stable"
	)
	assert_equal(
		StreamSeeds.derive(91234, "loot:sequence"),
		4273210760808627495,
		"loot sequence seed derivation is stable"
	)

	var golden_state: Dictionary = GameStateFactory.create(
		91234,
		"content",
		"test"
	)["state"]
	var golden_values: Array[int] = [
		1216047251,
		1362522818,
		688219308,
		1562967762,
	]
	for index: int in range(golden_values.size()):
		var golden_draw: Dictionary = RngStreams.next_u32(golden_state, "loot")
		assert_true(golden_draw["ok"], "golden loot draw %d succeeds" % index)
		assert_equal(
			golden_draw["value"],
			golden_values[index],
			"golden loot draw %d is stable" % index
		)

	var combat_first_state: Dictionary = GameStateFactory.create(
		91234,
		"content",
		"test"
	)["state"]
	var untouched_state: Dictionary = GameStateFactory.create(
		91234,
		"content",
		"test"
	)["state"]

	var combat_draw: Dictionary = RngStreams.next_u32(combat_first_state, "combat")
	var combat_first_loot: Dictionary = RngStreams.next_u32(combat_first_state, "loot")
	var untouched_loot: Dictionary = RngStreams.next_u32(untouched_state, "loot")

	assert_true(combat_draw["ok"], "combat draw succeeds")
	assert_true(combat_first_loot["ok"], "loot draw after combat succeeds")
	assert_true(untouched_loot["ok"], "untouched loot draw succeeds")
	assert_equal(
		combat_first_loot["value"],
		untouched_loot["value"],
		"loot is independent of combat consumption"
	)
	assert_true(
		combat_first_state["rng"]["streams"].has("loot"),
		"loot stream snapshot is serialized"
	)
	assert_true(
		combat_first_state["rng"]["streams"].has("combat"),
		"combat stream snapshot is serialized"
	)
	assert_true(
		untouched_state["rng"]["streams"].has("loot"),
		"untouched loot stream snapshot is serialized"
	)

	var persistent_state: Dictionary = GameStateFactory.create(
		91234,
		"content",
		"test"
	)["state"]
	var persisted_first: Dictionary = RngStreams.next_u32(persistent_state, "loot")
	var copied_state: Dictionary = persistent_state.duplicate(true)
	var persisted_original_next: Dictionary = RngStreams.next_u32(
		persistent_state,
		"loot"
	)
	var persisted_copy_next: Dictionary = RngStreams.next_u32(copied_state, "loot")
	assert_true(persisted_first["ok"], "loot draw before persistence succeeds")
	assert_true(persisted_original_next["ok"], "original state resumes loot stream")
	assert_true(persisted_copy_next["ok"], "copied state resumes loot stream")
	assert_equal(
		persisted_original_next["value"],
		persisted_copy_next["value"],
		"serialized loot snapshot resumes deterministically"
	)

	var negative_seed_state: Dictionary = GameStateFactory.create(
		91234,
		"content",
		"test"
	)["state"]
	negative_seed_state["campaign"]["seed"] = -1
	var negative_streams_before: Dictionary = negative_seed_state["rng"]["streams"].duplicate(
		true
	)
	var negative_seed_draw: Dictionary = RngStreams.next_u32(
		negative_seed_state,
		"loot"
	)
	assert_true(not negative_seed_draw["ok"], "negative campaign seed is rejected")
	assert_equal(
		negative_seed_state["rng"]["streams"],
		negative_streams_before,
		"negative campaign seed leaves streams unchanged"
	)

	var invalid_cases: Array[Dictionary] = [
		{"name": "missing campaign", "state": {"rng": {"streams": {}}}},
		{"name": "non-dictionary campaign", "state": {"campaign": [], "rng": {"streams": {}}}},
		{"name": "missing campaign seed", "state": {"campaign": {}, "rng": {"streams": {}}}},
		{
			"name": "non-integer campaign seed",
			"state": {"campaign": {"seed": "91234"}, "rng": {"streams": {}}},
		},
		{"name": "missing RNG root", "state": {"campaign": {"seed": 91234}}},
		{"name": "non-dictionary RNG root", "state": {"campaign": {"seed": 91234}, "rng": []}},
		{"name": "missing streams root", "state": {"campaign": {"seed": 91234}, "rng": {}}},
		{
			"name": "non-dictionary streams root",
			"state": {"campaign": {"seed": 91234}, "rng": {"streams": []}},
		},
		{
			"name": "even-increment snapshot",
			"state": {
				"campaign": {"seed": 91234},
				"rng": {"streams": {"loot": {"state": 1, "increment": 2}}},
			},
		},
		{
			"name": "non-dictionary snapshot",
			"state": {
				"campaign": {"seed": 91234},
				"rng": {"streams": {"loot": "corrupt"}},
			},
		},
	]
	for invalid_case: Dictionary in invalid_cases:
		var case_name: String = invalid_case["name"]
		var invalid_state: Dictionary = invalid_case["state"]
		var invalid_before: Dictionary = invalid_state.duplicate(true)
		var invalid_draw: Dictionary = RngStreams.next_u32(invalid_state, "loot")
		assert_true(not invalid_draw["ok"], "%s is rejected" % case_name)
		assert_equal(
			invalid_state,
			invalid_before,
			"%s leaves state unchanged" % case_name
		)

	var empty_id_state: Dictionary = GameStateFactory.create(
		91234,
		"content",
		"test"
	)["state"]
	var empty_id_before: Dictionary = empty_id_state.duplicate(true)
	var empty_id_draw: Dictionary = RngStreams.next_u32(empty_id_state, "")
	assert_true(
		not empty_id_draw["ok"],
		"empty stream ID is rejected"
	)
	assert_equal(
		empty_id_state,
		empty_id_before,
		"empty stream ID leaves state unchanged"
	)
