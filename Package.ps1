param(
    [string]$ApplicationDirectory = (Join-Path $PSScriptRoot 'out/portable'),
    [string]$ArchivePath
)
$ErrorActionPreference = 'Stop'
$versionFile = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'launcher-src/ReleaseVersion.cs'))
$version = [regex]::Match($versionFile, 'Current = "([^"]+)"').Groups[1].Value
if (-not $version) { throw 'Missing application version.' }
$tag = 'v' + $version
if (-not $ArchivePath) { $ArchivePath = Join-Path $PSScriptRoot "out/RockBand3Deluxe-$tag-windows-x64.zip" }
$root = (Resolve-Path -LiteralPath $ApplicationDirectory).ProviderPath
$files = @('RockBand3DeluxeLauncher.exe', 'RockBand3DeluxeLauncher.exe.config', 'game-files.json', 'Update-App.ps1',
    'runtime/rockband3deluxe.exe', 'runtime/rexruntime.dll', 'runtime/rexgpu-xenos.dll',
    'runtime/beatles-input.dll', 'runtime/rb3-content.exe', 'runtime/rockband3deluxe.toml')
$crt = @('concrt140.dll', 'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll',
    'msvcp140_atomic_wait.dll', 'msvcp140_codecvt_ids.dll', 'vccorlib140.dll', 'vcruntime140.dll',
    'vcruntime140_1.dll', 'vcruntime140_threads.dll')
$files += $crt | Where-Object { Test-Path -LiteralPath (Join-Path $root "runtime/$_") } | ForEach-Object { "runtime/$_" }
foreach ($required in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $root "runtime/$required"))) { throw "Missing x64 C++ runtime: $required" }
}
$files += Get-ChildItem -LiteralPath (Join-Path $root 'licenses') -File | ForEach-Object { 'licenses/' + $_.Name }
$records = foreach ($name in $files) {
    $path = Join-Path $root $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing application file: $name" }
    [pscustomobject]@{Path=$name; Sha256=(Get-FileHash -LiteralPath $path).Hash}
}
$config = Get-Content -LiteralPath (Join-Path $root 'runtime/rockband3deluxe.toml') -Raw
if ($config -match '(?m)^\s*(game_data_root|user_data_root|cache_root|log_file)\s*=') {
    throw 'The release configuration contains local player paths.'
}
$manifest = [ordered]@{Version=$tag; Files=@($records)} | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $root 'release-files.json'), $manifest, [Text.UTF8Encoding]::new($false))
$files += 'release-files.json'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Path]::GetFullPath($ArchivePath)
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($archive)) | Out-Null
$temporary = $archive + '.tmp'
try {
    $stream = [IO.File]::Create($temporary)
    try {
        $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            foreach ($name in $files) {
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $root $name), $name,
                    [IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }
    if ([IO.File]::Exists($archive)) { [IO.File]::Replace($temporary, $archive, [NullString]::Value) }
    else { [IO.File]::Move($temporary, $archive) }
} catch {
    if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    throw
}
$hash = (Get-FileHash -LiteralPath $archive).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($archive + '.sha256', "$hash  $([IO.Path]::GetFileName($archive))`n", [Text.UTF8Encoding]::new($false))
Write-Output $archive
Write-Output "SHA-256 $hash"
