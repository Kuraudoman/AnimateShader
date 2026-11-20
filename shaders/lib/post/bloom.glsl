#ifndef ANIMATE_BLOOM_GLSL
#define ANIMATE_BLOOM_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

// ==============================================================================
// Multi-Scale Dreamy Anime HDR Bloom + Cinematic Anamorphic Starlight Streaks
// Uses Karis weighting on bright-pass downsample to prevent shimmering fireflies.
// ==============================================================================

vec3 softKneeThreshold(vec3 col, float threshold, float knee) {
    // Clamp extreme HDR spikes gently so bloom never explodes into solid white
    vec3 clamped = min(col, vec3(14.0));
    float br = max(clamped.r, max(clamped.g, clamped.b));
    float rq = clamp(br - threshold + knee, 0.0, 2.0 * knee);
    rq = (rq * rq) / max(4.0 * knee, 1e-4);
    float weight = max(rq, br - threshold) / max(br, 1e-4);
    // Slightly enrich color purity in extracted bloom highlights
    vec3 extracted = clamped * max(weight, 0.0);
    return adjustSaturation(extracted, 1.12);
}

float karisWeight(vec3 c) {
    return 1.0 / (1.0 + luma(c) * 0.75);
}

// Pass 1 (composite1): 13-tap Karis-weighted bright-pass downsample (full -> half)
vec3 bloomBrightPassDownsample(sampler2D srcTex, vec2 uv, vec2 fullTexel) {
    // 5-tap center box + 4 corners for ultra-clean firefly-free downsample
    vec3 a = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2(-2.0,  2.0)).rgb, 0.88, 0.45);
    vec3 b = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2( 0.0,  2.0)).rgb, 0.88, 0.45);
    vec3 c = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2( 2.0,  2.0)).rgb, 0.88, 0.45);
    vec3 d = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2(-2.0,  0.0)).rgb, 0.88, 0.45);
    vec3 e = softKneeThreshold(texture(srcTex, uv).rgb,                                0.88, 0.45);
    vec3 f = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2( 2.0,  0.0)).rgb, 0.88, 0.45);
    vec3 g = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2(-2.0, -2.0)).rgb, 0.88, 0.45);
    vec3 h = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2( 0.0, -2.0)).rgb, 0.88, 0.45);
    vec3 i = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2( 2.0, -2.0)).rgb, 0.88, 0.45);

    vec3 j = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2(-1.0,  1.0)).rgb, 0.88, 0.45);
    vec3 k = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2( 1.0,  1.0)).rgb, 0.88, 0.45);
    vec3 l = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2(-1.0, -1.0)).rgb, 0.88, 0.45);
    vec3 m = softKneeThreshold(texture(srcTex, uv + fullTexel * vec2( 1.0, -1.0)).rgb, 0.88, 0.45);

    // Karis-weighted 4-quad average
    vec3 g0 = (j + k + l + m) * 0.25;
    vec3 g1 = (a + b + d + e) * 0.25;
    vec3 g2 = (b + c + e + f) * 0.25;
    vec3 g3 = (d + e + g + h) * 0.25;
    vec3 g4 = (e + f + h + i) * 0.25;

    float w0 = karisWeight(g0) * 0.50;
    float w1 = karisWeight(g1) * 0.125;
    float w2 = karisWeight(g2) * 0.125;
    float w3 = karisWeight(g3) * 0.125;
    float w4 = karisWeight(g4) * 0.125;

    return (g0 * w0 + g1 * w1 + g2 * w2 + g3 * w3 + g4 * w4) / max(w0 + w1 + w2 + w3 + w4, 1e-4);
}

// Pass 2 & 3 (composite2, composite3): Separable 9-tap silky Gaussian blur
// Optionally layers cinematic horizontal anime anamorphic light streak on the H-pass!
vec3 bloomSeparableBlur(sampler2D srcTex, vec2 uv, vec2 stepDir, bool addAnamorphic) {
    const float w[5] = float[5](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);
    vec3 result = texture(srcTex, uv).rgb * w[0];

    for (int i = 1; i < 5; i++) {
        vec2 off = stepDir * (float(i) * 1.45);
        result += texture(srcTex, clamp(uv + off, vec2(0.001), vec2(0.999))).rgb * w[i];
        result += texture(srcTex, clamp(uv - off, vec2(0.001), vec2(0.999))).rgb * w[i];
    }

#ifdef ANAMORPHIC_STREAK
    if (addAnamorphic) {
        // Subtle dreamy horizontal anime starlight streak on super-bright peaks only
        vec3 streak = vec3(0.0);
        for (int s = 1; s <= 6; s++) {
            float fs = float(s);
            vec2 sOff = vec2(stepDir.x * fs * 4.5, 0.0);
            float sw = exp(-fs * 0.42);
            vec3 cP = texture(srcTex, clamp(uv + sOff, vec2(0.001), vec2(0.999))).rgb;
            vec3 cN = texture(srcTex, clamp(uv - sOff, vec2(0.001), vec2(0.999))).rgb;
            // Only super-bright emissives/sun/moon cast streaks
            streak += (max(cP - vec3(1.15), vec3(0.0)) + max(cN - vec3(1.15), vec3(0.0))) * sw;
        }
        // Slight prismatic azure-pearl anime tint on streaks
        result += streak * vec3(0.86, 0.96, 1.18) * 0.065;
    }
#endif

    return result;
}

