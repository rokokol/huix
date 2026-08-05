// JPEG artefacts: 8×8 DCT blocking + 4:2:0 chroma subsampling (16×16 for colour) +
// aggressive chroma quantization + Gibbs ringing + saturation degradation.
// Mimics heavy JPEG compression (quality ~5–10).
// Static, samples the texture with an offset (block averaging).

// RGB ↔ YCbCr (BT.601, range 0..1 — no Cb/Cr offset, for simplicity)
vec3 toYCbCr(vec3 c) {
    float y  =  0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    float cb = -0.169 * c.r - 0.331 * c.g + 0.500 * c.b;
    float cr =  0.500 * c.r - 0.419 * c.g - 0.081 * c.b;
    return vec3(y, cb, cr);
}
vec3 toRGB(vec3 ycbcr) {
    float r = ycbcr.x                        + 1.402 * ycbcr.z;
    float g = ycbcr.x - 0.344 * ycbcr.y      - 0.714 * ycbcr.z;
    float b = ycbcr.x + 1.772 * ycbcr.y;
    return vec3(r, g, b);
}

// Block sampling: 4 points → bilinear interpolation by the position within the block
vec3 sampleBlock(vec2 origin, vec2 bUV, vec2 bPos) {
    vec3 s00 = texture(tex, origin + bUV * vec2(0.25, 0.25)).rgb;
    vec3 s10 = texture(tex, origin + bUV * vec2(0.75, 0.25)).rgb;
    vec3 s01 = texture(tex, origin + bUV * vec2(0.25, 0.75)).rgb;
    vec3 s11 = texture(tex, origin + bUV * vec2(0.75, 0.75)).rgb;
    return mix(mix(s00, s10, bPos.x), mix(s01, s11, bPos.x), bPos.y);
}

vec3 effect(vec3 c, vec2 uv) {
    vec2 px = vec2(fwidth(uv.x), fwidth(uv.y));

    // --- Luma: 8×8 blocks ---
    vec2 lumaUV     = vec2(8.0) * px;
    vec2 lumaOrigin = floor(uv / lumaUV) * lumaUV;
    vec2 lumaPos    = (uv - lumaOrigin) / lumaUV;
    vec3 lumaBlk    = sampleBlock(lumaOrigin, lumaUV, lumaPos);

    // --- Chroma: 16×16 blocks (4:2:0 — twice as coarse on both axes) ---
    vec2 chromaUV     = vec2(16.0) * px;
    vec2 chromaOrigin = floor(uv / chromaUV) * chromaUV;
    vec2 chromaPos    = (uv - chromaOrigin) / chromaUV;
    vec3 chromaBlk    = sampleBlock(chromaOrigin, chromaUV, chromaPos);

    // Convert both blocks to YCbCr
    vec3 lumaYCC   = toYCbCr(lumaBlk);
    vec3 chromaYCC = toYCbCr(chromaBlk);

    // Assemble: Y from the fine block (8×8), Cb/Cr from the coarse one (16×16)
    vec3 ycbcr = vec3(lumaYCC.x, chromaYCC.y, chromaYCC.z);

    // Quantization: luma — 24 levels, chroma — 6 levels (JPEG hits colour harder)
    ycbcr.x = floor(ycbcr.x * 24.0 + 0.5) / 24.0;
    ycbcr.y = floor(ycbcr.y * 6.0  + 0.5) / 6.0;
    ycbcr.z = floor(ycbcr.z * 6.0  + 0.5) / 6.0;

    // Saturation degradation — chroma gets "washed out" under heavy compression
    ycbcr.y *= 0.75;
    ycbcr.z *= 0.75;

    vec3 blk = toRGB(ycbcr);

    // Seams between luma blocks (8×8): slight darkening at the boundaries
    float edgeX = step(lumaPos.x, px.x / lumaUV.x) + step(1.0 - px.x / lumaUV.x, lumaPos.x);
    float edgeY = step(lumaPos.y, px.y / lumaUV.y) + step(1.0 - px.y / lumaUV.y, lumaPos.y);
    float edge  = clamp(edgeX + edgeY, 0.0, 1.0);
    blk *= mix(1.0, 0.92, edge);

    // Gibbs ringing — "ringing" at contrasty transitions (halos around text/lines)
    float origLum = toYCbCr(c).x;
    float diff    = abs(origLum - ycbcr.x);
    float ring    = sin(lumaPos.x * 25.13) * sin(lumaPos.y * 25.13);
    blk += vec3(ring * diff * 0.35);

    return clamp(blk, 0.0, 1.0);
}
