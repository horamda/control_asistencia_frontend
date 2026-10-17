[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,
    [ValidateSet('Apk', 'Bundle', 'Universal')]
    [string]$Format = 'Apk'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$endpoint = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$endpoint) -or
    $endpoint.Scheme -ne 'https' -or $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment) {
    throw 'ApiBaseUrl debe ser una URL HTTPS sin credenciales, query ni fragmento.'
}

$versionLine = Select-String -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Pattern '^version:\s*(\S+)'
$appVersion = $versionLine.Matches[0].Groups[1].Value
$artifactRoot = Join-Path $projectRoot "artifacts/android/$appVersion"
$outputDirectory = Join-Path $artifactRoot $Format.ToLowerInvariant()
$symbolsDirectory = Join-Path $outputDirectory 'symbols'
New-Item -ItemType Directory -Force -Path $symbolsDirectory | Out-Null

$hasSigningFile = Test-Path -LiteralPath (Join-Path $projectRoot 'android/key.properties')
if (-not $hasSigningFile -and -not $env:ANDROID_KEYSTORE_PATH) {
    throw 'Configurá la firma release en android/key.properties o en las variables ANDROID_KEYSTORE_*.'
}

$buildArguments = @('build')
if ($Format -eq 'Bundle') { $buildArguments += 'appbundle' } else { $buildArguments += 'apk' }
$buildArguments += @('--release', '--tree-shake-icons', "--split-debug-info=$symbolsDirectory",
    "--dart-define=API_BASE_URL=$($ApiBaseUrl.TrimEnd('/'))", '--dart-define=APP_FLAVOR=PROD', '--dart-define=APP_PROD=true')
if ($Format -eq 'Apk') { $buildArguments += '--split-per-abi' }

Push-Location $projectRoot
try {
    # Native stderr may contain harmless Java warnings under Windows PowerShell.
    # Always decide success from the native exit code.
    $ErrorActionPreference = 'Continue'
    & flutter @buildArguments
    $buildExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($buildExitCode -ne 0) { throw "La compilación Android falló (código $buildExitCode)." }

    $r8Mapping = Join-Path $projectRoot 'build/app/outputs/mapping/release/mapping.txt'
    if (Test-Path -LiteralPath $r8Mapping) {
        Copy-Item -LiteralPath $r8Mapping -Destination (Join-Path $symbolsDirectory 'mapping.txt')
    }

    $relativeFiles = switch ($Format) {
        'Bundle' { @('build/app/outputs/bundle/release/app-release.aab') }
        'Universal' { @('build/app/outputs/flutter-apk/app-release.apk') }
        'Apk' { @('build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
            'build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk',
            'build/app/outputs/flutter-apk/app-x86_64-release.apk') }
    }
    $packages = foreach ($relativeFile in $relativeFiles) {
        $source = Get-Item -LiteralPath (Join-Path $projectRoot $relativeFile)
        $destination = Join-Path $outputDirectory $source.Name
        Copy-Item -LiteralPath $source.FullName -Destination $destination
        [PSCustomObject]@{
            file = $source.Name
            bytes = $source.Length
            MiB = [Math]::Round($source.Length / 1MB, 2)
            sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        }
    }
    [PSCustomObject]@{
        version = $appVersion
        format = $Format
        createdUtc = [DateTime]::UtcNow.ToString('o')
        apiBaseUrl = $ApiBaseUrl
        packages = @($packages)
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputDirectory 'manifest.json') -Encoding UTF8
    $packages | Format-Table file, MiB, sha256 -AutoSize
    Write-Host "Paquetes y símbolos conservados en: $outputDirectory"
} finally {
    Pop-Location
}
