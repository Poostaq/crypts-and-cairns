# Crypts & Cairns Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Godot 4.7.2 foundation that can replay a fixed command sequence from a fixed seed and produce the same canonical state hashes on every run.

**Architecture:** Authoritative data and rules live in scene-free GDScript under `src/domain`; application services transact commands and replay them without presentation dependencies. JSON content is loaded through a platform adapter, validated into an immutable catalog, and hashed canonically. A small repository-owned test runner exercises the same GDScript in Godot headless mode without third-party addons.

**Tech Stack:** Godot 4.7.2-stable, typed GDScript, Compatibility renderer, single-threaded Web export, JSON content, SHA-256 through `HashingContext`, PowerShell verification scripts.

---

## Scope and acceptance

This plan implements only internal milestone 1, **Foundation**. It does not implement combat, exploration, UI flows, persistence, IndexedDB, Web Crypto, procedural floors, or production content balance.

Foundation is accepted when:

1. Godot reports `4.7.2.stable` and parses the project without errors.
2. Every authoritative value accepted by the canonical encoder is `null`, Boolean, integer, string, array, or string-keyed dictionary; floats and engine objects are rejected.
3. PCG32 matches the published reference vector and independent streams do not depend on consumption order.
4. Rejected or failed commands preserve the pre-command canonical state hash.
5. Recording and replaying the fixed fixture produces an identical hash after every command.
6. The content catalog validates seven reusable classes, six peoples, and fifteen permitted people/class combinations, then produces a stable content hash.
7. The project exports with the Web preset using Compatibility rendering, no C#, no extensions, and no threads.

## File map

```text
project.godot                              Engine pin, display defaults, main scene.
export_presets.cfg                        Single-threaded Web export preset.
.gitignore                                Godot cache, local tools, and builds.
scripts/test.ps1                          Version-gated headless test entry point.
scripts/export-web.ps1                    Version-gated Web export entry point.
src/domain/version_info.gd                Save/content/RNG version constants.
src/domain/state/game_state_factory.gd    Minimal serializable campaign state.
src/domain/determinism/canonical_json.gd  Stable authoritative JSON encoding.
src/domain/determinism/state_hasher.gd    SHA-256 over canonical state.
src/domain/determinism/pcg32.gd           Project-owned PCG32 implementation.
src/domain/determinism/stream_seeds.gd    Stable campaign-seed substreams.
src/domain/determinism/rng_streams.gd     Serializable named RNG stream state.
src/domain/content/content_validator.gd   Generic and people/class validation.
src/application/commands/command_processor.gd
                                             Transactional command pipeline.
src/application/replay/replay_runner.gd   Command/hash recording and verification.
src/platform/json/json_integer_normalizer.gd
                                             Safe JSON-number boundary conversion.
src/platform/content/json_content_repository.gd
                                             JSON loading and catalog hashing.
src/presentation/main.gd                  Minimal visible bootstrap screen.
src/presentation/main.tscn                Main presentation scene.
content/manifest.json                     Versioned definition manifest.
content/core/classes.json                 Seven reusable class identities.
content/core/peoples.json                 Six peoples and allowed class IDs.
content/localization/en.json              Names used by the foundation catalog.
tests/test_runner.gd                      Headless suite process and exit code.
tests/support/test_case.gd                Assertions with collected failures.
tests/support/test_manifest.gd            Ordered test-file registry.
tests/foundation/*.gd                     Foundation unit and integration tests.
tests/fixtures/foundation_replay.json     Fixed replay commands.
docs/development/foundation.md            Contracts and developer commands.
```

## Prerequisite

Install the standard, non-.NET Godot 4.7.2 editor and matching export templates. Set `GODOT_BIN` to the absolute console executable path for the current shell:

```powershell
$env:GODOT_BIN = '<godot-executable>'
& $env:GODOT_BIN --version
```

Expected: output begins with `4.7.2.stable`. Do not silently substitute a newer engine; update the approved design and this plan first.

### Task 1: Bootstrap the Godot project

**Files:**
- Create: `.gitignore`
- Create: `project.godot`
- Create: `src/presentation/main.gd`
- Create: `src/presentation/main.tscn`

- [ ] **Step 1: Add repository ignores**

```gitignore
.godot/
.tools/
build/
*.tmp
```

- [ ] **Step 2: Add the pinned project settings**

```ini
; project.godot
config_version=5

[application]

config/name="Crypts & Cairns"
config/version="0.1.0-dev"
run/main_scene="res://src/presentation/main.tscn"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
```

- [ ] **Step 3: Add the minimal presentation script**

```gdscript
# src/presentation/main.gd
extends Control

@onready var status: Label = $Status


func _ready() -> void:
    var version := str(ProjectSettings.get_setting("application/config/version"))
    status.text = "Crypts & Cairns\nFoundation build %s" % version
```

- [ ] **Step 4: Add the main scene**

```ini
; src/presentation/main.tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/presentation/main.gd" id="1_main"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_main")

[node name="Status" type="Label" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -180.0
offset_top = -32.0
offset_right = 180.0
offset_bottom = 32.0
grow_horizontal = 2
grow_vertical = 2
text = "Crypts & Cairns\nFoundation build"
horizontal_alignment = 1
vertical_alignment = 1
```

- [ ] **Step 5: Parse and run the bootstrap scene headlessly**

Run:

```powershell
& $env:GODOT_BIN --headless --path . --editor --quit
& $env:GODOT_BIN --headless --path . --quit-after 2
```

Expected: both commands exit `0`; output contains no parser error, invalid renderer, or missing-scene message.

- [ ] **Step 6: Commit the bootstrap**

```powershell
git add .gitignore project.godot src/presentation/main.gd src/presentation/main.tscn
git commit -m "chore: bootstrap Godot project"
```

### Task 2: Add a version-gated headless test harness

**Files:**
- Create: `tests/support/test_case.gd`
- Create: `tests/support/test_manifest.gd`
- Create: `tests/foundation/test_runner_smoke_test.gd`
- Create: `tests/test_runner.gd`
- Create: `scripts/test.ps1`

- [ ] **Step 1: Add the assertion base class**

```gdscript
# tests/support/test_case.gd
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
```

- [ ] **Step 2: Add the first smoke case and manifest**

```gdscript
# tests/foundation/test_runner_smoke_test.gd
extends TestCase


func run() -> void:
    assert_true(true, "test runner executes a registered case")
```

```gdscript
# tests/support/test_manifest.gd
class_name TestManifest
extends RefCounted

const CASE_PATHS: Array[String] = [
    "res://tests/foundation/test_runner_smoke_test.gd",
]
```

- [ ] **Step 3: Add the process-level runner**

```gdscript
# tests/test_runner.gd
extends SceneTree

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

        var test_case: TestCase = case_script.new()
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
```

- [ ] **Step 4: Add the version-gated PowerShell entry point**

