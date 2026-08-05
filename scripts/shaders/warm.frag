// Warm "night" filter — cuts the blue spectrum, easier on the eyes in the evening
vec3 effect(vec3 c, vec2 uv) {
    return c * vec3(1.0, 0.80, 0.58);
}
