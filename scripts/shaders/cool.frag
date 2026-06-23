// Холодный синеватый оттенок.
vec3 effect(vec3 c, vec2 uv) {
    return clamp(c * vec3(0.85, 0.95, 1.12), 0.0, 1.0);
}
