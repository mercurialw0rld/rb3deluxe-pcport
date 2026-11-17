param(
    [Parameter(Mandatory)][string]$ApplicationDirectory,
    [Parameter(Mandatory)][string]$StagingDirectory,
    [Parameter(Mandatory)][int]$LauncherProcessId,
    [switch]$NoRestart
)
$ErrorActionPreference = 'Stop'
$application = [IO.Path]::GetFullPath($ApplicationDirectory).TrimEnd('\')
$stage = [IO.Path]::GetFullPath($StagingDirectory).TrimEnd('\')
$work = [IO.Path]::GetDirectoryName($stage)
if ([IO.Path]::GetDirectoryName($work) -ne $application -or
    -not [IO.Path]::GetFileName($work).StartsWith('.update-', [StringComparison]::Ordinal) -or
    [IO.Path]::GetFileName($stage) -ne 'application') {
    throw 'The update staging directory must be inside the application folder.'
}
function Assert-NormalPath([string]$path) {
    for ($current = $path; $current; $current = [IO.Path]::GetDirectoryName($current)) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "The update path is redirected: $current"
        }
    }
}
Assert-NormalPath $application
Assert-NormalPath $stage
$lockPath = Join-Path $application '.update.lock'
Assert-NormalPath $lockPath
$lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
$backup = Join-Path $work 'backup'
$published = [Collections.Generic.List[object]]::new()
$success = $false
$message = ''
try {
    $launcher = Get-Process -Id $LauncherProcessId -ErrorAction SilentlyContinue
    if ($launcher -and -not $launcher.WaitForExit(60000)) {
        throw 'The launcher did not close in time. Try updating again.'
    }
    $gamePath = Join-Path $application 'runtime/rockband3deluxe.exe'
    if (Get-Process -Name rockband3deluxe -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $gamePath }) {
        throw 'Close Rock Band 3 Deluxe before installing this update.'
    }
    $manifestPath = Join-Path $stage 'release-files.json'
    Assert-NormalPath $manifestPath
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $manifest.Files -or $manifest.Files.Count -gt 100) { throw 'Invalid update file list.' }
    $allowed = @('RockBand3DeluxeLauncher.exe', 'RockBand3DeluxeLauncher.exe.config', 'game-files.json',
        'Update-App.ps1', 'runtime/rockband3deluxe.exe', 'runtime/rexruntime.dll', 'runtime/rexgpu-xenos.dll',
        'runtime/beatles-input.dll', 'runtime/rb3-content.exe', 'runtime/rockband3deluxe.toml',
        'runtime/concrt140.dll', 'runtime/msvcp140.dll', 'runtime/msvcp140_1.dll', 'runtime/msvcp140_2.dll',
        'runtime/msvcp140_atomic_wait.dll', 'runtime/msvcp140_codecvt_ids.dll', 'runtime/vccorlib140.dll',
        'runtime/vcruntime140.dll', 'runtime/vcruntime140_1.dll', 'runtime/vcruntime140_threads.dll')
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $manifest.Files) {
        $relative = [string]$file.Path
        if (($relative -notin $allowed -and $relative -cnotmatch '^licenses/[A-Za-z0-9_.-]+\.(txt|md)$') -or
            -not $names.Add($relative) -or $file.Sha256 -notmatch '^[0-9A-Fa-f]{64}$') {
            throw 'Invalid application file in the update.'
        }
        $source = Join-Path $stage $relative
        $target = Join-Path $application $relative
        Assert-NormalPath $source
        Assert-NormalPath $target
        $hash = [Security.Cryptography.SHA256]::Create()
        $inputFile = [IO.File]::OpenRead($source)
        try { $actualHash = [BitConverter]::ToString($hash.ComputeHash($inputFile)).Replace('-', '') }
        finally { $inputFile.Dispose(); $hash.Dispose() }
        if ($actualHash -ne $file.Sha256) {
            throw "Update verification failed for $relative."
        }
    }
    # A failed or interrupted install can be recovered from the backup folder.
    # Write the replacement manifest last so it describes the installed files.
    $files = @($manifest.Files) + @([pscustomobject]@{Path='release-files.json'})
    foreach ($file in $files) {
        $source = Join-Path $stage $file.Path
        $target = Join-Path $application $file.Path
        $saved = Join-Path $backup $file.Path
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($saved)) | Out-Null
        $existed = [IO.File]::Exists($target)
        if ($existed) { [IO.File]::Replace($source, $target, $saved) }
        else { [IO.File]::Move($source, $target) }
        $published.Add([pscustomobject]@{Target=$target; Backup=$saved; Existed=$existed})
    }
    $success = $true
    $message = "Updated to $($manifest.Version)."
} catch {
    $message = "Update failed: $($_.Exception.Message)"
    $rollbackErrors = [Collections.Generic.List[string]]::new()
    for ($i = $published.Count - 1; $i -ge 0; $i--) {
        $file = $published[$i]
        try {
            if ($file.Existed) { [IO.File]::Copy($file.Backup, $file.Target, $true) }
            else { [IO.File]::Delete($file.Target) }
        } catch { $rollbackErrors.Add($_.Exception.Message) }
    }
    if ($rollbackErrors.Count) { $message += " Recovery files are in $backup. " + ($rollbackErrors -join ' ') }
} finally {
    $result = @{Success=$success; Message=$message} | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $application 'update-result.json'), $result, [Text.UTF8Encoding]::new($false))
    $lock.Dispose()
}
if ($success) {
    # This exact generated directory is checked above before recursive deletion.
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
if (-not $NoRestart) {
    Start-Process -FilePath (Join-Path $application 'RockBand3DeluxeLauncher.exe') -WorkingDirectory $application
}
if (-not $success) { Write-Error $message; exit 1 }
