// Постеризация — резкое уменьшение числа оттенков (комикс / поп-арт).
vec3 effect(vec3 c, vec2 uv) {
    float levels = 5.0;
    return floor(c * levels + 0.5) / levels;
}
