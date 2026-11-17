param(
    [string]$Destination = 'L:\RockBand3Deluxe-PC'
)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$output = [IO.Path]::GetFullPath((Join-Path $project 'out'))
$destinationRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
$driveRoot = [IO.Path]::GetPathRoot($destinationRoot)
if ($destinationRoot -eq $driveRoot.TrimEnd('\') -or
    ($destinationRoot + '\').StartsWith($output + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose a separate destination folder on the external drive.'
}
if (Get-Process -Name rockband3deluxe,RockBand3DeluxeLauncher -ErrorAction SilentlyContinue) {
    throw 'Close the game and launcher before moving their files.'
}
$folders = @('game-characters', 'portable')
$bytes = 0L
foreach ($name in $folders) {
    $source = Join-Path $output $name
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "The source folder is missing: $source"
    }
    if (Test-Path -LiteralPath (Join-Path $destinationRoot $name)) {
        throw "The destination already contains $name. Choose another destination."
    }
    $entries = @(Get-Item -LiteralPath $source) + @(Get-ChildItem -LiteralPath $source -Recurse -Force)
    if ($entries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
        throw "The source contains a redirected path: $source"
    }
    $bytes += ($entries | Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum
}
if ([IO.DriveInfo]::new($driveRoot).AvailableFreeSpace -lt $bytes + 64MB) {
    throw 'There is not enough free space on the destination drive.'
}
[IO.Directory]::CreateDirectory($destinationRoot) | Out-Null
$stage = Join-Path $destinationRoot ('.rb3-transfer-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage) | Out-Null
foreach ($name in $folders) {
    $source = Join-Path $output $name
    $copy = Join-Path $stage $name
    Write-Output "Copying $name to the external drive..."
    Copy-Item -LiteralPath $source -Destination $copy -Recurse -Force
    Write-Output "Verifying $name..."
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -Force -File) {
        $relative = $file.FullName.Substring($source.Length + 1)
        $target = Join-Path $copy $relative
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $target).Hash) {
            throw "Verification failed for $relative. The source files are still available."
        }
    }
}
$settingsPath = Join-Path $stage 'portable/launcher-settings.json'
if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $settings.XexPath = Join-Path $destinationRoot 'game-characters/default.xex'
    $settingsJson = $settings | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($settingsPath, $settingsJson, [Text.UTF8Encoding]::new($false))
}
foreach ($name in $folders) {
    [IO.Directory]::Move((Join-Path $stage $name), (Join-Path $destinationRoot $name))
}
[IO.Directory]::Delete($stage)
$launcher = Join-Path $destinationRoot 'portable/RockBand3DeluxeLauncher.exe'
$report = Join-Path $destinationRoot 'launcher-check.txt'
$xex = Join-Path $destinationRoot 'game-characters/default.xex'
$arguments = '--self-test "{0}" "{1}"' -f $report,$xex
$check = Start-Process -FilePath $launcher -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
if ($check.ExitCode) {
    throw "The external launcher check failed. The source files are still available. See $report."
}
# Delete only the two verified, generated source folders within this project's out.
foreach ($name in $folders) {
    $source = [IO.Path]::GetFullPath((Join-Path $output $name))
    if ([IO.Path]::GetDirectoryName($source) -ne $output -or $name -notin @('game-characters', 'portable')) {
        throw 'Unexpected source cleanup path.'
    }
    Remove-Item -LiteralPath $source -Recurse -Force
}
Write-Output "Ready: $launcher"
