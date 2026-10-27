param(
	[string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = 'Stop'
$godotProcessModule = Join-Path $PSScriptRoot 'GodotProcess.psm1'
$projectRoot = [System.IO.Path]::GetFullPath(
	(Split-Path -Parent $PSScriptRoot)
)
$buildRoot = [System.IO.Path]::GetFullPath(
	(Join-Path $projectRoot 'build')
)
$outputDirectory = [System.IO.Path]::GetFullPath(
	(Join-Path $buildRoot 'web')
)
$outputFile = Join-Path $outputDirectory 'index.html'

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
	throw 'Set GODOT_BIN to the absolute Godot 4.7.2 executable path.'
}
if (-not [System.IO.Path]::IsPathRooted($GodotBin)) {
	throw "GODOT_BIN must be an absolute path: $GodotBin"
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
if (-not $version.StartsWith(
	'4.7.2.stable',
	[System.StringComparison]::Ordinal
)) {
	throw "Expected Godot 4.7.2-stable, received: $version"
}
if ($version.IndexOf(
	'mono',
	[System.StringComparison]::OrdinalIgnoreCase
) -ge 0) {
	throw "Use the standard Godot build, not the .NET/Mono build: $version"
}

$buildPrefix = $buildRoot.TrimEnd(
	[System.IO.Path]::DirectorySeparatorChar,
	[System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
if (-not $outputDirectory.StartsWith(
	$buildPrefix,
	[System.StringComparison]::OrdinalIgnoreCase
)) {
	throw "Refusing to clean output outside the project build directory: $outputDirectory"
}

if (Test-Path -LiteralPath $outputDirectory) {
	Remove-Item -LiteralPath $outputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$exportResult = Invoke-GodotProcess `
	-GodotBin $GodotBin `
	-ArgumentList @(
		'--headless',
		'--path',
		$projectRoot,
		'--export-debug',
		'Web',
		$outputFile
	) `
	-TimeoutSeconds 600
if (-not [string]::IsNullOrEmpty($exportResult.StandardOutput)) {
	[Console]::Out.Write($exportResult.StandardOutput)
}
if (-not [string]::IsNullOrEmpty($exportResult.StandardError)) {
	[Console]::Error.Write($exportResult.StandardError)
}
if ($exportResult.TimedOut) {
	[Console]::Error.WriteLine('Web export timed out after 600 seconds.')
	exit 124
}
if ($exportResult.ExitCode -ne 0) {
	exit $exportResult.ExitCode
}

foreach ($requiredName in @(
	'index.html',
	'index.js',
	'index.wasm',
	'index.pck'
)) {
	$requiredPath = Join-Path $outputDirectory $requiredName
	if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
		throw "Web export did not create $requiredPath"
	}
	if ((Get-Item -LiteralPath $requiredPath).Length -le 0) {
		throw "Web export created an empty file: $requiredPath"
	}
}

$pckPath = Join-Path $outputDirectory 'index.pck'
$pckVerifier = Join-Path $PSScriptRoot 'verify-web-pck.ps1'
& $pckVerifier -PckPath $pckPath -ProjectRoot $projectRoot

$pckVerifierTest = Join-Path $projectRoot 'tests/scripts/web_pck_verifier_test.ps1'
& $pckVerifierTest `
	-PckPath $pckPath `
	-ProjectRoot $projectRoot `
	-VerifierPath $pckVerifier

foreach ($forbiddenRoot in @(
	'docs',
	'tests',
	'.agents',
	'.codex',
	'.superpowers'
)) {
	$forbiddenPath = Join-Path $outputDirectory $forbiddenRoot
	if (Test-Path -LiteralPath $forbiddenPath) {
		throw "Web export contains forbidden loose content: $forbiddenPath"
	}
}

Write-Host "Web export created: $outputFile"
