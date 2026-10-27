param(
	[string]$RepositoryRoot = (
		Split-Path -Parent $PSScriptRoot
	)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NormalizedSha256 {
	param(
		[Parameter(Mandatory)]
		[string]$Path
	)

	$content = [System.IO.File]::ReadAllText($Path)
	$normalized = $content.Replace("`r`n", "`n").Replace("`r", "`n")
	$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
	$bytes = $utf8WithoutBom.GetBytes($normalized)
	return [Convert]::ToHexString(
		[System.Security.Cryptography.SHA256]::HashData($bytes)
	).ToLowerInvariant()
}

function Get-JsonPropertyValue {
	param(
		[AllowNull()]
		[object]$InputObject,
		[Parameter(Mandatory)]
		[string]$Name
	)

	if ($null -eq $InputObject) {
		return $null
	}
	$property = $InputObject.PSObject.Properties[$Name]
	if ($null -eq $property) {
		return $null
	}
	return $property.Value
}

$failures = [System.Collections.Generic.List[string]]::new()
$requiredFiles = @(
	'README.md',
	'CONTRIBUTING.md',
	'SECURITY.md',
	'.github/pull_request_template.md',
	'.github/approved-author-emails.txt',
	'.github/workflows/foundation.yml',
	'.github/rulesets/main.json',
	'scripts/GodotProcess.psm1',
	'scripts/validate-publication.ps1',
	'scripts/verify-web-pck.ps1',
	'tests/scripts/godot_process_test.ps1',
	'tests/scripts/publication_validator_test.ps1',
	'tests/scripts/web_pck_verifier_test.ps1',
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

# GitHub Licensee treats these conventional root names as license candidates.
$licenseCandidatePattern = '^(?:LICENSE|LICENCE|COPYING|COPYRIGHT|UNLICENSE)(?:-[A-Za-z0-9][A-Za-z0-9.-]*)?(?:\.(?:txt|md|markdown|html|rst))?$'
$licenseFiles = @(
	Get-ChildItem -LiteralPath $RepositoryRoot -File |
		Where-Object { $_.Name -imatch $licenseCandidatePattern }
)
$licenseDirectories = @(
	Get-ChildItem -LiteralPath $RepositoryRoot -Directory |
		Where-Object { $_.Name -ieq 'LICENSES' }
)
if ($licenseFiles.Count -gt 0 -or $licenseDirectories.Count -gt 0) {
	$failures.Add('A conventional license file or LICENSES directory exists before licensing has been approved.')
}

# Exact normalized hashes intentionally lock the reviewed CI and branch-protection policy.
$expectedPolicyHashes = [ordered]@{
	'.github/approved-author-emails.txt' = '5cf3782dbd69e0d0a63a0bac9933c5a9fd11488964ab07cdc45f58e2a9375b09'
	'.github/workflows/foundation.yml' = '34ef2a9423b2f0b08265a50a723d6090ea5eadba51cfadf92ce0e36ee4f944b3'
	'.github/rulesets/main.json' = '99651cce242eb4f8c3eceb6bc67b24e2e13303e6daab84ec838529fcb0d60d8e'
}
foreach ($entry in $expectedPolicyHashes.GetEnumerator()) {
	$absolutePath = Join-Path $RepositoryRoot $entry.Key
	if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
		$actualHash = Get-NormalizedSha256 -Path $absolutePath
		if ($actualHash -cne $entry.Value) {
			$failures.Add("Reviewed policy content changed: $($entry.Key)")
		}
	}
}

$approvedAuthorEmailsPath = Join-Path `
	$RepositoryRoot `
	'.github/approved-author-emails.txt'
if (Test-Path -LiteralPath $approvedAuthorEmailsPath -PathType Leaf) {
	$approvedAuthorContent = [System.IO.File]::ReadAllText(
		$approvedAuthorEmailsPath
	).Replace("`r`n", "`n").Replace("`r", "`n")
	if (-not $approvedAuthorContent.EndsWith("`n", [System.StringComparison]::Ordinal)) {
		$failures.Add('Approved author email file must end with one newline.')
	} else {
		$approvedAuthorLines = @(
			$approvedAuthorContent.Substring(
				0,
				$approvedAuthorContent.Length - 1
			).Split("`n", [System.StringSplitOptions]::None)
		)
		$approvedAuthorPattern = '^(?:[0-9]+\+)?[A-Za-z0-9-]+@users\.noreply\.github\.com$'
		$approvedAuthorSet = [System.Collections.Generic.HashSet[string]]::new(
			[System.StringComparer]::Ordinal
		)
		for ($index = 0; $index -lt $approvedAuthorLines.Count; $index++) {
			$email = $approvedAuthorLines[$index]
			if ([string]::IsNullOrWhiteSpace($email) -or
				$email -cne $email.Trim() -or
				$email.Length -gt 254 -or
				$email -cnotmatch $approvedAuthorPattern) {
				$failures.Add("Approved author email entry $($index + 1) must be a GitHub-provided noreply address without surrounding whitespace.")
				continue
			}
			if (-not $approvedAuthorSet.Add($email)) {
				$failures.Add("Approved author email entry $($index + 1) is duplicated.")
			}
		}
		if (-not $approvedAuthorSet.Contains(
			'24713387+Poostaq@users.noreply.github.com'
		)) {
			$failures.Add("Approved author email file must retain the owner's GitHub noreply address.")
		}
	}
}

$rulesetPath = Join-Path $RepositoryRoot '.github/rulesets/main.json'
if (Test-Path -LiteralPath $rulesetPath -PathType Leaf) {
	$ruleset = $null
	try {
		$ruleset = Get-Content -LiteralPath $rulesetPath -Raw | ConvertFrom-Json -Depth 100
	} catch {
		$failures.Add("Ruleset JSON is invalid: $($_.Exception.Message)")
	}
	if ($null -ne $ruleset) {
		if ((Get-JsonPropertyValue -InputObject $ruleset -Name 'name') -cne 'Protect main') {
			$failures.Add('Ruleset name must be Protect main.')
		}
		if ((Get-JsonPropertyValue -InputObject $ruleset -Name 'target') -cne 'branch') {
			$failures.Add('Ruleset target must be branch.')
		}
		if ((Get-JsonPropertyValue -InputObject $ruleset -Name 'enforcement') -cne 'active') {
			$failures.Add('Ruleset enforcement must be active.')
		}

		$conditions = Get-JsonPropertyValue -InputObject $ruleset -Name 'conditions'
		$refName = Get-JsonPropertyValue -InputObject $conditions -Name 'ref_name'
		$includedRefs = @(Get-JsonPropertyValue -InputObject $refName -Name 'include')
		$excludedRefs = @(Get-JsonPropertyValue -InputObject $refName -Name 'exclude')
		if ($includedRefs.Count -ne 1 -or $includedRefs[0] -cne '~DEFAULT_BRANCH' -or $excludedRefs.Count -ne 0) {
			$failures.Add('Ruleset conditions must target only the default branch.')
		}

		$rules = @(Get-JsonPropertyValue -InputObject $ruleset -Name 'rules')
		$expectedRuleTypes = @(
			'deletion',
			'non_fast_forward',
			'required_linear_history',
			'pull_request',
			'required_status_checks'
		)
		$actualRuleTypes = @($rules | ForEach-Object {
			Get-JsonPropertyValue -InputObject $_ -Name 'type'
		})
		if (($actualRuleTypes -join "`n") -cne ($expectedRuleTypes -join "`n")) {
			$failures.Add('Ruleset rule types do not match the approved protections.')
		}

		$pullRequestRules = @($rules | Where-Object {
			(Get-JsonPropertyValue -InputObject $_ -Name 'type') -ceq 'pull_request'
		})
		if ($pullRequestRules.Count -ne 1) {
			$failures.Add('Ruleset must contain exactly one pull_request rule.')
		} else {
			$pullRequestParameters = Get-JsonPropertyValue -InputObject $pullRequestRules[0] -Name 'parameters'
			if ((Get-JsonPropertyValue -InputObject $pullRequestParameters -Name 'require_extra_approval_for_unattributed_changes') -ne $false) {
				$failures.Add('Ruleset pull requests must not require extra approval for unattributed changes.')
			}
		}

		$statusRules = @($rules | Where-Object {
			(Get-JsonPropertyValue -InputObject $_ -Name 'type') -ceq 'required_status_checks'
		})
		if ($statusRules.Count -ne 1) {
			$failures.Add('Ruleset must contain exactly one required_status_checks rule.')
		} else {
			$statusParameters = Get-JsonPropertyValue -InputObject $statusRules[0] -Name 'parameters'
			$statusChecks = @(Get-JsonPropertyValue -InputObject $statusParameters -Name 'required_status_checks')
			if ($statusChecks.Count -ne 1) {
				$failures.Add('Ruleset must contain exactly one required status check.')
			} else {
				$context = Get-JsonPropertyValue -InputObject $statusChecks[0] -Name 'context'
				$integrationId = Get-JsonPropertyValue -InputObject $statusChecks[0] -Name 'integration_id'
				if ($context -cne 'Verify foundation' -or $integrationId -ne 15368) {
					$failures.Add('Ruleset status check must be Verify foundation from GitHub Actions integration 15368.')
				}
			}
			if ((Get-JsonPropertyValue -InputObject $statusParameters -Name 'do_not_enforce_on_create') -ne $true) {
				$failures.Add('Ruleset status checks must allow branch creation.')
			}
			if ((Get-JsonPropertyValue -InputObject $statusParameters -Name 'strict_required_status_checks_policy') -ne $true) {
				$failures.Add('Ruleset status checks must use strict policy.')
			}
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
	foreach ($fragment in @(
		'From PowerShell 7 or later (`pwsh`)',
		'Windows PowerShell 5.1 is not supported.'
	)) {
		if (-not $readme.Contains($fragment)) {
			$failures.Add("README is missing required PowerShell requirement: $fragment")
		}
	}
}

$contributingPath = Join-Path $RepositoryRoot 'CONTRIBUTING.md'
if (Test-Path -LiteralPath $contributingPath -PathType Leaf) {
	$contributing = Get-Content -LiteralPath $contributingPath -Raw
	foreach ($fragment in @(
		'PowerShell 7 or later (`pwsh`)',
		'PowerShell 5.1 is not supported.'
	)) {
		if (-not $contributing.Contains($fragment)) {
			$failures.Add("CONTRIBUTING is missing required PowerShell requirement: $fragment")
		}
	}
}

$termsUrl = 'https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#5-license-grant-to-other-users'
foreach ($relativePath in @(
	'README.md',
	'CONTRIBUTING.md',
	'docs/superpowers/specs/2026-10-27-github-introduction-design.md',
	'docs/superpowers/plans/2026-10-27-github-introduction.md'
)) {
	$absolutePath = Join-Path $RepositoryRoot $relativePath
	if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
		$content = Get-Content -LiteralPath $absolutePath -Raw
		if (-not $content.Contains('no open-source license') -or -not $content.Contains($termsUrl)) {
			$failures.Add("Public license guidance is incomplete: $relativePath")
		}
	}
}

$securityPath = Join-Path $RepositoryRoot 'SECURITY.md'
if (Test-Path -LiteralPath $securityPath -PathType Leaf) {
	$security = Get-Content -LiteralPath $securityPath -Raw
	foreach ($fragment in @('Security', 'Advisories', 'Report a vulnerability')) {
		if (-not $security.Contains($fragment)) {
			$failures.Add("SECURITY is missing private-reporting navigation: $fragment")
		}
	}
}

$publicMarkdown = @(
	Get-ChildItem -LiteralPath $RepositoryRoot -File -Filter '*.md'
	Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'docs') -Recurse -File -Filter '*.md'
)
foreach ($file in $publicMarkdown) {
	$content = Get-Content -LiteralPath $file.FullName -Raw
	if ($content -match '[A-Za-z]:\\') {
		$relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $file.FullName)
		$failures.Add("Public Markdown contains a machine-specific absolute path: $relativePath")
	}
}

if ($failures.Count -gt 0) {
	throw ('GitHub readiness validation failed:' + [Environment]::NewLine + '- ' + ($failures -join ([Environment]::NewLine + '- ')))
}

Write-Output 'GitHub readiness validation passed.'
