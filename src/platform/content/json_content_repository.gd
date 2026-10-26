class_name JsonContentRepository
extends RefCounted

const ContentValidatorScript = preload(
	"res://src/domain/content/content_validator.gd"
)
const JsonIntegerNormalizerScript = preload(
	"res://src/platform/json/json_integer_normalizer.gd"
)
const StateHasherScript = preload(
	"res://src/domain/determinism/state_hasher.gd"
)


static func load_catalog(manifest_path: String) -> Dictionary:
	if not _is_resource_json_path(manifest_path):
		return _error(
			"manifest path must be a canonical res:// JSON path"
		)

	var manifest_result: Dictionary = _read_json(manifest_path)
	if not manifest_result["ok"]:
		return manifest_result
	if typeof(manifest_result["value"]) != TYPE_DICTIONARY:
		return _error("manifest root must be a dictionary")
	var manifest: Dictionary = manifest_result["value"]

	var definition_files_value: Variant = manifest.get("definition_files")
	if typeof(definition_files_value) != TYPE_ARRAY:
		return _error("manifest definition_files must be an array")
	var localization_files_value: Variant = manifest.get(
		"localization_files"
	)
	if typeof(localization_files_value) != TYPE_ARRAY:
		return _error("manifest localization_files must be an array")

	var definition_files_result: Dictionary = (
		_validate_definition_files(definition_files_value)
	)
	if not definition_files_result["ok"]:
		return definition_files_result
	var localization_files_result: Dictionary = (
		_validate_localization_files(localization_files_value)
	)
	if not localization_files_result["ok"]:
		return localization_files_result

	var definitions_result: Dictionary = _load_definitions(
		definition_files_result["value"]
	)
	if not definitions_result["ok"]:
		return definitions_result
	var localization_result: Dictionary = _load_localization(
		localization_files_result["value"]
	)
	if not localization_result["ok"]:
		return localization_result

	var catalog: Dictionary = {
		"content_schema_version": manifest.get("content_schema_version"),
		"definitions": definitions_result["value"],
		"localization": localization_result["value"],
	}
	var validation_errors: Array[String] = (
		ContentValidatorScript.validate(catalog)
	)
	if not validation_errors.is_empty():
		return _error(" | ".join(validation_errors))

	var hash_result: Dictionary = StateHasherScript.hash_state(catalog)
	if not hash_result["ok"]:
		return _error(
			"catalog cannot be hashed: %s" %
				str(hash_result.get("error", "encoding failed"))
		)
	return {
		"ok": true,
		"catalog": catalog,
		"content_hash": hash_result["hash"],
	}


static func _validate_definition_files(value: Array) -> Dictionary:
	var files: Array = []
	var seen_families: Dictionary = {}
	var seen_paths: Dictionary = {}
	for index: int in range(value.size()):
		var spec_value: Variant = value[index]
		if typeof(spec_value) != TYPE_DICTIONARY:
			return _error(
				"definition file entry %d must be a dictionary" % index
			)
		var spec: Dictionary = spec_value
		var family_value: Variant = spec.get("family")
		var path_value: Variant = spec.get("path")
		if (
			typeof(family_value) != TYPE_STRING
			or typeof(path_value) != TYPE_STRING
		):
			return _error(
				"definition file entry %d requires string family and path" %
					index
			)

		var family: String = family_value
		var path: String = path_value
		if family.is_empty():
			return _error(
				"definition file entry %d requires a nonempty family" %
					index
			)
		if not _is_resource_json_path(path):
			return _error(
				"definition file path must be a canonical res:// JSON path: %s" %
					path
			)
		if seen_families.has(family):
			return _error("duplicate definition family %s" % family)
		if seen_paths.has(path):
			return _error("duplicate definition file path %s" % path)
		seen_families[family] = true
		seen_paths[path] = true
		files.append({"family": family, "path": path})

	files.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_path: String = left["path"]
			var right_path: String = right["path"]
			if left_path == right_path:
				return String(left["family"]) < String(right["family"])
			return left_path < right_path
	)
	return {"ok": true, "value": files}


static func _validate_localization_files(value: Array) -> Dictionary:
	var files: Array[String] = []
	var seen_paths: Dictionary = {}
	for index: int in range(value.size()):
		var path_value: Variant = value[index]
		if typeof(path_value) != TYPE_STRING:
			return _error(
				"localization file path %d must be a string" % index
			)
		var path: String = path_value
		if not _is_resource_json_path(path):
			return _error(
				"localization file path must be a canonical res:// JSON path: %s" %
					path
			)
		if seen_paths.has(path):
			return _error("duplicate localization file path %s" % path)
		seen_paths[path] = true
		files.append(path)
	files.sort()
	return {"ok": true, "value": files}


static func _load_definitions(files: Array) -> Dictionary:
	var definitions: Dictionary = {}
	for spec_value: Variant in files:
		var spec: Dictionary = spec_value
		var path: String = spec["path"]
		var loaded: Dictionary = _read_json(path)
		if not loaded["ok"]:
			return loaded
		if typeof(loaded["value"]) != TYPE_ARRAY:
			return _error("%s must contain an array" % path)
		definitions[spec["family"]] = loaded["value"].duplicate(true)
	return {"ok": true, "value": definitions}


static func _load_localization(files: Array) -> Dictionary:
	var localization: Dictionary = {}
	for path_value: Variant in files:
		var path: String = path_value
		var loaded: Dictionary = _read_json(path)
		if not loaded["ok"]:
			return loaded
		if typeof(loaded["value"]) != TYPE_DICTIONARY:
			return _error("%s must contain a dictionary" % path)

		var loaded_localization: Dictionary = loaded["value"]
		var keys: Array[String] = []
		for key_value: Variant in loaded_localization.keys():
			if typeof(key_value) != TYPE_STRING:
				return _error(
					"%s contains a non-string localization key" % path
				)
			keys.append(key_value)
		keys.sort()
		for key: String in keys:
			if localization.has(key):
				return _error("duplicate localization key %s" % key)
			localization[key] = loaded_localization[key]
	return {"ok": true, "value": localization}


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _error("content file not found: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("content file could not be opened: %s" % path)
	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Dictionary = (
		JsonIntegerNormalizerScript.parse_and_normalize(json_text)
	)
	if not parsed["ok"]:
		return _error(
			"%s: %s" %
				[path, str(parsed.get("error", "invalid JSON"))]
		)
	return parsed


static func _is_resource_json_path(path: String) -> bool:
	if not path.begins_with("res://") or not path.ends_with(".json"):
		return false
	var relative: String = path.substr(6)
	if relative.is_empty() or relative.begins_with("/"):
		return false
	var segments: PackedStringArray = relative.split("/", true)
	for segment: String in segments:
		if segment.is_empty() or segment == "." or segment == "..":
			return false
		if segment.contains("\\"):
			return false
	return true


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
