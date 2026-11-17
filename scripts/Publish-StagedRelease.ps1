param(
    [string]$ManifestPath = '.release/package.json',
    [Parameter(Mandatory)][string]$TargetCommit
)
$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$repository = 'mercurialw0rld/rb3deluxe-pcport'
if ($manifest.Version -notmatch '^v\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$' -or
    $manifest.Sha256 -notmatch '^[a-f0-9]{64}$' -or $TargetCommit -notmatch '^[a-f0-9]{40}$' -or
    -not $manifest.Parts -or $manifest.Parts.Count -gt 256) { throw 'Invalid release manifest.' }
$name = "RockBand3Deluxe-$($manifest.Version)-windows-x64.zip"
$directory = Join-Path ([IO.Path]::GetTempPath()) ('rb3-release-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$package = Join-Path $directory $name
$stream = [IO.File]::Create($package)
try {
    foreach ($part in $manifest.Parts) {
        if ($part -notmatch '^[a-f0-9]{40}$') { throw 'Invalid release segment.' }
        $json = & gh api "repos/$repository/git/blobs/$part"
        if ($LASTEXITCODE) { throw 'Could not download a release segment.' }
        $blob = $json | ConvertFrom-Json
        if ($blob.encoding -ne 'base64' -or $blob.sha -ne $part) { throw 'Unexpected release segment.' }
        $bytes = [Convert]::FromBase64String($blob.content)
        $stream.Write($bytes, 0, $bytes.Length)
    }
} finally { $stream.Dispose() }
if ((Get-FileHash -LiteralPath $package).Hash.ToLowerInvariant() -ne $manifest.Sha256) {
    throw 'The assembled Windows package failed SHA-256 verification.'
}
[IO.File]::WriteAllText($package + '.sha256', "$($manifest.Sha256)  $name`n", [Text.UTF8Encoding]::new($false))
$existing = & gh release view $manifest.Version --repo $repository --json assets 2>$null
if ($LASTEXITCODE -eq 0) {
    $asset = ($existing | ConvertFrom-Json).assets | Where-Object name -eq $name
    if ($asset) {
        $release = & gh api "repos/$repository/releases/tags/$($manifest.Version)" | ConvertFrom-Json
        $published = $release.assets | Where-Object name -eq $name
        if ($published.digest -ne ('sha256:' + $manifest.Sha256)) { throw 'A different package is already published under this version.' }
        Write-Output 'The same Windows package is already published.'
        exit 0
    }
} else {
    & gh release create $manifest.Version --repo $repository --target $TargetCommit --latest --title "Rock Band 3 Deluxe for Windows $($manifest.Version)" --notes-file 'docs/RELEASE-NOTES.md'
    if ($LASTEXITCODE) { throw 'Could not create the release.' }
}
& gh release upload $manifest.Version $package ($package + '.sha256') --repo $repository
if ($LASTEXITCODE) { throw 'Could not upload the Windows application package.' }
