// Animated glitch: jittering RGB split + occasional row shifts.
// Uses time -> Hyprland redraws the frame continuously
float hash(float n) { return fract(sin(n) * 43758.5453); }

vec3 effect(vec3 c, vec2 uv) {
    float t = time;
    // Horizontal shift by row bands, triggers rarely
    float band = floor(uv.y * 40.0);
    float jitter = (hash(band + floor(t * 12.0)) - 0.5) * 0.03;
    jitter *= step(0.92, hash(floor(t * 8.0) + band));
    vec2 suv = vec2(uv.x + jitter, uv.y);
    // RGB split that pulses over time
    float amt = 0.004 + 0.003 * sin(t * 6.0);
    float r = texture(tex, suv + vec2(amt, 0.0)).r;
    float g = texture(tex, suv).g;
    float b = texture(tex, suv - vec2(amt, 0.0)).b;
    return vec3(r, g, b);
}
