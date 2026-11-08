# Bathys identity

The emblem combines a wave, descending bathymetric bands, and a downward navigation point. Navy and cyan draw from the user's four-logo inspiration sheet. The emblem is paired with native BATHYS typography in the app header and the web loading screen; the emblem alone is used for the application icon, favicon, and touch icon.

## Assets

- `bathys-master.png`: original generated artwork with transparency, preserved unchanged; excluded from the Web pack.
- `bathys-512.png`: application icon and source for Godot's exported browser/touch icons.
- `bathys-256.png`: header emblem and boot/loading image.
- `loading-head.html`: source for loading-screen branding injected into the export preset.

Run `godot --headless --path . --script Tools/PrepareBrand.gd` to prepare the icon sizes with Lanczos scaling and synchronize the loading-screen CSS into the Web preset. No API key or image generation is needed to rebuild these sizes. The runtime assets are packaged locally and make no external network requests.

## Generation provenance

Created using the built-in image_gen tool through the imagegen skill, with the user's attached sheet as a style reference. No fallback CLI or API runner was used. Subsequent processing only resized the original artwork in Godot and preserved transparency.

Final prompt:

> Use case: logo-brand. Create ONE finished original logo emblem for BATHYS, an underwater exploration and dive-planning game. The attached four-logo sheet is a STYLE REFERENCE only: borrow the restrained deep navy, bright turquoise, flowing wave, sonar/navigation and layered depth motifs; do not copy any one design. Design a polished, compact circular expedition badge with a very dark ink-navy solid circular field, a substantial clean turquoise rim, and a bold luminous cyan flowing wave crest in the upper half seamlessly paired with two broad descending bathymetric chevron ribbons in the lower half. A small simple downward navigation point can be integrated into the negative space between wave and depth ribbons. Make it elegant and distinctive, restrained flat vector-like geometry, slightly rounded precise edges, two-tone turquoise/cyan accents with only a subtle gradient, no 3D mockup, no extraneous decoration, no gear teeth, no small detail. Strong silhouette, optical balance, good legibility at 32–48 px. Emblem only: NO TEXT, NO LETTERS, NO WORDMARK. Square canvas, emblem centered filling about 92% of the canvas, genuinely TRANSPARENT outside the circular badge. Output a clean production asset, not a presentation sheet.
