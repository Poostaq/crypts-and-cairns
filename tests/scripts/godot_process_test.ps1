param(
	[Parameter(Mandatory)]
	[string]$GodotBin,
	[string]$ModulePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
	throw 'Godot process launcher tests require PowerShell 7 or later. Run them with pwsh.'
}

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($ModulePath)) {
	$ModulePath = Join-Path $repositoryRoot 'scripts/GodotProcess.psm1'
}
if (-not (Test-Path -LiteralPath $ModulePath -PathType Leaf)) {
	throw "Godot process module not found: $ModulePath"
}

function Assert-Equal {
	param(
		[Parameter(Mandatory)]
		[string]$Name,
		[AllowNull()]
		[object]$Actual,
		[AllowNull()]
		[object]$Expected
	)

	if ($Actual -cne $Expected) {
		throw "$Name expected '$Expected' but received '$Actual'."
	}
}

function Test-ProcessAlive {
	param(
		[Parameter(Mandatory)]
		[int]$ProcessId,
		[long]$StartTimeUtcTicks = 0
	)

	$process = $null
	try {
		$process = [System.Diagnostics.Process]::GetProcessById($ProcessId)
		if (
			$StartTimeUtcTicks -ne 0 -and
			$process.StartTime.ToUniversalTime().Ticks -ne $StartTimeUtcTicks
		) {
			return $false
		}
		return -not $process.HasExited
	} catch [System.ArgumentException] {
		return $false
	} finally {
		if ($null -ne $process) {
			$process.Dispose()
		}
	}
}

function Wait-ProcessGone {
	param(
		[Parameter(Mandatory)]
		[int]$ProcessId,
		[long]$StartTimeUtcTicks = 0,
		[ValidateRange(1, 30)]
		[int]$TimeoutSeconds = 5
	)

	$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
	do {
		if (-not (Test-ProcessAlive -ProcessId $ProcessId -StartTimeUtcTicks $StartTimeUtcTicks)) {
			return $true
		}
		Start-Sleep -Milliseconds 100
	} while ([DateTime]::UtcNow -lt $deadline)
	return -not (Test-ProcessAlive -ProcessId $ProcessId -StartTimeUtcTicks $StartTimeUtcTicks)
}

Import-Module -Name $ModulePath -Force

$pwsh = Join-Path $PSHOME 'pwsh.exe'
if (-not (Test-Path -LiteralPath $pwsh -PathType Leaf)) {
	$pwsh = Join-Path $PSHOME 'pwsh'
}
if (-not (Test-Path -LiteralPath $pwsh -PathType Leaf)) {
	throw "PowerShell 7 executable not found under: $PSHOME"
}

$tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd(
	[System.IO.Path]::DirectorySeparatorChar,
	[System.IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = Join-Path $tempParent ('crypts-godot-process-test-' + [Guid]::NewGuid().ToString('N'))
$descendantId = $null
$descendantStartTimeUtcTicks = 0

try {
	New-Item -ItemType Directory -Path $tempRoot | Out-Null

	$result = Invoke-GodotProcess `
		-GodotBin $GodotBin `
		-ArgumentList @('--version') `
		-TimeoutSeconds 30
	if ($result.TimedOut) {
		throw 'Godot version probe timed out.'
	}
	Assert-Equal -Name 'Godot version exit code' -Actual $result.ExitCode -Expected 0
	$version = $result.StandardOutput.Trim()
	if (-not $version.StartsWith(
		'4.7.2.stable',
		[System.StringComparison]::Ordinal
	)) {
		throw "Expected Godot 4.7.2-stable, received: $version"
	}
	Write-Output 'PASS GUI Godot output capture'

	$stderrSentinel = 'godot-process-stderr-sentinel'
	$result = Invoke-GodotProcess `
		-GodotBin $pwsh `
		-ArgumentList @(
			'-NoLogo',
			'-NoProfile',
			'-Command',
			"[Console]::Error.Write('$stderrSentinel')"
		) `
		-TimeoutSeconds 30
	Assert-Equal -Name 'stderr exit code' -Actual $result.ExitCode -Expected 0
	Assert-Equal -Name 'stderr capture' -Actual $result.StandardError -Expected $stderrSentinel
	Write-Output 'PASS stderr capture'

	$result = Invoke-GodotProcess `
		-GodotBin $pwsh `
		-ArgumentList @('-NoLogo', '-NoProfile', '-Command', 'exit 37') `
		-TimeoutSeconds 30
	Assert-Equal -Name 'nonzero exit propagation' -Actual $result.ExitCode -Expected 37
	Assert-Equal -Name 'nonzero timeout state' -Actual $result.TimedOut -Expected $false
	Write-Output 'PASS nonzero exit propagation'

	$chunkSize = 4096
	$chunkCount = 256
	$largeOutputCommand = @"
`$chunk = 'x' * $chunkSize
for (`$index = 0; `$index -lt $chunkCount; `$index++) {
	[Console]::Out.Write(`$chunk)
	[Console]::Error.Write(`$chunk)
}
"@
	$result = Invoke-GodotProcess `
		-GodotBin $pwsh `
		-ArgumentList @('-NoLogo', '-NoProfile', '-Command', $largeOutputCommand) `
		-TimeoutSeconds 30
	Assert-Equal -Name 'large-output exit code' -Actual $result.ExitCode -Expected 0
	Assert-Equal `
		-Name 'large stdout length' `
		-Actual $result.StandardOutput.Length `
		-Expected ($chunkSize * $chunkCount)
	Assert-Equal `
		-Name 'large stderr length' `
		-Actual $result.StandardError.Length `
		-Expected ($chunkSize * $chunkCount)
	Write-Output 'PASS large simultaneous stdout and stderr capture'

	$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
	$timeoutStdout = 'timeout-stdout-sentinel'
	$timeoutStderr = 'timeout-stderr-sentinel'
	$timeoutCommand = (
		"[Console]::Out.Write('$timeoutStdout'); " +
		"[Console]::Error.Write('$timeoutStderr'); " +
		'Start-Sleep -Seconds 30'
	)
	$result = Invoke-GodotProcess `
		-GodotBin $pwsh `
		-ArgumentList @('-NoLogo', '-NoProfile', '-Command', $timeoutCommand) `
		-TimeoutSeconds 1
	$stopwatch.Stop()
	Assert-Equal -Name 'timeout state' -Actual $result.TimedOut -Expected $true
	Assert-Equal -Name 'timeout stdout' -Actual $result.StandardOutput -Expected $timeoutStdout
	Assert-Equal -Name 'timeout stderr' -Actual $result.StandardError -Expected $timeoutStderr
	if ($result.ExitCode -eq 0) {
		throw 'Timed-out process reported a successful exit code.'
	}
	if ($stopwatch.Elapsed.TotalSeconds -ge 10) {
		throw "Timed-out process returned too slowly: $($stopwatch.Elapsed.TotalSeconds) seconds."
	}
	Write-Output 'PASS bounded timeout'

	$pidPath = Join-Path $tempRoot 'descendant.pid'
	$escapedPwsh = $pwsh.Replace("'", "''")
	$escapedPidPath = $pidPath.Replace("'", "''")
	$childEncodedCommand = [Convert]::ToBase64String(
		[Text.Encoding]::Unicode.GetBytes('Start-Sleep -Seconds 60')
	)
	$descendantCommand = @"
if (`$IsWindows) {
	`$child = Start-Process -FilePath '$escapedPwsh' -ArgumentList @('-NoLogo', '-NoProfile', '-EncodedCommand', '$childEncodedCommand') -WindowStyle Hidden -PassThru
} else {
	`$child = Start-Process -FilePath '$escapedPwsh' -ArgumentList @('-NoLogo', '-NoProfile', '-EncodedCommand', '$childEncodedCommand') -PassThru
}
[System.IO.File]::WriteAllText(
	'$escapedPidPath',
	('{0}|{1}' -f `$child.Id, `$child.StartTime.ToUniversalTime().Ticks)
)
Start-Sleep -Seconds 60
"@
	$result = Invoke-GodotProcess `
		-GodotBin $pwsh `
		-ArgumentList @('-NoLogo', '-NoProfile', '-Command', $descendantCommand) `
		-TimeoutSeconds 2
	Assert-Equal -Name 'descendant timeout state' -Actual $result.TimedOut -Expected $true
	if (-not (Test-Path -LiteralPath $pidPath -PathType Leaf)) {
		throw "Timed process did not record its descendant PID: $($result.StandardError)"
	}
	$descendantRecord = [System.IO.File]::ReadAllText($pidPath).Split('|')
	$descendantId = [int]$descendantRecord[0]
	$descendantStartTimeUtcTicks = [long]$descendantRecord[1]
	if (-not (Wait-ProcessGone `
		-ProcessId $descendantId `
		-StartTimeUtcTicks $descendantStartTimeUtcTicks `
		-TimeoutSeconds 5
	)) {
		throw "Descendant process survived timeout: $descendantId"
	}
	$descendantId = $null
	$descendantStartTimeUtcTicks = 0
	Write-Output 'PASS timeout terminates descendant process tree'

	if ($IsWindows) {
		$windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
		$escapedModulePath = $ModulePath.Replace("'", "''")
		$guardResult = Invoke-GodotProcess `
			-GodotBin $windowsPowerShell `
			-ArgumentList @(
				'-NoLogo',
				'-NoProfile',
				'-Command',
				"Import-Module -Name '$escapedModulePath' -Force -ErrorAction Stop"
			) `
			-TimeoutSeconds 30
		if ($guardResult.ExitCode -eq 0) {
			throw 'Windows PowerShell 5.1 module import should fail.'
		}
		$guardMessage = $guardResult.StandardOutput + $guardResult.StandardError
		$expectedGuard = 'Godot process launcher requires PowerShell 7 or later. Run this command with pwsh.'
		if (-not $guardMessage.Contains($expectedGuard)) {
			throw "Windows PowerShell 5.1 guard message was not deliberate: $guardMessage"
		}
		Write-Output 'PASS Windows PowerShell 5.1 requirement guard'
	}

	Write-Output 'Godot process launcher tests passed: 7 cases.'
} finally {
	if (
		$null -ne $descendantId -and
		(Test-ProcessAlive `
			-ProcessId $descendantId `
			-StartTimeUtcTicks $descendantStartTimeUtcTicks
		)
	) {
		$descendant = [System.Diagnostics.Process]::GetProcessById($descendantId)
		try {
			try {
				$descendant.Kill($true)
			} catch {
				$descendant.Kill()
			}
			$descendant.WaitForExit(5000) | Out-Null
		} finally {
			$descendant.Dispose()
		}
	}

	$resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
	$tempPrefix = $tempParent + [System.IO.Path]::DirectorySeparatorChar
	if (-not $resolvedTempRoot.StartsWith(
		$tempPrefix,
		[System.StringComparison]::OrdinalIgnoreCase
	)) {
		throw "Refusing to clean unexpected test path: $resolvedTempRoot"
	}
	if (Test-Path -LiteralPath $resolvedTempRoot) {
		Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
	}
}
