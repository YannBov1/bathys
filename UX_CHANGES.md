# UX refinements

## Compact interaction revision

- Location cards now contain only the location name, depth, coordinates and **Add waypoint**. Removed the descriptive paragraphs and Close button to keep inspection quick.
- Clicking outside the card dismisses it. A full-screen input surface consumes that click, including its release, so another point does not open immediately. A subsequent map click inspects a new point.
- Removed the scenario summary line and the More simulation details toggle. OTU, water temperature, applied GF, controlling tissue, first stop, active gas and gas used are individual options in the physiology **+** menu. Depth remains the only initially visible card.
- Route insertion controls now occupy a compact gap with no button padding. The + appears on hover or keyboard focus, bringing waypoint cards closer together without removing insertion access.

Verification: focused workflow checks include a full outside mouse click, card content, additional readouts and compact route gaps. Desktop screenshots were rendered and inspected. The interface smoke suite and Web export are checked after these changes.


## Settings, file actions and stable map revision

- Compact insertion **+** controls remain visible all the time, including between route events.
- The header has labeled **Load**, **Save** and **Export** actions with distinct icons, plus a settings gear. Load offers a plan file or the backup on this device. Save creates a JSON plan file and keeps a local backup. Export creates a JPG of the displayed satellite, bathymetry or 3D view with attribution.
- Settings expose minimum, working maximum and maximum ppO₂, a gas-density warning and maximum, and maximum END. Oxygen bounds drive simulation checks; the working oxygen limit also drives MOD. Density and END drive the warning gauges. Invalid combinations stay in the dialog for correction. Limits travel with plan JSON files, while applied limits are remembered as defaults for new scenarios on this device. Older plans keep the original default limits.
- New empty scenario and reset-limits actions are available inside Settings, keeping the header focused on file actions.
- Fixed the brief map jump by keeping the existing playback panel visible during recalculation. Previously, hiding it enlarged the map for the calculation, then restored its original size. Checks now monitor map bounds on every calculation frame when adding a waypoint or tank, and preserve pan and zoom.

Validation: 483 numerical reference checks and the interface smoke suite pass. Settings checks cover invalid combinations, saved-plan round trips, oxygen enforcement, gauge updates, persistent insertion controls and stable map geometry. Rendered 2D and 3D JPGs decode successfully and were inspected, along with the header and settings dialog.


## Collapsible panels, route defaults and compact metrics

- Added icon-only left/right sidebar toggles to the map toolbar, matching the outlined split-panel design in the reference. Each panel can be hidden independently, and both restore controls remain visible on the map. Collapsing panels also releases their space in the narrow layout.
- Settings now include default SAC (L/min) and swim speed (m/min). These populate new waypoints; new holds inherit the SAC. Changing defaults preserves existing events. Defaults are included in saved plan files and remembered for new scenarios on the device. Existing settings files with only gas limits remain supported.
- Physiology cards place value and unit on a single row. Smaller dismiss controls remove excess header height while retaining labels, units and gas guidance bands. Ordinary cards are about 61 px tall and guidance cards about 92 px, compared with the previous roughly 93 / 124 px layouts. The playback panel's minimum height was reduced to make the saved space available to the map.

Validation: panel tests cover independent collapse/restore, accessible icon controls, narrow layouts, default application, preservation of existing events, plan round trips, invalid inputs and card heights. Settings and interface regression suites pass. Desktop views of expanded/collapsed panels and settings were rendered and inspected.


## Draggable panel boundaries

- Removed the tanks and route toggle buttons from the map toolbar. The toolbar once again contains only 3D, 2D Satellite, 2D Bathymetry and Home in their original order.
- Added slim dividers at the panel boundaries. They show a double-headed resize cursor and highlight on hover or focus. Dragging resizes the adjacent panel; dragging to the left edge collapses tanks, and dragging to the right edge collapses the route panel. The edge handle stays available to drag the panel open again.
- Double-click or Enter also toggles the adjacent panel; arrow keys allow resizing. In the stacked narrow layout, dividers become horizontal with vertical resize cursors.

Validation: viewport mouse events verify resizing, collapse and restore for both panels, release after collapsing, resize cursors and the four-control toolbar. Existing panel/default tests pass. Expanded and collapsed layouts were rendered and visually inspected.


## English and French