```powershell
# scripts/test.ps1
param(
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    throw 'Set GODOT_BIN to the absolute Godot 4.7.2 console executable path.'
}
if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
    throw "Godot executable not found: $GodotBin"
}

$version = (& $GodotBin --version).Trim()
if (-not $version.StartsWith('4.7.2.stable')) {
    throw "Expected Godot 4.7.2-stable, received: $version"
}
if ($version.Contains('mono')) {
    throw "Use the standard Godot build, not the .NET/Mono build: $version"
}

& $GodotBin --headless --path $projectRoot --script res://tests/test_runner.gd
exit $LASTEXITCODE
```

- [ ] **Step 5: Run the harness**

Run: `& .\scripts\test.ps1`

Expected: `PASS res://tests/foundation/test_runner_smoke_test.gd`, `Failures: 0`, exit `0`.

- [ ] **Step 6: Commit the harness**

```powershell
git add tests scripts/test.ps1
git commit -m "test: add headless GDScript harness"
```

### Task 3: Define versioned campaign state

**Files:**
- Create: `src/domain/version_info.gd`
- Create: `src/domain/state/game_state_factory.gd`
- Create: `tests/foundation/game_state_factory_test.gd`
- Modify: `tests/support/test_manifest.gd`

- [ ] **Step 1: Write the failing state-factory test**

```gdscript
# tests/foundation/game_state_factory_test.gd
extends TestCase


func run() -> void:
    var created := GameStateFactory.create(12345, "content-hash", "0.1.0-test")
    assert_true(created["ok"], "valid campaign state is created")
    var state: Dictionary = created["state"]
    assert_equal(state["meta"]["build_version"], "0.1.0-test", "build version is recorded")
    assert_equal(state["meta"]["save_schema_version"], 1, "save schema is recorded")
    assert_equal(state["meta"]["content_schema_version"], 1, "content schema is recorded")
    assert_equal(state["meta"]["rng_algorithm_version"], "pcg32-v1", "RNG version is recorded")
    assert_equal(state["meta"]["content_hash"], "content-hash", "content hash is recorded")
    assert_equal(state["campaign"]["seed"], 12345, "campaign seed is recorded")
    assert_equal(state["campaign"]["command_sequence"], 0, "sequence starts at zero")
    assert_equal(state["campaign"]["elapsed_ticks"], 0, "clock starts at zero")
    assert_equal(state["rng"]["streams"], {}, "RNG streams start empty")

    var rejected := GameStateFactory.create(-1, "content-hash", "0.1.0-test")
    assert_true(not rejected["ok"], "negative campaign seed is rejected")
```

Append this entry to `TestManifest.CASE_PATHS`:

```gdscript
    "res://tests/foundation/game_state_factory_test.gd",
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `& .\scripts\test.ps1`

Expected: failure because `GameStateFactory` is not defined.

- [ ] **Step 3: Add version constants and the state factory**

```gdscript
# src/domain/version_info.gd
class_name VersionInfo
extends RefCounted

const SAVE_SCHEMA_VERSION: int = 1
const CONTENT_SCHEMA_VERSION: int = 1
const RNG_ALGORITHM_VERSION: String = "pcg32-v1"
```

```gdscript
# src/domain/state/game_state_factory.gd
class_name GameStateFactory
extends RefCounted


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
                "save_schema_version": VersionInfo.SAVE_SCHEMA_VERSION,
                "content_schema_version": VersionInfo.CONTENT_SCHEMA_VERSION,
                "rng_algorithm_version": VersionInfo.RNG_ALGORITHM_VERSION,
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
```

- [ ] **Step 4: Run the state tests**

Run: `& .\scripts\test.ps1`

Expected: both registered cases pass and `Failures: 0`.

- [ ] **Step 5: Commit the state contract**

```powershell
git add src/domain/version_info.gd src/domain/state/game_state_factory.gd tests
git commit -m "feat: define versioned campaign state"
```

### Task 4: Normalize JSON integers, then add canonical encoding and state hashing

**Files:**
- Create: `src/platform/json/json_integer_normalizer.gd`
- Create: `src/domain/determinism/canonical_json.gd`
- Create: `src/domain/determinism/state_hasher.gd`
- Create: `tests/foundation/canonical_json_test.gd`
- Modify: `tests/support/test_manifest.gd`

- [ ] **Step 1: Write the failing canonicalization tests**

```gdscript
# tests/foundation/canonical_json_test.gd
extends TestCase


func run() -> void:
    var parsed_integer := JSON.parse_string("{\"value\":42}")
    var normalized_integer := JsonIntegerNormalizer.normalize(parsed_integer)
    assert_true(normalized_integer["ok"], "whole JSON numbers normalize")
    assert_equal(typeof(normalized_integer["value"]["value"]), TYPE_INT, "whole JSON number becomes int")
    assert_true(
        not JsonIntegerNormalizer.normalize(JSON.parse_string("{\"value\":1.5}"))["ok"],
        "fractional JSON number is rejected"
    )

    var encoded := CanonicalJson.encode({
        "z": 2,
        "actors": [
            {"id": "actor.z", "hp": 5},
            {"id": "actor.a", "hp": 7},
        ],
        "a": 1,
    })
    assert_true(encoded["ok"], "authoritative primitives encode")
    assert_equal(
        encoded["text"],
        "{\"a\":1,\"actors\":[{\"hp\":7,\"id\":\"actor.a\"},{\"hp\":5,\"id\":\"actor.z\"}],\"z\":2}",
        "maps and entity lists are sorted"
    )

    var ordered_values := CanonicalJson.encode([2, 1])
    assert_equal(ordered_values["text"], "[2,1]", "non-entity arrays preserve semantic order")

    var float_result := CanonicalJson.encode({"chance": 0.5})
    assert_true(not float_result["ok"], "floats are rejected")

    var hash_result := StateHasher.hash_state({})
    assert_equal(
        hash_result["hash"],
        "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
        "SHA-256 hashes canonical JSON"
    )
```

Append this entry to `TestManifest.CASE_PATHS`:

```gdscript
    "res://tests/foundation/canonical_json_test.gd",
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `& .\scripts\test.ps1`

Expected: failure because `JsonIntegerNormalizer` and `CanonicalJson` are not defined.

- [ ] **Step 3: Normalize exact JSON integers at the platform boundary**

Godot parses every JSON number as a float. Convert only finite, whole values in the interoperable integer range; reject fractional or unsafe numbers before constructing authoritative content or commands.