// Pass 4 (composite4): Wide Kawase blur downsample (half -> quarter)
vec3 bloomWideDownsample(sampler2D srcTex, vec2 uv, vec2 halfTexel) {
    vec3 sum = texture(srcTex, uv).rgb * 0.25;
    sum += texture(srcTex, clamp(uv + halfTexel * vec2( 2.5,  2.5), vec2(0.001), vec2(0.999))).rgb * 0.125;
    sum += texture(srcTex, clamp(uv + halfTexel * vec2(-2.5,  2.5), vec2(0.001), vec2(0.999))).rgb * 0.125;
    sum += texture(srcTex, clamp(uv + halfTexel * vec2( 2.5, -2.5), vec2(0.001), vec2(0.999))).rgb * 0.125;
    sum += texture(srcTex, clamp(uv + halfTexel * vec2(-2.5, -2.5), vec2(0.001), vec2(0.999))).rgb * 0.125;
    sum += texture(srcTex, clamp(uv + halfTexel * vec2( 4.5,  0.0), vec2(0.001), vec2(0.999))).rgb * 0.0625;
    sum += texture(srcTex, clamp(uv + halfTexel * vec2(-4.5,  0.0), vec2(0.001), vec2(0.999))).rgb * 0.0625;
    sum += texture(srcTex, clamp(uv + halfTexel * vec2( 0.0,  4.5), vec2(0.001), vec2(0.999))).rgb * 0.0625;
    sum += texture(srcTex, clamp(uv + halfTexel * vec2( 0.0, -4.5), vec2(0.001), vec2(0.999))).rgb * 0.0625;
    return sum;
}

// Pass 5 (composite5): Wide 9-tap tent upsample + combine tight & wide bloom halos
vec3 bloomCombineMultiScale(sampler2D tightTex, sampler2D wideTex, vec2 uv, vec2 quarterTexel) {
    vec3 tight = texture(tightTex, uv).rgb;

    // 9-tap tent filter on quarter-res wide halo for ultra-smooth atmospheric diffusion
    vec3 wide = texture(wideTex, uv).rgb * 4.0;
    wide += texture(wideTex, clamp(uv + quarterTexel * vec2( 1.5,  0.0), vec2(0.001), vec2(0.999))).rgb * 2.0;
    wide += texture(wideTex, clamp(uv + quarterTexel * vec2(-1.5,  0.0), vec2(0.001), vec2(0.999))).rgb * 2.0;
    wide += texture(wideTex, clamp(uv + quarterTexel * vec2( 0.0,  1.5), vec2(0.001), vec2(0.999))).rgb * 2.0;
    wide += texture(wideTex, clamp(uv + quarterTexel * vec2( 0.0, -1.5), vec2(0.001), vec2(0.999))).rgb * 2.0;
    wide += texture(wideTex, clamp(uv + quarterTexel * vec2( 1.5,  1.5), vec2(0.001), vec2(0.999))).rgb;
    wide += texture(wideTex, clamp(uv + quarterTexel * vec2(-1.5,  1.5), vec2(0.001), vec2(0.999))).rgb;
    wide += texture(wideTex, clamp(uv + quarterTexel * vec2( 1.5, -1.5), vec2(0.001), vec2(0.999))).rgb;
    wide += texture(wideTex, clamp(uv + quarterTexel * vec2(-1.5, -1.5), vec2(0.001), vec2(0.999))).rgb;
    wide *= (1.0 / 16.0);

    // Extra wide secondary mist ring
    vec3 ultraWide = vec3(0.0);
    ultraWide += texture(wideTex, clamp(uv + quarterTexel * vec2( 3.5,  2.0), vec2(0.001), vec2(0.999))).rgb;
    ultraWide += texture(wideTex, clamp(uv + quarterTexel * vec2(-3.5,  2.0), vec2(0.001), vec2(0.999))).rgb;
    ultraWide += texture(wideTex, clamp(uv + quarterTexel * vec2( 3.5, -2.0), vec2(0.001), vec2(0.999))).rgb;
    ultraWide += texture(wideTex, clamp(uv + quarterTexel * vec2(-3.5, -2.0), vec2(0.001), vec2(0.999))).rgb;
    ultraWide *= 0.25;

    return tight * 0.45 + wide * 0.38 + ultraWide * 0.22;
}

#endif