- Added a flag-only selector in the header. The UK flag represents English; the French flag represents French. Its menu lists **English** and **Français**, marks the active choice, and changes the interface immediately.
- English is the initial default regardless of operating-system language. An explicit selection is remembered on the device in a separate language preference file; language preferences are independent of saved plans and gas settings.
- Added a French catalog for interface labels, settings, menus, tooltips, map POIs, chart titles, status text, educational notices and validation messages. Formatted messages are translated before inserting numerical values. Flag assets and translations are packaged locally for offline use.
- Switching preserves route/tank names and other stored content, simulation frames, playback, zoom and panel visibility. Newly generated names use the selected language. Charts and map labels update without reloading the app.
- Adjusted wrapping and metric-card column counts for longer French text. Metric units remain consistent; pressure-field suffixes translate with the interface.

Validation: language tests cover English as the initial default, both flags, native language names and active menu state, switching in both directions, translated formatted errors, preservation of plan data/playback/zoom, and narrow-layout fit. French desktop, settings, inspection, menu and narrow screenshots were rendered and inspected.


## Edit and validate actions

- Replaced Edit text buttons with crossed-tools icons. Opening a tank, waypoint or hold changes the action to a highlighted checkmark with a **Validate changes** tooltip. Closing returns it to the tools icon. The gas switch selector now uses this same pattern.
- The checkmark commits text still being typed and validates the edited item. Invalid inputs keep the editor open with an inline error. Valid inputs close it and update the simulation. Live previews remain available while editing; validating is separate from saving the plan file.
- Card names are editable while their controls are open and remain readable when collapsed. Editor state survives rebuilds through the existing per-item expansion state. Replaced the Remove tank text action with a trash icon.
- Action tooltips and the gas-selection validation message are available in English and French.

Validation: editor checks cover tools/checkmark state, pending numeric input, invalid and corrected tanks, holds, gas selection and generated names, and French tooltips. Open and closed states were rendered and visually reviewed.


## Route event icons

- Replaced route-card numbers with a swimming diver for travel waypoints, a clock for holds and two cylinders with an arrow for gas switches. Each icon has an English/French tooltip.
- Removed the HOLD and GAS SWITCH prefixes from summaries. Gas switches now show only the selected gas and depth; the zero-duration and unchanged-position text is gone. Holds retain depth and duration, and waypoints retain navigation details.
- Validation feedback identifies the affected event by name, since card numbers are no longer displayed.


## Drag route events

- Replaced the two arrow buttons on every route card with one compact six-dot handle. Drag the handle to move the event before or after another card. A preview identifies the dragged event and a turquoise insertion line marks the destination.
- The route panel scrolls automatically near its top/bottom edges while dragging. Dropping outside the route or pressing Escape cancels the move. Dropping next to the original position leaves history untouched.
- Reordering uses stable event IDs, creates one undo step, preserves open editors, updates the map and simulation, and reanchors holds to their new preceding position. Cards stay mounted during an active drag so recalculation cannot interrupt it.
- Alt+Up/Down on a focused handle provides keyboard reordering without adding buttons. The handle tooltip is available in English and French.

Validation: full Godot input tests cover drag start, indicators, moving upward/downward, end boundaries, undo, hold anchoring, cancelling, no-op drops, drops over fields, retained editor state, foreign payload rejection and long-route scrolling. These checks pass in the rendered application as well as headless execution.


## Drag from the card body

- Removed the drag handle. Event cards can now be dragged from their padding, icons, summaries, collapsed names and other non-editable regions, including labels in open editors.
- Editable text fields, numeric inputs, selectors and buttons retain their native behavior. Selecting or dragging text, using spin arrows or interacting with buttons does not reorder the route. Collapsed names act as drag surfaces; opening the editor makes them ordinary text inputs again.
- Drop previews, insertion lines, automatic scrolling, cancellation, undo and keyboard reordering are preserved. Dropping a route event over a field remains supported without replacing that field's normal text-drop behavior.

Validation: card input checks exercise each drag surface, native text drag/drop, numeric gestures and arrows, editor buttons, selectors and cancellation. Route drag tests cover reordering, undo, anchoring, editor state, edge scrolling and keyboard focus.


## Learning workspace

