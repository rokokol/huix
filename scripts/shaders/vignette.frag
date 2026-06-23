// Виньетка — мягкое затемнение по краям экрана, фокус в центре.
vec3 effect(vec3 c, vec2 uv) {
    vec2 d = uv - 0.5;
    float v = smoothstep(0.85, 0.35, length(d));
    return c * mix(0.45, 1.0, v);
}
