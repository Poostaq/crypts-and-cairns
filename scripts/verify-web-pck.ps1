param(
	[string]$PckPath = (
		Join-Path (Split-Path -Parent $PSScriptRoot) 'build/web/index.pck'
	),
	[string]$ProjectRoot = (
		Split-Path -Parent $PSScriptRoot
	)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packMagic = [uint32]0x43504447
$packFormat = [uint32]4
$requiredPackFlags = [uint32]2
$headerSize = 104
$entryMetadataSize = 36
$forbiddenRoots = @('docs', 'tests', '.agents', '.codex', '.superpowers')
$requiredContent = @(
	'content/core/classes.json',
	'content/core/peoples.json',
	'content/localization/en.json',
	'content/manifest.json'
)
$strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Assert-Available {
	param(
		[Parameter(Mandatory)]
		[int64]$Offset,
		[Parameter(Mandatory)]
		[int64]$Count,
		[Parameter(Mandatory)]
		[int64]$Length,
		[Parameter(Mandatory)]
		[string]$Context
	)

	if ($Offset -lt 0 -or $Count -lt 0 -or $Offset -gt $Length -or $Count -gt ($Length - $Offset)) {
		throw "PCK bounds error while reading $Context."
	}
}

function Read-UInt32LittleEndian {
	param(
		[Parameter(Mandatory)]
		[byte[]]$Bytes,
		[Parameter(Mandatory)]
		[int64]$Offset,
		[Parameter(Mandatory)]
		[string]$Context
	)
	Assert-Available -Offset $Offset -Count 4 -Length $Bytes.LongLength -Context $Context
	return [BitConverter]::ToUInt32($Bytes, [int]$Offset)
}

function Read-UInt64LittleEndian {
	param(
		[Parameter(Mandatory)]
		[byte[]]$Bytes,
		[Parameter(Mandatory)]
		[int64]$Offset,
		[Parameter(Mandatory)]
		[string]$Context
	)
	Assert-Available -Offset $Offset -Count 8 -Length $Bytes.LongLength -Context $Context
	return [BitConverter]::ToUInt64($Bytes, [int]$Offset)
}

function Compare-ByteArrays {
	param(
		[Parameter(Mandatory)]
		[byte[]]$Left,
		[Parameter(Mandatory)]
		[byte[]]$Right
	)

	if ($Left.LongLength -ne $Right.LongLength) {
		return $false
	}
	for ($index = 0; $index -lt $Left.Length; $index++) {
		if ($Left[$index] -ne $Right[$index]) {
			return $false
		}
	}
	return $true
}

function Get-EntryBytes {
	param(
		[Parameter(Mandatory)]
		[byte[]]$Bytes,
		[Parameter(Mandatory)]
		[object]$Entry
	)

	if ($Entry.Size -eq 0) {
		return [byte[]]::new(0)
	}
	$result = [byte[]]::new([int]$Entry.Size)
	[Array]::Copy($Bytes, [int]$Entry.DataOffset, $result, 0, [int]$Entry.Size)
	return $result
}

$PckPath = [System.IO.Path]::GetFullPath($PckPath)
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path -LiteralPath $PckPath -PathType Leaf)) {
	throw "Web PCK does not exist: $PckPath"
}
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
	throw "Project root does not exist: $ProjectRoot"
}

$bytes = [System.IO.File]::ReadAllBytes($PckPath)
$length = $bytes.LongLength
if ($length -lt $headerSize) {
	throw "PCK is truncated before the $headerSize-byte v4 header."
}

$magic = Read-UInt32LittleEndian -Bytes $bytes -Offset 0 -Context 'magic'
if ($magic -ne $packMagic) {
	throw 'PCK magic is not GDPC.'
}
$format = Read-UInt32LittleEndian -Bytes $bytes -Offset 4 -Context 'pack format'
if ($format -ne $packFormat) {
	throw "Unsupported PCK format $format; expected format 4."
}
$engineMajor = Read-UInt32LittleEndian -Bytes $bytes -Offset 8 -Context 'engine major version'
$engineMinor = Read-UInt32LittleEndian -Bytes $bytes -Offset 12 -Context 'engine minor version'
$enginePatch = Read-UInt32LittleEndian -Bytes $bytes -Offset 16 -Context 'engine patch version'
if ($engineMajor -ne 4 -or $engineMinor -ne 7 -or $enginePatch -ne 2) {
	throw "PCK engine version must be exactly 4.7.2; found $engineMajor.$engineMinor.$enginePatch."
}
$packFlags = Read-UInt32LittleEndian -Bytes $bytes -Offset 20 -Context 'pack flags'
if ($packFlags -ne $requiredPackFlags) {
	throw "PCK flags must be relative-file-base only (2); found $packFlags. Encrypted directories and sparse bundles are unsupported."
}

