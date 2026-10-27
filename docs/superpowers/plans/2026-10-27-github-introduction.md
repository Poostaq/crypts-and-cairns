# Private GitHub Introduction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox ('- [ ]') syntax for tracking.

**Goal:** Publish Crypts & Cairns to a new private personal GitHub repository with rewritten noreply identities, a 'main' default branch, repository documentation, deterministic foundation CI, and protected-branch configuration when the owner's GitHub plan supports it.

**Architecture:** Treat '<legacy-source>' as the immutable source and recovery checkout during publication. Create and verify a full Git bundle, then make a fresh non-local clone at '<canonical-checkout>'; rewrite identity metadata only in that clone, and make it the canonical GitHub-connected checkout. Add repository-facing documentation and CI there, validate locally, create an empty private GitHub repository, push once, verify its workflow, and only then apply the stored default-branch ruleset.

**Tech Stack:** Git, PowerShell 7, Python virtual environment with git-filter-repo 2.47.0, GitHub CLI, GitHub Actions, Godot 4.7.2 standard build and Web export templates.

Each command block is self-contained. Re-resolve authenticated account values
instead of assuming PowerShell variables survive between steps.

Task 1 runs against the paths it names explicitly. After Task 1, run repository
commands from '<canonical-checkout>' unless a step names another working
directory.

---

## File Map

Files created in the new canonical checkout:

- 'README.md' — project landing page, development status, commands, structure, design and provenance links.
- 'CONTRIBUTING.md' — branch, verification, determinism, data, naming, and provenance requirements.
- 'SECURITY.md' — private vulnerability reporting and secret-handling policy.
- '.github/pull_request_template.md' — review checklist for foundation and content changes.
- '.github/workflows/foundation.yml' — pinned, least-privilege test and Web-export workflow.
- '.github/rulesets/main.json' — reproducible branch ruleset payload applied after the first successful workflow run.
- 'scripts/validate-github-readiness.ps1' — local and CI validation for repository metadata and non-deployment constraints.

Files deliberately not created:

- 'LICENSE' or another license file.
- GitHub Pages or release workflows.
- Dependabot configuration.
- CODEOWNERS or mandatory review configuration.

External recovery and tool locations:

- '<recovery-bundle>'
- '<tool-environment>'

## Task 1: Preflight, Backup, and Fresh Canonical Clone

**Files:**
- Read: '<legacy-source>'
- Create outside repository: '<recovery-bundle>'
- Create checkout: '<canonical-checkout>'

- [ ] **Step 1: Verify the source checkout is clean and still has no remote**

Run:

~~~powershell
$source = '<legacy-source>'
$sourceStatus = @(git -C $source status --short)
if ($sourceStatus.Count -ne 0) {
	throw ('Source checkout is dirty:' + [Environment]::NewLine + ($sourceStatus -join [Environment]::NewLine))
}
if ((git -C $source branch --show-current) -ne 'master') {
	throw 'Expected the source checkout to be on master.'
}
if (@(git -C $source remote).Count -ne 0) {
	throw 'Expected no configured source remotes before publication.'
}
git -C $source log -1 --oneline
~~~

Expected: clean output followed by the latest documentation-plan commit. Stop without changing anything if any assertion fails.

- [ ] **Step 2: Refuse to overwrite recovery or destination paths**

Run:

~~~powershell
$bundle = '<recovery-bundle>'
$destination = '<canonical-checkout>'
if (Test-Path -LiteralPath $bundle) {
	throw "Recovery bundle already exists: $bundle"
}
if (Test-Path -LiteralPath $destination) {
	throw "Canonical destination already exists: $destination"
}
~~~

Expected: no output and exit code 0.

- [ ] **Step 3: Create and verify the full recovery bundle**

Run:

~~~powershell
$source = '<legacy-source>'
$bundle = '<recovery-bundle>'
git -C $source bundle create $bundle --all
if ($LASTEXITCODE -ne 0) {
	throw 'Could not create the recovery bundle.'
}
git bundle verify $bundle
if ($LASTEXITCODE -ne 0) {
	throw 'Could not verify the recovery bundle.'
}
~~~

Expected: verification reports that the bundle is complete and records its refs.

- [ ] **Step 4: Record source invariants and clone without local object sharing**

Run:

~~~powershell
$source = '<legacy-source>'
$destination = '<canonical-checkout>'
$sourceTree = git -C $source rev-parse 'master^{tree}'
$sourceCommitCount = [int](git -C $source rev-list --count master)
$sourceSubjects = @(git -C $source log --reverse --format='%s' master)

git clone --no-local $source $destination
if ($LASTEXITCODE -ne 0) {
	throw 'Fresh canonical clone failed.'
}

$cloneTree = git -C $destination rev-parse 'master^{tree}'
$cloneCommitCount = [int](git -C $destination rev-list --count master)
$cloneSubjects = @(git -C $destination log --reverse --format='%s' master)

