extends "res://tests/support/test_case.gd"

const ContentValidator = preload(
	"res://src/domain/content/content_validator.gd"
)


func run() -> void:
	var valid_catalog: Dictionary = _valid_catalog()
	assert_equal(
		ContentValidator.validate(valid_catalog),
		[],
		"valid catalog passes"
	)

	var invalid_catalog: Dictionary = valid_catalog.duplicate(true)
	invalid_catalog["definitions"]["class"].append({
		"id": "class.fighter",
		"display_name_key": "class.missing.name",
		"weight": 1.5,
	})
	invalid_catalog["definitions"]["people"][0]["allowed_class_ids"] = [
		"class.unknown",
	]
	var invalid_errors: Array[String] = ContentValidator.validate(
		invalid_catalog
	)
	assert_true(
		_contains_error(invalid_errors, "duplicate definition id"),
		"duplicate IDs fail"
	)
	assert_true(
		_contains_error(invalid_errors, "contains a float"),
		"floats fail"
	)
	assert_true(
		_contains_error(invalid_errors, "missing localization key"),
		"missing localization fails"
	)
	assert_true(
		_contains_error(invalid_errors, "unknown class id"),
		"unknown class reference fails"
	)

	var float_schema: Dictionary = _valid_catalog()
	float_schema["content_schema_version"] = 1.0
	var float_schema_errors: Array[String] = ContentValidator.validate(
		float_schema
	)
	assert_true(
		_contains_error(
			float_schema_errors,
			"content schema version does not match runtime"
		),
		"schema version must be an exact integer"
	)
	assert_true(
		_contains_error(float_schema_errors, "contains a float"),
		"schema floats also violate the authoritative numeric policy"
	)

	var missing_roots: Dictionary = {"content_schema_version": 1}
	var missing_root_errors: Array[String] = ContentValidator.validate(
		missing_roots
	)
	assert_true(
		_contains_error(
			missing_root_errors,
			"definitions must be a dictionary"
		),
		"definitions root is required"
	)
	assert_true(
		_contains_error(
			missing_root_errors,
			"localization must be a dictionary"
		),
		"localization root is required"
	)

	var malformed_values: Dictionary = _valid_catalog()
	malformed_values["definitions"]["item"] = "not-an-array"
	malformed_values["localization"]["class.fighter.name"] = 7
	malformed_values["metadata"] = {
		1: "bad key",
		"vector": Vector2.ZERO,
	}
	var malformed_errors: Array[String] = ContentValidator.validate(
		malformed_values
	)
	assert_true(
		_contains_error(
			malformed_errors,
			"definition family item must be an array"
		),
		"definition families must be arrays"
	)
	assert_true(
		_contains_error(
			malformed_errors,
			"localization value class.fighter.name must be a string"
		),
		"all localization values must be strings"
	)
	assert_true(
		_contains_error(
			malformed_errors,
			"contains a non-string dictionary key"
		),
		"authoritative dictionary keys must be strings"
	)
	assert_true(
		_contains_error(malformed_errors, "contains unsupported type"),
		"engine-only values are rejected"
	)

	var reference_catalog: Dictionary = _valid_catalog()
	reference_catalog["definitions"]["class"].append({
		"id": "people.crossed",
		"display_name_key": "class.crossed.name",
	})
	reference_catalog["localization"]["class.crossed.name"] = "Crossed"
	reference_catalog["definitions"]["people"][0]["allowed_class_ids"] = [
		"class.fighter",
		"class.fighter",
		7,
		"class.unknown",
		"people.crossed",
	]
	var reference_errors: Array[String] = ContentValidator.validate(
		reference_catalog
	)
	assert_true(
		_contains_error(
			reference_errors,
			"invalid class definition id people.crossed"
		),
		"definition IDs must match their family prefix"
	)
	assert_true(
		_contains_error(
			reference_errors,
			"repeats allowed class id class.fighter"
		),
		"allowed class references must be unique"
	)
	assert_true(
		_contains_error(
			reference_errors,
			"contains a non-string class id"
		),
		"allowed class references must be strings"
	)
	assert_true(
		_contains_error(
			reference_errors,
			"references unknown class id class.unknown"
		),
		"allowed class references must resolve"
	)
	assert_true(
		_contains_error(
			reference_errors,
			"references unknown class id people.crossed"
		),
		"invalid class-family IDs cannot satisfy class references"
	)

	var cyclic_catalog: Dictionary = _valid_catalog()
	var cyclic_metadata: Dictionary = {}
	cyclic_metadata["self"] = cyclic_metadata
	cyclic_catalog["metadata"] = cyclic_metadata
	assert_true(
		_contains_error(
			ContentValidator.validate(cyclic_catalog),
			"contains a cyclic container reference"
		),
		"cyclic content is rejected without recursing forever"
	)

	var deep_catalog: Dictionary = _valid_catalog()
	deep_catalog["metadata"] = _nested_dictionary(66)
	assert_true(
		_contains_error(
			ContentValidator.validate(deep_catalog),
			"exceeds maximum nesting depth"
		),
		"excessive nesting is rejected safely"
	)

	var deterministic_a: Dictionary = _valid_catalog()
	deterministic_a["definitions"]["zeta"] = "bad"
	deterministic_a["definitions"]["alpha"] = [{
		"id": "wrong.prefix",
		"display_name_key": "missing.name",
	}]
	var deterministic_b: Dictionary = deterministic_a.duplicate(true)
	var source_definitions: Dictionary = deterministic_b["definitions"]
	deterministic_b["definitions"] = {
		"zeta": source_definitions["zeta"],
		"people": source_definitions["people"],
		"class": source_definitions["class"],
		"alpha": source_definitions["alpha"],
	}
	assert_equal(
		ContentValidator.validate(deterministic_a),
		ContentValidator.validate(deterministic_b),
		"validation errors do not depend on dictionary insertion order"
	)


func _valid_catalog() -> Dictionary:
	return {
		"content_schema_version": 1,
		"definitions": {
			"class": [{
				"id": "class.fighter",
				"display_name_key": "class.fighter.name",
			}],
			"people": [{
				"id": "people.human",
				"display_name_key": "people.human.name",
				"allowed_class_ids": ["class.fighter"],
			}],
		},
		"localization": {
			"class.fighter.name": "Fighter",
			"people.human.name": "Humans",
		},
	}


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func _nested_dictionary(depth: int) -> Dictionary:
	var root: Dictionary = {}
	var cursor: Dictionary = root
	for _index: int in range(depth):
		var child: Dictionary = {}
		cursor["child"] = child
		cursor = child
	return root
