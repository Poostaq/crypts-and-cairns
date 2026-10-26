extends "res://tests/support/test_case.gd"

const GameStateFactory = preload("res://src/domain/state/game_state_factory.gd")

func run() -> void:
	var created := GameStateFactory.create(12345, "content-hash", "0.1.0-test")
	assert_true(created["ok"], "valid campaign state is created")
	var state: Dictionary = created["state"]
	assert_equal(state["meta"]["build_version"], "0.1.0-test", "build version is recorded")
	assert_equal(state["meta"]["save_schema_version"], 1, "save schema is recorded")
	assert_equal(state["meta"]["content_schema_version"], 1, "content schema is recorded")
	assert_equal(state["meta"]["rng_algorithm_version"], "pcg32-v1", "RNG version is recorded")
	assert_equal(state["meta"]["content_hash"], "content-hash", "content hash is recorded")
	assert_equal(state["campaign"]["seed"], 12345, "campaign seed is recorded")
	assert_equal(state["campaign"]["command_sequence"], 0, "sequence starts at zero")
	assert_equal(state["campaign"]["elapsed_ticks"], 0, "clock starts at zero")
	assert_equal(state["rng"]["streams"], {}, "RNG streams start empty")
	assert_equal(state["entities"], [], "entities start empty")

	var rejected := GameStateFactory.create(-1, "content-hash", "0.1.0-test")
	assert_equal(
		rejected,
		{"ok": false, "error": "campaign seed must be nonnegative"},
		"negative campaign seed returns the expected error"
	)

	var empty_hash := GameStateFactory.create(12345, "", "0.1.0-test")
	assert_equal(
		empty_hash,
		{"ok": false, "error": "content hash is required"},
		"empty content hash returns the expected error"
	)

	var defaulted := GameStateFactory.create(67890, "second-content-hash")
	assert_true(defaulted["ok"], "state is created with the project build version")
	var defaulted_state: Dictionary = defaulted["state"]
	assert_equal(
		defaulted_state["meta"]["build_version"],
		"0.1.0-dev",
		"omitted build version falls back to project configuration"
	)

	var first_entities: Array = state["entities"]
	var first_streams: Dictionary = state["rng"]["streams"]
	first_entities.append({"id": "mutated"})
	first_streams["combat"] = {"state": 1}
	assert_equal(defaulted_state["entities"], [], "campaign states do not share entity arrays")
	assert_equal(
		defaulted_state["rng"]["streams"],
		{},
		"campaign states do not share RNG stream dictionaries"
	)
