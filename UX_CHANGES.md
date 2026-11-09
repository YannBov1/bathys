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