```gdscript
# src/platform/json/json_integer_normalizer.gd
class_name JsonIntegerNormalizer
extends RefCounted

const MAX_SAFE_JSON_INTEGER: float = 9007199254740991.0


static func normalize(value: Variant, path: String = "$") -> Dictionary:
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
            return {"ok": true, "value": value}
        TYPE_FLOAT:
            if not is_finite(value):
                return _error("%s contains a non-finite number" % path)
            if value != floor(value):
                return _error("%s contains a fractional number" % path)
            if absf(value) > MAX_SAFE_JSON_INTEGER:
                return _error("%s exceeds the safe JSON integer range" % path)
            return {"ok": true, "value": int(value)}
        TYPE_ARRAY:
            var normalized_array: Array = []
            for index in range(value.size()):
                var child := normalize(value[index], "%s[%d]" % [path, index])
                if not child["ok"]:
                    return child
                normalized_array.append(child["value"])
            return {"ok": true, "value": normalized_array}
        TYPE_DICTIONARY:
            var normalized_dictionary: Dictionary = {}
            for key in value.keys():
                if typeof(key) != TYPE_STRING:
                    return _error("%s contains a non-string key" % path)
                var child := normalize(value[key], "%s.%s" % [path, key])
                if not child["ok"]:
                    return child
                normalized_dictionary[key] = child["value"]
            return {"ok": true, "value": normalized_dictionary}
        _:
            return _error("%s contains unsupported type %s" % [path, type_string(typeof(value))])


static func _error(message: String) -> Dictionary:
    return {"ok": false, "error": message}
```

- [ ] **Step 4: Implement canonical JSON**

```gdscript
# src/domain/determinism/canonical_json.gd
class_name CanonicalJson
extends RefCounted


static func encode(value: Variant) -> Dictionary:
    return _encode_value(value, "$")


static func _encode_value(value: Variant, path: String) -> Dictionary:
    match typeof(value):
        TYPE_NIL:
            return _ok("null")
        TYPE_BOOL:
            return _ok("true" if value else "false")
        TYPE_INT:
            return _ok(str(value))
        TYPE_STRING:
            return _ok(JSON.stringify(value))
        TYPE_ARRAY:
            return _encode_array(value, path)
        TYPE_DICTIONARY:
            return _encode_dictionary(value, path)
        TYPE_FLOAT:
            return _error("%s contains a float" % path)
        _:
            return _error("%s contains unsupported type %s" % [path, type_string(typeof(value))])


static func _encode_array(values: Array, path: String) -> Dictionary:
    var ordered: Array = values.duplicate(true)
    if _is_entity_list(ordered):
        ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
            return str(left["id"]) < str(right["id"])
        )
        for index in range(1, ordered.size()):
            if ordered[index - 1]["id"] == ordered[index]["id"]:
                return _error("%s contains duplicate entity id %s" % [path, ordered[index]["id"]])

    var parts: Array[String] = []
    for index in range(ordered.size()):
        var child := _encode_value(ordered[index], "%s[%d]" % [path, index])
        if not child["ok"]:
            return child
        parts.append(child["text"])
    return _ok("[%s]" % ",".join(parts))


static func _encode_dictionary(values: Dictionary, path: String) -> Dictionary:
    var keys: Array[String] = []
    for raw_key in values.keys():
        if typeof(raw_key) != TYPE_STRING:
            return _error("%s contains a non-string dictionary key" % path)
        keys.append(raw_key)
    keys.sort()

    var parts: Array[String] = []
    for key in keys:
        var child := _encode_value(values[key], "%s.%s" % [path, key])
        if not child["ok"]:
            return child
        parts.append("%s:%s" % [JSON.stringify(key), child["text"]])
    return _ok("{%s}" % ",".join(parts))


static func _is_entity_list(values: Array) -> bool:
    if values.is_empty():
        return false
    for value in values:
        if typeof(value) != TYPE_DICTIONARY:
            return false
        if not value.has("id") or typeof(value["id"]) != TYPE_STRING:
            return false
    return true


static func _ok(text: String) -> Dictionary:
    return {"ok": true, "text": text}


static func _error(message: String) -> Dictionary:
    return {"ok": false, "error": message}
```

- [ ] **Step 5: Implement SHA-256 state hashing**

```gdscript
# src/domain/determinism/state_hasher.gd
class_name StateHasher
extends RefCounted


static func hash_state(state: Dictionary) -> Dictionary:
    var encoded := CanonicalJson.encode(state)
    if not encoded["ok"]:
        return encoded

    var context := HashingContext.new()
    var start_error := context.start(HashingContext.HASH_SHA256)
    if start_error != OK:
        return {"ok": false, "error": "could not start SHA-256 context"}
    var update_error := context.update(encoded["text"].to_utf8_buffer())
    if update_error != OK:
        return {"ok": false, "error": "could not update SHA-256 context"}
    return {
        "ok": true,
        "canonical": encoded["text"],
        "hash": context.finish().hex_encode(),
    }
```

- [ ] **Step 6: Run the canonicalization tests**

Run: `& .\scripts\test.ps1`

Expected: JSON integers normalize, fractional JSON values fail, and the empty-object hash matches the fixed SHA-256 value.

- [ ] **Step 7: Commit deterministic encoding**

```powershell
git add src/domain/determinism src/platform/json tests
git commit -m "feat: add canonical state hashing"
```

### Task 5: Implement project-owned PCG32

**Files:**
- Create: `src/domain/determinism/pcg32.gd`
- Create: `tests/foundation/pcg32_test.gd`
- Modify: `tests/support/test_manifest.gd`

- [ ] **Step 1: Write the PCG32 reference-vector test**

```gdscript
# tests/foundation/pcg32_test.gd
extends TestCase


func run() -> void:
    var generator := Pcg32.seeded(42, 54)
    var actual: Array[int] = []
    for index in range(5):
        actual.append(generator.next_u32())
    assert_equal(
        actual,
        [2707161783, 2068313097, 3122475824, 2211639955, 3215226955],
        "PCG32 matches the reference sequence"
    )

    var restored := Pcg32.from_snapshot(generator.snapshot())
    assert_equal(restored.next_u32(), generator.next_u32(), "snapshot restores exact RNG state")
```

Append this entry to `TestManifest.CASE_PATHS`:

```gdscript
    "res://tests/foundation/pcg32_test.gd",
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `& .\scripts\test.ps1`

Expected: failure because `Pcg32` is not defined.

- [ ] **Step 3: Implement PCG32 with explicit logical shifts**

```gdscript
# src/domain/determinism/pcg32.gd
class_name Pcg32
extends RefCounted

const MULTIPLIER: int = 6364136223846793005
const UINT32_MASK: int = 4294967295

var _state: int = 0
var _increment: int = 1


static func seeded(seed: int, sequence: int) -> Pcg32:
    var generator := Pcg32.new()
    generator._state = 0
    generator._increment = (sequence << 1) | 1
    generator.next_u32()
    generator._state += seed
    generator.next_u32()
    return generator


static func from_snapshot(snapshot_data: Dictionary) -> Pcg32:
    var generator := Pcg32.new()
    generator._state = int(snapshot_data["state"])
    generator._increment = int(snapshot_data["increment"])
    return generator


func next_u32() -> int:
    var old_state := _state
    _state = old_state * MULTIPLIER + _increment
    var xorshifted := _unsigned_right_shift(
        old_state ^ _unsigned_right_shift(old_state, 18),
        27
    ) & UINT32_MASK
    var rotation := _unsigned_right_shift(old_state, 59) & 31
    return (
        (xorshifted >> rotation)
        | (xorshifted << ((-rotation) & 31))
    ) & UINT32_MASK


