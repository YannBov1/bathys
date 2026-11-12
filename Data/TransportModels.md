# Transport, thermal and acoustic teaching models

Five physics topics use `Scripts/TransportModels.gd`, `TransportLessons.gd` and `TransportDiagram.gd`. Experiments are separate from the dive plan and do not alter planner physics, gases, history or playback. All figures are schematic; numerical readouts use the equations below. English and French include the equations, explanations, limits and sources under the information icon.

## Viscosity and gas properties

Parallel-plate Couette flow uses shear stress τ = μU/h and force F = τA, with A = 0.02 m². Velocity varies linearly from the fixed wall to the moving plate. Viscosity changes the required force, not this prescribed velocity profile. Kinematic viscosity is ν = μ/ρ.

Freshwater viscosity at 0.1 MPa uses IAPWS supplementary Eq. 7: μ = 10⁻⁶ Σ aᵢ(T/300 K)^bᵢ Pa·s. Coefficients are (280.68, −1.9), (511.45, −7.7), (61.131, −19.6), (0.45903, −40). The interface stays between 0 and 35°C. Surface density reuses the existing EOS-80 polynomial. Water conductivity 0.6 W/(m·K) and cp 4184 J/(kg·K) are deliberately fixed representative values, rather than a complete temperature/pressure property package.

Dry O₂/N₂/He gases use ideal density P M/(RT). At 300 K, viscosity anchors are 20.7, 17.8 and 19.9 µPa·s respectively. Sutherland scaling uses S = 139, 107 and 79.4 K; the helium value is an illustrative near-room-temperature fit. The Wilke mole-fraction mixing rule uses the pure viscosities and molar masses. Pressure-dependent viscosity corrections are omitted even when the flow experiment changes ideal density with depth.

Ideal molar cp is 7R/2 for O₂/N₂ and 5R/2 for He. Pure conductivity is estimated by classical Eucken, kᵢ = μᵢ(cp,mol + 5R/4)/Mᵢ, then combined with the same Wilke weights. This is a dilute-mixture estimate, not a certified high-pressure conductivity table. The binary air reference is 21% O₂ / 79% N₂, without argon or humidity.

