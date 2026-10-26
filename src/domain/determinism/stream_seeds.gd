class_name StreamSeeds
extends RefCounted


static func derive(campaign_seed: int, stream_id: String) -> int:
	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	assert(start_error == OK, "SHA-256 hashing must be available")

	var input := ("stream-v1|%d|%s" % [campaign_seed, stream_id]).to_utf8_buffer()
	var update_error := context.update(input)
	assert(update_error == OK, "SHA-256 input must be accepted")

	var digest := context.finish()
	var derived: int = digest[0] & 63
	for index in range(1, 8):
		derived = (derived << 8) | digest[index]
	return derived
