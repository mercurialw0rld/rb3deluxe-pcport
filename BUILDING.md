# Compilar Rock Band 3 Deluxe para Windows

Proyecto de recompilación estática para Windows x64 y Direct3D 12. Usa el `default.xex` de Deluxe y un directorio de juego que combina los `main_xbox.*` del disco con los `patch_xbox.*` de Deluxe. El launcher comprueba el SHA-256 del XEX y el tamaño de todos los archivos requeridos.

- Title ID: `45410914`.
- SHA-256 del XEX Deluxe: `6639CE25745505B598480499CA53B421FDEC5604D813F5EE2C8152ECDAD2A5EA`.
- Reutiliza perfiles de guitarra y batería, entrada SDL, XAudio2 y el importador de DLC del port de Green Day. También usa los parches del SDK de The Beatles para esperar el swap chain, temporizar esperas de GPU con precisión, redirigir clears MSAA reconocidos y compilar pipelines en segundo plano.
- **VSync** sincroniza la presentación D3D12 con la pantalla desde el próximo arranque. Arranca desactivado para conservar la presentación usada por los ports de referencia. **Performance mode** sigue controlando las esperas de compilación de shaders.
- `readback_resolve = "fast"` copia los resultados de render a textura a memoria del juego con un cuadro de demora.

## Preparar y compilar

Se necesita Git, Visual Studio 2022 Build Tools con C++ para escritorio, Windows SDK, Clang, CMake y Ninja. Pasá `-VsInstallDirectory` si están en una ubicación que `vswhere` no encuentra. El launcher WinForms se compila con .NET Framework.

Desde esta carpeta en PowerShell, reemplazá las rutas de ejemplo por las de tus archivos:

```powershell
.\Prepare-Game.ps1 -BaseDirectory 'C:\Games\Rock Band 3 [RF]' -DeluxeDirectory 'C:\Games\RB3DX-Xbox' -Copy
.\Build-Sdk.ps1
.\Build-Game.ps1
.\Build-Launcher.ps1
```

`Prepare-Game.ps1` arma `out/game`. Podés omitir `-Copy` si las fuentes y el destino están en el mismo volumen NTFS y permiten enlaces duros. La opción `-Copy` requiere aproximadamente 6,6 GB libres. Los originales se leen desde sus carpetas.

`Build-Sdk.ps1` descarga el SDK 0.10.0 fijado al commit `bd833a2ab69d305f99ddf57418fc38ffec8af93d` y aplica los dos parches en `sdk-patches`. Para usar una instalación compatible con estos parches, pasá su ruta como `-SdkDirectory` a `Build-Game.ps1`.

`Build-Game.ps1` genera C++ del XEX Deluxe. `-GenerateOnly` sirve para revisar la salida del generador antes de compilar. El launcher compilado queda en `out/portable`. Seleccioná el XEX de `out/game` si el launcher no lo encuentra automáticamente. Si movés la carpeta portable a otro equipo, instalá el redistribuible x64 de Visual C++ o pasá `-CrtDirectory` al empaquetar el launcher con el runtime.

## Canciones personalizadas y DLC

Abrí **Songs & DLC** en el launcher completo y seleccioná los paquetes de Rock Band 3 para Xbox 360. Podés elegir un archivo `_rb3con` aunque no tenga extensión. Si la descarga viene comprimida, extraé primero el paquete. Al reiniciar el juego se vuelve a escanear el catálogo de canciones.

## Personajes custom

El launcher admite Deluxe y [Principal + personajes custom](https://rb3dx.milohax.org/es/downloads/). Las dos descargas verificadas usan el mismo XEX. `Prepare-Game.ps1` detecta la edición por el conjunto de archivos `patch_xbox.*`. Podés preparar la edición con personajes en su propia carpeta.

```powershell
.\Prepare-Game.ps1 -BaseDirectory 'C:\Games\Rock Band 3 [RF]' -DeluxeDirectory 'C:\Games\RB3DX-Xbox-CustomCharacters' -OutputDirectory '.\out\game-characters' -Copy
```

Seleccioná `out/game-characters/default.xex` en **Choose XEX**. El launcher indica **Deluxe + Custom Characters** cuando verifica esos archivos. MiloHax recomienda elegir un personaje base con el mismo tipo de cuerpo al cambiar a uno custom para evitar deformaciones. Antes de volver a Deluxe sin personajes, quitá los personajes custom de los sustitutos de la banda.

## Trasladar el juego a otro disco

Con el juego y el launcher cerrados, ejecutá `scripts/Move-ToExternal.ps1` desde PowerShell. El destino predeterminado es `L:\RockBand3Deluxe-PC` y se puede cambiar con `-Destination`. El script copia `out/game-characters` y `out/portable`, compara sus SHA-256 y actualiza la ruta del XEX. Tras verificar el launcher en el destino, elimina esas dos carpetas de origen para liberar espacio. Los fuentes y la instalación del SDK quedan dentro del proyecto.

## Estado verificado

Se recompiló el XEX Deluxe para Windows x64 y se verificó su huella SHA-256 con el launcher. Se probó el arranque con VSync activado y desactivado. El log confirma que la build aplica `readback_resolve = "fast"`. En una prueba interactiva en Windows se cargaron y jugaron canciones. En una prueba automatizada con VSync activado se registró un acceso inválido de memoria cuya causa sigue sin confirmarse. La repetición con VSync activo se mantuvo ejecutándose durante 65 segundos. Se importó la custom Oceania desde un CON sin extensión y se verificó que Rock Band 3 leyó su songs.dta al escanear el catálogo. Se preparó la edición Custom Characters con su disco base y se comprobó el arranque durante 60 segundos con VSync activado. Queda por verificar un personaje custom dentro de una canción.

Después de compilar, `Build-Launcher.ps1` prepara `out/portable` con el launcher, el ejecutable nativo, los helpers y las DLL de Visual C++. `Package.ps1` genera `out/RockBand3Deluxe-v0.1.0-preview-windows-x64.zip`, su SHA-256 y el manifiesto que utiliza el actualizador. El empaquetador usa una lista de archivos de aplicación.

```powershell
.\Build-Launcher.ps1
.\Package.ps1
.\tests\Test-Updater.ps1 -ApplicationDirectory .\out\portable -PackagePath .\out\RockBand3Deluxe-v0.1.0-preview-windows-x64.zip
```

Las pruebas del actualizador usan datos sintéticos dentro de una carpeta nueva de `out`. Verifican el orden de versiones, paquetes inválidos, SHA-256, instalación, recuperación ante un archivo bloqueado y conservación de datos del jugador.