Sources: [IAPWS liquid-water supplementary release](https://iapws.org/technical-guidance/release/LiquidWater), [NASA Sutherland and Wilke equations](https://www.grc.nasa.gov/WWW/winddocs/user/keywords/viscosity.html), [NIST gas viscosities](https://tsapps.nist.gov/publication/get_pdf.cfm?pub_id=926439), [NIST helium table](https://www.nist.gov/pml/sensor-science/fluid-metrology/database-thermophysical-properties-gases-used-semiconductor-9), [NASA Eucken transport discussion](https://vulcan-cfd.larc.nasa.gov/WebPage/Documentation/JANNAF-2014.pdf).

## Pipe flow

Actual local volume flow Q becomes mean speed v = 4Q/(πD²). Reynolds number is ρvD/μ. Pressure loss uses Darcy–Weisbach: Δp = f(L/D)ρv²/2. Laminar f = 64/Re reproduces Poiseuille exactly. Above Re 4000, smooth-pipe Haaland uses f = [−1.8 log₁₀(6.9/Re)]⁻². Between 2000 and 4000 the app blends the laminar value and the turbulent value at Re 4000 for illustration; the blend is not a transition prediction.

The model assumes steady, fully developed flow in a smooth straight round tube; entry length, bends, valves, pulsation and compressibility are omitted. Flow is **local L/min**, not surface SAC. Density and viscosity therefore have distinct roles. Drawn eddies and particle motion indicate the regime, rather than solving Navier–Stokes.

Sources: [OpenStax viscosity and Poiseuille](https://openstax.org/books/university-physics-volume-1/pages/14-7-viscosity-and-turbulence), [NIST flow-regime discussion](https://www.nist.gov/system/files/documents/2018/03/16/airnet.pdf), [Haaland 1983](https://doi.org/10.1115/1.3240948).

## Heat transfer and storage

The mechanisms have separate views and maintained boundary temperatures:

- Conduction: Q̇ = kA(T_hot − T_cold)/d through a still uniform layer. The air reference has the same geometry and temperatures.
- Forced convection: Q̇ = hA(T_hot − T_environment), with h = Nu k/D and D = 0.1 m. Churchill–Bernstein evaluates fluid properties at mean film temperature. The correlation is Nu = 0.3 + [0.62 Re^½ Pr^⅓ / (1 + (0.4/Pr)^⅔)^¼] [1 + (Re/282000)^⅝]^⅘. The chosen speed range keeps Re·Pr above 0.2. Natural convection, end effects, insulation, clothing and perfusion are excluded; this is a reference heated surface, not total human heat loss.
- Radiation: Q̇ = εσA(T_hot⁴ − T_cold⁴), in kelvins, with σ = 5.670374419×10⁻⁸ W/(m²·K⁴). The diffuse-gray surface sees a large enclosure with view factor 1 across an air/vacuum gap. The model does not describe long-range thermal infrared through water.

No universal water/air cooling multiplier is asserted. Conduction isolates k and geometry, while forced convection also depends on speed, density, viscosity and heat capacity. The diagram and linked curve display an air comparison at the same conditions.

Heat storage uses C = m cp and ΔT = Q/C. Samples have equal 50 g mass or equal **initial** 50 mL volume. Gas samples heat at constant pressure and may expand, so cp is appropriate. Labels show the initial volume or mass to make the comparison basis visible. The energy range changes from 0–200 J to 0–1 J in equal-volume mode so gas temperature rises remain interpretable. Conductivity is a separate comparison with A = 0.02 m², ΔT = 20 K and adjustable thickness. Thermal diffusivity k/(ρcp) appears in the disclosed equations.

Representative solids: aluminium k = 237 W/(m·K), cp = 900 J/(kg·K), ρ = 2700 kg/m³; copper k = 401, cp = 385, ρ = 8960 in the same units. These values are room-temperature examples; alloy, temperature, contacts and phase changes are outside the experiment.

Sources: [OpenStax heat-transfer mechanisms](https://openstax.org/books/university-physics-volume-2/pages/1-6-mechanisms-of-heat-transfer), [Churchill–Bernstein 1977](https://doi.org/10.1115/1.3450685), [OpenStax heat capacities](https://openstax.org/books/chemistry-atoms-first/pages/9-1-energy-basics), [AIST metal conductivities](https://tpds.db.aist.go.jp/opendata/metal_tc_en.html).

## Sound

Coppens (1981) gives sound speed using t = T_C/10, salinity S and depth **D in kilometres**. The interface uses 0–35°C, salinity 0–40 and 0–60 m, within its listed domain. Air uses the ideal binary gas with γ = 1.4. Travel times are r/c. Animated fronts are slowed and normalized for viewing; the displayed times remain physical.

Normal-incidence reflection uses Z = ρc and **intensity** fractions R = [(Z₂ − Z₁)/(Z₂ + Z₁)]² and T = 1−R. The pressure reflection amplitude has the unsquared sign. Water-to-water is impedance matched. Air is at 1 bar; the steel half-space uses ρ = 7850 kg/m³ and longitudinal c = 5900 m/s as representative values. Finite layers, oblique incidence and elastic mode conversion are excluded.

Attenuation uses Ainslie–McColm at reference seawater S = 35, pH = 8, depth 10 m, temperatures 0–34°C and frequency 0.1–100 kHz. The three terms are boric acid, magnesium sulphate and pure-water absorption. α is in dB/km. Relative to the level at **1 m in the same medium**, loss = 20 log₁₀(r/1 m) + α(r−1 m)/1000 for r in metres. Spreading and absorption are displayed separately. This is not a lake/freshwater calibration, an absolute SPL comparison between air and water, or a hearing-range prediction; the upper frequency range includes ultrasound.

Direction cues use source coordinates (r sin θ, −r cos θ) and two point receivers at x = ±0.09 m. The exact path difference divided by c gives the arrival difference. Mirroring the source across the ear line preserves that cue. Head/ear spacing is exaggerated in the drawing. Ear coupling, head/body conduction, spectral cues and multipath are not modeled; no human localization-performance score is produced.

Sources: [NPL sound-speed equations and validity](https://resource.npl.co.uk/acoustics/techguides/soundseawater/), [NPL underlying equations](https://resource.npl.co.uk/acoustics/techguides/soundseawater/underlying-phys.html), [NPL seawater absorption](https://resource.npl.co.uk/acoustics/techguides/seaabsorption/), [Ainslie–McColm 1998](https://doi.org/10.1121/1.421258), [primary study of human underwater hearing/localization](https://findresearcher.sdu.dk/ws/files/201744102/1_s2.0_S0378595522000557_main.pdf).

## Verification

`Tests/TransportModels.gd` checks reference properties, scaling laws, Poiseuille reduction, conservation and limiting cases, comparison-basis effects, Coppens units, attenuation reference and timing symmetry. `Tests/TransportLearning.gd` tests every stage, direct figure manipulation, instruments/keyboard, mixture normalization, comparison/disclosure controls, translated phone layouts, retained experiment state and unchanged plan/history. Native screenshots are in the ignored `Screenshots/` folder. Existing lesson and planner reference suites cover integration.
