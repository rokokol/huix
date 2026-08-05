// "Matrix": the screen in dark green + falling digital rain.
// Animated (uses time)
float rnd(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 effect(vec3 c, vec2 uv) {
    // Backdrop — screen contents recoloured dark green
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 col = vec3(0.0, lum, lum * 0.35) * 0.5;

    // Grid of "glyph" cells
    const float cols = 90.0;
    const float rows = 50.0;
    float colId = floor(uv.x * cols);
    float rowId = floor(uv.y * rows);
    vec2  f     = fract(uv * vec2(cols, rows));

    // Each column has its own fall speed and starting offset
    float speed  = 0.5 + rnd(vec2(colId, 1.0)) * 1.5;
    float offset = rnd(vec2(colId, 2.0)) * (rows + 30.0);
    float head   = mod(time * speed * 12.0 + offset, rows + 30.0);

    // Rain tail: brighter at the "head", fading up the column
    float d    = head - rowId;
    float tail = d >= 0.0 ? exp(-d * 0.20) : 0.0;

    // Glyph flicker within a cell (changes over time) + gap between cells
    float flick = step(0.2, rnd(vec2(colId, rowId) + floor(time * 8.0)));
    float glyph = step(0.12, f.x) * step(f.y, 0.9);

    float rain = tail * flick * glyph;

    // Green rain + a nearly white stream "head"
    col += vec3(0.15, 1.0, 0.4) * rain;
    col += vec3(0.8, 1.0, 0.8) * smoothstep(1.2, 0.0, abs(d)) * glyph;

    return col;
}
