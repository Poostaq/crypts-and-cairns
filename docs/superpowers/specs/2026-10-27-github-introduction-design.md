# GitHub Introduction Design

**Status:** Proposed for implementation

**Date:** 2026-10-27

**Repository:** Crypts & Cairns

## Execution Amendment: Public Visibility

Private visibility was selected for the initial GitHub introduction. During
execution, the current GitHub Free account was found not to support rulesets or
protected branches for a private personal repository. The owner explicitly
authorized public visibility so the approved `main` protections can remain in
scope.

This amendment overrides the private-visibility steps and expectations below.
It does not add or approve an open-source license, an additional reuse grant,
a GitHub Pages deployment, or a release. Public availability carries only the
limited rights described in
[GitHub's Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#5-license-grant-to-other-users),
including viewing and forking through GitHub's platform features.

A post-publication hardening follow-up enables private vulnerability reporting,
secret scanning, and secret-scanning push protection. It also records the solo
maintainer policy explicitly by setting unattributed-change extra approval to
`false` in both the stored and live ruleset.

## Purpose

Introduce the existing local repository to GitHub as a private repository under
the owner's personal account. The setup must preserve a recoverable copy of the
current history, protect author-email privacy, establish a useful private
development baseline, and avoid prematurely making licensing or public-release
decisions.

The GitHub repository slug will be `crypts-and-cairns`. Its default branch will
be `main`.

## Scope

This introduction includes:

- a recoverable backup of all local Git refs before history changes;
- replacement of existing author and committer emails with the owner's
  authenticated GitHub `noreply` identity;
- renaming the local default branch from `master` to `main`;
- essential repository documentation and contribution guidance;
- continuous integration for the deterministic foundation tests and Godot Web
  export;
- creation of an empty private GitHub repository and the first push;
- practical protection of `main` after the first successful CI run.

This introduction does not include:

- making the repository public;
- choosing or adding a software or content license;
- deploying the game through GitHub Pages;
- publishing a release;
- adding dependency automation without a real dependency-management need;
- adding organization-level governance to a personal repository.

## Repository Preparation

Implementation starts only from a clean checkout whose `HEAD` is the verified
foundation revision or its direct descendant.

Before rewriting history, create a Git bundle outside the repository that
contains every local ref. Verify the bundle immediately. This bundle is the
recovery point if the identity rewrite produces an unexpected result.

The rewrite changes author and committer email fields to the owner's GitHub
`noreply` address. It preserves names, commit messages, timestamps, tree
contents, parent ordering, and branch topology. Because the repository has not
been pushed, the rewrite happens before any remote is added and does not
require a force-push.

After the rewrite, rename `master` to `main`. Re-run the complete foundation
test suite and Web export against the rewritten `main` history before creating
or pushing to a remote.

## GitHub-Facing Files

### `README.md`

The README will contain:

- the project name and concise game premise;
- a clear foundation-stage status statement;
- the Godot 4.7.2 and desktop-browser targets;
- local editor, test, and Web-export commands;
- a short repository map;
- links to the approved design specification, naming registry, source
  provenance ledger, and foundation development notes;
- a statement that the repository has no open-source license or additional
  reuse grant beyond the limited platform rights provided by GitHub's Terms of
  Service.

The README must describe Crypts & Cairns in its approved original terminology.
It must not promise that the project is legally risk-free.

### `CONTRIBUTING.md`

Contribution guidance will require:

- work on a focused feature branch rather than directly on `main`;
- tests for deterministic domain and content behavior;
- a successful full suite and Web export before review;
- data-driven definitions for gameplay content;
- naming-registry and provenance-ledger updates when world terms or external
  evidence change;
- preservation of replay determinism and authoritative integer handling.

### `SECURITY.md`

Security guidance will prohibit committing credentials, tokens, private keys,
or personal machine data. Private vulnerability reporting will be enabled, and
reports should use **Security** > **Advisories** > **Report a vulnerability**,
with an existing private owner channel as fallback. No contact email will be
embedded in the repository.

### `.github/pull_request_template.md`

The pull-request checklist will cover:

- focused scope and an explanatory summary;
- foundation test results;
- successful Web export when relevant;
- determinism and replay impact;
- content schema and validation impact;
- naming and source-provenance impact;
- confirmation that no credentials or generated build output were committed.

### `.github/workflows/foundation.yml`

The workflow will run for pull requests targeting `main` and pushes to `main`.
It will:

- use read-only repository permissions;
- cancel superseded runs for the same branch or pull request;
- use a finite job timeout;
- install exactly Godot 4.7.2 with Web export templates through a
  revision-pinned setup action;
- run the existing PowerShell test script;
- run the existing PowerShell Web-export script;
- upload the resulting Web build as a short-retention workflow artifact;
- avoid deployment, releases, or GitHub Pages.

The workflow job and check names must be stable so the successful check can be
required by the `main` ruleset.

## Remote Creation and First Push

Authenticate to GitHub without placing a token in the repository or shell
history. Create `crypts-and-cairns` under the authenticated personal account as
an empty private repository. Do not ask GitHub to generate a README, license,
or `.gitignore`, because the local repository already owns its initial history.

Add the new repository as `origin`, verify both fetch and push URLs, then push
`main` and set its upstream. Verify on GitHub that:

- repository visibility is public under the execution amendment;
- `main` is the default branch;
- all expected commits and files are present;
- the foundation workflow starts and succeeds;
- the Web artifact is attached to the workflow run;
- no generated `build/` or `.godot/` content was committed.

GitHub's documented import flow likewise recommends creating an empty remote
for an existing local repository before adding `origin` and pushing the local
default branch.

## Branch Protection

Configure a ruleset targeting the default branch only after the first workflow
run has registered its check. The initial solo-development ruleset will:

- block branch deletion;
- block force-pushes;
- require pull requests before changes reach `main`;
- require the foundation CI check to pass;
- require pull-request conversations to be resolved;
- allow a linear history.

The ruleset will not initially require another person's approval. That avoids
deadlocking a personal repository while still requiring reviewable pull
requests and automated verification. Approval requirements can be added when a
second maintainer joins. The pull-request rule will explicitly set
`require_extra_approval_for_unattributed_changes` to `false` rather than relying
on GitHub's default.

## Validation and Failure Handling

Publication stops before the first push if any of these checks fail:

- the working tree is not clean;
- the backup bundle cannot be verified;
- the rewritten history contains an unintended email identity;
- the full Godot test suite fails;
- the Web export fails;
- a credential/private-key pattern is found in the current tree or history;
- a tracked file exceeds the agreed repository-size threshold;
- the remote repository is not empty and private;
- the authenticated account is not the intended personal owner.

If remote creation succeeds but the first push fails, retain the local
repository and diagnose authentication, permissions, branch naming, and remote
URL configuration before retrying. Do not discard or rewrite the verified local
history again.

## Success Criteria

The introduction is complete when:

- local development uses `main`;
- history contains only the intended GitHub `noreply` email identity or
  identities explicitly approved by the owner;
- `origin` points to the public personal repository named
  `crypts-and-cairns`;
- local `main` tracks `origin/main`;
- README and contribution/security guidance render correctly on GitHub;
- foundation tests and Web export pass locally and in GitHub Actions;
- `main` is protected by the approved ruleset;
- no license, Pages deployment, or public release has been added.

## References

- [Adding locally hosted code to GitHub](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)
- [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)

