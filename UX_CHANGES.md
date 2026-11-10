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
