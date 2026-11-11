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

The left column shows cylinder SPGs and gas metrics. The right tabs edit the route and environment, show environment and decompression settings, and display tissues. Physiology starts with Depth; the **+** menu adds optional readouts. Value and unit share one row in compact cards. Drag the dividers beside the map to resize the tanks and route panels. Drag to the outer edge to collapse a panel, and drag inward from the remaining handle to restore it. Settings includes default SAC and swim speed for newly created route events. Click a POI or surveyed bed to inspect it, then choose **Add waypoint**. Always-visible **+** controls between route cards insert holds and gas switches. Drag any non-editable area of a route card to reorder it; an insertion line shows the destination. The list scrolls near its edges during a drag. Undo/redo and Alt+Up/Down on a focused card remain available. The lower timeline seeks or plays the simulation and switches among depth, TTS, NDL, CNS, and OTU plots. The 3D view loads on demand and supports orbit, pan, zoom, and terrain picking.

See [MIGRATION.md](MIGRATION.md) for the milestone record, numerical comparison, and browser measurements.






## Languages

English is the default. Use the flag in the header to select **English** or **Français**. The app remembers the chosen language on this device. Language changes preserve the current plan and playback; user-entered names are kept as written. French translations are maintained in `Data/i18n/fr.json`, with local SVG flag assets. Translation templates retain the English format placeholders.


## Interactive lessons

The header remains fixed while content scrolls. In learning, the categorized lesson list and lesson content have independent scroll containers. The icon switch in the header changes between the map workspace and the learning workspace (open-book icon). The map opens by default. Entering a lesson pauses playback; switching back preserves the scenario, time, map view, panel visibility and undo history. Scenario file actions are hidden while learning, and the language selector remains available.

Lessons open on one main experiment, with short gesture cues and visible drag handles. Move bubbles/divers, gas bars, vessel walls and diffusion barriers directly. Thermometers, pressure gauges, clocks, depth rulers and gas/salt vessels replace exposed slider panels. The chart icon opens a linked comparison; the gear opens precise values and additional variables; the information icon opens equations, full readouts, explanations, assumptions and sources. These views are independent, so a chart can be studied without reopening all the text. Visual instruments also support focus, arrow keys and Home/End.

Phone layouts use shorter stage tabs and a compact topic picker. The colour lesson combines surface/reference and underwater previews into one draggable before/after image; the paired reference view remains available in the expanded view. Instrument grips accept intentional drags while captions leave room for scrolling. A visible gas preset highlight identifies the current standard mixture.

Choose a topic in the left navigation:

- **Boyle’s law:** drag the gas sample through the water; precise depth and presets remain in the parameter inspector. A fixed gas sample shrinks under increasing absolute pressure, alongside a linked pressure–volume curve and live readouts. The simplified example starts with 1 L at 1 bar absolute and adds 1 bar per 10 m. Temperature and gas amount remain constant; bubble radius scales with the cube root of volume. This sea-level example is separate from the lake’s pressure/density model.
- **Snell’s law:** two stages separate a single interface from the diving mask. In **Boundary & rays**, adjust incidence with the slider or drag in the incoming medium. Switch air → water / water → air to explore bending toward/away from the normal, the critical angle and total internal reflection. Uses n = 1.000 / 1.333, a flat boundary and angles measured from the normal. Partial reflection below the critical angle is omitted. **Mask & apparent size** traces exact rays through water, parallel glass and mask air. Change object distance/height, eye spacing, window thickness and index; compare real geometry, edge back-projection, both interface angles and fixed-angular-field views of the same target. The size ratio is angular, not physical growth. A flat parallel window is distinguished from a corrective lens; the familiar 1.33×/0.75× values are small-angle limits.

