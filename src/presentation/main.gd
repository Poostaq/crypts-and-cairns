extends Control

@onready var status: Label = $Status


func _ready() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version"))
	status.text = "Crypts & Cairns\nFoundation build %s" % version