if ($cloneTree -ne $sourceTree) {
	throw 'Fresh clone tree does not match the source tree.'
}
if ($cloneCommitCount -ne $sourceCommitCount) {
	throw 'Fresh clone commit count does not match the source.'
}
if (($cloneSubjects -join [Environment]::NewLine) -ne ($sourceSubjects -join [Environment]::NewLine)) {
	throw 'Fresh clone commit subjects do not match the source.'
}
~~~

Expected: '<canonical-checkout>' exists as an independent clone with identical content and history.

- [ ] **Step 5: Confirm the recovery boundary**

Run:

~~~powershell
$destination = '<canonical-checkout>'
git -C $destination count-objects -vH
git -C $destination status --short
git -C $destination remote -v
~~~

Expected: clean status and a temporary 'origin' pointing to the local source. Do not delete or modify the old source checkout.

## Task 2: Authenticate and Rewrite Identity Metadata

**Files:**
- Modify history only in: '<canonical-checkout>'
- Create tool environment: '<tool-environment>'

- [ ] **Step 1: Install GitHub CLI only if it is absent**

Run:

~~~powershell
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
	winget install --id GitHub.cli --exact --source winget
	if ($LASTEXITCODE -ne 0) {
		throw 'GitHub CLI installation failed.'
	}
}
gh --version
~~~

Expected: GitHub CLI prints its installed version. If 'winget' is unavailable, stop and install GitHub CLI from the official package before continuing; do not substitute an unverified binary.

- [ ] **Step 2: Authenticate interactively to the intended personal account**

Run:

~~~powershell
gh auth login --hostname github.com --git-protocol https --web --scopes repo,workflow
gh auth status --hostname github.com
~~~

Expected: the browser authentication flow completes and names the intended personal account. This is a user-interaction checkpoint; never paste a token into a repository file or command history.

- [ ] **Step 3: Resolve the GitHub identity and local privacy address**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$account.login)) {
	throw 'GitHub login was not returned.'
}
if ([int64]$account.id -le 0) {
	throw 'GitHub numeric account ID was not returned.'
}
$owner = [string]$account.login
$noreply = "$($account.id)+$owner@users.noreply.github.com"
Write-Output "GitHub owner: $owner"
Write-Output "Noreply identity: $noreply"
~~~

Expected: the authenticated login and ID-based GitHub noreply address. Confirm the account is the intended personal owner before continuing.

- [ ] **Step 4: Create an isolated git-filter-repo environment**

Run:

~~~powershell
$toolRoot = '<tool-environment>'
if (-not (Test-Path -LiteralPath $toolRoot)) {
	py -m venv $toolRoot
	if ($LASTEXITCODE -ne 0) {
		throw 'Could not create the git-filter-repo virtual environment.'
	}
}
$toolPython = Join-Path $toolRoot 'Scripts\python.exe'
$filterRepo = Join-Path $toolRoot 'Scripts\git-filter-repo.exe'
& $toolPython -m pip install 'git-filter-repo==2.47.0'
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $filterRepo)) {
	throw 'Could not install git-filter-repo 2.47.0.'
}
& $filterRepo --version
~~~

Expected: git-filter-repo 2.47.0 is installed outside both repositories.

- [ ] **Step 5: Rewrite only author and committer email fields**

Run from '<canonical-checkout>':

~~~powershell
$destination = '<canonical-checkout>'
$source = '<legacy-source>'
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$noreply = "$($account.id)+$owner@users.noreply.github.com"
$filterRepo = '<filter-repo-executable>'
$sourceTree = git -C $source rev-parse 'master^{tree}'
$sourceCommitCount = [int](git -C $source rev-list --count master)
$sourceSubjects = @(git -C $source log --reverse --format='%s' master)
$callback = "commit.author_email = b'$noreply'; commit.committer_email = b'$noreply'"

& $filterRepo --commit-callback $callback
if ($LASTEXITCODE -ne 0) {
	throw 'History identity rewrite failed. Recover from the bundle or recreate the fresh clone.'
}
~~~

Expected: git-filter-repo reports a completed rewrite and removes the temporary local 'origin'.

- [ ] **Step 6: Rename the rewritten branch and set local commit identity**

Run:

~~~powershell
$destination = '<canonical-checkout>'
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$noreply = "$($account.id)+$owner@users.noreply.github.com"
git -C $destination branch -m master main
git -C $destination config user.email $noreply
$currentName = git -C $destination config user.name
if ([string]::IsNullOrWhiteSpace($currentName)) {
	git -C $destination config user.name $owner
}
~~~

Expected: the canonical clone is on 'main', and future commits use the noreply email.

- [ ] **Step 7: Verify content and history invariants after the rewrite**

Run:

