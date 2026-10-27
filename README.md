# Crypts & Cairns

Crypts & Cairns is a deterministic, turn-based simulation of living in a
game-like world built around expeditions into a lethal labyrinth.

> This is a foundation-stage project. The current build validates the
> deterministic state, command, replay, random-stream, and data-loading layers;
> it is not yet a playable game slice.

## Target

- Godot 4.7.2, standard build
- Desktop browsers
- Pixel-art presentation
- Action-point turn-based combat
- Knowledge-only persistence between mortal runs

## Open the project

Open `project.godot` in the standard Godot 4.7.2 editor and run the main scene.

## Test

From PowerShell 7 or later (`pwsh`), with Godot 4.7.2 available on `PATH`.
Windows PowerShell 5.1 is not supported.

```powershell
$godot = (Get-Command godot -ErrorAction Stop).Source
.\tests\scripts\godot_process_test.ps1 -GodotBin $godot
.\scripts\test.ps1 -GodotBin $godot
```

The foundation suite must complete with zero failures.

## Export for Web

```powershell
$godot = (Get-Command godot -ErrorAction Stop).Source
.\scripts\export-web.ps1 -GodotBin $godot
```

The export is written to `build/web/`. Generated Godot and build directories
are intentionally ignored by Git.

## Repository map

- `content/` — authoritative data definitions and localization
- `src/domain/` — deterministic state, content rules, hashing, and random streams
- `src/application/` — commands and replay orchestration
- `src/platform/` — JSON and content loading boundaries
- `src/presentation/` — Godot scenes and presentation code
- `tests/` — headless foundation suite and fixtures
- `docs/` — approved design, provenance, plans, and development notes
- `scripts/` — local test and Web-export entry points

## Design and provenance

- [Game design](docs/superpowers/specs/2026-10-25-crypts-and-cairns-design.md)
- [Naming registry](docs/design/naming-registry.md)
- [Source provenance ledger](docs/design/source-provenance.md)
- [Foundation notes](docs/development/foundation.md)

World terminology must follow the naming registry. New evidence or inspiration
that affects a world element must be recorded in the provenance ledger.

## License status

This repository is publicly visible but is not licensed for redistribution.
Public access grants no permission to copy, redistribute, publish, or create
derivative works from its code, content, or assets.
