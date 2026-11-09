<img src="Assets/Brand/bathys-256.png" width="96" alt="Bathys logo">

# Bathys Web

Godot 4.7.2, typed GDScript, Compatibility renderer. This project exports with the **standard Godot editor**, without .NET or Godot C# support. It is educational software only and must not be used for real dive decisions. The app displays its warning and © swisstopo SWISSIMAGE attribution.

## Run and test

Open this directory in standard Godot 4.7.2, then run `Main.tscn`. The Web export preset writes `WebBuild/index.html`; serve `WebBuild` over HTTP to test the exported app in a browser. For command line use, substitute your standard Godot 4.7.2 executable:

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script Tests/Reference.gd
godot --headless --path . --script Tests/UiSmoke.gd
godot --headless --path . --script Tests/Responsiveness.gd
godot --headless --path . --export-release Web WebBuild/index.html
python -m http.server 8765 --bind 127.0.0.1 --directory WebBuild
```

The Web preset does not package `Tools` or `Tests`. `Data/survey_grid.dat` is explicitly included. The source app in `../bathys` remains independent and runnable.

## Data and persistence

Packaged site JSON, satellite imagery, survey grid, bathymetry, and terrain tiles load from `res://`. The grid stores raw measured elevations and separately flagged interpolated small gap values; the rendered mesh uses the same display smoothing as the C# reference. The web app does not parse the full survey CSV or build the terrain and overlay pixel by pixel on launch.

Plans persist in `user://plan.json`. Packaged POIs are read only. **SAVE** downloads a plan JSON file and keeps a backup in local `user://` storage. **LOAD** opens a plan file or the saved backup on this device. **EXPORT** downloads the current 2D or 3D map view as a JPG, with source attribution. The gear opens gas-limit settings; these are included in plan files and remembered as defaults for new scenarios on this device.

Offline data preparation, when the source survey changes:

```powershell
dotnet run --project Tools/PrepareGrid.csproj
python Tools/prepare_overlay.py
godot --headless --path . --script Tools/PrepareTerrain.gd
```

The first command links C# reference source as a **build tool only**. Its outputs are packaged data; it is never needed by the exported app.

## UI

The left column shows cylinder SPGs and gas metrics. The right tabs edit the route and environment, show environment and decompression settings, and display tissues. Physiology starts with Depth; the **+** menu adds optional readouts. Value and unit share one row in compact cards. Icon-only controls in the map toolbar collapse or restore the tanks and route panels independently. Settings includes default SAC and swim speed for newly created route events. Click a POI or surveyed bed to inspect it, then choose **Add waypoint**. Always-visible **+** controls between route cards insert holds and gas switches. Route cards can be reordered or edited, with undo and redo. The lower timeline seeks or plays the simulation and switches among depth, TTS, NDL, CNS, and OTU plots. The 3D view loads on demand and supports orbit, pan, zoom, and terrain picking.

See [MIGRATION.md](MIGRATION.md) for the milestone record, numerical comparison, and browser measurements.




