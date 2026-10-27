# Foundation development guide

## Toolchain

- Godot 4.7.2-stable, standard GDScript build.
- Compatibility renderer.
- Single-threaded Web export without GDExtension.
- Desktop Chromium and Firefox are the browser targets.
- `GODOT_BIN` points to the absolute Godot console executable.

## Commands

```powershell
& .\scripts\test.ps1
& .\scripts\export-web.ps1
python -m http.server 8060 --directory build/web
```

Open `http://localhost:8060/` in current desktop versions of Chromium and
Firefox. Do not open `index.html` through `file://`; WebAssembly and packaged
resources must be served over HTTP.

The export script removes only the project-local `build/web` directory before
building. It then requires nonempty HTML, JavaScript, WebAssembly, and PCK
outputs. The Web preset explicitly includes authoritative JSON under
`content/` and excludes tests, design documents, and agent metadata.

To inspect the loose export artifacts:

```powershell
Get-ChildItem -Recurse -File build/web |
    Select-Object FullName,Length
```

The browser canvas must display:

```text
Crypts & Cairns
Foundation build 0.1.0-dev
```

The browser console must contain no uncaught exception, missing-resource,
thread-support, or WebGL initialization error.

## Authoritative contracts

- Commands resolve against a deep copy and commit only on success.
- Command sequence numbers are contiguous and start at one.
- Rejected commands and failed handlers preserve the prior state hash.
- Authoritative state contains only canonical primitive values and integral
  numbers.
- Dictionaries sort by key; entity arrays sort by stable `id`; ordered scalar
  arrays retain order.
- PCG32 state is stored per named stream under `state.rng.streams`.
- Stream seeds derive from the campaign seed and stream ID.
- Build, save schema, content schema, content hash, and RNG version are part of
  state.
- Gameplay content must pass validation before a campaign is created.
- Authoritative JSON is parsed with exact integer lexemes; decimal and exponent
  number syntax is rejected.
- The foundation catalog contains seven reusable classes, six peoples, and
  exactly fifteen lore-locked people/class combinations.
- Titanborn may follow the Knight, Paladin, or Mage class.
- Replay state is bound to the validated foundation content hash.

## Content workflow

The packaged manifest is `content/manifest.json`. Definition files and
localization files referenced by it must use canonical `res://` JSON paths.
The repository sorts manifest entries, rejects duplicate families, files, and
localization keys, validates the assembled catalog, and hashes its canonical
representation.

When content changes intentionally, expect the content hash and replay hashes
to change together. Update deterministic fixtures only after reviewing that
change.
