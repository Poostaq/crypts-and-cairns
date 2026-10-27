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

$licenseNames = @('LICENSE', 'LICENSE.md', 'LICENSE.txt', 'LICENSE.rst')
$licenseFiles = @(
	Get-ChildItem -LiteralPath $RepositoryRoot -File |
		Where-Object { $licenseNames -icontains $_.Name }
)
if ($licenseFiles.Count -gt 0) {
	$failures.Add('A license file exists before licensing has been approved.')
}

# Exact normalized hashes intentionally lock the reviewed CI and branch-protection policy.
$expectedPolicyHashes = [ordered]@{
	'.github/workflows/foundation.yml' = '531dd09d807eddc967ef6d569704ce366ad0e7cfe25d068f9312d418aadd38e8'
	'.github/rulesets/main.json' = 'a1495c817a1c8d7ffcd76e8a3e8161177c913cb514ab4e9e79d7cf24ceefac4f'
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
}

if ($failures.Count -gt 0) {
	throw ('GitHub readiness validation failed:' + [Environment]::NewLine + '- ' + ($failures -join ([Environment]::NewLine + '- ')))
}

Write-Output 'GitHub readiness validation passed.'