- **Dalton’s law:** adjust depth, oxygen fraction and helium fraction, or use air/nitrox/trimix examples. Nitrogen fills the remainder; changing a fraction adjusts the other editable fraction if needed to keep the total at 100%. Colour-coded bars show the individual ambient partial pressures and their stacked total. Uses ideal dry gas and the same simplified 1 bar + depth/10 sea-level pressure model as Boyle’s example.
- **Henry’s law:** change gas partial pressure to move the equilibrium dissolved concentration, then scrub elapsed half-times to follow uptake or release. The liquid’s dots represent dissolved molecules, not bubbles. Concentrations are relative to equilibrium at 1 bar for one fixed gas/liquid/temperature, with k normalised to 1 reference unit/bar. Henry’s law sets equilibrium; a separately labelled single-compartment exponential example shows exchange from the initial reference concentration. Pressure-step presets reset the elapsed time.
- **Water density & pressure:** change temperature (0–35°C) and salinity (0–40, approximately g/kg) to link density with metres per additional bar and hydrostatic pressure at 10 m. A density/temperature curve at the selected salinity reveals the freshwater maximum near 4°C. A water column shows the height needed for +1 bar, compared on the same scale with fresh water at 20°C. Reuses the app’s EOS-80 surface-density polynomial and g = 9.80665 m/s², assumes uniform water and omits compression/stratification. The salinity convention approximates practical salinity as g/kg; this is not TEOS-10 Absolute Salinity.

- **Bühlmann ZH-L16C:** two stages separate tissue loading from gradient-factor exploration. Choose exposure depth/time, select any of the 16 theoretical compartments and compare the bars with the selected nitrogen half-time curve. In the ascent stage, preview a pressure step, wait on air, and adjust GF Low/High to compare actual tissue pressures with M-values and GF limits. Readouts identify applied GF, selected tissue N₂, the instantaneous model ceiling and its controlling compartment. Bars can be selected by pointer or keyboard, and both plots support dragging.

- **Oxygen toxicity:** explore depth, oxygen fraction and duration, linking ppO₂ with separate CNS and OTU exposure indexes. The CNS dial explains elapsed time versus the app’s interpolated historical NOAA-style allocation; 100% is a table allocation rather than a symptom threshold. The historical bar-based table is deliberately not extrapolated beyond 1.6 bar. OTU uses ata and identifies 1 OTU as one minute at 1 ata O₂. Constant single exposures exclude recovery and prior loading; these are indexes, not individual illness probabilities or recommended modern exposure limits.
- **Nitrogen narcosis:** compare actual depth, equivalent narcotic depth (END) and counted gas pressure. Edit oxygen/helium fractions and choose whether to count N₂ + O₂ or N₂ only, with an explicit air-reference fraction for each assumption. Under the default equal O₂/N₂ convention, nitrox has the same END as air. Negative theoretical END is displayed as ≤0 m, with an explicit surface-reference comparison. END is not an impairment score and excludes CO₂, HPNS and individual response.
- **Gas density & breathing:** compare a mixture and air at equal depth and gas temperature with one-litre mass diagrams and cached real-gas density curves. Change depth, O₂/He fractions or gas temperature (distinct from water temperature). Uses the app’s Peng–Robinson calculation; the ideal trend uses absolute temperature in kelvin. Schematic dots illustrate compression and molecular mass. Fixed 5.2 and 6.2 g/L teaching references come from breathing/CO₂ literature and do not predict equipment-dependent work of breathing or individual safety.

- **Archimedes & buoyancy:** explore mass, rigid volume, partial immersion and fresh/sea water. Drag the body through the surface; a linked bucket shows the displaced water’s volume and mass, while arrows and four readouts compare buoyancy, weight and net force. Floating equilibrium sets the submerged fraction only when physically possible. A second experiment adds a fixed trapped gas sample and depth: pressure compresses the gas, changes displacement and shifts buoyancy. Balance the teaching mass at one depth, then preview ascent/descent without adding gas. The gas law uses absolute pressure from the selected uniform water density, rather than assuming exactly 10 m per bar.

- **Colour underwater:** compare a known synthetic colour/detail target in surface daylight and received underwater light. Three stages explore depth versus viewing range, optional off-axis white torch lighting, direct/forward-halo/backscatter component views, spectral a/b/c/Kd and a chosen HG phase function, then separate effective direct/backscatter coefficients after spectral integration. Six marine Jerlov presets use traceable offline tables; the phase function, torch geometry and forward halo are explicit teaching approximations. This is not a calibrated lake/camera simulation or full multiple-scattering solver. See [optical model and data provenance](Data/Optics/PROVENANCE.md) for equations, source distinctions, licences and reproducible preparation.

