param(
	[string]$GodotBin = $env:GODOT_BIN,
	# Two minutes bounds broken runners while leaving margin for slower hosts.
	[ValidateRange(1, 3600)]
	[int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotProcessModule = Join-Path $PSScriptRoot 'GodotProcess.psm1'

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
	throw 'Set GODOT_BIN to the absolute Godot 4.7.2 executable path.'
}
if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
	throw "Godot executable not found: $GodotBin"
}

Import-Module -Name $godotProcessModule -Force

$versionResult = Invoke-GodotProcess `
	-GodotBin $GodotBin `
	-ArgumentList @('--version') `
	-TimeoutSeconds 30
if ($versionResult.TimedOut -or $versionResult.ExitCode -ne 0) {
	throw "Could not read the Godot version from: $GodotBin"
}
$version = $versionResult.StandardOutput.Trim()
if (-not $version.StartsWith('4.7.2.stable')) {
	throw "Expected Godot 4.7.2-stable, received: $version"
}
if ($version.Contains('mono')) {
	throw "Use the standard Godot build, not the .NET/Mono build: $version"
}

$result = Invoke-GodotProcess `
	-GodotBin $GodotBin `
	-ArgumentList @(
		'--headless',
		'--path',
		$projectRoot,
		'--script',
		'res://tests/test_runner.gd'
	) `
	-TimeoutSeconds $TimeoutSeconds
$standardOutput = $result.StandardOutput
$standardError = $result.StandardError

if (-not [string]::IsNullOrEmpty($standardOutput)) {
	[Console]::Out.Write($standardOutput)
}
if (-not [string]::IsNullOrEmpty($standardError)) {
	[Console]::Error.Write($standardError)
}

if ($result.TimedOut) {
	[Console]::Error.WriteLine(
		"Test runner timed out after {0} seconds." -f $TimeoutSeconds
	)
	exit 124
}
if ($result.ExitCode -ne 0) {
	exit $result.ExitCode
}
if (($standardOutput + $standardError) -match 'SCRIPT ERROR:') {
	[Console]::Error.WriteLine('Godot reported a script error.')
	exit 1
}

exit 0
