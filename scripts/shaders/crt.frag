// Retro CRT: tube curvature + shadow RGB mask + scanlines + vignette.
// The curvature resamples the image along bowed coordinates, which makes the
// straight edges of windows/text jaggy (that very artefact). So we SMOOTH the
// sampling with 2x2 supersampling based on screen-space derivatives (dFdx/dFdy).
// Scanlines are computed in curved space (wuv) — they bend together with the
// screen. The mask is tied to physical pixels (gl_FragCoord) so its 3px
// frequency doesn't "drift" and produce colour moiré.
// Static (time is unused) — leaves Hyprland's debug options alone
vec3 effect(vec3 c, vec2 uv) {
    // Tube curvature
    vec2 cc = uv - 0.5;
    vec2 wuv = uv + cc * dot(cc, cc) * 0.18;

    // Pixel size in wuv coordinates — for supersampling (computed BEFORE branching,
    // derivatives must live in uniform control flow)
    vec2 dx = dFdx(wuv);
    vec2 dy = dFdy(wuv);

    // Beyond the edge of the rounded tube — a black border
    if (any(lessThan(wuv, vec2(0.0))) || any(greaterThan(wuv, vec2(1.0)))) {
        return vec3(0.0);
    }

    // 2x2 supersampling (rotated grid) — smooths the jaggies from the curvature
    vec3 col = 0.25 * (
        texture(tex, wuv + 0.25 * dx + 0.25 * dy).rgb +
        texture(tex, wuv - 0.25 * dx + 0.25 * dy).rgb +
        texture(tex, wuv + 0.25 * dx - 0.25 * dy).rgb +
        texture(tex, wuv - 0.25 * dx - 0.25 * dy).rgb
    );

    // Line density in pixels via derivatives — resolution-independent
    float H = 1.0 / max(fwidth(uv.y), 1e-6);
    // Scanlines are computed in CURVED space (wuv), not along physical rows —
    // so they bow together with the tube (period ~9px in the centre)
    float scan = 0.85 + 0.15 * sin(wuv.y * H * 0.7);

    // Shadow RGB mask with a 3px period, along physical pixels
    float ph = mod(gl_FragCoord.x, 3.0);
    vec3 mask = vec3(0.8);
    if (ph < 1.0) {
        mask.r = 1.0;
    } else if (ph < 2.0) {
        mask.g = 1.0;
    } else {
        mask.b = 1.0;
    }

    // Vignette at the edges
    float vig = smoothstep(0.95, 0.4, length(cc));

    col *= scan * mask * mix(0.7, 1.0, vig);
    return col * 1.3; // compensates for the dimming from the mask and scanlines
}
