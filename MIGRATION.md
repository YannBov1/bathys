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

- The UI is a compact layout rather than a pixel for pixel recreation. Gas, tissue, tank, and timeline values use the reference model, and the diver now interpolates between frames.
- The survey grid uses 1 cm elevation quantization; a sampled terrain depth can differ by up to about 0.005 m from the CSV source. The simulation reference fixtures do not use this quantized value.
- POIs are read only in the current interface; plan exports retain the existing saved-plan JSON format.
- `user://` persistence depends on browser storage. Plan export/import provides a recovery path for plans.

## Visual parity revision

The next pass follows the C# application's header, tank rail, central site panel, route/site/tissue tabs, and persistent physiology dashboard. It adds matching dark teal cards, spacing, button states, twelve vector icon assets, a branded app icon, a compass, depth legend, navigation hints, and readable terrain labels with leader lines.

Missing readouts restored: ten live metric cards and reference gas guidance bands; OTU, temperature, applied GF, controlling compartment, first stop, active gas and cumulative gas use; route leg distance, true bearing, depth change, duration, active gas, SAC and speed; site density and metres per bar at 0/20 m, pressure, temperatures, salinity, observed POI spreads and coordinates. Added the entrance route action and guarded tank removal.

All five plots are now scrollable together, use the reference units and colours, support click/drag seeking, and share a playback cursor. The depth profile puts the surface at the top and includes gas switch event lines. Diver movement interpolates between simulation frames.

POI creation, editing, deletion, and loading of prior POI overrides have been removed as requested. Points remain available for focusing the view and adding route waypoints.

Validation: 483 reference checks and 21 interface smoke checks pass. Standard Godot launch and Web export succeed. Browser verification covers the revised rendering, read only site tab, tissue tab, plot navigation, scrubber, and view switching; there were no browser console warnings or errors.

Route, cylinder and environment settings now use inline editors, replacing the earlier dialogs. Browser plan import/export remains available.


Latest browser measurement for the visual revision: 1.77 s page to map, 3.73 s page to completed simulation, 1.89 s calculation, 22 ms terrain loading, and 66.625 MB allocated Wasm heap. The 2D five-sample average was 59.4 FPS; a preceding revision in this pass recorded 45.8 FPS in 3D. These are local measurements, not a cross browser benchmark. The final browser console had no errors or warnings. A reviewed screenshot is saved at Screenshots/web-polish.png.


## Inline editor revision

Routes now have inline names, expandable depth/speed/SAC and hold-duration controls, collapsible WGS84 coordinates, and inline gas selectors. Cylinders have inline names, volume, start/reserve pressures and percentage mix controls. Environment and GF/rate settings are directly editable in the Site tab. Numeric changes debounce simulation for 350 ms; readouts update without replacing focused controls. Expanded route and tank cards survive undo/rebuilds by ID.

The tank glyph now follows the C# shaded cylinder, valve, oxygen percentage band and mix colour. SPG needles animate toward the playback pressure. Tissue pressure values, vector arrow symbols and right-aligned orange GF limits share one line.

Additional parity fixes: live model summary after GF edits; guarded removal of the starting tank; gas switches choose another tank; clearing the route resets playback, charts and readouts to an empty-plan state.

Validation: 483 simulation reference checks pass. The UI smoke suite now also covers inline field changes, retained control instances through simulation/playback, dial range updates, live environment/model summaries, tissue arrows, undo, gas-switch choice and empty-route behavior. The latest UI run reports zero failures.

Browser verification of the inline revision succeeded after restarting duplicate preview servers. Direct keyboard edits to route SAC and cylinder start pressure updated the model and preserved expanded editors. Site controls, compact tissue rows, scrubbing, route clear and undo were checked in the exported build; the final console had no warnings or errors. Latest local metrics: 3.00 s page to simulation, 1.62 s simulation calculation, 20 ms terrain load, 66.94 MB Wasm allocation, and a 51.2 FPS five-sample 3D average. Export size: 61,140,790 bytes. Reviewed images: Screenshots/inline-editors.png and Screenshots/inline-tissues.png.

## 2D navigation and response revision

Both 2D views now draw direction arrows and true compass bearing / distance labels for route segments, matching the reference thresholds (over 3 m and over 85 screen pixels). The Site tab now contains only environment and decompression settings, without the observed-point list or a nested card.

Map clicks update route geometry and cards immediately and cross a render frame before calculation begins. Simulation uses the same model in approximately 8 ms batches and yields to the event loop between batches. Each run uses a plan snapshot; newer edits cancel outdated runs so their results cannot replace the latest plan. Map edits avoid rebuilding unrelated panels.

Validation: all 483 reference checks pass; UI smoke tests pass; the new responsiveness suite verifies early waypoint drawing, successive clicks, cancellation and removal of Site panels. It also compares every field of every frame from the cooperative run with the synchronous run using exact serialized equality: no numerical differences.

Browser verification: satellite and bathymetry bearing labels were visually checked. Two rapid POI clicks displayed both waypoints while simulation was pending, then completed the correct two-leg simulation. The final browser console had no errors or warnings. Screenshot: Screenshots/2d-navigation.png.

Latest local measurements: initial map ready at 1.12 s; initial simulation finished at 5.20 s (3.76 s wall time in the cooperative calculation, including time yielded for rendering). Five-sample averages were 44.2 FPS in 3D and 60.0 FPS in 2D. Initial Wasm allocation was 66.94 MB; after cancellation/recalculation it reached 80.38 MB. Total calculation wall time is longer than the previous blocking run because UI frames run between calculation batches.

## Bathys logo

Created a new navy/cyan wave-and-depth emblem from the supplied inspiration sheet using built-in image generation. The master is preserved with transparency; Godot prepares 256 px and 512 px runtime versions. The emblem is paired with native typography in the header and web loading screen and is used for the application, browser and touch icons. The README also displays it. Generation provenance and the exact prompt are in Assets/Brand/README.md.

The branded web loader uses local exported assets and requires no external fonts or image hosts. Its actual loading state was visually checked with a deliberately delayed localhost pack download, followed by a successful transition into the app. Standard Godot validation, native launch, Web export and UI smoke tests pass; the browser console had no warnings or errors. Screenshots: Screenshots/brand-header.png and Screenshots/brand-loading.png.
