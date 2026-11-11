# Fick exchange and diving-mask optics

Both experiments are independent of the dive scenario. They teach a relation and its consequences under explicit boundary conditions; they are not clinical gas-transfer, eye-prescription or decompression predictions.

## Membrane transfer and finite storage

The pressure form of Fick’s diffusion law used here is `Qdot = (A κ / δ)(Psource − Preceiver)`. κ includes diffusion mobility and gas solubility/partitioning; it is not a bare diffusivity multiplied directly by a pressure gradient without that conversion. A concentration-gradient formulation is equivalent once the appropriate solubility relation is included. Diffusion across a membrane differs from bulk airflow/blood flow, and from the separate Fick principle used to infer cardiac output.

The UI keeps the barrier properties relative. Let `G = A_rel κ_rel / δ_rel`. The reference transfer unit is defined so the initial 100→40 mmHg example has rate 1 at unit geometry/permeability. Thus `Qdot_rel = G ΔP/60`. There is no measured mL/min coefficient behind that normalization.

The source is maintained at constant partial pressure. A separate storage assumption closes the time model: receiver storage is `C_rel/60` reference amount units per mmHg. With time τ in arbitrary reference intervals τ₀:

- `dPreceiver/dτ = (G/C_rel)(Psource − Preceiver)`
- `Preceiver(τ) = Psource + (Pinitial − Psource) exp(−G τ/C_rel)`
- `t_half/τ₀ = ln(2) C_rel/G`
- `Transferred_rel = C_rel (Preceiver − Pinitial)/60`

The total transferred amount and instantaneous rate are distinct. At a fixed gradient, doubling area doubles transfer; at a fixed later time, a larger area can already have removed most of the gradient and left a smaller current rate. The readout therefore reports current and initial rates together. Increasing storage increases the equilibration half-time without changing the initial rate. Equal partial pressures give zero net transfer, while molecular thermal motion need not stop.

Lung mode represents a single finite blood parcel exposed to maintained alveolar conditions, not an entire continuously perfused lung. Tissue mode uses the same mathematical receiver with an adjustable storage capacity. The pressure examples are rounded teaching values: lung/tissue O₂ 100→40 mmHg, lung/tissue CO₂ 40←46 mmHg. Tissue inert-gas uptake/release uses 1500/570 mmHg, chosen to illustrate reversing a gradient rather than a generated dive exposure. Each gas has its own pressure gradient; the total gas pressure is not substituted for that gradient.

Preset buttons deliberately set pressure examples only. They do not claim the same actual permeability for O₂, CO₂ and N₂, and do not derive κ from the gas name. Real CO₂ permeability, chemical carriage and blood gas storage differ substantially from O₂; this model leaves permeability/storage as explicitly independent relative controls. The default lung capacity is 1 and tissue capacity 3 for contrast, not a physiological ratio. τ₀ is not seconds, a capillary transit time, or a measured tissue half-time.

Henry’s law relates dissolved concentration and partial pressure; Fick’s law sets transfer driven by the gradient. Adding storage and fixed-source boundary conditions produces an exponential response. This does not derive the calibrated compartment half-times of Bühlmann. Haemoglobin binding, nonlinear gas capacity, bicarbonate/CO₂ chemistry, metabolism, ventilation, perfusion, spatial heterogeneity and bubbles are omitted. In real tissues, blood flow and consumption/production help maintain gradients that would disappear in this closed-receiver example.

