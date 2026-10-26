class_name JsonIntegerNormalizer
extends RefCounted

const MAX_SAFE_JSON_INTEGER: float = 9007199254740991.0
const MAX_SAFE_JSON_INTEGER_TEXT: String = "9007199254740991"
const MAX_NESTING_DEPTH: int = 64


static func parse_and_normalize(json_text: String) -> Dictionary:
	var source_parser := JSON.new()
	var parse_error := source_parser.parse(json_text)
	if parse_error != OK:
		return _error(
			"$ contains invalid JSON at line %d: %s" %
				[source_parser.get_error_line(), source_parser.get_error_message()]
		)

	var sentinel_key := "__crypts_internal_json_integer__"
	while _contains_dictionary_key(source_parser.data, sentinel_key):
		sentinel_key += "_"

	var rewrite_result: Dictionary = _rewrite_number_lexemes(json_text, sentinel_key)
	if not rewrite_result["ok"]:
		return rewrite_result

	var exact_parser := JSON.new()
	parse_error = exact_parser.parse(rewrite_result["text"])
	if parse_error != OK:
		return _error("$ could not parse validated authoritative JSON")

	var restored: Dictionary = _restore_exact_integers(
		exact_parser.data,
		sentinel_key,
		"$",
		0
	)
	if not restored["ok"]:
		return restored
	return normalize(restored["value"])


# Use parse_and_normalize() for authoritative JSON text. normalize() is the
# recursive boundary for programmatic or already-parsed values, where source
# number lexemes are no longer available.
static func normalize(value: Variant, path: String = "$") -> Dictionary:
	var ancestors: Array = []
	return _normalize_value(value, path, ancestors, 0)


static func _normalize_value(
	value: Variant,
	path: String,
	ancestors: Array,
	depth: int
) -> Dictionary:
	if depth > MAX_NESTING_DEPTH:
		return _error("%s exceeds maximum nesting depth %d" % [path, MAX_NESTING_DEPTH])

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return {"ok": true, "value": value}
		TYPE_FLOAT:
			var number: float = value
			if not is_finite(number):
				return _error("%s contains a non-finite number" % path)
			if number != floor(number):
				return _error("%s contains a fractional number" % path)
			if absf(number) > MAX_SAFE_JSON_INTEGER:
				return _error("%s exceeds the safe JSON integer range" % path)
			return {"ok": true, "value": int(number)}
		TYPE_ARRAY:
			if _contains_identity(ancestors, value):
				return _error("%s contains a cyclic array reference" % path)
			var source_array: Array = value
			var normalized_array: Array = []
			ancestors.append(value)
			for index: int in range(source_array.size()):
				var child: Dictionary = _normalize_value(
					source_array[index],
					_path_child(path, str(index)),
					ancestors,
					depth + 1
				)
				if not child["ok"]:
					ancestors.pop_back()
					return child
				normalized_array.append(child["value"])
			ancestors.pop_back()
			return {"ok": true, "value": normalized_array}
		TYPE_DICTIONARY:
			if _contains_identity(ancestors, value):
				return _error("%s contains a cyclic dictionary reference" % path)
			var source_dictionary: Dictionary = value
			var normalized_dictionary: Dictionary = {}
			ancestors.append(value)
			for key: Variant in source_dictionary.keys():
				if typeof(key) != TYPE_STRING:
					ancestors.pop_back()
					return _error("%s contains a non-string key" % path)
				var child: Dictionary = _normalize_value(
					source_dictionary[key],
					_path_child(path, String(key)),
					ancestors,
					depth + 1
				)
				if not child["ok"]:
					ancestors.pop_back()
					return child
				normalized_dictionary[key] = child["value"]
			ancestors.pop_back()
			return {"ok": true, "value": normalized_dictionary}
		_:
			return _error(
				"%s contains unsupported type %s" %
				[path, type_string(typeof(value))]
			)


