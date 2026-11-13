# Cylinder buoyancy teaching presets

The Archimedes **Displacement** experiment has four presets: 12 L steel or aluminium, each with air at 200 bar full or 50 bar reserve. They change only the teaching experiment. The dive scenario, tanks, settings, playback and undo history remain separate.

## Reference bodies and assumptions

- Steel: Faber’s 2023 lightened 12 L, 171 mm, 232 bar design, **13.3 kg bare body**, filled here to 200 bar. [Manufacturer’s release, 232 bar table](https://faber-italy.com/wp-content/uploads/2023/04/Press-Release-Faber-new-scuba-design_eng-1.pdf).
- Aluminium: Luxfer **P3080V**, 12.0 L, 200 bar, **16.5 kg body**. [Manufacturer’s 2022 specification sheet](https://luxfercylinders.com/wp-content/uploads/2023/10/LUXFER-SCUBA-SPEC-SHEET-2022.pdf).
- Add an illustrative **0.6 kg brass valve** to each. No regulator, hose, boot, rigging or other equipment is included.
- Air is 21% O₂ / 79% N₂ at **20°C**. Both pressure labels are gauge readings with a **1 bar surface reference**; the gas-density model therefore receives 201 or 51 bar absolute. Gas mass uses the app’s existing Peng–Robinson mixture density multiplied by **0.012 m³ internal capacity**.
- Displaced volume is **external volume**, not the 12 L gas capacity. It is estimated as internal volume + body mass / material density + valve mass / brass density. Representative densities are 7.85 kg/L steel, 2.70 kg/L aluminium and 8.4 kg/L brass. These are teaching estimates, not manufacturer measurements of displaced volume. Shell expansion is omitted.

| Example | Total mass | Estimated external volume | Net force, fresh water at 20°C |
| --- | ---: | ---: | ---: |
| Steel, 200 bar | 16.746 kg | 13.766 L | −29.5 N |
| Steel, 50 bar | 14.641 kg | 13.766 L | −8.8 N |
| Aluminium, 200 bar | 19.946 kg | 18.183 L | −17.6 N |
| Aluminium, 50 bar | 17.841 kg | 18.183 L | +3.0 N |

Positive force is upward. The existing EOS-80 water-density approximation at 20°C gives fresh/sea-water density; changing water changes buoyancy without changing the preset’s mass or external volume. Consuming the same amount of air changes both cylinders’ weight by the same amount, about 20.65 N between these two pressures. Their different shell mass and displacement account for their different net buoyancy.

## Supported-cylinder rotation

Selecting a preset now shows a recognizable horizontal cylinder with a valve, fixed neck support, gas-content stripe and draggable base. It starts horizontal and relaxes towards its own supported attitude. The pressure gauge and draggable linked pressure/angle curve let the user consume air continuously from 200 down to 0 bar gauge. Mass and volume instruments remain available; editing either returns to the original custom free-body experiment. Cylinder mode stays fully submerged, and its net-force readout excludes support reactions.

A force sum alone cannot predict whether the base turns upward. The illustrative axial model places body mass and gas at half the body length, and the valve at x = −0.03 m relative to the body neck. Its buoyancy centre weights those positions by body/valve external volumes. The mass centre weights them by body + gas / valve masses. A support at xP = 0.07 m gives the horizontal base-up moment:

τ₀ = Fᵦ(xB − xP) − W(xG − xP)

For finite schematic attitudes, a weak elastic support contributes a restoring moment with k = 3 N m:

τ(θ) = τ₀ cos θ − k sin θ

θequilibrium = atan(τ₀ / k)

This is a teaching support model, not a calibrated harness. The animation relaxes exponentially towards that angle; dragging/keyboard controls can hold another attitude until release. Body length is the Luxfer specification’s 0.612 m for aluminium and an assumed 0.65 m for steel. Body/gas centres and support geometry are assumptions, not measured centres of these models. No regulator is added. The valve’s brass volume is included in the buoyancy centre. Gas remains distributed throughout the internal volume; there is no invented gas pocket migrating to the cylinder base.

With these assumptions in fresh water:

| Example | Base-up moment from horizontal | Illustrative supported angle |
| --- | ---: | ---: |
| Steel, 200 bar | −5.67 N m | −62° |
| Steel, 50 bar | −0.41 N m | −8° |
| Aluminium, 200 bar | −2.42 N m | −39° |
| Aluminium, 50 bar | +2.46 N m | +39° |

At **100 bar**, the aluminium example has **negative total lift, about −4.2 N**, while its horizontal moment is positive and the base turns upward. This illustrates why the base rising and the entire cylinder floating are different observations. Different real valves, regulators, shell distributions, rear clips, bungees, support stiffness and attachment positions can change both the threshold and the attitude. The numerical angles are not predictions for a particular sidemount configuration.

The scene shows the two force directions at their separate axial centres, a horizontal reference and a short distinction between base tendency and whole-cylinder lift. The information toggle contains the equations, assumptions, sources and limits in English/French. [OpenStax’s equilibrium chapter](https://openstax.org/books/university-physics-volume-1/pages/12-1-conditions-for-static-equilibrium) provides the independent force-sum and torque-sum conditions underlying this illustration.

## Verification

`Tests/PanelAndCylinder.gd` covers total mass, rigid external displacement across pressures, equal gas-weight change, force signs, preset/manual/stage transitions, English/French phone layouts, and unchanged scenario/history. Native `-- --visual` runs capture each preset, the grouped force readout, both 2D map label modes and expanded/collapsed physiology. `Tests/CylinderTrim.gd` additionally checks distinct attitudes, moment balance, monotonic pressure response, a base-up / net-negative state, gauge/chart/scene manipulation, mouse/touch/keyboard release, stage transitions and preserved scenario/history. Native captures show all four attitudes, the 100 bar comparison and French phone layouts. The existing buoyancy and numerical reference suites provide regression checks.
