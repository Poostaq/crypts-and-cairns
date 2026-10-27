param(
	[string]$RepositoryRoot = (
		Split-Path -Parent $PSScriptRoot
	),
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$ExpectedEmail,
	[switch]$RequireNoRemote
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$failures = [System.Collections.Generic.List[string]]::new()
$secretLocations = [System.Collections.Generic.HashSet[string]]::new(
	[System.StringComparer]::Ordinal
)
$secretEre = 'gh(p|o|u|s|r)_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|(AKIA|ASIA)[0-9A-Z]{16}|BEGIN ((RSA|OPENSSH|EC|DSA|ENCRYPTED) )?PRIVATE KEY|aws_secret_access_key[[:space:]]*[:=][[:space:]]*[A-Za-z0-9/+=]{20,}|password[[:space:]]*[:=]|secret[[:space:]]*[:=]|api[_-]?key[[:space:]]*[:=]'
$secretRegex = [System.Text.RegularExpressions.Regex]::new(
	'gh(?:p|o|u|s|r)_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|(?:AKIA|ASIA)[0-9A-Z]{16}|BEGIN (?:(?:RSA|OPENSSH|EC|DSA|ENCRYPTED) )?PRIVATE KEY|aws_secret_access_key\s*[:=]\s*[A-Za-z0-9/+=]{20,}|password\s*[:=]|secret\s*[:=]|api[_-]?key\s*[:=]',
	(
		[System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
		[System.Text.RegularExpressions.RegexOptions]::CultureInvariant
	)
)

try {
	$gitExecutable = @(
		Get-Command git -CommandType Application -ErrorAction Stop
	)[0].Source
} catch {
	throw 'Publication validation failed: git executable was not found.'
}

function Invoke-GitCommand {
	param(
		[Parameter(Mandatory)]
		[string]$Description,
		[Parameter(Mandatory)]
		[string[]]$Arguments,
		[int[]]$AllowedExitCodes = @(0)
	)

	$output = @(& $gitExecutable -C $script:RepositoryRoot @Arguments 2>&1)
	$exitCode = $LASTEXITCODE
	if ($AllowedExitCodes -notcontains $exitCode) {
		$script:failures.Add("$Description failed with exit code $exitCode.")
	}
	return [pscustomobject]@{
		ExitCode = $exitCode
		Output = @($output | ForEach-Object { [string]$_ })
	}
}

function Throw-PublicationFailures {
	if ($script:failures.Count -gt 0) {
		throw (
			'Publication validation failed:' +
			[Environment]::NewLine +
			'- ' +
			($script:failures -join ([Environment]::NewLine + '- '))
		)
	}
}

if ([string]::IsNullOrWhiteSpace($ExpectedEmail)) {
	$failures.Add('ExpectedEmail must not be empty.')
}

try {
	$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
} catch {
	$failures.Add('RepositoryRoot is not a valid filesystem path.')
	Throw-PublicationFailures
}

if (-not (Test-Path -LiteralPath $RepositoryRoot -PathType Container)) {
	$failures.Add("RepositoryRoot does not exist: $RepositoryRoot")
	Throw-PublicationFailures
}

$topLevelResult = Invoke-GitCommand `
	-Description 'Resolve repository root' `
	-Arguments @('rev-parse', '--show-toplevel')
if ($topLevelResult.ExitCode -ne 0 -or $topLevelResult.Output.Count -ne 1) {
	Throw-PublicationFailures
}
$resolvedTopLevel = [System.IO.Path]::GetFullPath($topLevelResult.Output[0])
if (-not $resolvedTopLevel.Equals($RepositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
	$failures.Add("RepositoryRoot must name the Git worktree root: $resolvedTopLevel")
}

$branchResult = Invoke-GitCommand `
	-Description 'Resolve current branch' `
	-Arguments @('branch', '--show-current')
if ($branchResult.ExitCode -eq 0) {
	$branch = ($branchResult.Output -join '').Trim()
	if ($branch -cne 'main') {
		$failures.Add("Current branch must be main; found '$branch'.")
	}
}

$remoteResult = Invoke-GitCommand `
	-Description 'List remotes' `
	-Arguments @('remote')
if ($RequireNoRemote -and $remoteResult.ExitCode -eq 0 -and $remoteResult.Output.Count -ne 0) {
	$failures.Add("RequireNoRemote was set, but $($remoteResult.Output.Count) remote(s) are configured.")
}

$statusResult = Invoke-GitCommand `
	-Description 'Inspect worktree status' `
	-Arguments @('status', '--short', '--untracked-files=all')
if ($statusResult.ExitCode -eq 0 -and $statusResult.Output.Count -ne 0) {
	$failures.Add("Worktree must be clean; found $($statusResult.Output.Count) status entr$(if ($statusResult.Output.Count -eq 1) { 'y' } else { 'ies' }).")
}

$null = Invoke-GitCommand `
	-Description 'Run strict full fsck' `
	-Arguments @('fsck', '--full', '--strict')

$commitResult = Invoke-GitCommand `
	-Description 'Enumerate commits across all refs' `
	-Arguments @('rev-list', '--all')
$commits = @()
if ($commitResult.ExitCode -eq 0) {
	$commits = @($commitResult.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	if ($commits.Count -eq 0) {
		$failures.Add('No commits are reachable from repository refs.')
	}
}

foreach ($commit in $commits) {
	$grepResult = Invoke-GitCommand `
		-Description "Scan commit $commit for secret patterns" `
		-Arguments @('grep', '-a', '-i', '-l', '-E', '-e', $secretEre, $commit, '--') `
		-AllowedExitCodes @(0, 1)
	if ($grepResult.ExitCode -eq 0) {
		$prefix = "${commit}:"
		foreach ($entry in $grepResult.Output) {
			$path = $entry
			if ($path.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
				$path = $path.Substring($prefix.Length)
			}
			$null = $secretLocations.Add("commit $commit path $path")
		}
	}

	$messageResult = Invoke-GitCommand `
		-Description "Read commit message $commit" `
		-Arguments @('show', '--no-patch', '--format=%B', $commit)
	if ($messageResult.ExitCode -eq 0 -and $secretRegex.IsMatch(($messageResult.Output -join "`n"))) {
		$null = $secretLocations.Add("commit-message $commit")
	}
}

$objectResult = Invoke-GitCommand `
	-Description 'Enumerate reachable objects' `
	-Arguments @('rev-list', '--objects', '--all')
if ($objectResult.ExitCode -eq 0) {
	$reachableObjectIds = [System.Collections.Generic.HashSet[string]]::new(
		[System.StringComparer]::Ordinal
	)
	foreach ($line in $objectResult.Output) {
		$objectId = ($line -split ' ', 2)[0]
		if (-not [string]::IsNullOrWhiteSpace($objectId)) {
			$null = $reachableObjectIds.Add($objectId)
		}
	}
	foreach ($objectId in $reachableObjectIds) {
		$typeResult = Invoke-GitCommand `
			-Description "Read reachable object type $objectId" `
			-Arguments @('cat-file', '-t', $objectId)
		if ($typeResult.ExitCode -ne 0 -or $typeResult.Output.Count -ne 1 -or
			$typeResult.Output[0] -cne 'tag') {
			continue
		}
		$tagContentResult = Invoke-GitCommand `
			-Description "Read reachable annotated tag $objectId" `
			-Arguments @('cat-file', '-p', $objectId)
		if ($tagContentResult.ExitCode -eq 0 -and $secretRegex.IsMatch(($tagContentResult.Output -join "`n"))) {
			$null = $secretLocations.Add("annotated-tag $objectId")
		}
	}
}

foreach ($location in @($secretLocations | Sort-Object)) {
	$failures.Add("Potential secret pattern: $location")
}

$namedBlobCount = 0
$maxBlobSize = [int64]-1
$maxBlobPath = ''
if ($objectResult.ExitCode -eq 0) {
	foreach ($line in $objectResult.Output) {
		$parts = $line -split ' ', 2
		if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[1])) {
			continue
		}
		$objectId = $parts[0]
		$objectPath = $parts[1]
		$typeResult = Invoke-GitCommand `
			-Description "Read object type $objectId" `
			-Arguments @('cat-file', '-t', $objectId)
		$sizeResult = Invoke-GitCommand `
			-Description "Read object size $objectId" `
			-Arguments @('cat-file', '-s', $objectId)
		if ($typeResult.ExitCode -ne 0 -or $sizeResult.ExitCode -ne 0 -or
			$typeResult.Output.Count -ne 1 -or $sizeResult.Output.Count -ne 1) {
			continue
		}
		$objectSize = [int64]0
		if (-not [int64]::TryParse($sizeResult.Output[0], [ref]$objectSize)) {
			$failures.Add("Object size is not an integer for $objectId.")
			continue
		}
		if ($typeResult.Output[0] -cne 'blob') {
			continue
		}
		$namedBlobCount++
		if ($objectSize -gt $maxBlobSize) {
			$maxBlobSize = $objectSize
			$maxBlobPath = $objectPath
		}
		if ($objectSize -ge 50MB) {
			$failures.Add("Blob reaches the 50 MiB limit: $objectPath ($objectSize bytes).")
		}
	}
}

foreach ($commit in $commits) {
	$identityResult = Invoke-GitCommand `
		-Description "Read identities for commit $commit" `
		-Arguments @('show', '--no-patch', '--format=%ae%x09%ce', $commit)
	if ($identityResult.ExitCode -ne 0 -or $identityResult.Output.Count -ne 1) {
		continue
	}
	$identities = $identityResult.Output[0] -split "`t", 2
	if ($identities.Count -ne 2) {
		$failures.Add("Commit identity record is invalid: $commit")
		continue
	}
	if ($identities[0] -cne $ExpectedEmail -or $identities[1] -cne $ExpectedEmail) {
		$failures.Add("Commit has an unexpected author or committer email: $commit")
	}
}

if ($namedBlobCount -eq 0) {
	$failures.Add('No named reachable blobs were found.')
}

Throw-PublicationFailures

Write-Output (
	'Publication validation passed: ' +
	"$($commits.Count) commits; " +
	"$namedBlobCount named blobs; " +
	"largest blob $maxBlobSize bytes ($maxBlobPath); " +
	'0 secret-pattern hits.'
)
