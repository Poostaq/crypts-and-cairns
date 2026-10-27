extends Control

const JsonContentRepositoryScript = preload(
	"res://src/platform/content/json_content_repository.gd"
)

@onready var status: Label = $Status


func _ready() -> void:
	var loaded_content: Dictionary = JsonContentRepositoryScript.load_catalog(
		"res://content/manifest.json"
	)
	if not loaded_content["ok"]:
		status.text = "Crypts & Cairns\nFoundation content failed to load"
		push_error(str(loaded_content.get("error", "content load failed")))
		return
	set_meta("content_hash", loaded_content["content_hash"])
	var version := str(ProjectSettings.get_setting("application/config/version"))
	status.text = "Crypts & Cairns\nFoundation build %s" % version
