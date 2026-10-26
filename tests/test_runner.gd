extends SceneTree

const TestCaseScript = preload("res://tests/support/test_case.gd")
const TestManifestScript = preload("res://tests/support/test_manifest.gd")

func _init() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	var assertion_count := 0
	var failure_count := 0

	for case_path in TestManifestScript.CASE_PATHS:
		var case_script: Script = load(case_path)
		if case_script == null:
			failure_count += 1
			printerr("FAIL %s: script could not be loaded" % case_path)
			continue
		if not case_script.can_instantiate():
			failure_count += 1
			printerr("FAIL %s: script could not be instantiated" % case_path)
			continue

		var test_case: Object = case_script.new()
		if not (test_case is TestCaseScript):
			failure_count += 1
			printerr("FAIL %s: script does not extend TestCase" % case_path)
			continue

		test_case.run()
		assertion_count += test_case.assertions
		if test_case.failures.is_empty():
			print("PASS %s" % case_path)
		else:
			failure_count += test_case.failures.size()
			for failure in test_case.failures:
				printerr("FAIL %s: %s" % [case_path, failure])

	print("Assertions: %d; Failures: %d" % [assertion_count, failure_count])
	quit(mini(failure_count, 125))