func snapshot() -> Dictionary:
    return {"state": _state, "increment": _increment}


static func _unsigned_right_shift(value: int, bits: int) -> int:
    if bits == 0:
        return value
    return (value >> bits) & ((1 << (64 - bits)) - 1)
```

- [ ] **Step 4: Run the PCG32 tests**

Run: `& .\scripts\test.ps1`

Expected: the five-number reference vector and snapshot test pass.

- [ ] **Step 5: Commit PCG32**

```powershell
git add src/domain/determinism/pcg32.gd tests
git commit -m "feat: own deterministic PCG32 generator"
```

### Task 6: Add stable named RNG streams

**Files:**
- Create: `src/domain/determinism/stream_seeds.gd`
- Create: `src/domain/determinism/rng_streams.gd`
- Create: `tests/foundation/rng_streams_test.gd`
- Modify: `tests/support/test_manifest.gd`

- [ ] **Step 1: Write failing stream-isolation tests**

```gdscript
# tests/foundation/rng_streams_test.gd
extends TestCase


func run() -> void:
    var first_state := GameStateFactory.create(91234, "content", "test")["state"]
    var second_state := GameStateFactory.create(91234, "content", "test")["state"]

    var first_loot := RngStreams.next_u32(first_state, "loot")
    RngStreams.next_u32(first_state, "combat")
    var second_loot := RngStreams.next_u32(second_state, "loot")

    assert_true(first_loot["ok"], "first loot draw succeeds")
    assert_equal(first_loot["value"], second_loot["value"], "loot is independent of combat consumption")
    assert_true(first_state["rng"]["streams"].has("loot"), "loot stream snapshot is serialized")
    assert_true(first_state["rng"]["streams"].has("combat"), "combat stream snapshot is serialized")
    assert_true(not RngStreams.next_u32(first_state, "")["ok"], "empty stream ID is rejected")
```

Append this entry to `TestManifest.CASE_PATHS`:

```gdscript
    "res://tests/foundation/rng_streams_test.gd",
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `& .\scripts\test.ps1`

Expected: failure because `RngStreams` is not defined.

- [ ] **Step 3: Derive stable substream seeds with SHA-256**

```gdscript
# src/domain/determinism/stream_seeds.gd
class_name StreamSeeds
extends RefCounted


static func derive(campaign_seed: int, stream_id: String) -> int:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(("stream-v1|%d|%s" % [campaign_seed, stream_id]).to_utf8_buffer())
    var digest := context.finish()
    var derived: int = digest[0] & 63
    for index in range(1, 8):
        derived = (derived << 8) | digest[index]
    return derived
```

- [ ] **Step 4: Store each stream in authoritative state**

```gdscript
# src/domain/determinism/rng_streams.gd
class_name RngStreams
extends RefCounted


static func next_u32(state: Dictionary, stream_id: String) -> Dictionary:
    if stream_id.is_empty():
        return {"ok": false, "error": "stream ID is required"}
    if not state.has("campaign") or not state.has("rng"):
        return {"ok": false, "error": "state lacks RNG roots"}

    var streams: Dictionary = state["rng"]["streams"]
    var generator: Pcg32
    if streams.has(stream_id):
        generator = Pcg32.from_snapshot(streams[stream_id])
    else:
        var campaign_seed := int(state["campaign"]["seed"])
        generator = Pcg32.seeded(
            StreamSeeds.derive(campaign_seed, "%s:state" % stream_id),
            StreamSeeds.derive(campaign_seed, "%s:sequence" % stream_id)
        )

    var value := generator.next_u32()
    streams[stream_id] = generator.snapshot()
    return {"ok": true, "value": value}
```

- [ ] **Step 5: Run the stream tests**

Run: `& .\scripts\test.ps1`

Expected: all tests pass and named stream snapshots appear under `state.rng.streams`.

- [ ] **Step 6: Commit named streams**

```powershell
git add src/domain/determinism tests
git commit -m "feat: add isolated RNG streams"
```

### Task 7: Add transactional command processing

**Files:**
- Create: `src/application/commands/command_processor.gd`
- Create: `tests/foundation/command_processor_test.gd`
- Modify: `tests/support/test_manifest.gd`

- [ ] **Step 1: Write failing transaction tests**

```gdscript
# tests/foundation/command_processor_test.gd
extends TestCase


func run() -> void:
    var processor := CommandProcessor.new()
    processor.register_handler("test.advance", Callable(self, "_advance"))
    processor.register_handler("test.fail", Callable(self, "_mutate_then_fail"))
    var initial := GameStateFactory.create(5, "content", "test")["state"]

    var accepted := processor.process(initial, {
        "sequence": 1,
        "type": "test.advance",
        "payload": {"ticks": 6},
    })
    assert_true(accepted["ok"], "valid command succeeds")
    assert_equal(accepted["state"]["campaign"]["elapsed_ticks"], 6, "handler mutation commits")
    assert_equal(accepted["state"]["campaign"]["command_sequence"], 1, "sequence commits last")
    assert_equal(initial["campaign"]["elapsed_ticks"], 0, "input state remains immutable")

    var initial_hash := StateHasher.hash_state(initial)["hash"]
    var bad_sequence := processor.process(initial, {
        "sequence": 2,
        "type": "test.advance",
        "payload": {"ticks": 1},
    })
    assert_true(not bad_sequence["ok"], "sequence gap is rejected")
    assert_equal(StateHasher.hash_state(initial)["hash"], initial_hash, "validation rejection preserves hash")

    var injected_failure := processor.process(initial, {
        "sequence": 1,
        "type": "test.fail",
        "payload": {},
    })
    assert_true(not injected_failure["ok"], "handler failure is rejected")
    assert_equal(StateHasher.hash_state(initial)["hash"], initial_hash, "resolution failure preserves hash")


func _advance(candidate: Dictionary, payload: Dictionary) -> Dictionary:
    var ticks := int(payload.get("ticks", 0))
    if ticks <= 0:
        return {"ok": false, "error": "ticks must be positive"}
    candidate["campaign"]["elapsed_ticks"] += ticks
    return {"ok": true, "events": [{"type": "time_advanced", "ticks": ticks}]}


func _mutate_then_fail(candidate: Dictionary, _payload: Dictionary) -> Dictionary:
    candidate["campaign"]["elapsed_ticks"] = 999
    return {"ok": false, "error": "injected failure"}
```

Append this entry to `TestManifest.CASE_PATHS`:

```gdscript
    "res://tests/foundation/command_processor_test.gd",
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `& .\scripts\test.ps1`

Expected: failure because `CommandProcessor` is not defined.

- [ ] **Step 3: Implement validate-copy-resolve-commit**

```gdscript
# src/application/commands/command_processor.gd
class_name CommandProcessor
extends RefCounted

var _handlers: Dictionary = {}