static func _rewrite_number_lexemes(
	json_text: String,
	sentinel_key: String
) -> Dictionary:
	var index: int = 0
	var in_string: bool = false
	var segment_start: int = 0
	var parts: Array[String] = []
	while index < json_text.length():
		var character: String = json_text.substr(index, 1)
		if in_string:
			if character == "\\":
				index += 2
				continue
			if character == "\"":
				in_string = false
			index += 1
			continue

		if character == "\"":
			in_string = true
			index += 1
			continue
		if character == "+" or character == ".":
			return _error(
				"$ contains invalid numeric syntax at character %d" % index
			)
		if character != "-" and not _is_ascii_digit(character):
			index += 1
			continue

		var token_start: int = index
		index += 1
		while index < json_text.length():
			var token_character: String = json_text.substr(index, 1)
			if _is_json_token_delimiter(token_character):
				break
			index += 1
		var token: String = json_text.substr(token_start, index - token_start)
		if not _is_decimal_integer_lexeme(token):
			return _error(
				"$ numeric token %s at character %d must be an optional-minus decimal integer" %
					[JSON.stringify(token), token_start]
			)
		var digits: String = token.substr(1) if token.begins_with("-") else token
		if not _is_safe_integer_magnitude(digits):
			return _error(
				"$ numeric token %s at character %d exceeds the safe JSON integer range" %
					[JSON.stringify(token), token_start]
			)
		parts.append(json_text.substr(segment_start, token_start - segment_start))
		parts.append(
			"{%s:%s}" % [JSON.stringify(sentinel_key), JSON.stringify(token)]
		)
		segment_start = index
	parts.append(json_text.substr(segment_start))
	return {"ok": true, "text": "".join(parts)}


static func _contains_dictionary_key(root: Variant, key: String) -> bool:
	var pending: Array = [root]
	while not pending.is_empty():
		var current: Variant = pending.pop_back()
		match typeof(current):
			TYPE_ARRAY:
				var current_array: Array = current
				for child: Variant in current_array:
					pending.append(child)
			TYPE_DICTIONARY:
				var current_dictionary: Dictionary = current
				if current_dictionary.has(key):
					return true
				for child: Variant in current_dictionary.values():
					pending.append(child)
	return false


static func _restore_exact_integers(
	value: Variant,
	sentinel_key: String,
	path: String,
	depth: int
) -> Dictionary:
	if depth > MAX_NESTING_DEPTH:
		return _error("%s exceeds maximum nesting depth %d" % [path, MAX_NESTING_DEPTH])

	match typeof(value):
		TYPE_ARRAY:
			var source_array: Array = value
			var restored_array: Array = []
			for index: int in range(source_array.size()):
				var child: Dictionary = _restore_exact_integers(
					source_array[index],
					sentinel_key,
					_path_child(path, str(index)),
					depth + 1
				)
				if not child["ok"]:
					return child
				restored_array.append(child["value"])
			return {"ok": true, "value": restored_array}
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value
			if source_dictionary.size() == 1 and source_dictionary.has(sentinel_key):
				var token: Variant = source_dictionary[sentinel_key]
				if typeof(token) != TYPE_STRING:
					return _error("%s contains an invalid internal integer token" % path)
				return {"ok": true, "value": String(token).to_int()}

			var restored_dictionary: Dictionary = {}
			for key: Variant in source_dictionary.keys():
				if typeof(key) != TYPE_STRING:
					return _error("%s contains a non-string key" % path)
				var child: Dictionary = _restore_exact_integers(
					source_dictionary[key],
					sentinel_key,
					_path_child(path, String(key)),
					depth + 1
				)
				if not child["ok"]:
					return child
				restored_dictionary[key] = child["value"]
			return {"ok": true, "value": restored_dictionary}
		_:
			return {"ok": true, "value": value}


static func _is_decimal_integer_lexeme(token: String) -> bool:
	var digits: String = token.substr(1) if token.begins_with("-") else token
	if digits.is_empty():
		return false
	if digits.length() > 1 and digits.begins_with("0"):
		return false
	for index: int in range(digits.length()):
		if not _is_ascii_digit(digits.substr(index, 1)):
			return false
	return true


static func _is_safe_integer_magnitude(digits: String) -> bool:
	if digits.length() != MAX_SAFE_JSON_INTEGER_TEXT.length():
		return digits.length() < MAX_SAFE_JSON_INTEGER_TEXT.length()
	for index: int in range(digits.length()):
		var digit_code: int = digits.unicode_at(index)
		var limit_code: int = MAX_SAFE_JSON_INTEGER_TEXT.unicode_at(index)
		if digit_code < limit_code:
			return true
		if digit_code > limit_code:
			return false
	return true


static func _is_ascii_digit(character: String) -> bool:
	if character.length() != 1:
		return false
	var code: int = character.unicode_at(0)
	return code >= 48 and code <= 57


static func _is_json_token_delimiter(character: String) -> bool:
	return (
		character == " "
		or character == "\t"
		or character == "\r"
		or character == "\n"
		or character == ","
		or character == ":"
		or character == "["
		or character == "]"
		or character == "{"
		or character == "}"
	)


static func _contains_identity(ancestors: Array, value: Variant) -> bool:
	for ancestor: Variant in ancestors:
		if is_same(ancestor, value):
			return true
	return false


static func _path_child(path: String, segment: String) -> String:
	return "%s/%s" % [path, segment.replace("~", "~0").replace("/", "~1")]


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
