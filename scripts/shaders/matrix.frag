// «Матрица»: экран в тёмно-зелёном + падающий цифровой дождь.
// Анимированный (использует time).
float rnd(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 effect(vec3 c, vec2 uv) {
    // Подложка — содержимое экрана, перекрашенное в тёмно-зелёный.
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 col = vec3(0.0, lum, lum * 0.35) * 0.5;

    // Сетка ячеек-«символов».
    const float cols = 90.0;
    const float rows = 50.0;
    float colId = floor(uv.x * cols);
    float rowId = floor(uv.y * rows);
    vec2  f     = fract(uv * vec2(cols, rows));

    // У каждого столбца своя скорость падения и стартовый сдвиг.
    float speed  = 0.5 + rnd(vec2(colId, 1.0)) * 1.5;
    float offset = rnd(vec2(colId, 2.0)) * (rows + 30.0);
    float head   = mod(time * speed * 12.0 + offset, rows + 30.0);

    // Хвост дождя: ярче у «головы», гаснет выше по столбцу.
    float d    = head - rowId;
    float tail = d >= 0.0 ? exp(-d * 0.20) : 0.0;

    // Мерцание символа в ячейке (меняется во времени) + зазор между клетками.
    float flick = step(0.2, rnd(vec2(colId, rowId) + floor(time * 8.0)));
    float glyph = step(0.12, f.x) * step(f.y, 0.9);

    float rain = tail * flick * glyph;

    // Зелёный дождь + почти белая «голова» струи.
    col += vec3(0.15, 1.0, 0.4) * rain;
    col += vec3(0.8, 1.0, 0.8) * smoothstep(1.2, 0.0, abs(d)) * glyph;

    return col;
}