- **Charles’s law:** a movable piston, fixed particle count and linked V/T curve show expansion at constant pressure. Celsius and kelvin appear together; presets contrast 20°C → 40°C with doubling absolute temperature. A dashed ideal extrapolation is distinguished from the supported experiment range.
- **Ideal gas law:** choose pressure or volume as the dependent variable, then change temperature, gas amount and the remaining constraint. The schematic vessel, selectable temperature curve and readouts satisfy PV = nRT with explicit absolute units and bar·litre-to-joule conversion.
- **Real gases & compressibility:** compare equal-mole ideal/real volumes and a draggable Z/pressure curve for dry air, nitrogen or helium. A separate pair of 12 L readouts shows how fixed-cylinder gas amount changes by 1/Z. Reuses the planner’s Peng–Robinson parameters and mixing assumptions.
- **Joule–Thomson & gas cooling:** compare real-gas isenthalpic throttling, an ideal-gas throttle and an ideal reversible expansion delivering shaft work. Gas, inlet temperature and both pressures control a flow diagram and outlet-temperature curve. Readouts distinguish local inlet μJT from a finite pressure-drop solution; nitrogen cooling and helium warming presets make the sign visible. The real-gas solver conserves enthalpy rather than extrapolating a constant μ. [Thermal model notes and references](Data/ThermalModels.md) document the EOS, heat capacities and excluded heat-transfer/icing effects.

- **Fick’s law & gas exchange:** a new Physiology lesson with separate lung and tissue experiments. Pressure-gradient examples show O₂/CO₂ directions and inert-gas uptake/release. Adjust exchange area, thickness, effective permeability, receiver storage and contact time; net arrows and a draggable pressure/time curve show diffusion and equilibration together. Initial/current relative rates distinguish increased conductance from a gradient already reduced by faster uptake. Pressure examples do not supply measured gas-specific permeability, and time/rate/storage scales are explicitly normalized. See [exchange and mask model notes](Data/ExchangeMaskModels.md).

All sixteen lessons support English/French, keyboard-accessible visual instruments and narrow layouts. Precise sliders remain in the parameter inspector. On small screens, the topic list becomes a compact selector and paired diagrams stack vertically. Experiment settings survive topic/workspace/language changes for the current session. Run `godot --headless --path . --script Tests/LearningUi.gd` and `godot --headless --path . --script Tests/ScienceLearning.gd`, plus `godot --headless --path . --script Tests/BuhlmannLearning.gd` and `godot --headless --path . --script Tests/BreathingLearning.gd`, plus `godot --headless --path . --script Tests/BuoyancyLearning.gd`, `godot --headless --path . --script Tests/OpticsLearning.gd`, `godot --headless --path . --script Tests/ThermalLearning.gd`, `godot --headless --path . --script Tests/ExchangeMask.gd` and `godot --headless --path . --script Tests/LessonIntuition.gd`; add `-- --visual` without `--headless` to record rendered screenshots.

