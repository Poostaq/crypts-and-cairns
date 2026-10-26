class_name FoundationProbeHandler
extends RefCounted

const RngStreamsScript = preload("res://src/domain/determinism/rng_streams.gd")


func install(processor) -> void:
	processor.register_handler("test.advance", Callable(self, "_advance"))


func _advance(candidate: Dictionary, payload: Dictionary) -> Dictionary:
	if typeof(payload.get("ticks")) != TYPE_INT:
		return {"ok": false, "error": "ticks must be an integer"}
	if typeof(payload.get("stream_id")) != TYPE_STRING:
		return {"ok": false, "error": "stream ID must be a string"}

	var ticks: int = payload["ticks"]
	var stream_id: String = payload["stream_id"]
	if ticks <= 0:
		return {"ok": false, "error": "ticks must be positive"}
	if stream_id.is_empty():
		return {"ok": false, "error": "stream ID is required"}

	var draw: Dictionary = RngStreamsScript.next_u32(candidate, stream_id)
	if not draw["ok"]:
		return draw

	var next_sequence: int = int(
		candidate["campaign"]["command_sequence"]
	) + 1
	candidate["campaign"]["elapsed_ticks"] += ticks
	candidate["entities"].append({
		"id": "probe.%04d" % next_sequence,
		"roll": draw["value"],
		"ticks": ticks,
	})
	return {
		"ok": true,
		"events": [{
			"type": "probe_resolved",
			"sequence": next_sequence,
		}],
	}
