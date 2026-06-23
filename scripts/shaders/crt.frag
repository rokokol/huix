// Ретро-ЭЛТ: горизонтальные скан-линии + лёгкая виньетка.
vec3 effect(vec3 c, vec2 uv) {
    float scan = 0.85 + 0.15 * sin(uv.y * 800.0);
    vec2 d = uv - 0.5;
    float vig = smoothstep(0.9, 0.4, length(d));
    return c * scan * mix(0.6, 1.0, vig);
}
