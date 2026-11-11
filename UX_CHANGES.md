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


## Thermal gas laws and cooling

- Added four separate topics alongside Boyle under Physics of diving: Charles’s law, Ideal gas law, Real gases & compressibility, and Joule–Thomson & cooling. Existing topic IDs stay stable; the compact selector has the same categorized navigation. There are now fifteen lessons.
- Charles uses a pressure-balanced piston with a fixed gas sample, schematic motion arrows and a linked V/T curve. Reference, 40°C and double-kelvin examples address the common Celsius-ratio error. Supported states are separated from the dashed extrapolation toward absolute zero.
- The ideal-gas experiment lets the learner choose pressure or volume as the dependent variable. Temperature, moles and the remaining constraint stay editable. The curve, vessel and readouts show the same state, while PV and nRT are compared in joules. It teaches constraints and units rather than presenting an unlabeled gas-law calculator.
- Real-gas comparisons use the same dry O₂/N₂/He Peng–Robinson constants and zero binary-interaction mixing as the planner. Paired vessels hold one mole at identical P/T; separate fixed-12 L readouts use the inverse-Z amount correction. The Z/pressure curve exposes both attraction-dominated and positive departures. Notes distinguish Z from volumetric compressibility and identify EOS uncertainty, especially helium.
- The cooling lesson distinguishes an insulated steady-flow throttle from a reversible ideal expander delivering work. Real throttling solves h(Pin,Tin) = h(Pout,Tout) using analytic PR enthalpy departure and a constant ideal heat capacity, rather than multiplying the inlet coefficient by a large pressure drop. Ideal throttling has no temperature change; ideal expansion with work cools even helium. Pressure controls maintain Pout ≤ Pin. The selected curve can be dragged to vary outlet pressure; local μJT is labeled as an inlet slope.
- All diagrams and controls support English/French, keyboard sliders, narrow stacked layouts, independent per-topic experiment state and unchanged scenario/history. Curves are cached by their actual thermodynamic inputs, with short coalesced updates during slider interaction. The model uses double-precision scalars and has no runtime network/dependency requirement.
- Model notes describe uniform equilibrium states, absolute units, ideal Cp/γ, the single-phase EOS domain, and omitted water/metal heat exchange, cylinder blowdown and phase changes. Cryogenic ideal-work comparisons show an extra note. Corrected conditional model-note translation so appended notes keep the whole paragraph in French, including the existing optics lesson.

Validation: `Tests/ThermalLearning.gd` checks Charles ratios/kinetic scaling, the 1 mol/1 bar/273.15 K reference volume, PV/nRT units and inverses, real-gas agreement with the planner across all supported gases and limits, the enthalpy pressure-derivative identity, dilute limits, Z/amount relations, cooling/warming signs, constant-enthalpy endpoint conservation, ideal throttle/work comparisons, presets/plot/keyboard controls, pressure ordering, compact IDs, French phone layouts and preserved plans/history. Native captures cover all four topics, the three processes, helium warming and French desktop/phone layouts.


## Fick gas exchange and Snell mask optics

- Added Fick’s law & gas exchange under Physiology, bringing the learning space to sixteen topics without changing existing topic IDs. Lungs and tissues retain independent pressure/barrier/time experiments. A membrane view distinguishes the maintained source from the finite receiving blood parcel or tissue, with arrows following the selected gas’s partial-pressure gradient.
- Controls expose relative area, barrier thickness and effective permeability. Tissue mode additionally exposes gas-storage capacity. The linked pressure/time curve demonstrates equilibration rather than claiming that Fick’s steady transfer law alone supplies a time course. Larger storage slows the response without changing the initial rate; a faster-equilibrated receiver can have a smaller current gradient/rate. Initial and current rates are shown together to make that distinction clear.
- Lung O₂/CO₂ examples reverse the direction appropriately; tissue examples add O₂ delivery, CO₂ return, and inert-gas uptake/release. Presets change illustrative pressures only, with a visible reminder that they do not choose gas permeability. The source line is amber and receiving-compartment curve violet, with matching legend text. Equal partial pressures remove the net arrow while schematic random molecular motion remains represented.
- Normalized rate, geometry, permeability, storage and time units are explicit. The lesson excludes haemoglobin binding, CO₂ chemistry, ventilation/perfusion and metabolism rather than implying calibrated oxygenation or decompression results. It also distinguishes membrane diffusion from Fick’s cardiac-output principle.
- Extended Snell’s law with Boundary & rays / Mask & apparent size stages. Original ray-direction, critical-angle and total-internal-reflection controls remain the default and retain their state when switching stages.
- The mask stage solves a complete water–parallel-window–air ray path to the eye. The overview uses one world-distance scale; a labeled local inset exaggerates glass thickness while preserving the actual ray angles. Adjustable distance, object height, eye spacing, window thickness and refractive index reveal how the two interfaces affect the path.
- Paired 60° angular-field frames compare the same target in air and through the mask. Readouts distinguish actual eye-to-object distance, an explicitly defined edge-pair back-projection and angular size ratio. The physical target height stays constant. Notes explain the near-axis 1.33×/0.75× limits, finite-angle differences, the flat-window/corrective-lens distinction and the mask air pocket’s separate role in restoring the air–cornea interface.
- Both additions support English/French, keyboard sliders, direct plot/object dragging, compact categorized selection, stacked phone layouts and preserved scenario/history. The new mask geometry and each Fick context keep their values across topic, stage, workspace and language changes.

