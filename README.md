# Rock Band 3 Deluxe for Windows

**v0.1.0-preview · Windows 10/11 x64 · Direct3D 12**

An unofficial native PC port of Rock Band 3 Deluxe, with a launcher, keyboard and instrument controls, custom song import, VSync, and application updates.

## Download and play

1. Download **`RockBand3Deluxe-v0.1.0-preview-windows-x64.zip`** from the latest release and extract the entire ZIP to a writable folder. This is the complete Windows application. The **Source code** downloads are for rebuilding the project.

   [Download the Windows application](https://github.com/mercurialw0rld/rb3deluxe-pcport/releases/latest)

2. Prepare your own **extracted Xbox 360 copy of Rock Band 3**. Its folder must contain `default.xex`, `charnames.zbm`, and `gen` with all the original `main_xbox.*` files. The supported Title ID is `45410914`.

3. Download the **Xbox 360** version of Rock Band 3 Deluxe from MiloHax. Choose **Main + Custom Characters** for the additional characters, or **Main Download** for regular Deluxe. Extract that download, then copy its **`default.xex` and `gen` folder into your extracted Rock Band 3 folder**, merging `gen` and replacing the XEX when prompted. The resulting `gen` folder contains both the original `main_xbox.*` files and the Deluxe `patch_xbox.*` files.

   [Get Rock Band 3 Deluxe](https://rb3dx.milohax.org/downloads/)

4. Run **`RockBand3DeluxeLauncher.exe`** from the extracted Windows application. Select **Choose XEX** and choose `default.xex` from the combined game folder you prepared in step 3. Once the launcher verifies the files, press **Play**.

The application ZIP supplies the compiled PC executable, launcher, and required runtime libraries. You supply the Xbox 360 game files, Deluxe files, and any songs you import. Keep `runtime`, `licenses`, `game-files.json`, the launcher configuration file, and `Update-App.ps1` beside the launcher when moving the application.

The tested Deluxe XEX has SHA-256 `6639CE25745505B598480499CA53B421FDEC5604D813F5EE2C8152ECDAD2A5EA`. The launcher supports the regular and Custom Characters archive sets listed in `launcher-src/game-files.json`. If a future MiloHax build changes its XEX or archive set, use a port release that supports that build.

## Controls

**Edit controls** selects keyboard or connected controllers, maps instrument buttons and axes, and saves separate guitar and drum profiles.

| Action | Keyboard guitar | Keyboard drums |
| --- | --- | --- |
| Frets or pads | 1–5 | D, F, J, K |
| Strum or kick | ↑ / ↓ | Space |
| Confirm / back | 1 or Space / 2 or Backspace | 1 / 2 |
| Whammy | W | |
| Overdrive | Tab | Complete a fill and hit the final green pad |
| Pause | Enter | Enter |

**Performance mode** reduces shader compilation stalls during scene transitions. **VSync** synchronizes presentation with the display. Both apply on the next game start. Render-to-texture readback is configured as `fast` for Deluxe textures.

## Custom songs and DLC

Open **Songs & DLC**, then select Rock Band 3 Xbox 360 packages. Customs such as `_rb3con` files can be selected without adding an extension. Extract ZIP or RAR downloads first, then import the song package inside. Restart the game so its song cache scans the new content.

The importer accepts matching LIVE/PIRS DLC and CON custom song packages with `songs/songs.dta`. Imported songs are stored in `userdata` beside the launcher. **Saves** and **Logs** open their corresponding folders.

## Custom characters

Use the **Main + Custom Characters → Xbox 360** download in step 3. The launcher identifies this edition as **Deluxe + Custom Characters**. Choose characters through Deluxe's in-game character and band menus.

MiloHax recommends switching from a stock character with the same body type to avoid face deformation. Remove custom characters from band stand-ins before switching back to regular Deluxe.

## Updates

The launcher checks this repository's latest published release at startup. Click **Updates** or **Update available** to check manually and approve downloading a newer version. It verifies the package, updates the launcher and compiled application files together, and restarts. Close the game before installing an update.

Your launcher settings, saves, imported songs, shader cache, and game folder stay in their own locations. Deluxe game data comes from the MiloHax download separately. You can also update manually by extracting a newer Windows application ZIP over the application folder.

## Troubleshooting

- **The port executable is missing** — extract the entire Windows x64 application ZIP and run its launcher. `runtime/rockband3deluxe.exe` must be present.
- **Missing game files** — select the merged game folder from step 3. The Deluxe download supplies the patch archives. The extracted disc supplies the original archives.
- **After moving to another drive** — use **Choose XEX** again to select the game folder on the new drive. Move the complete application folder, including `userdata`, to keep your saves and imported songs.
- **A song closes the game** — open **Logs** and attach the latest session log to an issue, along with the song name, instrument, and graphics settings.

This is a preview. Songs have been played on Windows and the Custom Characters edition's startup has been checked. Testing continues across songs, characters, controllers, and PCs.

## Source and credits

Build instructions, the pinned SDK revision, and compatibility details are in **BUILDING.md**. Releases contain the playable application. The repository contains the host code, launcher, import helper, SDK patches, and build scripts.

[Build from source](BUILDING.md) · [Report a problem](https://github.com/mercurialw0rld/rb3deluxe-pcport/issues) · [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk)

Rock Band 3 Deluxe is by MiloHax. This port builds on the earlier The Beatles and Green Day ports, ReXGlue/Xenia, and SDL. See the component notices in `licenses` and `THIRD_PARTY_NOTICES.md`. Rock Band 3 and its original assets belong to their respective owners.
