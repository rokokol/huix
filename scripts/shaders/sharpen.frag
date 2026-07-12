// Резкое усиление чёткости — ядро 3×3: вес 9 в центре, −1 у каждого из 8 соседей.
vec3 effect(vec3 c, vec2 uv) {
    vec2 px = vec2(fwidth(uv.x), fwidth(uv.y));
    vec3 n  = texture(tex, uv + vec2( 0.0,  px.y)).rgb;
    vec3 s  = texture(tex, uv + vec2( 0.0, -px.y)).rgb;
    vec3 w  = texture(tex, uv + vec2(-px.x,  0.0)).rgb;
    vec3 e  = texture(tex, uv + vec2( px.x,  0.0)).rgb;
    vec3 nw = texture(tex, uv + vec2(-px.x,  px.y)).rgb;
    vec3 ne = texture(tex, uv + vec2( px.x,  px.y)).rgb;
    vec3 sw = texture(tex, uv + vec2(-px.x, -px.y)).rgb;
    vec3 se = texture(tex, uv + vec2( px.x, -px.y)).rgb;
    return clamp(9.0 * c - (n + s + w + e + nw + ne + sw + se), 0.0, 1.0);
}
