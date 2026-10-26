class_name TestCase
extends RefCounted

var assertions: int = 0
var failures: Array[String] = []

func run() -> void:
	fail_test("Test case did not override run()")

func assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s | expected=%s actual=%s" % [message, expected, actual])

func fail_test(message: String) -> void:
	assertions += 1
	failures.append(message)
