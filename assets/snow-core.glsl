float snow_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float snow_bank(vec2 p) {
    float height = 5.0 + 1.5 * sin(p.x * 0.016) + sin(p.x * 0.043);
    return 1.0 - smoothstep(height, height + 2.0, p.y);
}

float snow_flakes(vec2 p, float seconds) {
    vec2 moving = p + vec2(0.0, seconds * 14.0);
    vec2 cell = floor(moving / 48.0);
    vec2 local = fract(moving / 48.0) * 48.0;
    float seed = snow_hash(cell);
    vec2 center = vec2(8.0 + 32.0 * seed, 8.0 + 32.0 * snow_hash(cell + 17.0));
    center.x += 3.0 * sin(seconds * 0.8 + seed * 6.283);
    float radius = 1.2 + 1.2 * snow_hash(cell + 43.0);
    float flake = 1.0 - smoothstep(radius, radius + 1.0, length(local - center));
    return flake * step(0.42, snow_hash(cell + 91.0));
}
