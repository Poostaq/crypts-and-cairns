param(
	[string]$GodotBin = $env:GODOT_BIN,
	# Two minutes bounds broken runners while leaving margin for slower hosts.
	[ValidateRange(1, 3600)]
	[int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
	throw 'Set GODOT_BIN to the absolute Godot 4.7.2 console executable path.'
}
if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
	throw "Godot executable not found: $GodotBin"
}

$version = (& $GodotBin --version).Trim()
if (-not $version.StartsWith('4.7.2.stable')) {
	throw "Expected Godot 4.7.2-stable, received: $version"
}
if ($version.Contains('mono')) {
	throw "Use the standard Godot build, not the .NET/Mono build: $version"
}

$standardOutput = ''
$standardError = ''
$nativeExitCode = 0
$timedOut = $false

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $GodotBin
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
# Quote paths containing spaces. Doubling trailing backslashes prevents them
# from escaping the closing quote in the Windows native command line.
$escapedProjectRoot = $projectRoot -replace '(\\+)$', '$1$1'
$startInfo.Arguments = (
	'--headless --path "{0}" --script res://tests/test_runner.gd' -f
	$escapedProjectRoot
)

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo

try {
	if (-not $process.Start()) {
		throw 'Failed to start the Godot test process.'
	}
	$standardOutputTask = $process.StandardOutput.ReadToEndAsync()
	$standardErrorTask = $process.StandardError.ReadToEndAsync()

	if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
		$timedOut = $true
		$process.Kill()
		$process.WaitForExit()
	}

	$nativeExitCode = $process.ExitCode
	$standardOutput = $standardOutputTask.GetAwaiter().GetResult()
	$standardError = $standardErrorTask.GetAwaiter().GetResult()
} finally {
	$process.Dispose()
}

if (-not [string]::IsNullOrEmpty($standardOutput)) {
	[Console]::Out.Write($standardOutput)
}
if (-not [string]::IsNullOrEmpty($standardError)) {
	[Console]::Error.Write($standardError)
}

if ($timedOut) {
	[Console]::Error.WriteLine(
		"Test runner timed out after {0} seconds." -f $TimeoutSeconds
	)
	exit 124
}
if ($nativeExitCode -ne 0) {
	exit $nativeExitCode
}
if (($standardOutput + $standardError) -match 'SCRIPT ERROR:') {
	[Console]::Error.WriteLine('Godot reported a script error.')
	exit 1
}

exit 0