func register_handler(command_type: String, handler: Callable) -> void:
    assert(not command_type.is_empty())
    assert(handler.is_valid())
    assert(not _handlers.has(command_type))
    _handlers[command_type] = handler


func process(current_state: Dictionary, command: Dictionary) -> Dictionary:
    var validation_error := _validate_envelope(current_state, command)
    if not validation_error.is_empty():
        return _rejected(current_state, validation_error)

    var candidate: Dictionary = current_state.duplicate(true)
    var handler: Callable = _handlers[command["type"]]
    var resolution: Dictionary = handler.call(candidate, command["payload"])
    if not resolution.get("ok", false):
        return _rejected(current_state, str(resolution.get("error", "resolution failed")))

    candidate["campaign"]["command_sequence"] = int(command["sequence"])
    return {
        "ok": true,
        "state": candidate,
        "events": resolution.get("events", []).duplicate(true),
    }


func _validate_envelope(state: Dictionary, command: Dictionary) -> String:
    if not command.has("sequence") or typeof(command["sequence"]) != TYPE_INT:
        return "command sequence must be an integer"
    if not command.has("type") or typeof(command["type"]) != TYPE_STRING:
        return "command type must be a string"
    if not command.has("payload") or typeof(command["payload"]) != TYPE_DICTIONARY:
        return "command payload must be a dictionary"
    if not _handlers.has(command["type"]):
        return "unknown command type: %s" % command["type"]
    var expected := int(state["campaign"]["command_sequence"]) + 1
    if command["sequence"] != expected:
        return "expected command sequence %d" % expected
    return ""


func _rejected(state: Dictionary, message: String) -> Dictionary:
    return {"ok": false, "state": state, "events": [], "error": message}
```

- [ ] **Step 4: Run the command tests**

Run: `& .\scripts\test.ps1`

Expected: accepted command commits to a deep copy; both rejection paths retain the original hash.

- [ ] **Step 5: Commit the command pipeline**

```powershell
git add src/application/commands tests
git commit -m "feat: add transactional command pipeline"
```

### Task 8: Record and verify deterministic replays

**Files:**
- Create: `src/application/replay/replay_runner.gd`
- Create: `tests/fixtures/foundation_replay.json`
- Create: `tests/foundation/foundation_probe_handler.gd`
- Create: `tests/foundation/replay_determinism_test.gd`
- Modify: `tests/support/test_manifest.gd`

- [ ] **Step 1: Add the fixed command fixture**

```json
{
  "commands": [
    {"sequence": 1, "type": "test.advance", "payload": {"ticks": 5, "stream_id": "world"}},
    {"sequence": 2, "type": "test.advance", "payload": {"ticks": 7, "stream_id": "loot"}},
    {"sequence": 3, "type": "test.advance", "payload": {"ticks": 11, "stream_id": "world"}}
  ]
}
```

- [ ] **Step 2: Add the test-only deterministic handler**

```gdscript
# tests/foundation/foundation_probe_handler.gd
class_name FoundationProbeHandler
extends RefCounted


func install(processor: CommandProcessor) -> void:
    processor.register_handler("test.advance", Callable(self, "_advance"))


func _advance(candidate: Dictionary, payload: Dictionary) -> Dictionary:
    var ticks := int(payload.get("ticks", 0))
    var stream_id := str(payload.get("stream_id", ""))
    if ticks <= 0:
        return {"ok": false, "error": "ticks must be positive"}
    var draw := RngStreams.next_u32(candidate, stream_id)
    if not draw["ok"]:
        return draw

    var next_sequence := int(candidate["campaign"]["command_sequence"]) + 1
    candidate["campaign"]["elapsed_ticks"] += ticks
    candidate["entities"].append({
        "id": "probe.%04d" % next_sequence,
        "roll": draw["value"],
        "ticks": ticks,
    })
    return {
        "ok": true,
        "events": [{"type": "probe_resolved", "sequence": next_sequence}],
    }
```

- [ ] **Step 3: Write the failing replay test**

```gdscript
# tests/foundation/replay_determinism_test.gd
extends TestCase


func run() -> void:
    var parsed_fixture := JSON.parse_string(
        FileAccess.get_file_as_string("res://tests/fixtures/foundation_replay.json")
    )
    var normalized_fixture := JsonIntegerNormalizer.normalize(parsed_fixture)
    assert_true(normalized_fixture["ok"], "fixture contains integral JSON numbers")
    var fixture: Dictionary = normalized_fixture["value"]
    var initial := GameStateFactory.create(8675309, "fixture-content", "test")["state"]

    var first_processor := CommandProcessor.new()
    var first_handler := FoundationProbeHandler.new()
    first_handler.install(first_processor)
    var recording := ReplayRunner.record(initial, fixture["commands"], first_processor)
    assert_true(recording["ok"], "fixture records successfully")

    var second_processor := CommandProcessor.new()
    var second_handler := FoundationProbeHandler.new()
    second_handler.install(second_processor)
    var verification := ReplayRunner.verify(initial, recording["replay"], second_processor)
    assert_true(verification["ok"], "recorded replay verifies")
    assert_equal(
        verification["final_hash"],
        recording["replay"]["hashes"][-1],
        "final canonical hash is identical"
    )
    assert_equal(initial["campaign"]["command_sequence"], 0, "recording does not mutate initial state")
```

Append this entry to `TestManifest.CASE_PATHS`:

```gdscript
    "res://tests/foundation/replay_determinism_test.gd",
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `& .\scripts\test.ps1`

Expected: failure because `ReplayRunner` is not defined.

- [ ] **Step 5: Implement replay recording and verification**

```gdscript
# src/application/replay/replay_runner.gd
class_name ReplayRunner
extends RefCounted


static func record(
    initial_state: Dictionary,
    commands: Array,
    processor: CommandProcessor
) -> Dictionary:
    var state: Dictionary = initial_state.duplicate(true)
    var hashes: Array[String] = []
    var initial_hash := StateHasher.hash_state(state)
    if not initial_hash["ok"]:
        return initial_hash
    hashes.append(initial_hash["hash"])

    for command in commands:
        var result := processor.process(state, command)
        if not result["ok"]:
            return {"ok": false, "error": result["error"]}
        state = result["state"]
        var state_hash := StateHasher.hash_state(state)
        if not state_hash["ok"]:
            return state_hash
        hashes.append(state_hash["hash"])

    return {
        "ok": true,
        "final_state": state,
        "replay": {
            "commands": commands.duplicate(true),
            "hashes": hashes,
        },
    }


static func verify(
    initial_state: Dictionary,
    replay: Dictionary,
    processor: CommandProcessor
) -> Dictionary:
    var recorded := record(initial_state, replay["commands"], processor)
    if not recorded["ok"]:
        return recorded
    var actual_hashes: Array = recorded["replay"]["hashes"]
    var expected_hashes: Array = replay["hashes"]
    if actual_hashes.size() != expected_hashes.size():
        return {"ok": false, "error": "replay hash count differs"}
    for index in range(actual_hashes.size()):
        if actual_hashes[index] != expected_hashes[index]:
            return {"ok": false, "error": "replay diverged at hash index %d" % index}
    return {
        "ok": true,
        "final_state": recorded["final_state"],
        "final_hash": actual_hashes[-1],
    }
```

