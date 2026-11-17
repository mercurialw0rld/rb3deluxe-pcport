param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'out/portable'),
    [string]$GameBuildDirectory = (Join-Path $PSScriptRoot 'out/build/game'),
    [string]$CrtDirectory,
    [switch]$LauncherOnly
)
$ErrorActionPreference = 'Stop'
$output = [IO.Path]::GetFullPath($OutputDirectory)
$runtime = Join-Path $output 'runtime'
$launcherSource = Join-Path $PSScriptRoot 'launcher-src'
$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$runtimeFiles = @('rockband3deluxe.exe', 'rexruntime.dll', 'rexgpu-xenos.dll', 'beatles-input.dll', 'rb3-content.exe')
if (-not $LauncherOnly) {
    foreach ($name in $runtimeFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $GameBuildDirectory $name) -PathType Leaf)) {
            throw "Missing $name. Build the native port with Build-Game.ps1 first."
        }
    }
    if (-not $CrtDirectory) {
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
        if (Test-Path -LiteralPath $vswhere) {
            $vs = @(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath) | Select-Object -First 1
            if ($vs) {
                $redist = Join-Path $vs 'VC/Redist/MSVC'
                $crt = Get-ChildItem -LiteralPath $redist -Directory |
                    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
                    Sort-Object { [version]$_.Name } -Descending |
                    ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $_.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' } |
                    Select-Object -First 1
                if ($crt) { $CrtDirectory = $crt.FullName }
            }
        }
    }
    if (-not $CrtDirectory) { throw 'Pass -CrtDirectory with the x64 Microsoft Visual C++ runtime folder.' }
}
[IO.Directory]::CreateDirectory($runtime) | Out-Null
$sources = @(Get-ChildItem -LiteralPath $launcherSource -File -Filter '*.cs' | ForEach-Object FullName)
$launcher = Join-Path $output 'RockBand3DeluxeLauncher.exe'
& $csc /nologo /target:winexe /platform:x64 /optimize+ /codepage:65001 "/out:$launcher" "/win32manifest:$launcherSource/launcher.manifest" "/resource:$launcherSource/rock-band-3-cover.png,rock-band-3-cover.png" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Runtime.Serialization.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll @sources
if ($LASTEXITCODE) { throw 'Launcher compilation failed.' }

foreach ($name in @('RockBand3DeluxeLauncher.exe.config', 'game-files.json')) {
    Copy-Item -LiteralPath (Join-Path $launcherSource $name) -Destination $output -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'scripts/Update-App.ps1') -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'rockband3deluxe.toml') -Destination $runtime -Force
if (-not $LauncherOnly) {
    foreach ($name in $runtimeFiles) {
        Copy-Item -LiteralPath (Join-Path $GameBuildDirectory $name) -Destination $runtime -Force
    }
    if ($CrtDirectory) {
        Get-ChildItem -LiteralPath $CrtDirectory -Filter '*.dll' -File |
            Copy-Item -Destination $runtime -Force
    }
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'licenses') -Destination $output -Recurse -Force
Write-Output $launcher
