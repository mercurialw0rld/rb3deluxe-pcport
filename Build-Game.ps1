param(
    [string]$GameDirectory = (Join-Path $PSScriptRoot 'out/game'),
    [string]$SdkDirectory = (Join-Path $PSScriptRoot 'external/rexglue-sdk/out/install/rb3dx'),
    [string]$BuildDirectory = (Join-Path $PSScriptRoot 'out/build/game'),
    [string]$VsInstallDirectory,
    [ValidateRange(1,128)][int]$Jobs = 3,
    [switch]$GenerateOnly,
    [switch]$ConfigureOnly
)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameDirectory).ProviderPath
$xex = Join-Path $game 'default.xex'
$assets = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'launcher-src/game-files.json') -Raw | ConvertFrom-Json
. (Join-Path $PSScriptRoot 'scripts/GameFiles.ps1')
if ((Get-FileHash -LiteralPath $xex -Algorithm SHA256).Hash -ne $assets.XexSha256) {
    throw 'This build requires the supported Deluxe default.xex. Run Prepare-Game.ps1 first.'
}
foreach ($file in (Get-Rb3GameFiles -Manifest $assets -DeluxeDirectory $game)) {
    $item = Get-Item -LiteralPath (Join-Path $game $file.Path)
    if ($item.PSIsContainer -or $item.Length -ne $file.Size) {
        throw "Invalid game data at $($file.Path). Run Prepare-Game.ps1 first."
    }
}
$sdk = [IO.Path]::GetFullPath($SdkDirectory)
$build = [IO.Path]::GetFullPath($BuildDirectory)
$generator = Join-Path $sdk 'bin/rexglue.exe'
if (-not (Test-Path -LiteralPath $generator -PathType Leaf)) {
    throw 'The patched ReXGlue code generator is missing. Run Build-Sdk.ps1 or pass -SdkDirectory.'
}
# ReXGlue 0.10.0 cannot emit bcl BO=20 at 0x82272E90. BO=20 always branches
# and leaves CTR/CR alone, so bl to the same target is equivalent. Only the
# local generator reads this copy. The launcher and runtime use the real XEX.
$inputDirectory = Join-Path $PSScriptRoot 'out/codegen-input'
$codegenXex = Join-Path $inputDirectory 'default.xex'
$codegenHash = '2EE9439E4155641570E32363BA0302422EE76E9CF3A5AF1060026D9D71976714'
if (-not (Test-Path -LiteralPath $codegenXex -PathType Leaf) -or
    (Get-FileHash -LiteralPath $codegenXex -Algorithm SHA256).Hash -ne $codegenHash) {
    $image = [IO.File]::ReadAllBytes($xex)
    $instructionOffset = 0x26DE90
    if ([BitConverter]::ToString($image, $instructionOffset, 4) -ne '42-80-D1-F1') {
        throw 'Unexpected instruction at Deluxe codegen offset 0x26DE90.'
    }
    $image[$instructionOffset] = 0x4B
    $image[$instructionOffset + 1] = 0xFF
    # Expose the detour's fallthrough to the generator. Finalize-Codegen
    # restores its behavior in the parent function in the emitted C++.
    $detourOffset = 0x7586E0
    if ([BitConverter]::ToString($image, $detourOffset, 4) -ne '4B-DB-8C-44') {
        throw 'Unexpected Deluxe detour at codegen offset 0x7586E0.'
    }
    [byte[]]$nop = 0x60, 0x00, 0x00, 0x00
    [Array]::Copy($nop, 0, $image, $detourOffset, $nop.Length)
    [IO.Directory]::CreateDirectory($inputDirectory) | Out-Null
    [IO.File]::WriteAllBytes($codegenXex, $image)
}
$manifest = Join-Path $PSScriptRoot 'rockband3deluxe_manifest.local.toml'
$gameValue = ConvertTo-Json -InputObject $inputDirectory.Replace('\','/') -Compress
$xexValue = ConvertTo-Json -InputObject $codegenXex.Replace('\','/') -Compress
$content = @"
[project]
name = "rockband3deluxe"
sdk_version = "0.10.0"
game_root = $gameValue

[entrypoint]
file_path = $xexValue
out_directory_path = "generated/default"
includes = ["config/codegen.toml"]
"@
if (-not (Test-Path -LiteralPath $manifest) -or [IO.File]::ReadAllText($manifest) -ne $content) {
    [IO.File]::WriteAllText($manifest, $content, [Text.UTF8Encoding]::new($false))
}
Push-Location -LiteralPath $PSScriptRoot
try {
    & $generator codegen $manifest
    if ($LASTEXITCODE) { throw 'ReXGlue generation failed for the Deluxe XEX. See the generator diagnostics above.' }
} finally { Pop-Location }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'generated/default/sources.cmake'))) {
    throw 'ReXGlue did not generate sources.cmake.'
}
& (Join-Path $PSScriptRoot 'scripts/Finalize-Codegen.ps1')
if ($GenerateOnly) { return }

. (Join-Path $PSScriptRoot 'scripts/DevTools.ps1')
$tools = Get-TbrbDevTools -VsInstallDirectory $VsInstallDirectory
& $tools.CMake -S $PSScriptRoot -B $build -G Ninja "-DCMAKE_MAKE_PROGRAM=$($tools.Ninja)" "-DCMAKE_CXX_COMPILER=$($tools.ClangCl)" -DCMAKE_CXX_COMPILER_TARGET=x86_64-pc-windows-msvc -DCMAKE_BUILD_TYPE=Release -DRB3_GENERATE_IN_CMAKE=OFF "-Drexglue_DIR=$sdk/lib/cmake/rexglue" "-DRB3_CODEGEN_MANIFEST=$manifest"
if ($LASTEXITCODE) { throw 'Native CMake configuration failed.' }
if ($ConfigureOnly) { return }
& $tools.CMake --build $build --parallel $Jobs
if ($LASTEXITCODE) { throw 'Native game build failed.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'rockband3deluxe.toml') -Destination $build -Force
Write-Output $build