~~~powershell
$destination = '<canonical-checkout>'
$source = '<legacy-source>'
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$noreply = "$($account.id)+$owner@users.noreply.github.com"
$sourceTree = git -C $source rev-parse 'master^{tree}'
$sourceCommitCount = [int](git -C $source rev-list --count master)
$sourceSubjects = @(git -C $source log --reverse --format='%s' master)
$rewrittenTree = git -C $destination rev-parse 'main^{tree}'
$rewrittenCommitCount = [int](git -C $destination rev-list --count main)
$rewrittenSubjects = @(git -C $destination log --reverse --format='%s' main)
$rewrittenEmails = @(
	git -C $destination log --all --format='%ae%n%ce' |
		Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
		Sort-Object -Unique
)

if ($rewrittenTree -ne $sourceTree) {
	throw 'History rewrite changed project file content.'
}
if ($rewrittenCommitCount -ne $sourceCommitCount) {
	throw 'History rewrite changed the commit count.'
}
if (($rewrittenSubjects -join [Environment]::NewLine) -ne ($sourceSubjects -join [Environment]::NewLine)) {
	throw 'History rewrite changed commit subjects or order.'
}
if ($rewrittenEmails.Count -ne 1 -or $rewrittenEmails[0] -ne $noreply) {
	throw "Unexpected rewritten emails: $($rewrittenEmails -join ', ')"
}
if (@(git -C $destination remote).Count -ne 0) {
	throw 'Expected git-filter-repo to remove the temporary local origin.'
}

git -C $destination fsck --full
git -C $destination status --short
~~~

Expected: identical tip tree, commit count, and subject ordering; exactly one author/committer email; no remote; clean status; successful 'git fsck'.

## Task 3: Add Private Repository Documentation

**Files:**
- Create: 'README.md'
- Create: 'CONTRIBUTING.md'
- Create: 'SECURITY.md'
- Create: '.github/pull_request_template.md'

- [ ] **Step 1: Create the project README**

Create 'README.md' with exactly:

~~~~markdown
# Crypts & Cairns

Crypts & Cairns is a deterministic, turn-based simulation of living in a
game-like world built around expeditions into a lethal labyrinth.

> This is a private foundation-stage project. The current build validates the
> deterministic state, command, replay, random-stream, and data-loading layers;
> it is not yet a playable game slice.

## Target

- Godot 4.7.2, standard build
- Desktop browsers
- Pixel-art presentation
- Action-point turn-based combat
- Knowledge-only persistence between mortal runs

## Open the project

Open 'project.godot' in the standard Godot 4.7.2 editor and run the main scene.

## Test

From PowerShell, with Godot 4.7.2 available on 'PATH':

~~~powershell
$godot = (Get-Command godot -ErrorAction Stop).Source
.\scripts\test.ps1 -GodotBin $godot
~~~

The foundation suite must complete with zero failures.

## Export for Web

~~~powershell
$godot = (Get-Command godot -ErrorAction Stop).Source
.\scripts\export-web.ps1 -GodotBin $godot
~~~

The export is written to 'build/web/'. Generated Godot and build directories
are intentionally ignored by Git.

## Repository map

- 'content/' — authoritative data definitions and localization
- 'src/domain/' — deterministic state, content rules, hashing, and random streams
- 'src/application/' — commands and replay orchestration
- 'src/platform/' — JSON and content loading boundaries
- 'src/presentation/' — Godot scenes and presentation code
- 'tests/' — headless foundation suite and fixtures
- 'docs/' — approved design, provenance, plans, and development notes
- 'scripts/' — local test and Web-export entry points

## Design and provenance

- [Game design](docs/superpowers/specs/2026-10-25-crypts-and-cairns-design.md)
- [Naming registry](docs/design/naming-registry.md)
- [Source provenance ledger](docs/design/source-provenance.md)
- [Foundation notes](docs/development/foundation.md)

World terminology must follow the naming registry. New evidence or inspiration
that affects a world element must be recorded in the provenance ledger.

## License status

This private repository is not yet licensed for redistribution. No permission
to copy, redistribute, publish, or create derivative works from its code,
content, or assets is granted by its presence on GitHub.
~~~~

- [ ] **Step 2: Create contribution guidance**

Create 'CONTRIBUTING.md' with exactly:

~~~~markdown
# Contributing to Crypts & Cairns

Crypts & Cairns is currently a private project. Contributors must have explicit
repository access and must preserve the approved design and deterministic
foundation.

## Workflow

1. Branch from the current 'main'.
2. Keep one coherent change per branch.
3. Add or update tests before changing deterministic or validation behavior.
4. Run the complete test suite.
5. Run the Web export for changes that can affect startup, content packaging, or
   presentation.
6. Open a pull request and complete every applicable checklist item.
7. Merge only after required checks pass and review conversations are resolved.

Do not push feature work directly to 'main'.

## Required verification

~~~powershell
$godot = (Get-Command godot -ErrorAction Stop).Source
.\scripts\validate-github-readiness.ps1
.\scripts\test.ps1 -GodotBin $godot
.\scripts\export-web.ps1 -GodotBin $godot
~~~

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
- Follow 'docs/design/naming-registry.md'.
- Update 'docs/design/source-provenance.md' when new external evidence informs a
  world element.
