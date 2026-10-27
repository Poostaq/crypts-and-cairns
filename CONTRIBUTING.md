# Contributing to Crypts & Cairns

Crypts & Cairns has no open-source license or additional reuse grant. Public
availability carries only the limited rights described in
[GitHub's Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#5-license-grant-to-other-users),
including viewing and forking through GitHub's platform features. Coordinate
contributions with the repository owner and submit them through pull requests
for review. All contributions must preserve the approved design and
deterministic foundation.

## Workflow

1. Before the first commit, coordinate the exact GitHub-provided `noreply`
   author address with the owner. It must be owner-approved in
   `.github/approved-author-emails.txt`; do not add an address without that
   review.
2. Configure Git to author every commit with the approved address. GitHub's
   generated `noreply@github.com` address is accepted only as the committer of
   GitHub-created commits such as squash merges.
3. Branch from the current `main`.
4. Keep one coherent change per branch.
5. Add or update tests before changing deterministic or validation behavior.
6. Run the complete test suite and publication validator.
7. Run the Web export for changes that can affect startup, content packaging, or
   presentation.
8. Open a pull request and complete every applicable checklist item.
9. Merge only after required checks pass and review conversations are resolved.

Do not push feature work directly to `main`.

## Required verification

Run verification commands with PowerShell 7 or later (`pwsh`). Windows
PowerShell 5.1 is not supported.

```powershell
.\scripts\validate-github-readiness.ps1
.\scripts\validate-publication.ps1
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
