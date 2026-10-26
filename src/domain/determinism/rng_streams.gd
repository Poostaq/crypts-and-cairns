class_name RngStreams
extends RefCounted

const Pcg32Script = preload("res://src/domain/determinism/pcg32.gd")
const StreamSeedsScript = preload("res://src/domain/determinism/stream_seeds.gd")


static func next_u32(state: Dictionary, stream_id: String) -> Dictionary:
	if stream_id.is_empty():
		return {"ok": false, "error": "stream ID is required"}

	var campaign_value: Variant = state.get("campaign")
	if typeof(campaign_value) != TYPE_DICTIONARY:
		return {"ok": false, "error": "state.campaign must be a dictionary"}
	var campaign: Dictionary = campaign_value
	if typeof(campaign.get("seed")) != TYPE_INT:
		return {"ok": false, "error": "state.campaign.seed must be an int"}
	var campaign_seed: int = campaign["seed"]
	if campaign_seed < 0:
		return {"ok": false, "error": "state.campaign.seed must be nonnegative"}

	var rng_value: Variant = state.get("rng")
	if typeof(rng_value) != TYPE_DICTIONARY:
		return {"ok": false, "error": "state.rng must be a dictionary"}
	var rng: Dictionary = rng_value
	if typeof(rng.get("streams")) != TYPE_DICTIONARY:
		return {"ok": false, "error": "state.rng.streams must be a dictionary"}
	var streams: Dictionary = rng["streams"]

	var generator: Variant
	if streams.has(stream_id):
		var snapshot_value: Variant = streams[stream_id]
		if typeof(snapshot_value) != TYPE_DICTIONARY:
			return {"ok": false, "error": "stored RNG stream snapshot must be a dictionary"}
		generator = Pcg32Script.from_snapshot(snapshot_value)
		if generator == null:
			return {"ok": false, "error": "stored RNG stream snapshot is invalid"}
	else:
		generator = Pcg32Script.seeded(
			StreamSeedsScript.derive(campaign_seed, "%s:state" % stream_id),
			StreamSeedsScript.derive(campaign_seed, "%s:sequence" % stream_id)
		)

	var value: int = generator.next_u32()
	streams[stream_id] = generator.snapshot()
	return {"ok": true, "value": value}
