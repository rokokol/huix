// Анимированная «водная» рябь: экран мягко колышется во времени.
// Использует time -> Hyprland перерисовывает кадр непрерывно.
vec3 effect(vec3 c, vec2 uv) {
    vec2 o;
    o.x = 0.004 * sin(uv.y * 30.0 + time * 2.0);
    o.y = 0.004 * cos(uv.x * 30.0 + time * 2.0);
    return texture(tex, uv + o).rgb;
}