- Generic terms may remain generic only where the naming registry permits them.
- Do not copy names, text, art, maps, UI, or other expressive material from the
  inspiration work.

## Generated and sensitive files

Do not commit:

- '.godot/' or 'build/' output;
- local credentials, access tokens, private keys, or machine identifiers;
- editor caches or temporary exports;
- third-party assets without recorded provenance and permission.
~~~~

- [ ] **Step 3: Create the security policy**

Create 'SECURITY.md' with exactly:

~~~markdown
# Security Policy

## Supported version

Security fixes apply to the current 'main' branch during private development.

## Reporting

Do not disclose a suspected vulnerability in ordinary issue or pull-request
discussion. Contact the repository owner through an existing private channel or
open a draft GitHub security advisory for the repository.

Include the affected revision, reproduction steps, expected and observed
behavior, impact, and any suggested mitigation. Do not include real
credentials, tokens, keys, machine identifiers, or unrelated personal data.

## Secret handling

Never commit secrets. If a secret enters Git history, stop publication and
rotation work, notify the owner privately, revoke or rotate the secret, and
clean every reachable ref before further pushes.
~~~

- [ ] **Step 4: Create the pull-request template**

Create '.github/pull_request_template.md' with exactly:

~~~markdown
## Summary

Describe the player-facing or technical outcome and why the change is needed.

## Verification

- [ ] The full foundation test suite passes.
- [ ] The Godot Web export passes when startup, packaging, content, or
      presentation can be affected.
- [ ] New deterministic or validation behavior has regression coverage.
- [ ] Replay and authoritative RNG implications were reviewed.
- [ ] Content schema, manifest, and localization implications were reviewed.
- [ ] Naming-registry implications were reviewed.
- [ ] Source-provenance implications were reviewed.
- [ ] No credentials, machine identifiers, generated '.godot/' files, or
      'build/' output are included.

## Notes

Record intentional follow-up work, migration concerns, or reviewer context.
~~~

- [ ] **Step 5: Verify documentation paths and license absence**

Run:

~~~powershell
$required = @(
	'README.md',
	'CONTRIBUTING.md',
	'SECURITY.md',
	'.github/pull_request_template.md',
	'docs/superpowers/specs/2026-10-25-crypts-and-cairns-design.md',
	'docs/design/naming-registry.md',
	'docs/design/source-provenance.md',
	'docs/development/foundation.md'
)
foreach ($path in $required) {
	if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
		throw "Missing documentation path: $path"
	}
}
if (Get-ChildItem -File -Name 'LICENSE*' -ErrorAction SilentlyContinue) {
	throw 'A license file was added outside the approved scope.'
}
git diff --check
~~~

Expected: no missing paths, no license file, and no whitespace errors.

- [ ] **Step 6: Commit the documentation baseline**

Run:

~~~powershell
git add README.md CONTRIBUTING.md SECURITY.md .github/pull_request_template.md
git commit -m 'docs: add private repository guidance'
~~~

Expected: one documentation commit authored with the GitHub noreply identity.


## Task 4: Add Readiness Validation, CI, and the Stored Ruleset

**Files:**
- Create: 'scripts/validate-github-readiness.ps1'
- Create: '.github/workflows/foundation.yml'
- Create: '.github/rulesets/main.json'

- [ ] **Step 1: Write the readiness validator before its required files exist**

Create 'scripts/validate-github-readiness.ps1' with exactly:

~~~powershell
param(
	[string]$RepositoryRoot = (
		Split-Path -Parent $PSScriptRoot
	)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$failures = [System.Collections.Generic.List[string]]::new()
$requiredFiles = @(
	'README.md',
	'CONTRIBUTING.md',
	'SECURITY.md',
	'.github/pull_request_template.md',
	'.github/workflows/foundation.yml',
	'.github/rulesets/main.json',
	'docs/superpowers/specs/2026-10-25-crypts-and-cairns-design.md',
	'docs/design/naming-registry.md',
	'docs/design/source-provenance.md',
	'docs/development/foundation.md'
)

foreach ($relativePath in $requiredFiles) {
	$absolutePath = Join-Path $RepositoryRoot $relativePath
	if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
		$failures.Add("Missing required file: $relativePath")
	}
}

$licenseFiles = @(
	Get-ChildItem -LiteralPath $RepositoryRoot -File -Filter 'LICENSE*'
)
if ($licenseFiles.Count -gt 0) {
	$failures.Add('A license file exists before licensing has been approved.')
}