- [ ] **Step 6: Run the replay tests twice**

Run:

```powershell
& .\scripts\test.ps1
& .\scripts\test.ps1
```

Expected: both runs exit `0` and the replay test passes on each run.

- [ ] **Step 7: Commit replay verification**

```powershell
git add src/application/replay tests
git commit -m "feat: verify deterministic command replays"
```

### Task 9: Validate content structure and references

**Files:**
- Create: `src/domain/content/content_validator.gd`
- Create: `tests/foundation/content_validator_test.gd`
- Modify: `tests/support/test_manifest.gd`

- [ ] **Step 1: Write failing in-memory validation tests**

```gdscript
# tests/foundation/content_validator_test.gd
extends TestCase


func run() -> void:
    var valid_catalog := {
        "content_schema_version": 1,
        "definitions": {
            "class": [{"id": "class.fighter", "display_name_key": "class.fighter.name"}],
            "people": [{
                "id": "people.human",
                "display_name_key": "people.human.name",
                "allowed_class_ids": ["class.fighter"],
            }],
        },
        "localization": {
            "class.fighter.name": "Fighter",
            "people.human.name": "Humans",
        },
    }
    assert_equal(ContentValidator.validate(valid_catalog), [], "valid catalog passes")

    var invalid_catalog: Dictionary = valid_catalog.duplicate(true)
    invalid_catalog["definitions"]["class"].append({
        "id": "class.fighter",
        "display_name_key": "class.missing.name",
        "weight": 1.5,
    })
    invalid_catalog["definitions"]["people"][0]["allowed_class_ids"] = ["class.unknown"]
    var errors := ContentValidator.validate(invalid_catalog)
    var joined := " | ".join(errors)
    assert_true(joined.contains("duplicate definition id"), "duplicate IDs fail")
    assert_true(joined.contains("contains a float"), "floats fail")
    assert_true(joined.contains("missing localization key"), "missing localization fails")
    assert_true(joined.contains("unknown class id"), "unknown class reference fails")
```

Append this entry to `TestManifest.CASE_PATHS`:

```gdscript
    "res://tests/foundation/content_validator_test.gd",
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `& .\scripts\test.ps1`

Expected: failure because `ContentValidator` is not defined.

- [ ] **Step 3: Implement structural, numeric, localization, and reference validation**

```gdscript
# src/domain/content/content_validator.gd
class_name ContentValidator
extends RefCounted


