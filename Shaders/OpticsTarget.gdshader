shader_type canvas_item;
render_mode unshaded;
uniform vec3 direct_colours[10];
uniform vec3 forward_colours[10];
uniform vec3 reference_colours[10];
uniform vec3 backscatter = vec3(0.0);
uniform float sigma = 0.01;
uniform float exposure = 1.0;
uniform bool reference = false;
uniform float compare_split = -1.0;
uniform int component = 0;

int material_at(vec2 uv) {
    uv = clamp(uv, vec2(0.0), vec2(0.9999));
    vec2 chart = (uv - vec2(0.045, 0.09)) / vec2(0.91, 0.82);
    if (chart.x < 0.0 || chart.y < 0.0 || chart.x >= 1.0 || chart.y >= 1.0) { return 0; }
    vec2 cell = fract(chart * vec2(4.0, 2.0));
    if (cell.x < 0.035 || cell.x > 0.965 || cell.y < 0.05 || cell.y > 0.95) { return 0; }
    int patch = int(floor(chart.x * 4.0)) + 4 * int(floor(chart.y * 2.0)) + 1;
    // Black/grey fine detail makes loss of local contrast and forward blur visible.
    if (cell.y > 0.63 && cell.y < 0.86 && cell.x > 0.16 && cell.x < 0.84) {
        return mod(floor(cell.x * 20.0), 2.0) == 0.0 ? 8 : 9;
    }
    return patch;
}
vec3 srgb(vec3 c) {
    c = clamp(c, vec3(0.0), vec3(1.0));
    return mix(12.92 * c, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
void fragment() {
    int index = material_at(UV);
    if (reference || UV.x < compare_split) { COLOR = vec4(srgb(reference_colours[index]), 1.0); }
    else {
        // Normalised nine-tap Gaussian surrogate; it is NOT a measured camera PSF.
        vec2 radius = vec2(sigma, sigma * 2.2) * 1.41421356;
        vec3 halo = forward_colours[index] * 0.25;
        halo += forward_colours[material_at(UV + vec2(radius.x, 0.0))] * 0.125;
        halo += forward_colours[material_at(UV - vec2(radius.x, 0.0))] * 0.125;
        halo += forward_colours[material_at(UV + vec2(0.0, radius.y))] * 0.125;
        halo += forward_colours[material_at(UV - vec2(0.0, radius.y))] * 0.125;
        halo += forward_colours[material_at(UV + radius)] * 0.0625;
        halo += forward_colours[material_at(UV + vec2(-radius.x, radius.y))] * 0.0625;
        halo += forward_colours[material_at(UV + vec2(radius.x, -radius.y))] * 0.0625;
        halo += forward_colours[material_at(UV - radius)] * 0.0625;
        vec3 direct = direct_colours[index];
        vec3 signal = component == 1 ? direct : component == 2 ? halo : component == 3 ? backscatter : component == 4 ? direct + halo : direct + halo + backscatter;
        COLOR = vec4(srgb(signal * exposure), 1.0);
    }
}