$workflowPath = Join-Path $RepositoryRoot '.github/workflows/foundation.yml'
if (Test-Path -LiteralPath $workflowPath -PathType Leaf) {
	$workflow = Get-Content -LiteralPath $workflowPath -Raw
	$requiredWorkflowFragments = @(
		'name: Foundation',
		'permissions:',
		'contents: read',
		'timeout-minutes: 15',
		'cancel-in-progress: true',
		'version: 4.7.2',
		'use-dotnet: false',
		'include-templates: true',
		'.\scripts\test.ps1',
		'.\scripts\export-web.ps1',
		'retention-days: 7',
		'11d5960a326750d5838078e36cf38b85af677262',
		'ac93246ea68518a384c1c280a496e5989341f2f6',
		'ea165f8d65b6e75b540449e92b4886f43607fa02'
	)
	foreach ($fragment in $requiredWorkflowFragments) {
		if (-not $workflow.Contains($fragment)) {
			$failures.Add("Workflow is missing required fragment: $fragment")
		}
	}
	$forbiddenWorkflowPatterns = @(
		'(?im)^\s*pages:\s*write\s*$',
		'(?im)^\s*id-token:\s*write\s*$',
		'actions/deploy-pages',
		'softprops/action-gh-release',
		'gh\s+release\s+create'
	)
	foreach ($pattern in $forbiddenWorkflowPatterns) {
		if ($workflow -match $pattern) {
			$failures.Add("Workflow contains forbidden deployment behavior: $pattern")
		}
	}
}

$readmePath = Join-Path $RepositoryRoot 'README.md'
if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
	$readme = Get-Content -LiteralPath $readmePath -Raw
	foreach ($link in @(
		'docs/superpowers/specs/2026-10-25-crypts-and-cairns-design.md',
		'docs/design/naming-registry.md',
		'docs/design/source-provenance.md',
		'docs/development/foundation.md'
	)) {
		if (-not $readme.Contains($link)) {
			$failures.Add("README is missing required link: $link")
		}
	}
}

if ($failures.Count -gt 0) {
	throw ('GitHub readiness validation failed:' + [Environment]::NewLine + '- ' + ($failures -join ([Environment]::NewLine + '- ')))
}

Write-Output 'GitHub readiness validation passed.'
~~~

- [ ] **Step 2: Run the validator to prove the missing CI files are detected**

Run:

~~~powershell
.\scripts\validate-github-readiness.ps1
~~~

Expected: FAIL listing '.github/workflows/foundation.yml' and '.github/rulesets/main.json' as missing. Do not weaken the validator.

- [ ] **Step 3: Create the pinned foundation workflow**

Create '.github/workflows/foundation.yml' with exactly:

~~~yaml
name: Foundation

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

permissions:
  contents: read

concurrency:
  group: foundation-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  verify:
    name: Verify foundation
    runs-on: windows-latest
    timeout-minutes: 15

    steps:
      - name: Check out repository
        uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262

      - name: Install Godot 4.7.2
        uses: chickensoft-games/setup-godot@ac93246ea68518a384c1c280a496e5989341f2f6
        with:
          version: 4.7.2
          use-dotnet: false
          include-templates: true

      - name: Validate repository metadata
        shell: pwsh
        run: .\scripts\validate-github-readiness.ps1

      - name: Run foundation tests
        shell: pwsh
        run: |
          $godot = (Get-Command godot -ErrorAction Stop).Source
          .\scripts\test.ps1 -GodotBin $godot

      - name: Export Web build
        shell: pwsh
        run: |
          $godot = (Get-Command godot -ErrorAction Stop).Source
          .\scripts\export-web.ps1 -GodotBin $godot

      - name: Upload Web build
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02
        with:
          name: crypts-and-cairns-web-${{ github.sha }}
          path: build/web
          if-no-files-found: error
          retention-days: 7
~~~

The three actions are pinned to full commit SHAs resolved from their official repositories. Do not replace them with mutable major-version tags.

- [ ] **Step 4: Create the reproducible main ruleset payload**

Create '.github/rulesets/main.json' with exactly:

~~~json
{
  "name": "Protect main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "required_linear_history"},
    {
      "type": "pull_request",
      "parameters": {
        "allowed_merge_methods": ["squash", "rebase"],
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_approving_review_count": 0,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "do_not_enforce_on_create": true,
        "required_status_checks": [
          {"context": "Verify foundation"}
        ],
        "strict_required_status_checks_policy": true
      }
    }
  ]
}
~~~

This payload is stored for auditability but is not automatically applied by GitHub.

- [ ] **Step 5: Run the validator to green**

Run:

~~~powershell
.\scripts\validate-github-readiness.ps1
git diff --check
~~~

Expected: 'GitHub readiness validation passed.' and no whitespace errors.

- [ ] **Step 6: Commit CI and readiness metadata**

Run:

~~~powershell
git add scripts/validate-github-readiness.ps1 .github/workflows/foundation.yml .github/rulesets/main.json
git commit -m 'ci: verify foundation and Web export'
~~~

Expected: one commit authored with the GitHub noreply identity.

## Task 5: Run Local Publication Gates

**Files:**
- Verify: entire canonical checkout
- Generate ignored output: 'build/web/' and '.godot/'

