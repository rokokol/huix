// «Матрица» — зелёный фосфорный монохром.
vec3 effect(vec3 c, vec2 uv) {
    float g = dot(c, vec3(0.2126, 0.7152, 0.0722));
    return vec3(0.0, g * 1.1, g * 0.35);
}