$fileBaseRaw = Read-UInt64LittleEndian -Bytes $bytes -Offset 24 -Context 'file base'
$directoryOffsetRaw = Read-UInt64LittleEndian -Bytes $bytes -Offset 32 -Context 'directory offset'
if ($fileBaseRaw -gt [uint64][int64]::MaxValue -or $directoryOffsetRaw -gt [uint64][int64]::MaxValue) {
	throw 'PCK file base or directory offset exceeds supported bounds.'
}
$fileBase = [int64]$fileBaseRaw
$directoryOffset = [int64]$directoryOffsetRaw
if ($fileBase -lt $headerSize -or $fileBase -gt $directoryOffset -or $directoryOffset -gt ($length - 4)) {
	throw 'PCK file base or directory offset is outside the file layout.'
}

for ($offset = 40; $offset -lt $headerSize; $offset++) {
	if ($bytes[$offset] -ne 0) {
		throw 'PCK reserved header bytes must be zero.'
	}
}

$entryCountRaw = Read-UInt32LittleEndian -Bytes $bytes -Offset $directoryOffset -Context 'directory entry count'
if ($entryCountRaw -gt [uint32][int32]::MaxValue) {
	throw 'PCK directory entry count exceeds supported bounds.'
}
$entryCount = [int]$entryCountRaw
$minimumDirectoryBytes = [int64]$entryCount * (4 + $entryMetadataSize)
if ($minimumDirectoryBytes -gt ($length - ($directoryOffset + 4))) {
	throw 'PCK directory entry count cannot fit in the remaining file.'
}

