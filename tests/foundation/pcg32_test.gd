extends "res://tests/support/test_case.gd"

const Pcg32 = preload("res://src/domain/determinism/pcg32.gd")


func run() -> void:
	var generator = Pcg32.seeded(42, 54)
	var actual: Array[int] = []
	for _index in range(5):
		actual.append(generator.next_u32())
	assert_equal(
		actual,
		[2707161783, 2068313097, 3122475824, 2211639955, 3215226955],
		"PCG32 matches the reference sequence"
	)

	var restored = Pcg32.from_snapshot(generator.snapshot())
	assert_equal(
		restored.next_u32(),
		generator.next_u32(),
		"snapshot restores exact RNG state"
	)

	assert_equal(
		Pcg32.from_snapshot({}),
		null,
		"snapshot requires state and increment keys"
	)
	assert_equal(
		Pcg32.from_snapshot({"state": "1", "increment": 1}),
		null,
		"snapshot rejects non-integer state"
	)
	assert_equal(
		Pcg32.from_snapshot({"state": 1, "increment": 2}),
		null,
		"snapshot rejects an even increment"
	)

	var rotation_zero = Pcg32.from_snapshot({"state": 4294967296, "increment": 1})
	assert_equal(
		rotation_zero.next_u32(),
		32,
		"rotation zero preserves the unrotated output"
	)

	var rotation_thirty_one = Pcg32.from_snapshot(
		{"state": -576460748008456192, "increment": 1}
	)
	assert_equal(
		rotation_thirty_one.next_u32(),
		1015872,
		"rotation thirty-one uses a logical right shift"
	)
