param(
	[string]$PckPath,
	[string]$ProjectRoot,
	[string]$VerifierPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
	$ProjectRoot = $repositoryRoot
}
if ([string]::IsNullOrWhiteSpace($PckPath)) {
	$PckPath = Join-Path $repositoryRoot 'build/web/index.pck'
}
if ([string]::IsNullOrWhiteSpace($VerifierPath)) {
	$VerifierPath = Join-Path $repositoryRoot 'scripts/verify-web-pck.ps1'
}

$tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd(
	[System.IO.Path]::DirectorySeparatorChar,
	[System.IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = Join-Path $tempParent ('crypts-pck-test-' + [Guid]::NewGuid().ToString('N'))

function Read-UInt32LittleEndian {
	param(
		[Parameter(Mandatory)]
		[byte[]]$Bytes,
		[Parameter(Mandatory)]
		[int]$Offset
	)
	return [BitConverter]::ToUInt32($Bytes, $Offset)
}

function Read-UInt64LittleEndian {
	param(
		[Parameter(Mandatory)]
		[byte[]]$Bytes,
		[Parameter(Mandatory)]
		[int]$Offset
	)
	return [BitConverter]::ToUInt64($Bytes, $Offset)
}

function Get-PckEntryLocation {
	param(
		[Parameter(Mandatory)]
		[byte[]]$Bytes,
		[Parameter(Mandatory)]
		[string]$ExpectedPath
	)

	$fileBase = Read-UInt64LittleEndian -Bytes $Bytes -Offset 24
	$directoryOffset = [int](Read-UInt64LittleEndian -Bytes $Bytes -Offset 32)
	$entryCount = [int](Read-UInt32LittleEndian -Bytes $Bytes -Offset $directoryOffset)
	$cursor = $directoryOffset + 4
	for ($index = 0; $index -lt $entryCount; $index++) {
		$pathLength = [int](Read-UInt32LittleEndian -Bytes $Bytes -Offset $cursor)
		$pathOffset = $cursor + 4
		$pathBytes = $Bytes[$pathOffset..($pathOffset + $pathLength - 1)]
		$zeroIndex = [Array]::IndexOf($pathBytes, [byte]0)
		if ($zeroIndex -ge 0) {
			$pathBytes = $pathBytes[0..($zeroIndex - 1)]
		}
		$path = [System.Text.Encoding]::UTF8.GetString($pathBytes)
		$metadataOffset = $pathOffset + $pathLength
		$relativeOffset = Read-UInt64LittleEndian -Bytes $Bytes -Offset $metadataOffset
		$size = Read-UInt64LittleEndian -Bytes $Bytes -Offset ($metadataOffset + 8)
		if ($path -ceq $ExpectedPath) {
			return [pscustomobject]@{
				PathOffset = $pathOffset
				DataOffset = [int64]$fileBase + [int64]$relativeOffset
				Md5Offset = $metadataOffset + 16
				Size = [int64]$size
			}
		}
		$cursor = $metadataOffset + 36
	}
	throw "PCK fixture does not contain $ExpectedPath."
}

function Invoke-Verifier {
	param(
		[Parameter(Mandatory)]
		[string]$CandidatePath
	)

	$output = @(& (Join-Path $PSHOME 'pwsh.exe') `
		-NoLogo `
		-NoProfile `
		-File $VerifierPath `
		-PckPath $CandidatePath `
		-ProjectRoot $ProjectRoot 2>&1)
	return [pscustomobject]@{
		ExitCode = $LASTEXITCODE
		Output = $output
	}
}

function Assert-VerifierFails {
	param(
		[Parameter(Mandatory)]
		[string]$Name,
		[Parameter(Mandatory)]
		[string]$CandidatePath
	)

	$result = Invoke-Verifier -CandidatePath $CandidatePath
	if ($result.ExitCode -eq 0) {
		throw "$Name should fail but passed: $($result.Output -join [Environment]::NewLine)"
	}
	Write-Output "PASS $Name"
}

try {
	if (-not (Test-Path -LiteralPath $PckPath -PathType Leaf)) {
		throw "Exported PCK fixture not found: $PckPath"
	}
	New-Item -ItemType Directory -Path $tempRoot | Out-Null

	$validResult = Invoke-Verifier -CandidatePath $PckPath
	if ($validResult.ExitCode -ne 0) {
		throw "valid PCK should pass but exited $($validResult.ExitCode): $($validResult.Output -join [Environment]::NewLine)"
	}
	Write-Output 'PASS valid exported PCK'

	$original = [System.IO.File]::ReadAllBytes($PckPath)

	$badMagic = [byte[]]$original.Clone()
	$badMagic[0] = $badMagic[0] -bxor 0xff
	$badMagicPath = Join-Path $tempRoot 'bad-magic.pck'
	[System.IO.File]::WriteAllBytes($badMagicPath, $badMagic)
	Assert-VerifierFails -Name 'bad magic' -CandidatePath $badMagicPath

	$truncatedPath = Join-Path $tempRoot 'truncated.pck'
	[System.IO.File]::WriteAllBytes($truncatedPath, $original[0..15])
	Assert-VerifierFails -Name 'truncation' -CandidatePath $truncatedPath

	$entry = Get-PckEntryLocation -Bytes $original -ExpectedPath 'content/core/classes.json'
	if ($entry.Size -le 0) {
		throw 'Authoritative content fixture is unexpectedly empty.'
	}

	$contentCorrupt = [byte[]]$original.Clone()
	$contentCorrupt[[int]$entry.DataOffset] = $contentCorrupt[[int]$entry.DataOffset] -bxor 0x01
	$contentCorruptPath = Join-Path $tempRoot 'content-corrupt.pck'
	[System.IO.File]::WriteAllBytes($contentCorruptPath, $contentCorrupt)
	Assert-VerifierFails -Name 'content byte and MD5 corruption' -CandidatePath $contentCorruptPath

	$sourceMismatch = [byte[]]$original.Clone()
	$sourceMismatch[[int]$entry.DataOffset] = $sourceMismatch[[int]$entry.DataOffset] -bxor 0x01
	$md5 = [System.Security.Cryptography.MD5]::Create()
	try {
		$updatedMd5 = $md5.ComputeHash(
			$sourceMismatch,
			[int]$entry.DataOffset,
			[int]$entry.Size
		)
	} finally {
		$md5.Dispose()
	}
	[Array]::Copy($updatedMd5, 0, $sourceMismatch, [int]$entry.Md5Offset, $updatedMd5.Length)
	$sourceMismatchPath = Join-Path $tempRoot 'source-mismatch.pck'
	[System.IO.File]::WriteAllBytes($sourceMismatchPath, $sourceMismatch)
	Assert-VerifierFails -Name 'authoritative source mismatch with valid MD5' -CandidatePath $sourceMismatchPath

	$forbiddenPath = [byte[]]$original.Clone()
	$replacement = [System.Text.Encoding]::UTF8.GetBytes('.agents')
	[Array]::Copy($replacement, 0, $forbiddenPath, [int]$entry.PathOffset, $replacement.Length)
	$forbiddenPathFile = Join-Path $tempRoot 'forbidden-root.pck'
	[System.IO.File]::WriteAllBytes($forbiddenPathFile, $forbiddenPath)
	Assert-VerifierFails -Name 'forbidden root directory entry' -CandidatePath $forbiddenPathFile

	Write-Output 'Web PCK verifier mutation tests passed: 6 cases.'
	$global:LASTEXITCODE = 0
} finally {
	$resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
	$tempPrefix = $tempParent + [System.IO.Path]::DirectorySeparatorChar
	if (-not $resolvedTempRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
		-not ([System.IO.Path]::GetFileName($resolvedTempRoot)).StartsWith('crypts-pck-test-', [System.StringComparison]::Ordinal)) {
		throw "Refusing to clean unexpected test path: $resolvedTempRoot"
	}
	if (Test-Path -LiteralPath $resolvedTempRoot) {
		Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
	}
}