- Added a single icon-only header switch with a folded map on one side and an open book on the other. The active half is highlighted, with translated tooltips and ordinary keyboard activation. The current dive workspace remains the default.
- Added a dedicated learning view with Boyle’s law and Snell’s law in its left navigation. Each lesson combines a live diagram, slider, linked values, formula, a short diving connection, explicit model assumptions and a source link. The diagrams support direct manipulation as well as the sliders so learners can discover the relationships visually.
- Boyle’s lesson keeps the same gas particles, scales a flexible bubble by volume, and links it to a pressure–volume curve. Depth presets make familiar pressure ratios easy to compare. Absolute pressure and the simplified sea-level assumption are explicit to prevent confusion with the lake scenario.
- Snell’s lesson follows a ray through a flat air/water boundary, marks the normal and measured angles, supports both directions, and shows total internal reflection above the critical angle. A shortcut brings the experiment to the critical-angle boundary; learners can cross it with the slider.
- Entering learning pauses playback. The existing scenario, map state, collapsed panels, current time and history are retained. Scenario file actions are hidden in learning to keep the header relevant, while the language selector stays available. Lesson choices and values survive switching views/languages.
- All new explanations, controls and diagram labels are translated into French. Narrow layouts stack navigation and, for Boyle’s lesson, the two diagrams; phone readouts stack to stay readable.

Validation: input-driven checks cover the header switch, navigation, direct diagram input, keyboard slider adjustment, pressure/volume examples, refraction in both directions, critical angle, total internal reflection, French localization, narrow layouts and preservation of scenario/view state. Rendered screenshots cover both lessons and French phone layouts.


## Partial pressure, dissolved gas and water properties

- Added three learning topics with dedicated icons: Dalton’s law, Henry’s law and Water density. Existing lessons retain their controls and experiment settings.
- Dalton’s lesson links depth and an editable O₂/N₂/He mixture to colour-coded partial-pressure bars, their stacked sum and four readouts. Air, nitrox and trimix examples make it easy to compare gases at the same depth. Editable fractions always leave a valid nitrogen remainder; the diagram itself can be dragged vertically to change depth.
- Henry’s lesson links partial pressure to equilibrium concentration, then uses a separately identified exponential exchange example to show why uptake/release takes time. This distinction prevents teaching a time law as part of Henry’s law. Dots in a fixed liquid volume represent dissolved molecules; a dashed target and scrubbed curve show current concentration versus equilibrium. Pressure-rise/drop presets restart from the same reference state for direct comparison.
- The water lesson links temperature and salinity to density, metres per additional bar and water pressure at 10 m. A draggable temperature curve at the selected salinity exposes the freshwater density maximum near 4°C. A water-column diagram compares the selected water with fresh water at 20°C on a shared depth scale, preserving the actual size of the difference.
- The water calculation reuses the existing EOS-80 surface-density approximation, rather than introducing a conflicting density model. Model notes identify the approximate salinity convention, uniform water assumption and distinction between water-pressure increments and absolute pressure.
- New controls, explanations, diagram labels and tooltips are available in English and French. Five topics remain a left-hand list on desktop; a compact selector replaces that list on narrow screens so it does not overwhelm the lesson. Paired diagrams and readouts stack where needed. All experiments remain separate from the dive scenario and preserve their state across topic, workspace and language changes.

Validation: `Tests/ScienceLearning.gd` checks known partial pressures, gas-fraction constraints, Henry equilibrium and half-time uptake/release, EOS-80 density reference values, the freshwater maximum, hydrostatic conversions, direct diagram interaction, presets, French localization, phone layouts, retained experiment state and unchanged scenario/history. Rendered screenshots verify all three lessons in both languages, including phone layouts. Existing learning/workspace checks remain applicable.


## Bühlmann decompression lesson

