// Оттенки серого (коэффициенты яркости Rec. 709).
vec3 effect(vec3 c, vec2 uv) {
    float g = dot(c, vec3(0.2126, 0.7152, 0.0722));
    return vec3(g);
}
