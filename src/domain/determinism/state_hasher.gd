class_name StateHasher
extends RefCounted

const CanonicalJsonScript = preload("res://src/domain/determinism/canonical_json.gd")


static func hash_state(state: Dictionary) -> Dictionary:
	var encoded: Dictionary = CanonicalJsonScript.encode(state)
	if not encoded["ok"]:
		return encoded

	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return {"ok": false, "error": "could not start SHA-256 context"}
	var update_error := context.update(encoded["text"].to_utf8_buffer())
	if update_error != OK:
		return {"ok": false, "error": "could not update SHA-256 context"}
	return {
		"ok": true,
		"canonical": encoded["text"],
		"hash": context.finish().hex_encode(),
	}
