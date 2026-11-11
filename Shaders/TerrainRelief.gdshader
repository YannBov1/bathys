shader_type spatial;
render_mode unshaded, cull_disabled;

varying float bed_depth_m;
varying vec3 bed_world_normal;

void vertex() {
    bed_depth_m = -(MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
    bed_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    float d = max(0.0, bed_depth_m);
    vec3 a = vec3(0.270, 0.705, 0.660);
    vec3 b = vec3(0.145, 0.540, 0.565);
    vec3 c = vec3(0.073, 0.365, 0.455);
    vec3 e = vec3(0.040, 0.245, 0.360);
    vec3 f = vec3(0.025, 0.145, 0.245);
    vec3 color = d < 10.0 ? mix(a,b,d/10.0) :
                 d < 20.0 ? mix(b,c,(d-10.0)/10.0) :
                 d < 30.0 ? mix(c,e,(d-20.0)/10.0) :
                 mix(e,f,clamp((d-30.0)/15.0,0.0,1.0));

    // World-space relief stays attached to the lakebed as the camera orbits.
    // Only colour changes: vertices, depth, picking and route coordinates do not.
    vec3 n = normalize(bed_world_normal);
    n = n.y < 0.0 ? -n : n;
    float steep = smoothstep(0.134, 0.5, 1.0 - n.y); // approximately 30 to 60 degrees
    float relief = 0.55 + 0.45 * max(dot(n, normalize(vec3(-0.55, 0.75, 0.38))), 0.0);
    color = mix(color, vec3(0.56, 0.40, 0.23), 0.5 * steep);
    color *= relief * (1.0 - 0.12 * steep);

    // Screen-aware edges keep five-metre contours visible without distant shimmer.
    float phase = mod(d, 5.0);
    float edge = min(phase, 5.0 - phase);
    float width = max(0.035, fwidth(d) * 1.1);
    float contour = 1.0 - smoothstep(0.0, width, edge);
    ALBEDO = color * (1.0 - 0.28 * contour);
    ROUGHNESS = 1.0;
}
