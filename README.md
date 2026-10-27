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

## Commit identity policy

Every commit author must use an owner-approved address listed in
`.github/approved-author-emails.txt`. GitHub's generated
`noreply@github.com` address is also accepted for the committer field on
GitHub-created squash commits. See [CONTRIBUTING.md](CONTRIBUTING.md) before
preparing a pull request or changing the allowlist.

## License status

This repository has no open-source license and grants no additional reuse
rights. Public availability carries only the limited rights described in
[GitHub's Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#5-license-grant-to-other-users),
including viewing and forking through GitHub's platform features. Beyond those
platform rights, no permission is granted to copy, redistribute, publish, or
create derivative works from the code, content, or assets.
