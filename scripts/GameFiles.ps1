function Get-Rb3GameFiles {
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][string]$DeluxeDirectory
    )

    # A variant is one complete set of patch archives. Matching each file
    # independently could accept a header from a different Deluxe edition.
    if (-not $Manifest.Variants) { return $Manifest.Files }
    foreach ($variant in $Manifest.Variants) {
        $matchingFiles = @($variant.Files | Where-Object {
            $file = Get-Item -LiteralPath (Join-Path $DeluxeDirectory $_.Path) -ErrorAction SilentlyContinue
            $file -and -not $file.PSIsContainer -and $file.Length -eq $_.Size
        })
        if ($variant.Files.Count -gt 0 -and $matchingFiles.Count -eq $variant.Files.Count) {
            return @($Manifest.Files) + @($variant.Files)
        }
    }
    throw 'The Deluxe patch archives are incomplete or from an unsupported edition. Use a complete supported Deluxe or Custom Characters download.'
}
