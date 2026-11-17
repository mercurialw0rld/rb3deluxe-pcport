# Publishing a Windows application release

1. Update `Current` and the assembly versions in `launcher-src/ReleaseVersion.cs`. Update the player guide and `docs/RELEASE-NOTES.md` for that version.
2. Build the native port and launcher following `BUILDING.md`. Keep the executable and runtime DLLs from the same build together.
3. Run `./Package.ps1` and `./tests/Test-Updater.ps1 -ApplicationDirectory ./out/portable -PackagePath ./out/RockBand3Deluxe-vVERSION-windows-x64.zip`, replacing `VERSION` with `Current`.
4. Push the source and wait for the Windows launcher checks to pass. Create a GitHub release targeting that commit with tag `vVERSION`, copy the release notes, and attach both the Windows ZIP and its `.sha256` file. Publish it as the **latest release**. Keep GitHub's **pre-release** option unchecked so `/releases/latest` can find it, even while the application version includes `-preview`.

The ZIP filename must match `RockBand3Deluxe-vVERSION-windows-x64.zip`. `Package.ps1` writes the application manifest and SHA-256 hashes that the updater verifies. Upload the complete ZIP without adding a containing directory or repacking it. Publish the release after both assets finish uploading.

The launcher updates only the application files listed in that manifest. Saves, controls, imported songs, shader caches, and Xbox 360 game data are outside the application package. Original game files and generated game sources stay out of the source repository.

The GitHub workflow builds the launcher and runs synthetic updater tests without requiring Xbox 360 game data. Native game builds and release packaging run on the maintainer's Windows machine.

