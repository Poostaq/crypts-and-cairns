if ($PSVersionTable.PSVersion.Major -lt 7) {
	throw 'Godot process launcher requires PowerShell 7 or later. Run this command with pwsh.'
}

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

		if (
			-not $process.WaitForExit($TimeoutSeconds * 1000) -and
			-not $process.WaitForExit(0)
		) {
			$timedOut = $true
			try {
				$process.Kill($true)
			} catch {
				$treeKillError = $_.Exception
				try {
					if (-not $process.HasExited) {
						$process.Kill()
						$process.WaitForExit()
					}
				} catch {
					throw [System.InvalidOperationException]::new(
						'Godot process timed out; process-tree and direct-process termination both failed.',
						$_.Exception
					)
				}
				throw [System.InvalidOperationException]::new(
					'Godot process timed out; direct process terminated, but process-tree termination failed and descendant state is unknown.',
					$treeKillError
				)
			}
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
