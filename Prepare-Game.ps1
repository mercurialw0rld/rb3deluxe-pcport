param(
    [Parameter(Mandatory)][string]$BaseDirectory,
    [Parameter(Mandatory)][string]$DeluxeDirectory,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'out/game'),
    [switch]$Copy
)
$ErrorActionPreference = 'Stop'
$base = (Resolve-Path -LiteralPath $BaseDirectory).ProviderPath
$deluxe = (Resolve-Path -LiteralPath $DeluxeDirectory).ProviderPath
$output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
foreach ($sourceRoot in @($base, $deluxe)) {
    $prefix = $sourceRoot.TrimEnd('\') + '\'
    if (($output.TrimEnd('\') + '\').StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Choose an output folder outside the original game and Deluxe folders.'
    }
}

$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'launcher-src/game-files.json') -Raw | ConvertFrom-Json
. (Join-Path $PSScriptRoot 'scripts/GameFiles.ps1')
$xex = Get-Item -LiteralPath (Join-Path $deluxe 'default.xex')
if ($xex.PSIsContainer -or (Get-FileHash -LiteralPath $xex.FullName -Algorithm SHA256).Hash -ne $manifest.XexSha256) {
    throw 'The Deluxe default.xex does not match the revision selected for the native port.'
}
$files = @([pscustomobject]@{ Path = 'default.xex'; Source = $xex.FullName; Size = $xex.Length })
foreach ($file in (Get-Rb3GameFiles -Manifest $manifest -DeluxeDirectory $deluxe)) {
    $root = if ($file.Path -like 'gen/patch_xbox*') { $deluxe } else { $base }
    $source = Get-Item -LiteralPath (Join-Path $root $file.Path)
    if ($source.PSIsContainer -or $source.Length -ne $file.Size) {
        throw "Unexpected size for $($file.Path) in $root."
    }
    $files += [pscustomobject]@{ Path = $file.Path; Source = $source.FullName; Size = $file.Size }
}
foreach ($name in @('AvatarAwards', 'nxeart')) {
    $source = Get-Item -LiteralPath (Join-Path $base $name) -ErrorAction SilentlyContinue
    if ($source -and -not $source.PSIsContainer) {
        $files += [pscustomobject]@{ Path = $name; Source = $source.FullName; Size = $source.Length }
    }
}

foreach ($folder in @($output, (Join-Path $output 'gen'))) {
    $old = Get-Item -LiteralPath $folder -Force -ErrorAction SilentlyContinue
    if ($old -and (-not $old.PSIsContainer -or ($old.Attributes -band [IO.FileAttributes]::ReparsePoint))) {
        throw "Choose a regular output folder: $folder."
    }
    [IO.Directory]::CreateDirectory($folder) | Out-Null
}
foreach ($file in $files) {
    $target = Join-Path $output $file.Path
    $old = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($old) {
        if ($old.PSIsContainer -or ($old.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $old.Length -ne $file.Size) {
            throw "An incompatible entry already exists at $target. Choose an empty output folder."
        }
        if ($file.Path -eq 'default.xex' -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $manifest.XexSha256) {
            throw 'The output already contains a different default.xex. Choose an empty output folder.'
        }
        continue
    }
    if ($Copy -or $file.Path -eq 'default.xex') {
        $temporary = "$target.$([Guid]::NewGuid().ToString('N')).tmp"
        try {
            [IO.File]::Copy($file.Source, $temporary)
            [IO.File]::Move($temporary, $target)
        } finally {
            if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
        }
    } else {
        try {
            New-Item -ItemType HardLink -Path $target -Target $file.Source | Out-Null
        } catch {
            throw "Could not link $($file.Path). Use an NTFS output folder on the same drive or rerun with -Copy. $($_.Exception.Message)"
        }
    }
}
Write-Output $output
