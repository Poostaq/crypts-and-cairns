Set-StrictMode -Version Latest

function Invoke-GodotProcess {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$GodotBin,
		[string[]]$ArgumentList = @(),
		[ValidateRange(1, 3600)]
		[int]$TimeoutSeconds = 120
	)

	$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
	$startInfo.FileName = $GodotBin
	$startInfo.UseShellExecute = $false
	$startInfo.CreateNoWindow = $true
	$startInfo.RedirectStandardOutput = $true
	$startInfo.RedirectStandardError = $true
	foreach ($argument in $ArgumentList) {
		$startInfo.ArgumentList.Add($argument)
	}

	$process = [System.Diagnostics.Process]::new()
	$process.StartInfo = $startInfo
	$timedOut = $false
	try {
		if (-not $process.Start()) {
			throw 'Failed to start the Godot process.'
		}
		$standardOutputTask = $process.StandardOutput.ReadToEndAsync()
		$standardErrorTask = $process.StandardError.ReadToEndAsync()

		if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
			$timedOut = $true
			$process.Kill()
			$process.WaitForExit()
		}

		return [pscustomobject]@{
			ExitCode = $process.ExitCode
			StandardOutput = $standardOutputTask.GetAwaiter().GetResult()
			StandardError = $standardErrorTask.GetAwaiter().GetResult()
			TimedOut = $timedOut
		}
	} finally {
		$process.Dispose()
	}
}

Export-ModuleMember -Function Invoke-GodotProcess
