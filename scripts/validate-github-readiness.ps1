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
