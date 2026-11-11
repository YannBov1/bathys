# Thermal gas lessons: equations and limits

The four experiments are independent of the scenario, tank defaults and lake environment. All pressures are absolute and all gas-law ratios use kelvin. Diagrams are schematic; dots do not count individual molecules and do not imply a validated microscopic simulation.

## Charles and the ideal gas

Charles’s example starts with 1 L at 293.15 K and 1 bar absolute, with the same amount of gas and a frictionless movable piston. `V = 1 L × T/293.15 K`. The experiment spans −100 to 350°C (173.15–623.15 K); a dashed ideal line extends toward zero outside that range. Real gases do not remain a classical ideal gas down to absolute zero. Motion-arrow lengths scale as √T, with a fixed particle count. This is a state comparison, without a heating/cooling time model.

The ideal-gas experiment solves either `P = nRT/V` or `V = nRT/P`, with `R = 8.314462618 J/(mol K)` and `1 bar L = 100 J`. Its temperature curve holds the selected n and V or P fixed. The volume-mode vessel uses a relative visual scale; numeric readouts retain the actual units. A mole is an amount, not a reference volume. The two constraint modes retain their input settings during topic/workspace switching.

References: [OpenStax Chemistry: gas laws](https://openstax.org/books/chemistry/pages/9-2-relating-pressure-volume-amount-and-temperature-the-ideal-gas-law), [OpenStax College Physics: ideal gas law](https://openstax.org/books/college-physics/pages/13-3-the-ideal-gas-law).

## Real gas and Z

Uses the original Peng–Robinson EOS, with zero volume translation and the same critical constants, acentric factors and zero-kij mixing as `Scripts/Core/Physics.gd`. Air is the app’s dry 0.21 O₂ / 0.79 N₂ blend, not a measured atmospheric composition. Nitrogen and helium are pure-species teaching presets, not suggested breathing mixtures.

`P = RT/(v−b) − a(T)/(v²+2bv−b²)` and `Z = Pv/(RT)`.

For each component, `a0 = 0.45724 (R Tc)²/Pc`, `b = 0.07780 R Tc/Pc`, `q = 1+κ(1−sqrt(T/Tc))`, `a(T) = a0 q²`, with `κ = 0.37464+1.54226ω−0.26992ω²`. The mixture uses `sqrt(a_mix) = Σ xi sqrt(ai)` and `b_mix = Σ xi bi`. Derivatives of a are analytic under those same mixing assumptions.

| Species | Tc (K) | Pc (Pa) | ω |
|---|---:|---:|---:|
| O₂ | 154.5994 | 5046410.5 | 0.0222 |
| N₂ | 126.192 | 3395800.4 | 0.0372 |
| He | 5.1953 | 228322.8 | −0.38354 |

These constants are inherited from the existing app. No new measurement precision or reference-EOS accuracy is claimed. The lesson’s 253.15–353.15 K and 0.1–300 bar domain is above the species’ critical temperatures, with one physical gas/supercritical root. The cubic is bracketed in Z between B and 1+B (`B=bP/RT`); all model arithmetic uses double-precision scalars. Numerical checks compare the new solver with the planner’s separate volume/density solver across the supported domain.

Paired vessels compare **one mole at equal P and T**, so real/ideal volume ratio is Z. The 12 L readouts compare **equal fixed volume at equal P and T**, so real/ideal gas amount ratio is 1/Z. Z is dimensionless and differs from isothermal bulk compressibility κT. A cubic EOS is an approximation, particularly for helium; phase equilibrium, material limits and filling transients are excluded.

References: [NIST: original PR coefficients/equations](https://trc.nist.gov/TDE/TDE_Help/DETAILS-TDE-Peng-Robinson-EOS.htm) (this lesson sets volume translation to zero), [OpenStax: non-ideal gas behaviour](https://openstax.org/books/chemistry-2e/pages/9-6-non-ideal-gas-behavior).

## Throttling and expansion with work

An insulated steady-flow throttle, with negligible inlet/outlet kinetic/potential energy change and no shaft work, conserves specific/molar enthalpy. It does not generally conserve entropy. h includes flow work, `h = u+Pv`; this differs from an ideal reversible expander that produces shaft work.

Real throttling uses:

`h(P,T) = Cp_ideal (T−293.15 K) + h_departure(P,T)`

`h_departure = RT(Z−1) + [T da/dT − a]/(2 sqrt(2) b) × ln[(Z+(1+sqrt(2))B)/(Z+(1−sqrt(2))B)]`.

Ideal heat capacities are deliberately constant: 7R/2 for the diatomic air/N₂ examples and 5R/2 for monatomic helium. There is no Cp fit, vibrational excitation model, mixture interaction correction or cryogenic quantum treatment. The arbitrary reference h cancels because each path uses a fixed composition.

Outlet T is found by bisection on `h(Pout,Tout) = h(Pin,Tin)` over 180–450 K. The UI permits Tin = 253.15–353.15 K, Pin = 2–300 bar and 1 bar ≤ Pout ≤ Pin; tests verify all supported endpoint extremes remain inside that temperature bracket and conserve h. This domain avoids a multi-phase branch in the real-gas solver. A failed bracket returns undefined rather than silently extrapolating an outlet state.

The displayed inlet coefficient is a local derivative, `μJT = −(∂h/∂P)T / (∂h/∂T)P`, in K/bar. Centered differences use ±0.001 bar and ±0.02 K. Its sign describes the response to a small pressure drop; it is **not** treated as constant over a finite pressure drop. Tests additionally check the independent identity `(∂h/∂P)T = v−T(∂v/∂T)P` to validate the enthalpy departure and temperature derivative.

The ideal throttle comparison has Tout = Tin. The separate ideal, reversible steady-flow expander uses `γ = Cp/(Cp−R)`, `Tout/Tin = (Pout/Pin)^((γ−1)/γ)` and shaft work out `w = Cp(Tin−Tout)`. It is an ideal constant-γ comparison, not the PR throttle with a different label. Its mathematically low temperatures do not include condensation or real-fluid behaviour; a conditional note identifies cryogenic results.

These examples do not calculate regulator temperature or icing probability. They omit heat exchange with water and metal, local nozzle kinetic energy, moisture, mass flow, cylinder blowdown, reaction/phase changes and material/equipment properties. A draining cylinder requires its own transient mass/energy balance. Real diving hardware may exchange substantial heat; the insulated path is a teaching limit.

References: [University of Mainz: Joule–Thomson theory and experiment](https://interaktiv.chemie.uni-mainz.de/vpcgp/jt-man.en.html), [EES: PR enthalpy departure](https://fchart.com/ees/pengrobinson/h_dep_pr.htm), [University of Colorado LearnChemE: real/ideal enthalpy departure](https://learncheme.github.io/demos/EnthalpyEntropyDepartureFxnsGases/index.html). The implementation uses h_real−h_ideal for departure; some references define the opposite departure sign.

## Verification

Run `godot --headless --path . --script Tests/ThermalLearning.gd`. Run without `--headless` and add `-- --visual` to capture all four topics, process comparisons, both languages and 390-pixel layouts. Existing learning, physiology, optics, scenario, UI and language suites cover integration. Model functions live in `Scripts/ThermalModels.gd`, separate from production simulation physics.