Validation: `Tests/ExchangeMask.gd` covers Fick scaling and direction, receiver mass balance, half-times/storage, equal-pressure and supported endpoint limits; conserved optical invariants at both faces, endpoint closure, index matching, near-axis angular/distance limits, finite glass/index effects and angular-field bounds; presets, keyboard/drag input, both Snell stages, translation, phone layouts and unchanged plan/history. Native screenshots verify the lung/tissue views, reverse flow, near-object mask geometry and both languages on desktop and phone. Existing learning and numerical/UI suites provide regression coverage.


## Iterative lesson intuitiveness pass

### Pass 1: visual hierarchy across all sixteen lessons

- Changed the initial lesson view to one main experiment. Secondary curves, phase plots, signal budgets, ray diagnostics and displaced-water comparisons are opt-in through a small chart/comparison icon. Related scenes still use the same numerical model and can be reopened without revealing a parameter wall.
- Removed the default explanatory paragraphs, formulas and multi-card readout grids. The information icon reveals the original scientific explanations, complete readouts, assumptions and references. A small single outcome remains where the graphic does not already display it. Core plot axes/units and oxygen table-boundary messages remain visible where needed.
- Put precise numeric controls and less central variables behind a local gear. Existing bounds, gas-fraction constraints, model values and keyboard paths are retained. New visual instruments disappear while this inspector is open, avoiding a second copy of every control. Compact chart, parameter and information toggles are independent and keep their state during the session.

### Pass 2: controls that describe what they change

- Added draggable thermometers with Celsius and kelvin, pressure/percentage gauges, clocks, water-depth rulers, gas-volume/amount vessels and salt jars. These bind to the same bounded inputs as the precise inspector, support keyboard arrows/Home/End, and redraw when another constrained variable changes silently. Pressing the mercury grip preserves its current value before dragging.
- Charles’s thermometer sits beside the piston inside the apparatus. Dragging the piston changes its equilibrium volume/temperature directly. Ideal-gas vessel walls now resize the drawn vessel and change volume or the corresponding controlled pressure, with visible grab points.
- Added handles to existing bubble, diver, immersion and actual-depth interactions. Dalton’s O₂ and He bar tops directly edit their fractions while nitrogen remains the remainder. The depth control is a water ruler. The water-density curve is the primary view, with a draggable temperature marker and a salt jar; the physical water column is optional.
- Fick’s barrier has separately locked width and active-area handles. Source/initial pressures use gauges and elapsed time uses a clock. The unchanged model continues to distinguish current and initial rates.
- The colour target is directly draggable in two dimensions: vertical movement changes depth and horizontal movement changes viewing distance. The mask’s compact size comparison has a draggable distance rail, with exact ray tracing behind the comparison icon. These replace duplicate default distance/depth sliders.
- Kept visible mode/gas/direction choices and shortened stage names. Full names remain in tooltips. Standard gas examples visibly highlight their selected mixture. Equilibrium models, coefficients, physiological bounds and planner simulation code are unchanged. Teaching examples now use freshwater for the density curve, 300 bar for a more visible real-gas departure, and a larger/nearer mask target for the initial size comparison.

### Pass 3: mobile, interaction and translation refinement

- Reduced compact figure heights without shrinking physical labels or clipping the active apparatus. Kept full stacked figures when comparisons are requested. The phone lesson picker no longer repeats the learning heading, and its icons are smaller; this brings the main apparatus and its instruments into the first screen more often.
- The phone colour lesson uses one aligned before/after preview with a draggable divider, preserving the fixed surface reference and computed underwater signal. Full paired panes return with the expanded inspector. The divider supports keyboard arrows and distinguishes horizontal comparison gestures from vertical scroll intent.
- Limited instrument pickup to the visible apparatus/grip area so touching a caption does not unexpectedly change a parameter. Explicit arrow keys remain usable, and coupled controls redraw after model normalization or GF ordering updates. Numerical precision remains available without requiring it for exploration.
- Translated all new gesture cues, tooltips, stage names and instrument captions into French. Phone layouts were rendered for every lesson, plus direct-drag and optional-chart/detail states. Revised the buoyancy instruction to describe dragging the diver.

Validation: `Tests/LessonIntuition.gd` verifies compact defaults across all sixteen topics (no exposed HSliders or long visible paragraphs), primary figure sizing, direct bubble/bar/piston/vessel/barrier/target gestures, calibrated thermometer pickup, keyboard instruments, silent coupled-value redraws, comparison/inspector restoration, mobile colour divider, French phone widths, retained model notes and unchanged plan/history. Existing learning suites explicitly open the public inspection toggles to continue checking the complete scientific views; layout settling now also runs for non-rendered captures, avoiding stale click coordinates after scrolling. Numerical reference and planner/UI suites cover integration.


