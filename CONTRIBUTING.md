# Contributing to Crypts & Cairns

Crypts & Cairns has no open-source license or additional reuse grant. Public
availability carries only the limited rights described in
[GitHub's Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#5-license-grant-to-other-users),
including viewing and forking through GitHub's platform features. Coordinate
contributions with the repository owner and submit them through pull requests
for review. All contributions must preserve the approved design and
deterministic foundation.

## Workflow

1. Branch from the current `main`.
2. Keep one coherent change per branch.
3. Add or update tests before changing deterministic or validation behavior.
4. Run the complete test suite.
5. Run the Web export for changes that can affect startup, content packaging, or
   presentation.
6. Open a pull request and complete every applicable checklist item.
7. Merge only after required checks pass and review conversations are resolved.

Do not push feature work directly to `main`.

## Required verification

Run verification commands with PowerShell 7 or later (`pwsh`). Windows
PowerShell 5.1 is not supported.

```powershell
.\scripts\validate-github-readiness.ps1
$godot = (Get-Command godot -ErrorAction Stop).Source
.\tests\scripts\godot_process_test.ps1 -GodotBin $godot
.\scripts\test.ps1 -GodotBin $godot
.\scripts\export-web.ps1 -GodotBin $godot
```

## Deterministic code

- Route simulation changes through commands.
- Preserve canonical hashing and replay equivalence.
- Use owned deterministic random streams; do not use Godot's global RNG for
  authoritative outcomes.
- Preserve strict integer handling at the JSON boundary.
- Add regression tests for every defect in deterministic or content behavior.

## Content and terminology

- Keep gameplay definitions data-driven.
- Validate manifests and definitions before they affect campaign state.
- Follow `docs/design/naming-registry.md`.
- Update `docs/design/source-provenance.md` when new external evidence informs a
  world element.
- Generic terms may remain generic only where the naming registry permits them.
- Do not copy names, text, art, maps, UI, or other expressive material from the
  inspiration work.

## Generated and sensitive files

Do not commit:

- `.godot/` or `build/` output;
- local credentials, access tokens, private keys, or machine identifiers;
- editor caches or temporary exports;
- third-party assets without recorded provenance and permission.
