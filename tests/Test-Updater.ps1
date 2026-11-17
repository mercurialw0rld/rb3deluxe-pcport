param(
    [string]$ApplicationDirectory,
    [string]$PackagePath
)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
if (-not $ApplicationDirectory) { $ApplicationDirectory = Join-Path $project 'out/publication' }
$application = (Resolve-Path -LiteralPath $ApplicationDirectory).ProviderPath
$output = Join-Path $project ('out/update-tests-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$test = Join-Path $application 'UpdaterTests.exe'
$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$launcher = Join-Path $application 'RockBand3DeluxeLauncher.exe'
& $csc /nologo /target:exe /platform:x64 "/out:$test" "/reference:$launcher" /reference:System.Runtime.Serialization.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll (Join-Path $PSScriptRoot 'UpdaterTests.cs')
if ($LASTEXITCODE) { throw 'Updater test compilation failed.' }
$arguments = @($output, (Join-Path $project 'scripts/Update-App.ps1'))
if ($PackagePath) { $arguments += (Resolve-Path -LiteralPath $PackagePath).ProviderPath }
try {
    & $test @arguments
    if ($LASTEXITCODE) { throw 'Updater tests failed.' }
} finally {
    Remove-Item -LiteralPath $test
}