References: [OpenStax: lung and tissue gas exchange](https://openstax.org/books/anatomy-and-physiology-2e/pages/22-4-gas-exchange), [American Physiological Society: concentration/flux form and permeability](https://journals.physiology.org/doi/full/10.1152/advances.2001.25.2.15), [Virginia Tech pulmonary physiology: Fick factors](https://pressbooks.lib.vt.edu/pulmonaryphysiology/chapter/fundamentals-of-gas-exchange/). Source values illustrate physiology; normalized model coefficients/time units are our teaching choices.

## Exact rays through a flat mask window

The original Snell stage retains `n1 sin θ1 = n2 sin θ2`, air/water direction selection and total internal reflection. The mask stage adds two parallel interfaces rather than assigning a fixed magnification factor.

The pinhole eye is at x = 0. Mask air extends to the inner window at x = e, glass thickness is g, and the object lies d beyond the outer face. The target is a flat vertical line of unchanged height H, centred on the optical axis. Water n_w = 1.333 and mask air n_a = 1.000 are fixed; window n_g is selected (1.34–1.70). These are illustrative wavelength-independent indices, not a material calibration. Eye spacing is 15–80 mm, window thickness 1–12 mm, object distance 0.5–3 m, and object height 0.05–0.40 m.

For the upper target edge h = H/2, the conserved quantity is `q = n_i sin θ_i`. The solver finds q by bisection:

`h = e q/sqrt(n_a²−q²) + g q/sqrt(n_g²−q²) + d q/sqrt(n_w²−q²)`.

Then `θ_i = asin(q/n_i)`. Ray intersections are computed from the actual layer distances, including both window faces; rays drawn with arrows propagate from object toward eye. The local inset preserves those computed angles, with an explicitly exaggerated slab width so the two bends are visible. The overview uses the same scale for horizontal and vertical world distances. The inset’s drawing dimensions are not a second physical window thickness.

For comparison, the **same object in air at the same eye-to-object distance** subtends `αair = 2 atan[h/(e+g+d)]`. Through the mask it subtends `αmask = 2θa`. Angular magnification is `αmask/αair`. The paired 60° frames share a linear angular-height scale; they are a diagram of angular extent, not calibrated photographic or retinal images. All supported control extremes fit that displayed field.

The dashed construction continues the two received edge rays straight from the eye. At their original edge heights ±h the back-projected distance is `de = h/tan θa`. The outline target retains the same H; the construction illustrates why a nearer interpretation gives a greater angular size. It is labeled **edge back-projected distance**, not a claim that every finite-angle ray through a flat port forms one perfect virtual-image plane. Flat-port off-axis image geometry is more complex; angular magnification is not exactly actual-distance/de at finite angles.

In the paraxial limit, `dp = e + g n_a/n_g + d n_a/n_w`. For small air gap/thickness relative to d, the angular ratio tends toward n_w/n_a ≈ 1.333 and the apparent-distance ratio toward n_a/n_w ≈ 0.750. The values are limits, not universal constants: at the reference case H = 0.20 m, d = 1 m, e = 35 mm, g = 4 mm and n_g = 1.5, the model gives about 1.320 angular size, 1.039 m actual eye distance and 0.785 m edge back-projected distance. Changing eye spacing, window thickness/index or field angle changes those results. The compact lesson starts with H = 0.30 m and d = 0.75 m so the size difference is easier to see; this changes the demonstration state, not the model.

An ordinary flat parallel window has no focusing curvature like a corrective spectacle lens. Its index/thickness affects the internal segment and lateral displacement; the overall angular transformation comes from the water-to-mask-air indices plus the geometry. The mask air space also restores the air–cornea interface needed for normal focusing; bare-eye underwater blur is not simulated. The comparison is not a claim about what a bare underwater eye can resolve.

Excluded effects: finite pupil/aperture and frame clipping, binocular perception/accommodation, corneal/lens focusing, curved/corrective windows, wavelength dispersion, reflections/Fresnel intensity, scattering and visual adaptation. Water/glass indices and fixed object height are controlled teaching assumptions. Refraction/magnification should not be interpreted as a change in physical object dimensions.

References: [OpenStax: refraction and total internal reflection](https://openstax.org/books/university-physics-volume-3/pages/1-4-total-internal-reflection), [Diving and hyperbaric ophthalmology review hosted by UHMS](https://uhms.org/images/MEDFAQs/September-2016/Diving_and_Hyperbaric_Opthalmology.pdf). The exact ray and edge-construction equations above follow from Snell’s invariant and straight segments in uniform media; no fixed 33% scaling is applied to the diagrams.

## Verification

`Tests/ExchangeMask.gd` checks algebraic scaling, half-time/transfer balance, both gradient directions, equal-pressure and supported parameter extremes. Optics checks verify Snell’s invariant at both faces, endpoint closure, index-matched limits, paraxial angular/distance limits, finite slab/index effects and all-control angular bounds. UI checks cover presets, plot/object dragging, keyboard input, existing Snell/TIR behaviour, preserved per-stage/topic state, French layouts, phone widths and unchanged scenario/history.

Run `godot --headless --path . --script Tests/ExchangeMask.gd`. For native rendered screenshots, omit `--headless` and append `-- --visual`. Source classes are `ExchangeModels.gd`, `ExchangeLesson.gd`, `ExchangeDiagram.gd`, `MaskOptics.gd`, `MaskLesson.gd` and `MaskDiagram.gd` under `Scripts/`.
