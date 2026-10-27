param(
	[Parameter(Mandatory)]
	[string]$GodotBin,
	[string]$ModulePath = (
		Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'scripts/GodotProcess.psm1'
	)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ModulePath -PathType Leaf)) {
	throw "Godot process module not found: $ModulePath"
}

Import-Module -Name $ModulePath -Force

$result = Invoke-GodotProcess `
	-GodotBin $GodotBin `
	-ArgumentList @('--version') `
	-TimeoutSeconds 30

if ($result.TimedOut) {
	throw 'Godot version probe timed out.'
}
if ($result.ExitCode -ne 0) {
	throw "Godot version probe exited $($result.ExitCode): $($result.StandardError)"
}

$version = $result.StandardOutput.Trim()
if (-not $version.StartsWith(
	'4.7.2.stable',
	[System.StringComparison]::Ordinal
)) {
	throw "Expected Godot 4.7.2-stable, received: $version"
}

Write-Output 'PASS Godot process invocation captures GUI-subsystem output.'
