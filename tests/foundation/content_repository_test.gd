extends "res://tests/support/test_case.gd"

const JsonContentRepository = preload(
	"res://src/platform/content/json_content_repository.gd"
)

const FOUNDATION_MANIFEST: String = "res://content/manifest.json"
const REORDERED_MANIFEST: String = (
	"res://tests/fixtures/content_repository/reordered_manifest.json"
)


func run() -> void:
	var first: Dictionary = JsonContentRepository.load_catalog(
		FOUNDATION_MANIFEST
	)
	var second: Dictionary = JsonContentRepository.load_catalog(
		FOUNDATION_MANIFEST
	)
	assert_true(first["ok"], "foundation catalog loads")
	assert_true(second["ok"], "foundation catalog loads repeatedly")
	if not first["ok"] or not second["ok"]:
		return

	var definitions: Dictionary = first["catalog"]["definitions"]
	assert_equal(
		_definition_ids(definitions["class"]),
		[
			"class.berserker",
			"class.fighter",
			"class.hunter",
			"class.knight",
			"class.mage",
			"class.paladin",
			"class.rogue",
		],
		"seven approved reusable classes load"
	)
	assert_equal(
		_definition_ids(definitions["people"]),
		[
			"people.beastkin",
			"people.dwarf",
			"people.elf",
			"people.human",
			"people.titanborn",
			"people.tribal",
		],
		"six approved peoples load"
	)

	var combinations: int = 0
	for people_value: Variant in definitions["people"]:
		var people: Dictionary = people_value
		combinations += people["allowed_class_ids"].size()
	assert_equal(
		combinations,
		15,
		"exactly fifteen lore-locked people and class combinations load"
	)
	var class_matrix: Dictionary = {}
	for people_value: Variant in definitions["people"]:
		var people: Dictionary = people_value
		class_matrix[people["id"]] = people["allowed_class_ids"].duplicate()
	assert_equal(
		class_matrix,
		{
			"people.beastkin": ["class.hunter", "class.rogue"],
			"people.dwarf": ["class.fighter", "class.knight"],
			"people.elf": ["class.hunter", "class.mage"],
			"people.human": [
				"class.fighter",
				"class.knight",
				"class.mage",
				"class.rogue",
			],
			"people.titanborn": [
				"class.knight",
				"class.paladin",
				"class.mage",
			],
			"people.tribal": ["class.fighter", "class.berserker"],
		},
		"all lore-locked people and class mappings are exact"
	)

	var titanborn: Dictionary = _find_definition(
		definitions["people"],
		"people.titanborn"
	)
	assert_true(not titanborn.is_empty(), "Titanborn definition loads")
	if not titanborn.is_empty():
		assert_equal(
			titanborn["allowed_class_ids"],
			["class.knight", "class.paladin", "class.mage"],
			"Titanborn include mage in their traditional classes"
		)

	var localization: Dictionary = first["catalog"]["localization"]
	assert_equal(
		localization.size(),
		13,
		"every foundation definition has English localization"
	)
	assert_equal(
		localization["people.tribal.name"],
		"Tribal People",
		"approved Tribal People display name loads"
	)
	assert_equal(
		first["content_hash"].length(),
		64,
		"catalog has a SHA-256 hash"
	)
	assert_equal(
		first["content_hash"],
		second["content_hash"],
		"catalog hash is stable across independent loads"
	)

	var reordered: Dictionary = JsonContentRepository.load_catalog(
		REORDERED_MANIFEST
	)
	assert_true(reordered["ok"], "reordered manifest loads")
	if reordered["ok"]:
		assert_equal(
			reordered["content_hash"],
			first["content_hash"],
			"manifest entry order does not change the content hash"
		)
		assert_equal(
			reordered["catalog"],
			first["catalog"],
			"manifest entry order does not change catalog structure"
		)

	first["catalog"]["definitions"]["class"][0]["id"] = "class.changed"
	var after_mutation: Dictionary = JsonContentRepository.load_catalog(
		FOUNDATION_MANIFEST
	)
	assert_true(after_mutation["ok"], "catalog reloads after caller mutation")
	if after_mutation["ok"]:
		assert_equal(
			after_mutation["content_hash"],
			second["content_hash"],
			"caller mutation cannot contaminate later repository loads"
		)

	_assert_failure_contains(
		JsonContentRepository.load_catalog(
			"res://tests/fixtures/content_repository/missing.json"
		),
		"content file not found",
		"missing manifests fail safely"
	)
	_assert_failure_contains(
		JsonContentRepository.load_catalog(
			"res://tests/fixtures/content_repository/invalid_root_manifest.json"
		),
		"manifest root must be a dictionary",
		"manifest root must be a dictionary"
	)
	_assert_failure_contains(
		JsonContentRepository.load_catalog(
			"res://tests/fixtures/content_repository/invalid_number_manifest.json"
		),
		"optional-minus decimal integer",
		"authoritative JSON rejects decimal number syntax"
	)
	_assert_failure_contains(
		JsonContentRepository.load_catalog(
			"res://tests/fixtures/content_repository/invalid_path_manifest.json"
		),
		"canonical res:// JSON path",
		"manifest entries cannot escape packaged resources"
	)
	_assert_failure_contains(
		JsonContentRepository.load_catalog(
			"res://tests/fixtures/content_repository/duplicate_definition_manifest.json"
		),
		"duplicate definition family class",
		"duplicate definition families fail"
	)
	_assert_failure_contains(
		JsonContentRepository.load_catalog(
			"res://tests/fixtures/content_repository/duplicate_localization_manifest.json"
		),
		"duplicate localization key class.fighter.name",
		"duplicate localization keys fail"
	)
	_assert_failure_contains(
		JsonContentRepository.load_catalog(
			"res://tests/fixtures/content_repository/duplicate_keys_localization_manifest.json"
		),
		"duplicate object key",
		"duplicate localization keys inside one JSON file fail"
	)


func _definition_ids(definitions: Array) -> Array[String]:
	var ids: Array[String] = []
	for definition_value: Variant in definitions:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		if typeof(definition.get("id")) == TYPE_STRING:
			ids.append(definition["id"])
	return ids


func _find_definition(definitions: Array, definition_id: String) -> Dictionary:
	for definition_value: Variant in definitions:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		if definition.get("id") == definition_id:
			return definition
	return {}


func _assert_failure_contains(
	result: Dictionary,
	fragment: String,
	message: String
) -> void:
	assert_true(
		not result.get("ok", false)
		and str(result.get("error", "")).contains(fragment),
		message
	)