## Recognizable instruments and visual access to every variable

- Linked charts now start enabled. Exact values and explanations remain independent optional views. Recorded the visual-first lesson style in the project’s `AGENTS.md` so future lesson work follows it.
- Added a compact instrument palette for secondary variables: exposure, torch power/offset, wavelength, diffuse light, halo angle, mask geometry/index, exchange permeability/storage and ascent exposure/wait. Selecting an icon opens one visual instrument, avoiding a large permanent control panel. Every currently editable lesson variable is accessible through a scene interaction, a primary instrument or this palette; the gear is now labelled “Precise values”. Torch-only controls appear when the torch is enabled.
- Underwater geometry uses a fish, an eye and a recognizable torch. The image-model stage includes an eye-to-fish horizontal distance ruler before the plots, available independently of the numeric inspector.
- Reduced the thermometer bulb to fit its housing. Time now uses a full stopwatch face with twelve ticks, two hands and a crown, clearly distinct from pressure’s open gauge. Salt uses a perforated cap, tapered shaker and a draggable crystal level.
- Replaced separate gas-fraction jars with one O₂/N₂/He tank in Dalton, oxygen, narcosis and gas-density lessons. Two draggable dividers preserve a 100% total and nonnegative fractions. Opposite-side handles keep both dividers accessible when nitrogen reaches zero. Keyboard left/right selects a divider; up/down moves it. Nitrogen (N₂) is the third gas used by the app’s models.
- Moved Boyle’s drag cue outside the bubble and buoyancy’s cue beside the diver. The trapped gas sample sits separately from the diver, and force arrows remain clear. Displacement bodies keep the same colour above and below the surface.
- Releasing the displacement body or its precise immersion slider animates toward mass/(water density × volume), capped at full immersion. A denser body retains a negative net force rather than being shown falsely balanced. This is an illustrative damped relaxation, documented as such; no hydrodynamic solver or planner physiology changed. New drags, parameter edits and stage changes cancel the animation.

Validation: `Tests/LessonInstruments.gd` checks default charts, clock interaction, both mixture dividers and normalization, keyboard edits, horizontal range, visual lighting controls, floating equilibrium, sinking-body behavior, stage cancellation, French phone widths and unchanged plan/history. Native renders cover all sixteen lessons and selected instrument/stage states. Existing lesson, reference and planner/UI suites provide regression coverage.


## Visual instruments as the complete control interface

- Removed the Precise values button and instrument-picker toggles. All instruments applicable to the current lesson/stage are visible by default, including the ideal-gas volume/pressure constraint, colour exposure/torch power/scattering variables, Fick geometry/permeability/storage and Bühlmann exposure/wait controls. The information toggle still reveals equations, full readouts, sources and model limits. Internal bounded inputs continue to coordinate model values; they are not exposed as a second user interface.
- The ideal-gas comparison labels the two products separately: pressure × volume (PV) and gas amount × R × temperature (nRT), each with its joule value. Distinct lesson equations now use blank lines rather than a small middle dot. Multiplication signs and unit products remain intact. English/French formula templates were updated together.
- Torch offset is controlled by dragging the torch vertically in the scene; its separate instrument is removed. The interaction locks onto the torch so it cannot also move the fish. A labelled schematic rail keeps the full 0–1.5 m offset range visible, including at the deepest target position. Keyboard arrows edit the selected object; T selects the torch. Removed the 100% heading from the gas-mixture tank while retaining normalized fractions.
- Changing mass or rigid volume in the displacement experiment now animates the body toward its new floating level, using the same density and force-balance calculation as release. The animation remains a damped illustration rather than a hydrodynamic model; a denser body becomes fully immersed and retains a downward net force.
- Replaced Fick’s text context tabs with lung ↔ blood and blood ↔ tissue SVG icons and translated tooltips. The membrane and adjacent exchange regions now change height with exchange area, and the membrane itself changes width with thickness. There is no fixed background barrier plus an active rectangular overlay. Geometry handles choose the nearest edge, preserve pickup values and remain usable at small areas.
- Added a Bühlmann depth/time profile before the tissue plots. Amber marks exposure and aqua marks the preview/wait segment; dashed vertical lines explicitly represent instantaneous depth steps. Drag the exposure corner for depth/time, the wait corner for preview depth/wait, or the midpoint for depth only. Handles support keyboard selection and editing, and zero-wait handles stay separable. Every edit uses the existing snapshot/tissue computation; no finite-rate ascent or dive schedule is invented.
- Updated the persistent lesson-design guidance to keep the interface visual-only and stage instruments visible. Horizontal instruments retain their compact height in mixed rows, and all new controls/formulas support English/French and phone layouts.

Validation: `Tests/VisualLessons.gd` exercises removal of the old interface, visible constraint instruments, labelled ideal-gas products, isolated torch dragging and endpoint bounds, buoyancy responses to both inputs, icon context tabs, all four profile parameters, model agreement, profile keyboard input, French phone widths and preserved plan/history. Existing lesson tests now use the public visual instruments for keyboard checks; numerical example callbacks retain their model coverage. Native screenshots cover all sixteen lessons plus the new drag and instrument states.
