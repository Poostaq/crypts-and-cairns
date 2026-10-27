param(
	[string]$ValidatorPath = (
		Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'scripts/validate-publication.ps1'
	)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedEmail = '24713387+Poostaq@users.noreply.github.com'
$tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd(
	[System.IO.Path]::DirectorySeparatorChar,
	[System.IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = Join-Path $tempParent ('crypts-publication-test-' + [Guid]::NewGuid().ToString('N'))

function Invoke-Git {
	param(
		[Parameter(Mandatory)]
		[string]$RepositoryRoot,
		[Parameter(Mandatory, ValueFromRemainingArguments)]
		[string[]]$Arguments
	)

	& git -C $RepositoryRoot @Arguments | Out-Null
	if ($LASTEXITCODE -ne 0) {
		throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
	}
}

function Write-TestFile {
	param(
		[Parameter(Mandatory)]
		[string]$Path,
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Content
	)

	[System.IO.File]::WriteAllText(
		$Path,
		$Content,
		[System.Text.UTF8Encoding]::new($false)
	)
}

function New-TestRepository {
	param(
		[Parameter(Mandatory)]
		[string]$Name,
		[string]$Email = $expectedEmail,
		[string]$Message = 'test: baseline'
	)

	$root = Join-Path $tempRoot $Name
	New-Item -ItemType Directory -Path $root | Out-Null
	& git init --initial-branch=main $root | Out-Null
	if ($LASTEXITCODE -ne 0) {
		throw "git init failed for $root."
	}
	Invoke-Git -RepositoryRoot $root config user.name 'Publication Test'
	Invoke-Git -RepositoryRoot $root config user.email $Email
	Invoke-Git -RepositoryRoot $root config commit.gpgsign false
	Invoke-Git -RepositoryRoot $root config tag.gpgSign false
	Invoke-Git -RepositoryRoot $root config advice.nestedTag false
	Invoke-Git -RepositoryRoot $root config core.autocrlf false
	Write-TestFile -Path (Join-Path $root 'README.md') -Content "fixture`n"
	Invoke-Git -RepositoryRoot $root add README.md
	Invoke-Git -RepositoryRoot $root commit -m $Message
	return $root
}

function Invoke-Validator {
	param(
		[Parameter(Mandatory)]
		[string]$RepositoryRoot,
		[switch]$RequireNoRemote
	)

	$arguments = @(
		'-NoLogo',
		'-NoProfile',
		'-File',
		$ValidatorPath,
		'-RepositoryRoot',
		$RepositoryRoot,
		'-ExpectedEmail',
		$expectedEmail
	)
	if ($RequireNoRemote) {
		$arguments += '-RequireNoRemote'
	}
	$output = @(& (Join-Path $PSHOME 'pwsh.exe') @arguments 2>&1)
	return [pscustomobject]@{
		ExitCode = $LASTEXITCODE
		Output = $output
	}
}

function Assert-ValidatorPasses {
	param(
		[Parameter(Mandatory)]
		[string]$Name,
		[Parameter(Mandatory)]
		[string]$RepositoryRoot,
		[switch]$RequireNoRemote
	)

	$result = Invoke-Validator -RepositoryRoot $RepositoryRoot -RequireNoRemote:$RequireNoRemote
	if ($result.ExitCode -ne 0) {
		throw "$Name should pass but exited $($result.ExitCode): $($result.Output -join [Environment]::NewLine)"
	}
	Write-Output "PASS $Name"
}

function Assert-ValidatorFails {
	param(
		[Parameter(Mandatory)]
		[string]$Name,
		[Parameter(Mandatory)]
		[string]$RepositoryRoot,
		[switch]$RequireNoRemote
	)

	$result = Invoke-Validator -RepositoryRoot $RepositoryRoot -RequireNoRemote:$RequireNoRemote
	if ($result.ExitCode -eq 0) {
		throw "$Name should fail but passed: $($result.Output -join [Environment]::NewLine)"
	}
	Write-Output "PASS $Name"
}

try {
	New-Item -ItemType Directory -Path $tempRoot | Out-Null

	$baseline = New-TestRepository -Name 'baseline'
	Assert-ValidatorPasses -Name 'baseline repository' -RepositoryRoot $baseline -RequireNoRemote

	$invalidRepository = Join-Path $tempRoot 'not-a-repository'
	New-Item -ItemType Directory -Path $invalidRepository | Out-Null
	Assert-ValidatorFails -Name 'Git command and repository failure' -RepositoryRoot $invalidRepository

	$uppercaseFixtureRepo = New-TestRepository -Name 'uppercase-secret'
	$textSecretFixture = 'PASS' + "WORD = placeholder`n"
	Write-TestFile -Path (Join-Path $uppercaseFixtureRepo 'config.txt') -Content $textSecretFixture
	Invoke-Git -RepositoryRoot $uppercaseFixtureRepo add config.txt
	Invoke-Git -RepositoryRoot $uppercaseFixtureRepo commit -m 'test: uppercase secret fixture'
	Assert-ValidatorFails -Name 'uppercase text secret' -RepositoryRoot $uppercaseFixtureRepo

	$binaryFixtureRepo = New-TestRepository -Name 'binary-secret'
	$binaryBytes = [System.Collections.Generic.List[byte]]::new()
	$binaryBytes.Add(0)
	$binarySecretFixture = 'API_' + 'KEY=placeholder'
	$binaryBytes.AddRange([System.Text.Encoding]::ASCII.GetBytes($binarySecretFixture))
	$binaryBytes.Add(0)
	[System.IO.File]::WriteAllBytes((Join-Path $binaryFixtureRepo 'fixture.bin'), $binaryBytes.ToArray())
	Invoke-Git -RepositoryRoot $binaryFixtureRepo add fixture.bin
	Invoke-Git -RepositoryRoot $binaryFixtureRepo commit -m 'test: binary fixture'
	Assert-ValidatorFails -Name 'binary blob secret' -RepositoryRoot $binaryFixtureRepo

	foreach ($tokenSuffix in @('o', 'u', 's', 'r')) {
		$tokenFixture = 'gh' + $tokenSuffix + '_' + ('A' * 20)
		if ($tokenSuffix -ceq 's') {
			$tokenFixtureRepo = New-TestRepository `
				-Name "github-token-$tokenSuffix" `
				-Message ('test: ' + $tokenFixture)
		} else {
			$tokenFixtureRepo = New-TestRepository -Name "github-token-$tokenSuffix"
			if ($tokenSuffix -ceq 'r') {
				Invoke-Git -RepositoryRoot $tokenFixtureRepo -Arguments @(
					'tag', '-a', "github-token-$tokenSuffix", '-m', $tokenFixture
				)
			} else {
				Write-TestFile -Path (Join-Path $tokenFixtureRepo 'token.txt') -Content ($tokenFixture + "`n")
				Invoke-Git -RepositoryRoot $tokenFixtureRepo add token.txt
				Invoke-Git -RepositoryRoot $tokenFixtureRepo commit -m "test: GitHub token $tokenSuffix fixture"
			}
		}
		Assert-ValidatorFails -Name "GitHub gh${tokenSuffix}_ token" -RepositoryRoot $tokenFixtureRepo
	}

	$temporaryCredentialRepo = New-TestRepository -Name 'temporary-aws-id'
	$temporaryCredentialFixture = 'AS' + 'IA' + ('A' * 16)
	Write-TestFile -Path (Join-Path $temporaryCredentialRepo 'aws-id.txt') -Content ($temporaryCredentialFixture + "`n")
	Invoke-Git -RepositoryRoot $temporaryCredentialRepo add aws-id.txt
	Invoke-Git -RepositoryRoot $temporaryCredentialRepo commit -m 'test: temporary AWS ID fixture'
	Assert-ValidatorFails -Name 'ASIA access key ID' -RepositoryRoot $temporaryCredentialRepo

	foreach ($pemVariant in @('', 'ENCRYPTED ')) {
		$pemFixture = '-----BEGIN ' + $pemVariant + 'PRIVATE KEY-----'
		if ($pemVariant.Length -eq 0) {
			$pemFixtureRepo = New-TestRepository -Name 'pem-generic'
			Write-TestFile -Path (Join-Path $pemFixtureRepo 'key.pem') -Content ($pemFixture + "`n")
			Invoke-Git -RepositoryRoot $pemFixtureRepo add key.pem
			Invoke-Git -RepositoryRoot $pemFixtureRepo commit -m 'test: PEM fixture'
		} else {
			$pemFixtureRepo = New-TestRepository -Name 'pem-encrypted' -Message ('test: ' + $pemFixture)
		}
		Assert-ValidatorFails `
			-Name $(if ($pemVariant.Length -eq 0) { 'generic private key PEM header' } else { 'encrypted private key PEM header' }) `
			-RepositoryRoot $pemFixtureRepo
	}

	$assignedAwsCredentialRepo = New-TestRepository -Name 'assigned-aws-secret'
	$awsAssignmentFixture = 'aws_' + 'secret_access_key = ' + ('A' * 20)
	Invoke-Git -RepositoryRoot $assignedAwsCredentialRepo -Arguments @(
		'tag', '-a', 'assigned-aws-credential', '-m', $awsAssignmentFixture
	)
	Assert-ValidatorFails -Name 'AWS secret access key assignment' -RepositoryRoot $assignedAwsCredentialRepo

	$awsNameOnlyFixture = 'AWS_' + 'SECRET_ACCESS_KEY'
	$unassignedAwsNameRepo = New-TestRepository `
		-Name 'unassigned-aws-name' `
		-Message ('test: ' + $awsNameOnlyFixture)
	Write-TestFile -Path (Join-Path $unassignedAwsNameRepo 'environment.txt') -Content ($awsNameOnlyFixture + "`n")
	Invoke-Git -RepositoryRoot $unassignedAwsNameRepo add environment.txt
	Invoke-Git -RepositoryRoot $unassignedAwsNameRepo commit -m 'test: unassigned AWS name fixture'
	Assert-ValidatorPasses -Name 'AWS secret access key name without value' -RepositoryRoot $unassignedAwsNameRepo

	$messageSecretFixture = 'test: SEC' + 'RET = placeholder'
	$messageFixtureRepo = New-TestRepository -Name 'message-secret' -Message $messageSecretFixture
	Assert-ValidatorFails -Name 'commit message secret' -RepositoryRoot $messageFixtureRepo

	$tagFixtureRepo = New-TestRepository -Name 'tag-secret'
	$tagSecretFixture = 'PASS' + 'WORD = placeholder'
	Invoke-Git -RepositoryRoot $tagFixtureRepo -Arguments @(
		'tag', '-a', 'publication-test', '-m', $tagSecretFixture
	)
	Assert-ValidatorFails -Name 'annotated tag secret' -RepositoryRoot $tagFixtureRepo

	$nestedTagRepo = New-TestRepository -Name 'nested-tag-secret'
	$nestedTagMessageFixture = 'SEC' + 'RET = placeholder'
	Invoke-Git -RepositoryRoot $nestedTagRepo -Arguments @(
		'tag', '-a', 'inner-publication-test', '-m', $nestedTagMessageFixture
	)
	Invoke-Git -RepositoryRoot $nestedTagRepo -Arguments @(
		'tag', '-a', 'outer-publication-test', 'inner-publication-test^{tag}', '-m', 'clean outer tag'
	)
	Invoke-Git -RepositoryRoot $nestedTagRepo -Arguments @(
		'tag', '-d', 'inner-publication-test'
	)
	Assert-ValidatorFails -Name 'reachable nested annotated tag secret' -RepositoryRoot $nestedTagRepo

	$dirty = New-TestRepository -Name 'dirty'
	Write-TestFile -Path (Join-Path $dirty 'dirty.txt') -Content "uncommitted`n"
	Assert-ValidatorFails -Name 'dirty worktree' -RepositoryRoot $dirty

	$remote = New-TestRepository -Name 'remote'
	Invoke-Git -RepositoryRoot $remote remote add origin 'https://example.invalid/example.git'
	Assert-ValidatorFails -Name 'remote with RequireNoRemote' -RepositoryRoot $remote -RequireNoRemote

	$wrongEmail = New-TestRepository -Name 'wrong-email' -Email 'wrong@example.invalid'
	Assert-ValidatorFails -Name 'wrong author and committer email' -RepositoryRoot $wrongEmail

	Write-Output 'Publication validator mutation tests passed: 19 cases.'
	$global:LASTEXITCODE = 0
} finally {
	$resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
	$tempPrefix = $tempParent + [System.IO.Path]::DirectorySeparatorChar
	if (-not $resolvedTempRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
		-not ([System.IO.Path]::GetFileName($resolvedTempRoot)).StartsWith('crypts-publication-test-', [System.StringComparison]::Ordinal)) {
		throw "Refusing to clean unexpected test path: $resolvedTempRoot"
	}
	if (Test-Path -LiteralPath $resolvedTempRoot) {
		Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
	}
}
