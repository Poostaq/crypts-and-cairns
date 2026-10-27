extends "res://tests/support/test_case.gd"

const JsonIntegerNormalizer = preload("res://src/platform/json/json_integer_normalizer.gd")
const CanonicalJson = preload("res://src/domain/determinism/canonical_json.gd")
const StateHasher = preload("res://src/domain/determinism/state_hasher.gd")


func run() -> void:
	var parsed_integer: Variant = JSON.parse_string("{\"value\":42}")
	var normalized_integer: Dictionary = JsonIntegerNormalizer.normalize(parsed_integer)
	assert_true(normalized_integer["ok"], "whole JSON numbers normalize")
	assert_equal(
		typeof(normalized_integer["value"]["value"]),
		TYPE_INT,
		"whole JSON number becomes int"
	)
	assert_true(
		not JsonIntegerNormalizer.normalize(JSON.parse_string("{\"value\":1.5}"))["ok"],
		"fractional JSON number is rejected"
	)

	var encoded: Dictionary = CanonicalJson.encode({
		"z": 2,
		"actors": [
			{"id": "actor.z", "hp": 5},
			{"id": "actor.a", "hp": 7},
		],
		"a": 1,
	})
	assert_true(encoded["ok"], "authoritative primitives encode")
	assert_equal(
		encoded["text"],
		"{\"a\":1,\"actors\":[{\"hp\":7,\"id\":\"actor.a\"},{\"hp\":5,\"id\":\"actor.z\"}],\"z\":2}",
		"maps and entity lists are sorted"
	)

	var ordered_values: Dictionary = CanonicalJson.encode([2, 1])
	assert_equal(ordered_values["text"], "[2,1]", "non-entity arrays preserve semantic order")

	var float_result: Dictionary = CanonicalJson.encode({"chance": 0.5})
	assert_true(not float_result["ok"], "floats are rejected")

	var hash_result: Dictionary = StateHasher.hash_state({})
	assert_equal(
		hash_result["hash"],
		"44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
		"SHA-256 hashes canonical JSON"
	)

	var rounded_fraction: Dictionary = JsonIntegerNormalizer.parse_and_normalize(
		"{\"value\":9007199254740991.1}"
	)
	assert_true(
		not rounded_fraction["ok"],
		"source decimals are rejected before floating-point rounding"
	)
	var exponent_number: Dictionary = JsonIntegerNormalizer.parse_and_normalize(
		"{\"value\":1e3}"
	)
	assert_true(not exponent_number["ok"], "source exponent numbers are rejected")
	var unsafe_integer: Dictionary = JsonIntegerNormalizer.parse_and_normalize(
		"{\"value\":9007199254740992}"
	)
	assert_true(not unsafe_integer["ok"], "unsafe source integers are rejected")
	var safe_bounds: Dictionary = JsonIntegerNormalizer.parse_and_normalize(
		"[9007199254740991,-9007199254740991]"
	)
	assert_true(safe_bounds["ok"], "positive and negative safe bounds are accepted")
	assert_equal(
		safe_bounds["value"],
		[9007199254740991, -9007199254740991],
		"safe source bounds normalize exactly"
	)
	var parse_failure: Dictionary = JsonIntegerNormalizer.parse_and_normalize("{")
	assert_true(
		not parse_failure["ok"] and String(parse_failure["error"]).contains("invalid JSON"),
		"strict parsing returns a structured JSON parse error"
	)
	var duplicate_key: Dictionary = JsonIntegerNormalizer.parse_and_normalize(
		"{\"a\":1,\"a\":2}"
	)
	assert_true(
		not duplicate_key["ok"]
		and String(duplicate_key["error"]).contains("duplicate object key"),
		"authoritative JSON rejects duplicate object keys"
	)
	var escaped_duplicate_key: Dictionary = (
		JsonIntegerNormalizer.parse_and_normalize(
			"{\"a\":1,\"\\u0061\":2}"
		)
	)
	assert_true(
		not escaped_duplicate_key["ok"]
		and String(escaped_duplicate_key["error"]).contains(
			"duplicate object key"
		),
		"escaped-equivalent object keys are duplicates"
	)
	var separately_scoped_keys: Dictionary = (
		JsonIntegerNormalizer.parse_and_normalize(
			"{\"left\":{\"a\":1},\"right\":{\"a\":2}}"
		)
	)
	assert_true(
		separately_scoped_keys["ok"],
		"the same key remains valid in separate nested objects"
	)
	var sentinel_collision: Dictionary = JsonIntegerNormalizer.parse_and_normalize(
		"{\"__crypts_internal_json_integer__\":\"1.5e3\",\"value\":2}"
	)
	assert_true(sentinel_collision["ok"], "internal integer wrappers avoid source-key collisions")
	assert_equal(
		sentinel_collision["value"],
		{"__crypts_internal_json_integer__": "1.5e3", "value": 2},
		"numeric-looking strings remain unchanged"
	)

	var nan_result: Dictionary = JsonIntegerNormalizer.normalize(NAN)
	var infinity_result: Dictionary = JsonIntegerNormalizer.normalize(INF)
	assert_true(not nan_result["ok"], "NaN is rejected")
	assert_true(not infinity_result["ok"], "infinity is rejected")

	var nested_input: Dictionary = {"items": [{"value": 42.0}]}
	var nested_result: Dictionary = JsonIntegerNormalizer.normalize(nested_input)
	assert_equal(
		typeof(nested_result["value"]["items"][0]["value"]),
		TYPE_INT,
		"nested whole floats normalize to integers"
	)
	nested_result["value"]["items"][0]["value"] = 7
	assert_equal(
		nested_input["items"][0]["value"],
		42.0,
		"normalization detaches nested containers from its input"
	)

	var non_string_key: Dictionary = {1: "value"}
	assert_true(
		not JsonIntegerNormalizer.normalize(non_string_key)["ok"],
		"normalization rejects non-string dictionary keys"
	)
	assert_true(
		not CanonicalJson.encode(non_string_key)["ok"],
		"canonical encoding rejects non-string dictionary keys"
	)
	assert_true(
		not JsonIntegerNormalizer.normalize(Vector2.ZERO)["ok"],
		"normalization rejects unsupported values"
	)
	assert_true(
		not CanonicalJson.encode(Vector2.ZERO)["ok"],
		"canonical encoding rejects unsupported values"
	)

	var escaped_string: Dictionary = CanonicalJson.encode("line\n\"quoted\"\\tail")
	assert_equal(
		escaped_string["text"],
		"\"line\\n\\\"quoted\\\"\\\\tail\"",
		"strings use JSON escaping"
	)

	var duplicate_ids: Dictionary = CanonicalJson.encode([
		{"id": "actor.a"},
		{"id": "actor.a"},
	])
	assert_true(not duplicate_ids["ok"], "duplicate entity ids are rejected")
	var missing_id: Dictionary = CanonicalJson.encode([
		{"id": "actor.a"},
		{"hp": 5},
	])
	assert_equal(
		missing_id["text"],
		"[{\"id\":\"actor.a\"},{\"hp\":5}]",
		"dictionary arrays with missing ids preserve semantic order"
	)
	var non_string_id: Dictionary = CanonicalJson.encode([
		{"id": "actor.a"},
		{"id": 2},
	])
	assert_equal(
		non_string_id["text"],
		"[{\"id\":\"actor.a\"},{\"id\":2}]",
		"dictionary arrays with non-string ids preserve semantic order"
	)
	var idless_dictionary_list: Dictionary = CanonicalJson.encode([
		{"z": 2},
		{"a": 1},
	])
	assert_equal(
		idless_dictionary_list["text"],
		"[{\"z\":2},{\"a\":1}]",
		"all-dictionary lists without ids preserve semantic order"
	)

	var escaped_path_error: Dictionary = CanonicalJson.encode({"a/b~c": 0.5})
	assert_true(
		String(escaped_path_error["error"]).contains("$/a~1b~0c"),
		"canonical error paths escape pointer-like segments"
	)
	var entity_path_error: Dictionary = CanonicalJson.encode([
		{"id": "actor/z~q", "chance": 0.5},
	])
	assert_true(
		String(entity_path_error["error"]).contains("$/@actor~1z~0q/chance"),
		"entity child errors identify the stable id"
	)

	var cyclic_array: Array = []
	cyclic_array.append(cyclic_array)
	var normalized_cycle: Dictionary = JsonIntegerNormalizer.normalize(cyclic_array)
	var encoded_cycle: Dictionary = CanonicalJson.encode(cyclic_array)
	assert_true(
		not normalized_cycle["ok"] and normalized_cycle.has("error"),
		"normalization rejects cyclic containers with a structured error"
	)
	assert_true(
		not encoded_cycle["ok"] and encoded_cycle.has("error"),
		"canonical encoding rejects cyclic containers with a structured error"
	)

	var too_deep: Array = _make_nested_array(65)
	assert_true(
		not JsonIntegerNormalizer.normalize(too_deep)["ok"],
		"normalization rejects excessive nesting"
	)
	assert_true(
		not CanonicalJson.encode(too_deep)["ok"],
		"canonical encoding rejects excessive nesting"
	)

	var shared_dictionary: Dictionary = {"value": 1}
	var shared_array: Array = [shared_dictionary, shared_dictionary]
	assert_true(
		JsonIntegerNormalizer.normalize(shared_array)["ok"],
		"normalization allows shared acyclic references"
	)
	assert_true(
		CanonicalJson.encode(shared_array)["ok"],
		"canonical encoding allows shared acyclic references"
	)

	var reordered_encoded: Dictionary = CanonicalJson.encode({
		"actors": [
			{"hp": 7, "id": "actor.a"},
			{"hp": 5, "id": "actor.z"},
		],
		"a": 1,
		"z": 2,
	})
	assert_equal(
		reordered_encoded["text"],
		encoded["text"],
		"canonical text is invariant under map and entity-list reordering"
	)
	var reordered_hash: Dictionary = StateHasher.hash_state({
		"actors": [
			{"hp": 7, "id": "actor.a"},
			{"hp": 5, "id": "actor.z"},
		],
		"a": 1,
		"z": 2,
	})
	var original_hash: Dictionary = StateHasher.hash_state({
		"z": 2,
		"actors": [
			{"id": "actor.z", "hp": 5},
			{"id": "actor.a", "hp": 7},
		],
		"a": 1,
	})
	assert_equal(
		reordered_hash["hash"],
		original_hash["hash"],
		"state hashes are invariant under canonical reordering"
	)

	var float_hash: Dictionary = StateHasher.hash_state({"chance": 0.5})
	assert_true(
		not float_hash["ok"] and String(float_hash["error"]).contains("$/chance"),
		"state hashing propagates canonical float errors"
	)


func _make_nested_array(depth: int) -> Array:
	var root: Array = []
	var cursor: Array = root
	for _index: int in range(depth):
		var child: Array = []
		cursor.append(child)
		cursor = child
	return root