$cursor = $directoryOffset + 4
$entries = [System.Collections.Generic.Dictionary[string, object]]::new(
	[System.StringComparer]::Ordinal
)
$verifiedMd5Count = 0
for ($index = 0; $index -lt $entryCount; $index++) {
	$pathBlockLengthRaw = Read-UInt32LittleEndian -Bytes $bytes -Offset $cursor -Context "entry $index path length"
	$cursor += 4
	if ($pathBlockLengthRaw -eq 0 -or ($pathBlockLengthRaw % 4) -ne 0 -or $pathBlockLengthRaw -gt [uint32][int32]::MaxValue) {
		throw "PCK entry $index has an invalid padded path length."
	}
	$pathBlockLength = [int]$pathBlockLengthRaw
	Assert-Available -Offset $cursor -Count $pathBlockLength -Length $length -Context "entry $index path"
	$pathBlock = [byte[]]::new($pathBlockLength)
	[Array]::Copy($bytes, [int]$cursor, $pathBlock, 0, $pathBlockLength)
	$cursor += $pathBlockLength

	$firstPadding = [Array]::IndexOf($pathBlock, [byte]0)
	$pathByteLength = if ($firstPadding -ge 0) { $firstPadding } else { $pathBlockLength }
	$expectedPadding = (4 - ($pathByteLength % 4)) % 4
	if (($pathBlockLength - $pathByteLength) -ne $expectedPadding) {
		throw "PCK entry $index has invalid path padding."
	}
	for ($paddingIndex = $pathByteLength; $paddingIndex -lt $pathBlockLength; $paddingIndex++) {
		if ($pathBlock[$paddingIndex] -ne 0) {
			throw "PCK entry $index has nonzero path padding."
		}
	}
	try {
		$path = $strictUtf8.GetString($pathBlock, 0, $pathByteLength)
	} catch {
		throw "PCK entry $index path is not valid UTF-8."
	}
	if ([string]::IsNullOrWhiteSpace($path) -or $path.Contains('\') -or $path.Contains(':') -or
		$path.StartsWith('/', [System.StringComparison]::Ordinal) -or
		$path.EndsWith('/', [System.StringComparison]::Ordinal)) {
		throw "PCK entry $index has an invalid path."
	}
	$segments = $path.Split('/')
	if ($segments.Count -eq 0 -or @($segments | Where-Object {
			[string]::IsNullOrEmpty($_) -or $_ -ceq '.' -or $_ -ceq '..'
		}).Count -gt 0) {
		throw "PCK entry $index has an invalid or traversing path."
	}
	if ($entries.ContainsKey($path)) {
		throw "PCK contains duplicate path: $path"
	}
	if ($forbiddenRoots -icontains $segments[0]) {
		throw "PCK contains forbidden root: $($segments[0])"
	}

	Assert-Available -Offset $cursor -Count $entryMetadataSize -Length $length -Context "entry $index metadata"
	$relativeOffsetRaw = Read-UInt64LittleEndian -Bytes $bytes -Offset $cursor -Context "entry $index offset"
	$sizeRaw = Read-UInt64LittleEndian -Bytes $bytes -Offset ($cursor + 8) -Context "entry $index size"
	$expectedMd5 = [byte[]]::new(16)
	[Array]::Copy($bytes, [int]($cursor + 16), $expectedMd5, 0, 16)
	$entryFlags = Read-UInt32LittleEndian -Bytes $bytes -Offset ($cursor + 32) -Context "entry $index flags"
	$cursor += $entryMetadataSize
	if ($entryFlags -ne 0) {
		throw "PCK entry '$path' uses unsupported encrypted, removal, delta, or unknown flags ($entryFlags)."
	}
	if ($relativeOffsetRaw -gt [uint64][int64]::MaxValue -or $sizeRaw -gt [uint64][int32]::MaxValue) {
		throw "PCK entry '$path' exceeds supported offset or size bounds."
	}
	$relativeOffset = [int64]$relativeOffsetRaw
	$size = [int64]$sizeRaw
	if ($relativeOffset -gt ([int64]::MaxValue - $fileBase)) {
		throw "PCK entry '$path' data offset overflows."
	}
	$dataOffset = $fileBase + $relativeOffset
	Assert-Available -Offset $dataOffset -Count $size -Length $directoryOffset -Context "entry '$path' data"

	$md5 = [System.Security.Cryptography.MD5]::Create()
	try {
		$actualMd5 = $md5.ComputeHash($bytes, [int]$dataOffset, [int]$size)
	} finally {
		$md5.Dispose()
	}
	if (-not (Compare-ByteArrays -Left $actualMd5 -Right $expectedMd5)) {
		throw "PCK entry '$path' failed its MD5 integrity check."
	}
	$verifiedMd5Count++
	$entries.Add($path, [pscustomobject]@{
		Path = $path
		DataOffset = $dataOffset
		Size = $size
	})
}

if ($cursor -ne $length) {
	throw "PCK directory does not end at the end of the file ($cursor of $length bytes)."
}

$gitExecutable = @(
	Get-Command git -CommandType Application -ErrorAction Stop
)[0].Source
foreach ($relativePath in $requiredContent) {
	if (-not $entries.ContainsKey($relativePath)) {
		throw "PCK is missing authoritative content: $relativePath"
	}
	& $gitExecutable -C $ProjectRoot ls-files --error-unmatch -- $relativePath 2>$null | Out-Null
	if ($LASTEXITCODE -ne 0) {
		throw "Authoritative source is not tracked by Git: $relativePath"
	}
	$sourcePath = Join-Path $ProjectRoot $relativePath
	if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
		throw "Authoritative source file is missing: $relativePath"
	}
	$sourceBytes = [System.IO.File]::ReadAllBytes($sourcePath)
	$packedBytes = Get-EntryBytes -Bytes $bytes -Entry $entries[$relativePath]
	if (-not (Compare-ByteArrays -Left $sourceBytes -Right $packedBytes)) {
		throw "PCK authoritative content differs from tracked source: $relativePath"
	}
}

Write-Output (
	'Web PCK verification passed: ' +
	"format 4; engine 4.7.2; $entryCount entries; " +
	"$verifiedMd5Count MD5 checks; $($requiredContent.Count) authoritative JSON files match; " +
	"$length bytes."
)
