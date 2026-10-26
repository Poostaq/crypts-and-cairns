class_name CanonicalJson
extends RefCounted

const MAX_NESTING_DEPTH: int = 64


static func encode(value: Variant) -> Dictionary:
	var ancestors: Array = []
	return _encode_value(value, "$", ancestors, 0)


static func _encode_value(
	value: Variant,
	path: String,
	ancestors: Array,
	depth: int
) -> Dictionary:
	if depth > MAX_NESTING_DEPTH:
		return _error("%s exceeds maximum nesting depth %d" % [path, MAX_NESTING_DEPTH])

	var value_type: int = typeof(value)
	if value_type == TYPE_ARRAY or value_type == TYPE_DICTIONARY:
		if _contains_identity(ancestors, value):
			return _error("%s contains a cyclic container reference" % path)
		ancestors.append(value)
		var container_result: Dictionary
		if value_type == TYPE_ARRAY:
			container_result = _encode_array(value, path, ancestors, depth)
		else:
			container_result = _encode_dictionary(value, path, ancestors, depth)
		ancestors.pop_back()
		return container_result

	match value_type:
		TYPE_NIL:
			return _ok("null")
		TYPE_BOOL:
			return _ok("true" if value else "false")
		TYPE_INT:
			return _ok(str(value))
		TYPE_STRING:
			return _ok(JSON.stringify(value))
		TYPE_FLOAT:
			return _error("%s contains a float" % path)
		_:
			return _error(
				"%s contains unsupported type %s" %
					[path, type_string(value_type)]
			)


static func _encode_array(
	values: Array,
	path: String,
	ancestors: Array,
	depth: int
) -> Dictionary:
	# Authoritative convention: only a nonempty array where every entry is a
	# dictionary with a string id is an entity list. All other arrays retain
	# semantic order.
	var is_entity_list: bool = _is_entity_list(values)
	var ordered: Array = values.duplicate()
	if is_entity_list:
		ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return str(left["id"]) < str(right["id"])
		)
		for index: int in range(1, ordered.size()):
			if ordered[index - 1]["id"] == ordered[index]["id"]:
				return _error(
					"%s contains duplicate entity id %s" % [
						_entity_path(path, String(ordered[index]["id"])),
						ordered[index]["id"],
					]
				)

	var parts: Array[String] = []
	for index: int in range(ordered.size()):
		var child_path: String = _path_child(path, str(index))
		if is_entity_list:
			child_path = _entity_path(path, String(ordered[index]["id"]))
		var child: Dictionary = _encode_value(
			ordered[index],
			child_path,
			ancestors,
			depth + 1
		)
		if not child["ok"]:
			return child
		parts.append(child["text"])
	return _ok("[%s]" % ",".join(parts))


static func _encode_dictionary(
	values: Dictionary,
	path: String,
	ancestors: Array,
	depth: int
) -> Dictionary:
	var keys: Array[String] = []
	for raw_key: Variant in values.keys():
		if typeof(raw_key) != TYPE_STRING:
			return _error("%s contains a non-string dictionary key" % path)
		keys.append(raw_key)
	keys.sort()

	var parts: Array[String] = []
	for key: String in keys:
		var child: Dictionary = _encode_value(
			values[key],
			_path_child(path, key),
			ancestors,
			depth + 1
		)
		if not child["ok"]:
			return child
		parts.append("%s:%s" % [JSON.stringify(key), child["text"]])
	return _ok("{%s}" % ",".join(parts))


static func _is_entity_list(values: Array) -> bool:
	if values.is_empty():
		return false
	for value: Variant in values:
		if typeof(value) != TYPE_DICTIONARY:
			return false
		var dictionary_value: Dictionary = value
		if not dictionary_value.has("id"):
			return false
		if typeof(dictionary_value["id"]) != TYPE_STRING:
			return false
	return true


static func _contains_identity(ancestors: Array, value: Variant) -> bool:
	for ancestor: Variant in ancestors:
		if is_same(ancestor, value):
			return true
	return false


static func _path_child(path: String, segment: String) -> String:
	return "%s/%s" % [path, _escape_path_segment(segment)]


static func _entity_path(path: String, entity_id: String) -> String:
	return "%s/@%s" % [path, _escape_path_segment(entity_id)]


static func _escape_path_segment(segment: String) -> String:
	return segment.replace("~", "~0").replace("/", "~1")


static func _ok(text: String) -> Dictionary:
	return {"ok": true, "text": text}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