static func validate(catalog: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    if catalog.get("content_schema_version") != VersionInfo.CONTENT_SCHEMA_VERSION:
        errors.append("content schema version does not match runtime")
    if typeof(catalog.get("definitions")) != TYPE_DICTIONARY:
        errors.append("definitions must be a dictionary")
        return errors
    if typeof(catalog.get("localization")) != TYPE_DICTIONARY:
        errors.append("localization must be a dictionary")
        return errors

    _find_floats(catalog, "$", errors)
    var ids: Dictionary = {}
    var definitions: Dictionary = catalog["definitions"]
    var families: Array = definitions.keys()
    families.sort()
    for family in families:
        if typeof(definitions[family]) != TYPE_ARRAY:
            errors.append("definition family %s must be an array" % family)
            continue
        for definition in definitions[family]:
            _validate_definition(str(family), definition, catalog["localization"], ids, errors)

    var class_ids: Dictionary = {}
    for class_definition in definitions.get("class", []):
        if typeof(class_definition) == TYPE_DICTIONARY and class_definition.has("id"):
            class_ids[class_definition["id"]] = true
    for people_definition in definitions.get("people", []):
        if typeof(people_definition) != TYPE_DICTIONARY:
            continue
        if typeof(people_definition.get("allowed_class_ids")) != TYPE_ARRAY:
            errors.append("%s requires allowed_class_ids array" % people_definition.get("id", "people.?"))
            continue
        var seen_allowed: Dictionary = {}
        for class_id in people_definition.get("allowed_class_ids", []):
            if typeof(class_id) != TYPE_STRING:
                errors.append("%s contains a non-string class id" % people_definition.get("id", "people.?"))
                continue
            if not class_ids.has(class_id):
                errors.append("%s references unknown class id %s" % [people_definition.get("id", "people.?"), class_id])
            if seen_allowed.has(class_id):
                errors.append("%s repeats allowed class id %s" % [people_definition.get("id", "people.?"), class_id])
            seen_allowed[class_id] = true
    return errors


static func _validate_definition(
    family: String,
    definition: Variant,
    localization: Dictionary,
    ids: Dictionary,
    errors: Array[String]
) -> void:
    if typeof(definition) != TYPE_DICTIONARY:
        errors.append("definition in %s must be a dictionary" % family)
        return
    if typeof(definition.get("id")) != TYPE_STRING:
        errors.append("definition in %s requires a string id" % family)
        return
    var definition_id: String = definition["id"]
    var pattern := RegEx.new()
    pattern.compile("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")
    if pattern.search(definition_id) == null or not definition_id.begins_with("%s." % family):
        errors.append("invalid %s definition id %s" % [family, definition_id])
    if ids.has(definition_id):
        errors.append("duplicate definition id %s" % definition_id)
    ids[definition_id] = true
    if typeof(definition.get("display_name_key")) != TYPE_STRING:
        errors.append("%s requires a string display_name_key" % definition_id)
        return
    var display_key: String = definition["display_name_key"]
    if not localization.has(display_key):
        errors.append("%s has missing localization key %s" % [definition_id, display_key])
    elif typeof(localization[display_key]) != TYPE_STRING:
        errors.append("localization value %s must be a string" % display_key)


static func _find_floats(value: Variant, path: String, errors: Array[String]) -> void:
    match typeof(value):
        TYPE_FLOAT:
            errors.append("%s contains a float" % path)
        TYPE_ARRAY:
            for index in range(value.size()):
                _find_floats(value[index], "%s[%d]" % [path, index], errors)
        TYPE_DICTIONARY:
            for key in value.keys():
                _find_floats(value[key], "%s.%s" % [path, key], errors)
```

- [ ] **Step 4: Run the validator tests**

Run: `& .\scripts\test.ps1`

Expected: the valid catalog returns no errors; each injected defect is reported.

- [ ] **Step 5: Commit content validation**

```powershell
git add src/domain/content tests
git commit -m "feat: validate authoritative content"
```

### Task 10: Load and hash the real foundation catalog

**Files:**
- Create: `content/manifest.json`
- Create: `content/core/classes.json`
- Create: `content/core/peoples.json`
- Create: `content/localization/en.json`
- Create: `src/platform/content/json_content_repository.gd`
- Create: `tests/foundation/content_repository_test.gd`
- Modify: `tests/foundation/replay_determinism_test.gd`
- Modify: `tests/support/test_manifest.gd`

- [ ] **Step 1: Add the manifest and seven reusable classes**

```json
{
  "content_schema_version": 1,
  "definition_files": [
    {"family": "class", "path": "res://content/core/classes.json"},
    {"family": "people", "path": "res://content/core/peoples.json"}
  ],
  "localization_files": ["res://content/localization/en.json"]
}
```

```json
[
  {"id": "class.berserker", "display_name_key": "class.berserker.name"},
  {"id": "class.fighter", "display_name_key": "class.fighter.name"},
  {"id": "class.hunter", "display_name_key": "class.hunter.name"},
  {"id": "class.knight", "display_name_key": "class.knight.name"},
  {"id": "class.mage", "display_name_key": "class.mage.name"},
  {"id": "class.paladin", "display_name_key": "class.paladin.name"},
  {"id": "class.rogue", "display_name_key": "class.rogue.name"}
]
```

- [ ] **Step 2: Add six peoples and exactly fifteen permitted combinations**

```json
[
  {"id": "people.beastkin", "display_name_key": "people.beastkin.name", "allowed_class_ids": ["class.hunter", "class.rogue"]},
  {"id": "people.dwarf", "display_name_key": "people.dwarf.name", "allowed_class_ids": ["class.fighter", "class.knight"]},
  {"id": "people.elf", "display_name_key": "people.elf.name", "allowed_class_ids": ["class.hunter", "class.mage"]},
  {"id": "people.human", "display_name_key": "people.human.name", "allowed_class_ids": ["class.fighter", "class.knight", "class.mage", "class.rogue"]},
  {"id": "people.titanborn", "display_name_key": "people.titanborn.name", "allowed_class_ids": ["class.knight", "class.paladin", "class.mage"]},
  {"id": "people.tribal", "display_name_key": "people.tribal.name", "allowed_class_ids": ["class.fighter", "class.berserker"]}
]
```

- [ ] **Step 3: Add English localization coverage**

```json
{
  "class.berserker.name": "Berserker",
  "class.fighter.name": "Fighter",
  "class.hunter.name": "Hunter",
  "class.knight.name": "Knight",
  "class.mage.name": "Mage",
  "class.paladin.name": "Paladin",
  "class.rogue.name": "Rogue",
  "people.beastkin.name": "Beastkin",
  "people.dwarf.name": "Dwarves",
  "people.elf.name": "Elves",
  "people.human.name": "Humans",
  "people.titanborn.name": "Titanborn",
  "people.tribal.name": "Tribal People"
}
```

- [ ] **Step 4: Write the failing repository test**

```gdscript
# tests/foundation/content_repository_test.gd
extends TestCase


func run() -> void:
    var first := JsonContentRepository.load_catalog("res://content/manifest.json")
    var second := JsonContentRepository.load_catalog("res://content/manifest.json")
    assert_true(first["ok"], "foundation catalog loads")
    assert_equal(first["catalog"]["definitions"]["class"].size(), 7, "seven classes load")
    assert_equal(first["catalog"]["definitions"]["people"].size(), 6, "six peoples load")

    var combinations := 0
    for people in first["catalog"]["definitions"]["people"]:
        combinations += people["allowed_class_ids"].size()
    assert_equal(combinations, 15, "fifteen people/class combinations load")
    assert_equal(first["content_hash"].length(), 64, "catalog has a SHA-256 hash")
    assert_equal(first["content_hash"], second["content_hash"], "catalog hash is stable")
```

Append this entry to `TestManifest.CASE_PATHS`:

```gdscript
    "res://tests/foundation/content_repository_test.gd",
```

- [ ] **Step 5: Run the repository test to verify it fails**

Run: `& .\scripts\test.ps1`

Expected: failure because `JsonContentRepository` is not defined.

- [ ] **Step 6: Implement deterministic JSON loading**

```gdscript
# src/platform/content/json_content_repository.gd
class_name JsonContentRepository
extends RefCounted


static func load_catalog(manifest_path: String) -> Dictionary:
    var manifest_result := _read_json(manifest_path)
    if not manifest_result["ok"]:
        return manifest_result
    if typeof(manifest_result["value"]) != TYPE_DICTIONARY:
        return {"ok": false, "error": "manifest root must be a dictionary"}
    var manifest: Dictionary = manifest_result["value"]
    if typeof(manifest.get("definition_files")) != TYPE_ARRAY:
        return {"ok": false, "error": "manifest definition_files must be an array"}
    if typeof(manifest.get("localization_files")) != TYPE_ARRAY:
        return {"ok": false, "error": "manifest localization_files must be an array"}
    var definitions: Dictionary = {}
    var definition_files: Array = manifest.get("definition_files", []).duplicate(true)
    for file_spec in definition_files:
        if typeof(file_spec) != TYPE_DICTIONARY:
            return {"ok": false, "error": "definition file entry must be a dictionary"}
        if not file_spec.has("family") or not file_spec.has("path"):
            return {"ok": false, "error": "definition file entry requires family and path"}
        if typeof(file_spec["family"]) != TYPE_STRING or typeof(file_spec["path"]) != TYPE_STRING:
            return {"ok": false, "error": "definition file family and path must be strings"}
    definition_files.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return str(left["path"]) < str(right["path"])
    )
    for file_spec in definition_files:
        var loaded := _read_json(str(file_spec["path"]))
        if not loaded["ok"]:
            return loaded
        if typeof(loaded["value"]) != TYPE_ARRAY:
            return {"ok": false, "error": "%s must contain an array" % file_spec["path"]}
        var family := str(file_spec["family"])
        if definitions.has(family):
            return {"ok": false, "error": "duplicate definition family %s" % family}
        definitions[family] = loaded["value"]

    var localization: Dictionary = {}
    var localization_files: Array = manifest.get("localization_files", []).duplicate()
    for localization_path in localization_files:
        if typeof(localization_path) != TYPE_STRING:
            return {"ok": false, "error": "localization file path must be a string"}
    localization_files.sort()
    for localization_path in localization_files:
        var loaded := _read_json(str(localization_path))
        if not loaded["ok"]:
            return loaded
        if typeof(loaded["value"]) != TYPE_DICTIONARY:
            return {"ok": false, "error": "%s must contain a dictionary" % localization_path}
        for key in loaded["value"].keys():
            if localization.has(key):
                return {"ok": false, "error": "duplicate localization key %s" % key}
            localization[key] = loaded["value"][key]

    var catalog := {
        "content_schema_version": manifest.get("content_schema_version"),
        "definitions": definitions,
        "localization": localization,
    }
    var errors := ContentValidator.validate(catalog)
    if not errors.is_empty():
        return {"ok": false, "error": " | ".join(errors)}
    var hash_result := StateHasher.hash_state(catalog)
    if not hash_result["ok"]:
        return hash_result
    return {"ok": true, "catalog": catalog, "content_hash": hash_result["hash"]}


