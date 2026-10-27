extends "res://tests/support/test_case.gd"


func run() -> void:
	var packed_value: Variant = load("res://src/presentation/main.tscn")
	assert_true(packed_value is PackedScene, "main scene loads")
	if not (packed_value is PackedScene):
		return

	var packed: PackedScene = packed_value
	var instance: Node = packed.instantiate()
	assert_true(instance is Control, "main scene root is Control")
	assert_true(
		instance.has_node("Status"),
		"foundation status label exists"
	)
	var status_value: Variant = instance.get_node_or_null("Status")
	assert_true(status_value is Label, "foundation status is a label")

	var main_loop: Variant = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		tree.root.add_child(instance)
		if status_value is Label:
			var status: Label = status_value
			assert_equal(
				status.text,
				"Crypts & Cairns\nFoundation build 0.1.0-dev",
				"main scene displays the project version"
			)
		assert_equal(
			str(instance.get_meta("content_hash", "")).length(),
			64,
			"main scene validates and binds foundation content"
		)
	else:
		fail_test("main loop is a SceneTree")
	instance.free()

	assert_equal(
		ProjectSettings.get_setting(
			"rendering/renderer/rendering_method"
		),
		"gl_compatibility",
		"foundation uses the Web-compatible renderer"
	)

	var preset := ConfigFile.new()
	var preset_error: Error = preset.load("res://export_presets.cfg")
	assert_equal(preset_error, OK, "Web export preset loads")
	if preset_error != OK:
		return

	assert_equal(
		preset.get_value("preset.0", "platform", ""),
		"Web",
		"foundation exports for Web"
	)
	assert_equal(
		preset.get_value(
			"preset.0.options",
			"variant/thread_support",
			true
		),
		false,
		"Web export is single-threaded"
	)
	assert_equal(
		preset.get_value(
			"preset.0.options",
			"variant/extensions_support",
			true
		),
		false,
		"Web export excludes GDExtension support"
	)

	var include_filter := str(
		preset.get_value("preset.0", "include_filter", "")
	)
	assert_true(
		include_filter.contains("content/**/*.json"),
		"authoritative nested content JSON is exported"
	)
	assert_true(
		include_filter.contains("content/*.json"),
		"root content manifest is exported"
	)

	var exclude_filter := str(
		preset.get_value("preset.0", "exclude_filter", "")
	)
	for excluded_root: String in [
		"docs/**",
		"tests/**",
		".agents/**",
		".codex/**",
		".superpowers/**",
	]:
		assert_true(
			exclude_filter.contains(excluded_root),
			"Web export excludes %s" % excluded_root
		)