- Added a sixth learning topic with its own compartment/curve icon. Two stages keep the controls focused: load tissues, then explore ascent and gradient factors.
- The loading view shows all 16 theoretical ZH-L16C nitrogen compartments on a shared pressure scale. Selecting a bar or using the picker/keyboard shows that compartment’s half-time and loading curve. Exposure depth/time and short/long examples show why fast and slow compartments behave differently; the curve can be dragged to scrub exposure time.
- The ascent view carries the same loading into an instantaneous pressure preview. Waiting at the preview depth uses the app’s real gas-exchange calculation, so fast tissues can unload while slow tissues continue loading. GF Low/High controls maintain valid ordering. The graph distinguishes ambient pressure, the selected compartment’s M-value, its GF limit and actual tissue pressure; per-compartment limit ticks and a controller dot link the graph to the 16 bars.
- Readouts show applied GF, selected tissue N₂, the current ceiling and the actual controlling compartment. A formula and short explanation define GF as a fraction of the ambient-to-M-value gap, avoiding the common mistake of multiplying the whole tissue/M-value pressure by GF or interpreting GF as a risk percentage.
- Calculations reuse the existing `BathysTissue` and `BathysDeco` implementation. Model notes explicitly identify the air-only example, water-vapour correction, idealised depth conversion, instantaneous pressure steps and frozen-tissue GF Low anchor. The preview demonstrates model boundaries and gas exchange; it does not claim to generate an ascent schedule or a guaranteed safe limit.
- English/French text, narrow stacked diagrams, compact phone topic selection, keyboard controls and retained experiment state follow the existing learning workflow. The scenario, map and undo history remain untouched.

Validation: `Tests/BuhlmannLearning.gd` covers numerical half-time examples, real tissue exchange, selection and plot input, GF gap scaling, Low/High interpolation and constraints, ceiling/controller calculations, simultaneous uptake/release, surface equilibrium, state preservation and French phone layouts. Native rendered checks cover both stages in English and French; screenshots verify desktop and phone layouts. Existing learning, science-lesson, simulation UI, translation and numerical reference suites provide regression coverage.


## Organized learning and breathing lessons

- Corrected the Bühlmann ascent plot legend: its GF-limit label is now amber, independently of the violet M-value label, including in French.
- Organized the nine lessons into Physics of diving, Physiology, and Models & risk. Oxygen toxicity/narcosis teach physiological phenomena and the assumptions behind their exposure/comparison indexes; Bühlmann remains in the models category. The compact phone selector has the same category separators.
- Moved the top ribbon outside scrolling content in both workspaces. Learning now has independent navigation and content scroll containers, so browsing topics never moves a lesson and reading a lesson never hides the workspace/language controls. A selected lesson opens at its heading. Scenario content retains its own scroll position when returning to the planner.
- Added oxygen toxicity with interactive depth, oxygen fraction and duration, a ppO₂ curve, CNS-allocation dial and pulmonary OTU counter. Explanations separate physiological effects from exposure indexes. The historical app CNS table is labelled as such and is not extrapolated past its last 1.6-bar row; zero accrual and 100% are explained without claiming individual tolerance. OTU’s reference unit and the bar/ata distinction are explicit.
- Added nitrogen narcosis with actual/air-equivalent depth columns, matching counted-gas pressure, editable mixture and an explicit oxygen-counting assumption. This makes the differing END conventions visible. Below-surface-reference results are labelled rather than shown as an exact physical match. END is described as a pressure comparison, not an impairment or risk score.
- Added gas density with equal one-litre mixture/air mass diagrams, schematic compression/molecular-mass dots, cached Peng–Robinson curves and gas-temperature control. Fixed 5.2/6.2 g/L literature references are explained in context; density is not presented as a complete work-of-breathing model. Changing depth reuses the composition/temperature curve cache.
- All new controls, labels, model assumptions and sources are available in English and French, with stacked phone diagrams and retained per-lesson experiment values. The new learning controls do not change the dive scenario or its gas settings.

Validation: `Tests/BreathingLearning.gd` covers table examples/OTU units, out-of-table CNS states, narcosis conventions and negative equivalents, normalized fractions, density trends and real-gas reference behavior, direct diagram/keyboard/preset input, categorized topic IDs, independent wheel scrolling, fixed ribbons in both workspaces, French phone layouts and unchanged scenario/history. Native rendered screenshots verify all three new lessons, both scroll panes and the corrected Bühlmann legend.


## Archimedes, buoyancy and clearer 3D relief