- [ ] **Step 1: Validate metadata and run all foundation tests**

Run:

~~~powershell
$godot = '<godot-executable>'
.\scripts\validate-github-readiness.ps1
.\scripts\test.ps1 -GodotBin $godot
~~~

Expected: readiness passes; 10 test cases, 225 assertions, 0 failures.

- [ ] **Step 2: Run the production Web export**

Run:

~~~powershell
.\scripts\export-web.ps1 -GodotBin $godot
~~~

Expected: successful export to 'build/web/index.html', including all four authoritative content JSON files in the pack log.

- [ ] **Step 3: Scan current content and all history for obvious secrets**

Run:

~~~powershell
$pattern = 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|password[[:space:]]*[:=]|secret[[:space:]]*[:=]|api[_-]?key[[:space:]]*[:=]'
$currentHits = @(git grep -I -l -E $pattern HEAD 2>$null)
$historyHits = [System.Collections.Generic.List[string]]::new()
foreach ($commit in @(git rev-list --all)) {
	foreach ($hit in @(git grep -I -l -E $pattern $commit 2>$null)) {
		$historyHits.Add($hit)
	}
}
if ($currentHits.Count -gt 0 -or $historyHits.Count -gt 0) {
	throw ('Potential secret-pattern files found. Current: ' + ($currentHits -join ', ') + '; history: ' + ($historyHits -join ', '))
}
~~~

Expected: no hits. This is a publication gate, not proof that no secret exists.

- [ ] **Step 4: Reject tracked blobs at or above GitHub's 50 MiB warning threshold**

Run:

~~~powershell
$limit = 50MB
$oversized = [System.Collections.Generic.List[string]]::new()
foreach ($line in @(git rev-list --objects --all)) {
	$parts = $line -split ' ', 2
	if ($parts.Count -ne 2) {
		continue
	}
	$size = [int64](git cat-file -s $parts[0])
	if ($size -ge $limit) {
		$oversized.Add("$size bytes $($parts[1])")
	}
}
if ($oversized.Count -gt 0) {
	throw ('Tracked blobs reach 50 MiB:' + [Environment]::NewLine + ($oversized -join [Environment]::NewLine))
}
~~~

Expected: no oversized blobs.