References: [NASA: Boyle’s law](https://www.grc.nasa.gov/www/BGH/boyle.html), [OpenStax: total internal reflection and Snell’s window](https://openstax.org/books/university-physics-volume-3/pages/1-4-total-internal-reflection), [Divers Alert Network: lung expansion](https://dan.org/alert-diver/article/lung-expansion-injuries/).


Additional lesson references: [OpenStax: Dalton’s law](https://openstax.org/books/chemistry-2e/pages/9-3-stoichiometry-of-gaseous-substances-mixtures-and-reactions), [OpenStax: Henry’s law](https://openstax.org/books/chemistry/pages/11-3-solubility), [DAN: gas exchange and half-times](https://world.dan.org/health-medicine/health-resource/dive-medical-reference-books/decompression-sickness/introduction/), [UNESCO: EOS-80 algorithms](https://www.vliz.be/imisdocs/publications/ocrd/122840.pdf), [OpenStax: hydrostatic pressure](https://openstax.org/books/university-physics-volume-1/pages/14-1-fluids-density-and-pressure).


The Bühlmann lesson reuses `BathysTissue` nitrogen coefficients/exchange/ceiling calculations and `BathysDeco.gf_at`. Its air-only example starts at equilibrium at 1 bar, uses inspired N₂ = (ambient − 0.0627 bar) × 0.79 and the simplified +1 bar/10 m pressure model. Pressure steps deliberately have no travel time. The ascent preview always starts from the chosen loaded state, then waits at the preview pressure; changing inputs recomputes that experiment rather than appending to a dive. The GF Low illustration anchor is the loaded state’s GF Low ceiling rounded up to a 3 m multiple (zero if no ceiling), frozen during the preview; interpolation reaches GF High at the surface. This is a transparent frozen-tissue illustration, not a first-stop prediction or ascent schedule. Both the model assumptions and the distinction between theoretical compartments and real organs are explained in the lesson.

Bühlmann/GF references: [Shearwater technical manual, decompression and gradient factors](https://www.shearwater.com/wp-content/uploads/2022/05/Petrel-3_Technical_Manual_RevB.pdf), [DAN: compartment half-times](https://world.dan.org/health-medicine/health-resource/dive-medical-reference-books/decompression-sickness/introduction/), [Ceiling-controlled versus staged decompression](https://pmc.ncbi.nlm.nih.gov/articles/PMC9016140/).


Learning categories: **Physics of diving** (Boyle, Snell, Dalton, Henry, water density, Archimedes/buoyancy and gas density), **Physiology** (oxygen toxicity and nitrogen narcosis), **Models & risk** (Bühlmann). The phone selector includes the same category separators and stable topic IDs. Topic scrolling never moves the lesson; lesson scrolling never moves the topic list or top ribbon. The ribbon also remains fixed in the planner. Experiment values survive language/topic/workspace changes without modifying scenario data.

Breathing-lesson references: [DAN: oxygen toxicity](https://dan.org/health-medicine/health-resources/diseases-conditions/oxygen-toxicity/), [2025 oxygen-guideline paper discussing the historical CNS clock](https://pmc.ncbi.nlm.nih.gov/articles/PMC12500339/), [NOAA: narcosis and oxygen toxicity](https://www.omao.noaa.gov/sites/default/files/documents/Inert%20Gas%20Narcosis%20and%20O2%20Toxicity_slides121316.pdf), [scuba package: END convention](https://search.r-project.org/CRAN/refmans/scuba/html/END.html), [DAN: gas density and breathing](https://dan.org/alert-diver/article/performance-under-pressure/), [Anthony and Mitchell: breathing/CO₂ study discussion](https://rebreatherforum.tech/wp-content/uploads/2022/11/rebreathers_and_scientific_diving_proceedings_2016-copy.pdf).


The buoyancy lesson uses Fᵦ = ρgVdisplaced, W = mg and Vgas = Vsurface / Pabsolute with 1 bar at the surface. Water density uses the existing EOS-80 approximation at 20°C. The rigid body is schematic; force direction is shown without motion integration. The gas-at-depth example is fully submerged, neglects gas mass, and excludes active inflation/venting, suit compression and real-world weighting advice. [OpenStax: Archimedes’ principle and buoyancy](https://openstax.org/books/university-physics-volume-1/pages/14-4-archimedes-principle-and-buoyancy).

## 3D terrain relief

The 3D lakebed keeps its original geometry and depth palette, with world-space directional hillshading and a gradual warm accent for steep slopes (approximately 30–60° from the existing smoothed mesh normals). Five-metre contours use screen-aware line widths for clearer edges. This is a rendering aid, not new survey information; picking, route positions, waterline transforms and terrain dimensions are unchanged. The shader uses a single Compatibility-compatible pass without new textures or shadow maps. Run `godot --path . --script Tests/TerrainRelief.gd` for native viewpoint captures. [Godot spatial-shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).
