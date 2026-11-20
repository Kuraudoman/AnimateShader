#ifndef ANIMATE_TONEMAP_GLSL
#define ANIMATE_TONEMAP_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

// ==============================================================================
// Adaptive Brightness Balance + Anime Luminance-Preserving Filmic Tone Mapping
// Calibrated in linear light so shadows stay deep & colorful (never milky),
// midtones stay rich & vivid, highlights roll off smoothly without chalky
// desaturation, and nights remain bright, clear, and jewel-toned!
// ==============================================================================

// Calibrated anime filmic tone curve (linear 0.18 -> ~0.18, silky HDR highlight shoulder)
float animeFilmicScalar(float x) {
    float v = max(x, 0.0) * 0.72;
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((v * (a * v + b)) / max(v * (c * v + d) + e, 1e-4), 0.0, 1.0);
}

// Hue- & Chroma-Preserving Anime Tone Mapper
vec3 animeToneMap(vec3 hdrColor) {
    hdrColor = max(hdrColor, vec3(0.0));

    // Per-channel filmic for clean white highlight core rolloff (sun disc, lava core)
    vec3 perChannel = vec3(
        animeFilmicScalar(hdrColor.r),
        animeFilmicScalar(hdrColor.g),
        animeFilmicScalar(hdrColor.b)
    );

    // Luminance-preserving ratio keeps saturated anime blues, sakura pinks, cyans & golds pure!
    float lIn = max(luma(hdrColor), 1e-5);
    float lOut = animeFilmicScalar(lIn);
    vec3 lumaPreserved = hdrColor * (lOut / lIn);

    // Keep vibrant color purity through midtones & glowing highlights; roll only extreme cores to pearl-white
    float peak = max(hdrColor.r, max(hdrColor.g, hdrColor.b));
    float whiteRoll = smoothstep(1.8, 6.5, peak);
    vec3 mapped = mix(lumaPreserved, perChannel, 0.28 + 0.62 * whiteRoll);
    return clamp(mapped, vec3(0.0), vec3(1.0));
}

// Balanced exposure harmonizing bright daytime sun, golden twilight, starry night & caves
float computeBalancedExposure(ivec2 eyeBrightSmooth, float dayFactor, float rainMix) {
    float eyeSky   = clamp(float(eyeBrightSmooth.y) / 240.0, 0.0, 1.0);
    float eyeBlock = clamp(float(eyeBrightSmooth.x) / 240.0, 0.0, 1.0);
    float envLight = max(eyeSky * mix(0.35, 1.0, dayFactor), eyeBlock * 0.78);

    // Gentle comfort balance: avoids noon blowout while keeping nights & caves crisp and readable
    float autoBalance = mix(1.12, 0.94, smoothstep(0.15, 0.95, envLight));
    autoBalance *= mix(1.0, 1.06, rainMix * dayFactor);

#if defined(DIMENSION_NETHER)
    autoBalance = 1.02;
#elif defined(DIMENSION_END)
    autoBalance = 1.04;
#endif

    return autoBalance * OVERALL_EXPOSURE;
}

// Painterly Anime Color Grading, Split-Toning, Soft Vignette & Dithering
vec3 applyAnimeColorGrading(
    vec3 hdrScene,
    vec3 bloomColor,
    vec2 uv,
    float dither,
    ivec2 eyeBrightSmooth,
    float dayFactor,
    float sunsetFactor,
    float rainMix
) {
    // Combine HDR scene with dreamy multi-scale bloom
    vec3 color = hdrScene;
#ifdef BLOOM_ENABLED
    float bloomScale = 0.28 * BLOOM_INTENSITY;
    color += bloomColor * bloomScale;
#endif

    // Apply balanced exposure
    float exposure = computeBalancedExposure(eyeBrightSmooth, dayFactor, rainMix);
    color *= exposure;

    // Anime Luminance-Preserving Filmic Tone Mapping
    color = animeToneMap(color);

    // Selective Anime Vibrance (rich, vivid, crystal-clear color expression)
    color = adjustVibrance(color, COLOR_VIBRANCE);

    // Subtle Painterly Split-Toning:
    //   Shadows -> cool cerulean/lavender clarity
    //   Highlights -> warm golden-ivory / rose-peach radiance
    float l = luma(color);
    float shadowMask = pow(1.0 - smoothstep(0.0, 0.38, l), 1.5);
    float highMask   = smoothstep(0.45, 0.95, l);

    vec3 shadowSplit = mix(vec3(0.94, 0.98, 1.10), vec3(1.04, 0.93, 1.10), sunsetFactor);
    vec3 highSplit   = mix(vec3(1.04, 1.01, 0.96), vec3(1.10, 0.96, 0.93), sunsetFactor);
    color *= mix(vec3(1.0), shadowSplit, shadowMask * 0.34 * clamp(SHADOW_COLOR_TINT, 0.0, 1.5));
    color *= mix(vec3(1.0), highSplit, highMask * 0.26);

    // Balanced Contrast Curve
    float contrast = TONEMAP_CONTRAST;
    if (abs(contrast - 1.0) > 0.001) {
        vec3 sCurve = color * color * (3.0 - 2.0 * color);
        color = mix(color, sCurve, clamp((contrast - 1.0) * 1.5, -0.35, 0.45));
    }

    // Optional soft atmospheric vignette (subtle indigo framing)
    if (VIGNETTE_STRENGTH > 0.001) {
        vec2 centered = (uv - 0.5) * 1.4142;
        float vig = smoothstep(0.45, 1.32, length(centered));
        color = mix(color, color * vec3(0.62, 0.68, 0.85), vig * VIGNETTE_STRENGTH * 0.48);
    }

    // Linear -> sRGB output conversion
    color = linearToSrgb(clamp(color, vec3(0.0), vec3(1.0)));

    // Ordered IGN dithering eliminates 8-bit sky banding
    color += (dither - 0.5) / 255.0;

    return clamp(color, vec3(0.0), vec3(1.0));
}

#endif