static func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "error": "content file not found: %s" % path}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if parsed == null:
        return {"ok": false, "error": "invalid JSON: %s" % path}
    var normalized := JsonIntegerNormalizer.normalize(parsed)
    if not normalized["ok"]:
        return {"ok": false, "error": "%s: %s" % [path, normalized["error"]]}
    return normalized
```

- [ ] **Step 7: Bind replay state to the real content hash**

Replace the fixed `fixture-content` state construction in `replay_determinism_test.gd` with:

```gdscript
    var loaded_content := JsonContentRepository.load_catalog("res://content/manifest.json")
    assert_true(loaded_content["ok"], "foundation catalog loads for replay")
    var initial := GameStateFactory.create(
        8675309,
        loaded_content["content_hash"],
        "test"
    )["state"]
```

- [ ] **Step 8: Run all content and replay tests**

Run: `& .\scripts\test.ps1`

Expected: seven classes, six peoples, fifteen combinations, stable content hash, and replay verification all pass.

- [ ] **Step 9: Commit the foundation catalog**

```powershell
git add content src/platform/content tests
git commit -m "feat: load and hash foundation content"
```

### Task 11: Configure Web export and close the milestone

**Files:**
- Create: `export_presets.cfg`
- Create: `scripts/export-web.ps1`
- Create: `tests/foundation/main_scene_smoke_test.gd`
- Create: `docs/development/foundation.md`
- Modify: `tests/support/test_manifest.gd`

- [ ] **Step 1: Add the main-scene smoke test**

```gdscript
# tests/foundation/main_scene_smoke_test.gd
extends TestCase


func run() -> void:
    var packed: PackedScene = load("res://src/presentation/main.tscn")
    assert_true(packed != null, "main scene loads")
    var instance := packed.instantiate()
    assert_true(instance is Control, "main scene root is Control")
    assert_true(instance.has_node("Status"), "foundation status label exists")
    instance.free()
```

Append this entry to `TestManifest.CASE_PATHS`:

```gdscript
    "res://tests/foundation/main_scene_smoke_test.gd",
```

- [ ] **Step 2: Add the single-threaded Web preset**

```ini
; export_presets.cfg
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="docs/**,tests/**,.agents/**,.codex/**"
export_path="build/web/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=false
progressive_web_app/offline_page=""
progressive_web_app/display=0
progressive_web_app/orientation=1
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
```

- [ ] **Step 3: Add the export script**

```powershell
# scripts/export-web.ps1
param(
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $projectRoot 'build\web'
$outputFile = Join-Path $outputDirectory 'index.html'

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    throw 'Set GODOT_BIN to the absolute Godot 4.7.2 console executable path.'
}
$version = (& $GodotBin --version).Trim()
if (-not $version.StartsWith('4.7.2.stable')) {
    throw "Expected Godot 4.7.2-stable, received: $version"
}
if ($version.Contains('mono')) {
    throw "Use the standard Godot build, not the .NET/Mono build: $version"
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
& $GodotBin --headless --path $projectRoot --export-debug 'Web' $outputFile
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
    throw "Web export did not create $outputFile"
}
Write-Host "Web export created: $outputFile"
```

- [ ] **Step 4: Document the foundation contracts**

````markdown
# Foundation development guide

## Toolchain

- Godot 4.7.2-stable, standard GDScript build.
- Compatibility renderer.
- Web export without threads or GDExtension.
- `GODOT_BIN` points to the absolute console executable.

## Commands

```powershell
& .\scripts\test.ps1
& .\scripts\export-web.ps1
python -m http.server 8060 --directory build/web
```

Open `http://localhost:8060/` in a current desktop Chromium browser and Firefox.

## Authoritative contracts

- Commands are processed against a deep copy and commit only on success.
- Command sequence numbers are contiguous and start at one.
- Rejected commands and failed handlers preserve the prior state hash.
- Authoritative state contains only canonical primitive values and integral numbers.
- Dictionaries sort by key; entity arrays sort by stable `id`; ordered scalar arrays retain order.
- PCG32 state is stored per named stream under `state.rng.streams`.
- Stream seeds derive from campaign seed plus stream ID.
- Build, save schema, content schema, content hash, and RNG version are part of state.
- Gameplay content must pass validation before a campaign is created.
````

- [ ] **Step 5: Run the complete headless suite**

Run: `& .\scripts\test.ps1`

Expected: every registered case reports `PASS`, summary reports `Failures: 0`, exit `0`.

- [ ] **Step 6: Parse the project and export Web**

Run:

```powershell
& $env:GODOT_BIN --headless --path . --editor --quit
& .\scripts\export-web.ps1
```

Expected: both commands exit `0`; `build/web/index.html`, `.wasm`, `.pck`, and JavaScript loader files exist.

- [ ] **Step 7: Smoke-test both target browser families**

Run: `python -m http.server 8060 --directory build/web`

Open `http://localhost:8060/` in a current desktop Chromium browser and Firefox.

Expected in each browser: the canvas displays `Crypts & Cairns` and `Foundation build 0.1.0-dev`; the developer console has no uncaught exception, missing resource, thread-support, or WebGL initialization error.

- [ ] **Step 8: Review the export contents**

Run:

```powershell
Get-ChildItem -Recurse -File build/web | Select-Object FullName,Length
```

Expected: runtime export files only; no `docs`, `tests`, naming registry, provenance ledger, `.agents`, or `.codex` path appears.

- [ ] **Step 9: Commit the milestone**

```powershell
git add export_presets.cfg scripts/export-web.ps1 tests docs/development/foundation.md
git commit -m "feat: complete deterministic foundation"
```

## Final verification checklist

- [ ] `& .\scripts\test.ps1` exits `0` with zero failures.
- [ ] The PCG32 reference vector is exact.
- [ ] The content repository reports 7 classes, 6 peoples, and 15 allowed pairings.
- [ ] The replay fixture verifies every recorded hash on two consecutive runs.
- [ ] Invalid commands and injected handler failures preserve the prior state hash.
- [ ] `& .\scripts\export-web.ps1` exits `0` using the unthreaded Web preset.
- [ ] Chromium and Firefox display the bootstrap scene without console errors.
- [ ] The Web build contains no design, source-reference, or test documents.
- [ ] `git status --short` is empty after the milestone commit.

## Reference documentation

- [Godot 4.7 command-line tutorial](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)
- [Godot 4.7 Web export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html)
- [Godot 4.7 JSON API and number-type behavior](https://docs.godotengine.org/en/4.7/classes/class_json.html)
- [Godot `HashingContext`](https://docs.godotengine.org/en/4.7/classes/class_hashingcontext.html)
- [Godot `SceneTree.quit`](https://docs.godotengine.org/en/4.7/classes/class_scenetree.html#class-scenetree-method-quit)
- [PCG reference implementation and test vectors](https://www.pcg-random.org/using-pcg-c-basic.html)
