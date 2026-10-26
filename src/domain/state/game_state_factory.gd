class_name GameStateFactory
extends RefCounted

const VersionInfoScript = preload("res://src/domain/version_info.gd")

static func create(
	campaign_seed: int,
	content_hash: String,
	build_version: String = ""
) -> Dictionary:
	if campaign_seed < 0:
		return {"ok": false, "error": "campaign seed must be nonnegative"}
	if content_hash.is_empty():
		return {"ok": false, "error": "content hash is required"}
	if build_version.is_empty():
		build_version = str(ProjectSettings.get_setting("application/config/version"))

	return {
		"ok": true,
		"state": {
			"meta": {
				"build_version": build_version,
				"save_schema_version": VersionInfoScript.SAVE_SCHEMA_VERSION,
				"content_schema_version": VersionInfoScript.CONTENT_SCHEMA_VERSION,
				"rng_algorithm_version": VersionInfoScript.RNG_ALGORITHM_VERSION,
				"content_hash": content_hash,
			},
			"campaign": {
				"seed": campaign_seed,
				"command_sequence": 0,
				"elapsed_ticks": 0,
			},
			"rng": {"streams": {}},
			"entities": [],
		},
	}