- [ ] **Step 5: Verify final local state**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$noreply = "$($account.id)+$owner@users.noreply.github.com"
$emails = @(git log --all --format='%ae%n%ce' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
if ($emails.Count -ne 1 -or $emails[0] -ne $noreply) {
	throw "Unexpected commit identities: $($emails -join ', ')"
}
if ((git branch --show-current) -ne 'main') {
	throw 'Canonical checkout is not on main.'
}
if (@(git remote).Count -ne 0) {
	throw 'A remote was added before all local publication gates passed.'
}
git status --short
git log --oneline -5
~~~

Expected: 'main', no remote, one noreply email, and clean status.

## Task 6: Create the Empty Private Repository and Push Once

**Files:**
- Remote repository: the authenticated personal account's 'crypts-and-cairns'
- Configure local Git remote: 'origin'

- [ ] **Step 1: Reconfirm authenticated ownership and repository absence**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
$existing = gh api "repos/$owner/$repoName" 2>$null
if ($LASTEXITCODE -eq 0) {
	throw "Repository already exists: $owner/$repoName"
}
~~~

Expected: not found. If the repository exists, stop and inspect it; do not overwrite or push.

- [ ] **Step 2: Create an empty private repository and add origin**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
gh repo create $repoName --private --source=. --remote=origin --description 'A deterministic, turn-based labyrinth survival RPG built with Godot 4.'
if ($LASTEXITCODE -ne 0) {
	throw 'Private GitHub repository creation failed.'
}
$remote = gh api "repos/$owner/$repoName" | ConvertFrom-Json
if (-not [bool]$remote.private) {
	throw 'Created repository is not private. Stop before pushing.'
}
if ([int64]$remote.size -ne 0) {
	throw 'Created repository is not empty. Stop before pushing.'
}
git remote -v
~~~

Expected: an empty private repository and one 'origin' remote owned by the authenticated personal account.

- [ ] **Step 3: Push main and set its upstream**

Run:

~~~powershell
git push --set-upstream origin main
if ($LASTEXITCODE -ne 0) {
	throw 'First push failed. Preserve local history and diagnose before retrying.'
}
~~~

Expected: a new 'origin/main'; no force push.

- [ ] **Step 4: Set and verify the remote default branch**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
gh api --method PATCH "repos/$owner/$repoName" -f default_branch=main -F has_wiki=false | Out-Null
$remote = gh api "repos/$owner/$repoName" | ConvertFrom-Json
if (-not [bool]$remote.private) {
	throw 'Remote visibility changed unexpectedly.'
}
if ([string]$remote.default_branch -ne 'main') {
	throw 'Remote default branch is not main.'
}
if ([bool]$remote.has_wiki) {
	throw 'Repository wiki should be disabled for this baseline.'
}
~~~

Expected: private visibility, 'main' as default, wiki disabled.

- [ ] **Step 5: Verify local tracking and exact remote revision**

Run:

~~~powershell
git fetch origin
$localHead = git rev-parse main
$remoteHead = git rev-parse origin/main
if ($localHead -ne $remoteHead) {
	throw 'Local and remote main revisions differ.'
}
if ((git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}') -ne 'origin/main') {
	throw 'Local main does not track origin/main.'
}
git status --short
~~~

Expected: identical hashes, correct upstream, clean status.

## Task 7: Verify the First GitHub Actions Run

**Files:**
- Read remote workflow: '.github/workflows/foundation.yml'
- Download artifact outside repository: '<ci-artifact-directory>'

- [ ] **Step 1: Wait for the push workflow to appear with bounded polling**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
$repository = "$owner/$repoName"
$deadline = [DateTime]::UtcNow.AddMinutes(3)
$runId = $null
while ([DateTime]::UtcNow -lt $deadline -and $null -eq $runId) {
	$runIdText = gh run list --repo $repository --workflow foundation.yml --branch main --event push --limit 1 --json databaseId --jq '.[0].databaseId'
	if (-not [string]::IsNullOrWhiteSpace($runIdText)) {
		$runId = [int64]$runIdText
		break
	}
	Start-Sleep -Seconds 5
}
if ($null -eq $runId) {
	throw 'Foundation workflow did not appear within three minutes.'
}
Write-Output "Workflow run: $runId"
~~~

Expected: a workflow run ID. During agent execution, poll in short intervals and keep the user informed.

- [ ] **Step 2: Watch the workflow to completion**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
$repository = "$owner/$repoName"
$runId = [int64](gh run list --repo $repository --workflow foundation.yml --branch main --event push --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch $runId --repo $repository --compact --exit-status
if ($LASTEXITCODE -ne 0) {
	gh run view $runId --repo $repository --log-failed
	throw 'Foundation workflow failed.'
}
~~~

Expected: successful metadata validation, tests, Web export, and artifact upload.

- [ ] **Step 3: Verify the stable status-check context**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
$checks = @(gh api "repos/$owner/$repoName/commits/main/check-runs" --jq '.check_runs[].name')
if ($checks -notcontains 'Verify foundation') {
	throw "Expected status check is missing. Found: $($checks -join ', ')"
}
~~~

Expected: 'Verify foundation' is present.

- [ ] **Step 4: Download and inspect the Web artifact without overwriting**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
$repository = "$owner/$repoName"
$runId = [int64](gh run list --repo $repository --workflow foundation.yml --branch main --event push --limit 1 --json databaseId --jq '.[0].databaseId')
$artifactDestination = '<ci-artifact-directory>'
if (Test-Path -LiteralPath $artifactDestination) {
	throw "Artifact destination already exists: $artifactDestination"
}
New-Item -ItemType Directory -Path $artifactDestination | Out-Null
$artifactName = 'crypts-and-cairns-web-' + (git rev-parse HEAD)
gh run download $runId --repo $repository --name $artifactName --dir $artifactDestination
if ($LASTEXITCODE -ne 0) {
	throw 'Could not download the CI Web artifact.'
}
foreach ($file in @('index.html', 'index.js', 'index.wasm', 'index.pck')) {
	$match = Get-ChildItem -LiteralPath $artifactDestination -Recurse -File -Filter $file
	if (@($match).Count -eq 0) {
		throw "CI artifact is missing $file"
	}
}
~~~

Expected: nonempty exported Web files. Keep the artifact directory until final verification is complete.

## Task 8: Protect Main When the GitHub Plan Supports Private Rulesets

**Files:**
- Read: '.github/rulesets/main.json'
- Create remote ruleset: 'Protect main'

- [ ] **Step 1: Check account-plan support before applying the ruleset**

Run:

~~~powershell
$planName = [string](gh api user --jq '.plan.name')
Write-Output "GitHub plan: $planName"
if ($planName -notin @('pro', 'team', 'enterprise')) {
	throw ('Private personal repository rulesets require a supporting GitHub plan. Ask the owner to choose between upgrading or accepting an unenforced main branch. Do not make the repository public as a workaround.')
}
~~~

Expected: a plan supporting private-repository rulesets. Current GitHub documentation limits this to GitHub Pro, Team, and Enterprise plans.

- [ ] **Step 2: Ensure the ruleset does not already exist**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
$existingRuleset = gh api "repos/$owner/$repoName/rulesets" --jq '.[] | select(.name == "Protect main") | .id'
if (-not [string]::IsNullOrWhiteSpace($existingRuleset)) {
	throw "Protect main ruleset already exists with ID $existingRuleset"
}
~~~

Expected: no existing matching ruleset.

- [ ] **Step 3: Apply the reviewed ruleset payload**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
gh api --method POST "repos/$owner/$repoName/rulesets" --input .github/rulesets/main.json | Out-Null
if ($LASTEXITCODE -ne 0) {
	throw 'Could not create the Protect main ruleset.'
}
~~~

Expected: HTTP 201 through GitHub CLI.

- [ ] **Step 4: Verify every required remote rule**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
$rulesetList = @(gh api "repos/$owner/$repoName/rulesets" | ConvertFrom-Json)
$rulesetSummary = @($rulesetList | Where-Object name -eq 'Protect main')
if ($rulesetSummary.Count -ne 1) {
	throw 'Expected exactly one Protect main ruleset.'
}
$rulesetId = [int64]$rulesetSummary[0].id
$ruleset = gh api "repos/$owner/$repoName/rulesets/$rulesetId" | ConvertFrom-Json
if ($ruleset.enforcement -ne 'active') {
	throw 'Protect main ruleset is not active.'
}
$ruleTypes = @($ruleset.rules.type)
foreach ($requiredType in @('deletion', 'non_fast_forward', 'required_linear_history', 'pull_request', 'required_status_checks')) {
	if ($ruleTypes -notcontains $requiredType) {
		throw "Protect main is missing rule: $requiredType"
	}
}
$statusRule = @($ruleset.rules | Where-Object type -eq 'required_status_checks')[0]
$contexts = @($statusRule.parameters.required_status_checks.context)
if ($contexts -notcontains 'Verify foundation') {
	throw 'Protect main does not require Verify foundation.'
}
~~~

Expected: one active ruleset with all approved protections and the strict 'Verify foundation' check.

## Task 9: Final End-to-End Verification and Handoff

**Files:**
- Verify canonical checkout: '<canonical-checkout>'
- Preserve legacy source: '<legacy-source>'
- Preserve bundle: '<recovery-bundle>'

- [ ] **Step 1: Run a final local suite and export**

Run:

~~~powershell
$godot = '<godot-executable>'
.\scripts\validate-github-readiness.ps1
.\scripts\test.ps1 -GodotBin $godot
.\scripts\export-web.ps1 -GodotBin $godot
~~~

Expected: readiness passes; 225 assertions, zero failures; Web export succeeds.

- [ ] **Step 2: Verify the local and remote contract**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
if ((git branch --show-current) -ne 'main') {
	throw 'Canonical checkout is not on main.'
}
if ((git remote get-url origin) -notmatch 'github\.com[:/].+/crypts-and-cairns(\.git)?$') {
	throw 'Origin does not target crypts-and-cairns on GitHub.'
}
if ((git rev-parse HEAD) -ne (git rev-parse origin/main)) {
	throw 'Canonical main differs from origin/main.'
}
$remote = gh api "repos/$owner/$repoName" | ConvertFrom-Json
if (-not [bool]$remote.private -or $remote.default_branch -ne 'main') {
	throw 'Remote privacy or default branch is incorrect.'
}
if (@(git status --short).Count -ne 0) {
	throw 'Canonical checkout is not clean.'
}
~~~

Expected: clean 'main', exact upstream match, private remote, correct default branch.

- [ ] **Step 3: Preserve recovery sources and identify the canonical checkout**

Do not delete, move, reset, or add a GitHub remote to '<legacy-source>'. Report:

~~~text
Canonical GitHub-connected checkout:
<canonical-checkout>

Legacy local source retained for recovery:
<legacy-source>

Verified pre-rewrite bundle:
<recovery-bundle>
~~~

The owner can decide in a later cleanup task whether to archive the legacy checkout and bundle.

- [ ] **Step 4: Record final evidence**

Run:

~~~powershell
$account = gh api user | ConvertFrom-Json
$owner = [string]$account.login
$repoName = 'crypts-and-cairns'
git log --oneline -5
git status --short
git branch -vv
git remote -v
gh repo view "$owner/$repoName" --json nameWithOwner,visibility,defaultBranchRef,url
gh run list --repo "$owner/$repoName" --workflow foundation.yml --branch main --limit 1
gh api "repos/$owner/$repoName/rulesets" --jq '.[] | {name, enforcement, id}'
~~~

Expected: private 'crypts-and-cairns', clean tracked 'main', successful CI, and active 'Protect main' ruleset when account-plan support is available.

## References

- GitHub Docs: Adding locally hosted code to GitHub
  https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github
- GitHub Docs: Email addresses reference
  https://docs.github.com/en/account-and-profile/reference/email-addresses-reference
- GitHub Docs: Secure use of GitHub Actions
  https://docs.github.com/en/actions/reference/security/secure-use
- GitHub Docs: About large files on GitHub
  https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
- GitHub Docs: Creating rulesets
  https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository
- git-filter-repo documentation
  https://github.com/newren/git-filter-repo/blob/main/Documentation/git-filter-repo.txt
- GitHub CLI 'gh repo create'
  https://cli.github.com/manual/gh_repo_create
- setup-godot
  https://github.com/chickensoft-games/setup-godot


