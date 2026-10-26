class_name ContentValidator
extends RefCounted

const VersionInfoScript = preload("res://src/domain/version_info.gd")
const MAX_NESTING_DEPTH: int = 64


static func validate(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema_version: Variant = catalog.get("content_schema_version")
	if (
		typeof(schema_version) != TYPE_INT
		or schema_version != VersionInfoScript.CONTENT_SCHEMA_VERSION
	):
		errors.append("content schema version does not match runtime")

	var ancestors: Array = []
	_validate_value_tree(catalog, "$", ancestors, 0, errors)

	var definitions_value: Variant = catalog.get("definitions")
	var localization_value: Variant = catalog.get("localization")
	if typeof(definitions_value) != TYPE_DICTIONARY:
		errors.append("definitions must be a dictionary")
	if typeof(localization_value) != TYPE_DICTIONARY:
		errors.append("localization must be a dictionary")
	if (
		typeof(definitions_value) != TYPE_DICTIONARY
		or typeof(localization_value) != TYPE_DICTIONARY
	):
		errors.sort()
		return errors

	var definitions: Dictionary = definitions_value
	var localization: Dictionary = localization_value
	_validate_localization(localization, errors)

	var ids: Dictionary = {}
	_validate_definition_families(
		definitions,
		localization,
		ids,
		errors
	)
	_validate_people_references(definitions, errors)

	errors.sort()
	return errors


static func _validate_localization(
	localization: Dictionary,
	errors: Array[String]
) -> void:
	var keys: Array[String] = _string_keys(localization)
	keys.sort()
	for key: String in keys:
		if typeof(localization[key]) != TYPE_STRING:
			errors.append(
				"localization value %s must be a string" % key
			)


static func _validate_definition_families(
	definitions: Dictionary,
	localization: Dictionary,
	ids: Dictionary,
	errors: Array[String]
) -> void:
	var families: Array[String] = _string_keys(definitions)
	families.sort()
	for family: String in families:
		if not _is_valid_segment(family):
			errors.append("invalid definition family %s" % family)

		var family_value: Variant = definitions[family]
		if typeof(family_value) != TYPE_ARRAY:
			errors.append(
				"definition family %s must be an array" % family
			)
			continue

		var family_definitions: Array = family_value
		for index: int in range(family_definitions.size()):
			_validate_definition(
				family,
				index,
				family_definitions[index],
				localization,
				ids,
				errors
			)


static func _validate_definition(
	family: String,
	index: int,
	definition_value: Variant,
	localization: Dictionary,
	ids: Dictionary,
	errors: Array[String]
) -> void:
	if typeof(definition_value) != TYPE_DICTIONARY:
		errors.append(
			"definition in %s at index %d must be a dictionary" %
				[family, index]
		)
		return

	var definition: Dictionary = definition_value
	var id_value: Variant = definition.get("id")
	if typeof(id_value) != TYPE_STRING:
		errors.append(
			"definition in %s at index %d requires a string id" %
				[family, index]
		)
		return

	var definition_id: String = id_value
	if (
		not _is_valid_definition_id(definition_id)
		or not definition_id.begins_with("%s." % family)
	):
		errors.append(
			"invalid %s definition id %s" %
				[family, definition_id]
		)
	if ids.has(definition_id):
		errors.append("duplicate definition id %s" % definition_id)
	ids[definition_id] = true

	var display_key_value: Variant = definition.get("display_name_key")
	if typeof(display_key_value) != TYPE_STRING:
		errors.append(
			"%s requires a string display_name_key" % definition_id
		)
		return

	var display_key: String = display_key_value
	if display_key.is_empty():
		errors.append(
			"%s requires a nonempty display_name_key" % definition_id
		)
		return
	if not localization.has(display_key):
		errors.append(
			"%s has missing localization key %s" %
				[definition_id, display_key]
		)


static func _validate_people_references(
	definitions: Dictionary,
	errors: Array[String]
) -> void:
	var class_ids: Dictionary = {}
	var class_value: Variant = definitions.get("class", [])
	if typeof(class_value) == TYPE_ARRAY:
		var class_definitions: Array = class_value
		for definition_value: Variant in class_definitions:
			if typeof(definition_value) != TYPE_DICTIONARY:
				continue
			var definition: Dictionary = definition_value
			var class_id_value: Variant = definition.get("id")
			if typeof(class_id_value) != TYPE_STRING:
				continue
			var class_id: String = class_id_value
			if (
				_is_valid_definition_id(class_id)
				and class_id.begins_with("class.")
			):
				class_ids[class_id] = true

	var people_value: Variant = definitions.get("people", [])
	if typeof(people_value) != TYPE_ARRAY:
		return
	var people_definitions: Array = people_value
	for index: int in range(people_definitions.size()):
		var definition_value: Variant = people_definitions[index]
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		var people_label: String = "people[%d]" % index
		if typeof(definition.get("id")) == TYPE_STRING:
			people_label = definition["id"]

		var allowed_value: Variant = definition.get("allowed_class_ids")
		if typeof(allowed_value) != TYPE_ARRAY:
			errors.append(
				"%s requires allowed_class_ids array" % people_label
			)
			continue

		var seen_allowed: Dictionary = {}
		var allowed_class_ids: Array = allowed_value
		for class_id_value: Variant in allowed_class_ids:
			if typeof(class_id_value) != TYPE_STRING:
				errors.append(
					"%s contains a non-string class id" % people_label
				)
				continue

			var class_id: String = class_id_value
			if not class_ids.has(class_id):
				errors.append(
					"%s references unknown class id %s" %
						[people_label, class_id]
				)
			if seen_allowed.has(class_id):
				errors.append(
					"%s repeats allowed class id %s" %
						[people_label, class_id]
				)
			seen_allowed[class_id] = true


static func _validate_value_tree(
	value: Variant,
	path: String,
	ancestors: Array,
	depth: int,
	errors: Array[String]
) -> void:
	if depth > MAX_NESTING_DEPTH:
		errors.append(
			"%s exceeds maximum nesting depth %d" %
				[path, MAX_NESTING_DEPTH]
		)
		return

	var value_type: int = typeof(value)
	match value_type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return
		TYPE_FLOAT:
			errors.append("%s contains a float" % path)
		TYPE_ARRAY:
			if _contains_identity(ancestors, value):
				errors.append(
					"%s contains a cyclic container reference" % path
				)
				return
			ancestors.append(value)
			var array_value: Array = value
			for index: int in range(array_value.size()):
				_validate_value_tree(
					array_value[index],
					_path_child(path, str(index)),
					ancestors,
					depth + 1,
					errors
				)
			ancestors.pop_back()
		TYPE_DICTIONARY:
			if _contains_identity(ancestors, value):
				errors.append(
					"%s contains a cyclic container reference" % path
				)
				return
			ancestors.append(value)
			var dictionary_value: Dictionary = value
			var keys: Array[String] = []
			var has_non_string_key: bool = false
			for raw_key: Variant in dictionary_value.keys():
				if typeof(raw_key) != TYPE_STRING:
					has_non_string_key = true
				else:
					keys.append(raw_key)
			if has_non_string_key:
				errors.append(
					"%s contains a non-string dictionary key" % path
				)
			keys.sort()
			for key: String in keys:
				_validate_value_tree(
					dictionary_value[key],
					_path_child(path, key),
					ancestors,
					depth + 1,
					errors
				)
			ancestors.pop_back()
		_:
			errors.append(
				"%s contains unsupported type %s" %
					[path, type_string(value_type)]
			)


static func _string_keys(values: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for raw_key: Variant in values.keys():
		if typeof(raw_key) == TYPE_STRING:
			keys.append(raw_key)
	return keys


static func _is_valid_definition_id(definition_id: String) -> bool:
	var segments: PackedStringArray = definition_id.split(".", true)
	if segments.size() < 2:
		return false
	for segment: String in segments:
		if not _is_valid_segment(segment):
			return false
	return true


static func _is_valid_segment(segment: String) -> bool:
	if segment.is_empty():
		return false
	var first_code: int = segment.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index: int in range(1, segment.length()):
		var code: int = segment.unicode_at(index)
		var is_lowercase: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		if not is_lowercase and not is_digit and code != 95:
			return false
	return true


static func _contains_identity(ancestors: Array, value: Variant) -> bool:
	for ancestor: Variant in ancestors:
		if is_same(ancestor, value):
			return true
	return false


static func _path_child(path: String, segment: String) -> String:
	return "%s/%s" % [
		path,
		segment.replace("~", "~0").replace("/", "~1"),
	]