- Added Archimedes & buoyancy under Physics of diving, bringing the learning space to ten topics. Two stages separate partial immersion/displacement from gas compression at depth.
- The displacement stage links mass, body volume and immersed fraction to a schematic body, force arrows and a bucket of displaced water. Readouts use litres and newtons, distinguishing mass from force. Floating equilibrium adjusts immersion only when the body can physically float; a denser body cannot obtain equilibrium by reducing immersion.
- The depth stage holds a rigid body fully submerged and adds a fixed gas sample. Boyle compression changes total displaced volume while weight stays constant. A force-versus-depth plot makes the loss/gain of buoyancy on descent/ascent visible. Balance at one depth changes the teaching mass, then allows comparison at other depths. No gas sample implies constant buoyancy with depth in uniform water.
- Fresh/sea water examples reuse the density model. The experiment uses actual hydrostatic pressure from that density and 1 bar surface pressure. Notes identify the schematic body, omitted motion/surface tension, neglected gas mass and excluded active buoyancy adjustments. All text and diagram labels are translated into French, with phone layouts and preserved experiment state.
- Made 3D steep terrain easier to distinguish using world-space hillshading, a gradual warm tint on steeper mesh normals and clearer anti-aliased five-metre contours. The depth colour sequence remains the base layer. The shading stays fixed to the terrain when orbiting, and the short 3D hint explains the relief/contour cues.
- This feasible rendering change uses the existing 878,652-triangle terrain and a single lightweight Compatibility shader. It adds no textures, shadow maps, geometry deformation or vertical exaggeration. Survey data, waterline transforms, route positions and picking retain their original geometry. Before/after native captures from matching viewpoints verify the improvement.

Validation: buoyancy checks cover displacement fractions, known force examples, floating/neutral balance, water-density effects, trapped-gas compression, unchanged rigid-body buoyancy with depth, direct drag and keyboard controls, English/French layouts and scenario preservation. Native terrain captures check the shader from two camera angles; existing 3D/JPEG and simulation checks cover integration.


## Colour underwater: spectral image formation

- Added an eleventh lesson under Physics of diving with its own light/water icon, English/French controls, preserved experiment state and stacked phone diagrams. Three stages progressively introduce the extra optics instead of presenting every parameter at once.
- The first stage compares a synthetic spectral reflectance chart and fine black/grey detail against the light received underwater. Depth and camera-to-target range control different paths. A component selector isolates direct light, the forward halo, backscatter, or the object signal without the veil. Fixed display exposure makes brightening distinct from recovering lost spectral information. Examples compare nearby clear water, distant coastal water and a nearby torch.
- White-torch controls reveal power and camera offset only when enabled. A chosen beam geometry and single-scatter line integral show why nearby particles, lighting distance and off-axis placement change the veil. No photographic white-balance or unknown surface colours are inferred from the supplied photo references; the synthetic target keeps the starting reflectances explicit.
- The second stage plots absorption a, scattering b, beam attenuation c and diffuse downwelling Kd separately, with a draggable wavelength probe. A normalized Henyey–Greenstein phase plot and sliders expose the additional assumptions: asymmetry, diffuse-light share and a finite accepted forward cone. It reports backward/accepted fractions and reduced scattering b′ without equating them with Kd.
- The third stage integrates 61 wavelengths before deriving separate effective direct and backscatter coefficients. White/red target curves make reflectance and range dependence visible, while a linked signal budget separates the three components. Diagnostics use nonnegative linear CIE Y rather than claiming calibrated RGB camera coefficients.
- Six measured-data-derived marine a/b presets are checked against the original Dstl workbook. Historical Jerlov Kd values are checked independently and identified as class data rather than co-located measurements. CIE/D65 samples are checked against official datasets, with the more precise official CMFs retained. Source hashes, measurement/extrapolation flags and licence notices are bundled or documented. The app needs no network or analysis package at runtime.
- Forward blur is explicitly an energy-bounded nine-tap Gaussian surrogate; phase/illumination parameters are chosen assumptions. The model omits a full multiple-scattering radiative-transfer solution, fluorescence and visual adaptation. Thick-scattering cases show an additional qualitative-preview note. All of these limits appear in the lesson and its provenance document.

Validation: `Tests/OpticsLearning.gd` checks primary coefficients, phase normalization, source-term limits, energy bounds, D65 reference colour, wideband coefficient differences/range dependence, torch geometry, all-preset extremes, component selection, plot/keyboard interaction, translated phone layouts and unchanged scenario/history. Native captures verify the actual preview shader, plots, colour-matched legends and responsive layout. `Tools/prepare_optics.py` reproduces and validates the bundled table without executing downloaded source code.
