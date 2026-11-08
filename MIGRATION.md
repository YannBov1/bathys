# Migration record

The destination directory was supplied as a new worktree, but had no `.git` directory or worktree metadata. Changes are grouped below by the requested runnable milestones. No commit was created in the C# reference repository, and nothing was deployed.

## 1. Map and packaged data

- Replaced the C# project configuration with a standard Godot 4.7.2 Compatibility project.
- Loaded site JSON and satellite imagery through `res://` and displayed the satellite and bathymetry maps.
- Prepared a 3.286 MB binary grid offline from the reference survey. It retains raw measured and interpolated cells separately: 439,564 measured and 2,184 interpolated cells in 640 small patches.
- Built the default bathymetry overlay offline. Waterline edits recolour the overlay on demand.
- Validated scripts, launched the project, exported Web, and checked the first map in a Chromium based browser.

## 2. Plans and simulation

- Ported the dive model to typed GDScript with double precision arrays for geographic and tissue values.
- Preserved the saved plan JSON format, legacy waterline migration, gas switch and hold event handling, undo/redo, and POI merge behavior.
- Added `user://` save/load plus browser download and file import for plan recovery.
- Compared C# generated frames and Python fixtures for gas use, tissue pressures, ceiling, NDL, TTS, switches, holds, and scrubbing. The `Tests/Reference.gd` suite passes **483/483** checks. The C# reference suite passes **122/122** checks. No existing tolerance was loosened.
- The GDScript example duration differs from C# by −0.00000000235445 s. Against the Python planner, the example NDL differs by −60 s and TTS by +2.873138959 s; these are the existing C# versus Python differences, within the preexisting 120 s and 10 s tolerances.
- Validated, launched, exported Web, and exercised save, browser download, import, route hold, and undo in the browser.

## 3. UI

- Added route, site, tank, tissue, graph, playback, and vitals UI. Tissue bars use one scale computed over the full plan; cylinder SPGs show reserve arcs. Gas guidance bands match the reference thresholds.
- Kept the educational warning and swisstopo attribution visible.
- Validated, launched, exported Web, and inspected the UI and browser console.

## 4. 3D terrain

- Prepared 41 mesh tiles offline, with 878,652 triangles in total. The app loads these on first 3D activation.
- Ported the depth colouring shader and added Compatibility lighting, route and POI overlays, and heightfield ray picking. Runtime waterline edits translate the terrain mesh.
- Validated, launched, exported Web, and visually checked the terrain, colour bands, lighting, overlays, and a surveyed bed click in the browser. There were no console errors or warnings.

## 5. Performance and browser check

- Avoided per launch survey CSV parsing, overlay painting, and mesh construction. The 3D viewport stops rendering while hidden, and playback panels update when the selected frame changes.
- Final Web export: **61,059,023 bytes** total, including **21,206,744 byte** pack and **39,514,754 byte** Wasm runtime.
- On the in-app Chromium based desktop browser, page to visible map was **0.83 s**, page to finished simulation was **2.27 s**, simulation calculation was **1.39 s**, and first terrain load was **20 ms**. Wasm heap allocation after simulation and after terrain load was **66.5 MB**; this excludes GPU and browser process memory. Five one second FPS samples averaged **48.4 in 2D** and **58.8 in 3D**. Results depend on this machine and browser window.
- The exported browser build reported WebGL 2.0 Compatibility, single threaded Emscripten, and no GDExtension support. The console had no errors or warnings. Firefox was available but desktop computer control approval timed out, so cross browser verification remains open.

## Known differences and limits

- The UI is a compact layout rather than a pixel for pixel recreation. Gas, tissue, tank, and timeline values use the reference model, while the reference's smooth between frame diver interpolation is not yet reproduced.
- The survey grid uses 1 cm elevation quantization; a sampled terrain depth can differ by up to about 0.005 m from the CSV source. The simulation reference fixtures do not use this quantized value.
- Plan export contains the saved plan JSON, not the independent POI edit store. Browser storage can erase POI edits; users should record them separately.
- `user://` persistence depends on browser storage. Plan export/import provides a recovery path for plans.
