#ifndef ANIMATE_WATER_WAVES_GLSL
#define ANIMATE_WATER_WAVES_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

// ==============================================================================
// Multi-Octave Analytical Fantasy Water Ripples + Rain Splash Rings
// Produces silky, crystalline anime wave normals with sparkling crests.
// ==============================================================================

float waterWaveHeight(vec2 xz, float timeSec, float rainAmount) {
    float t = timeSec * 1.15;

    // 4 layered directional Gerstner-like wave swells for organic non-repeating motion
    vec2 p1 = xz * 0.62 + vec2(t * 0.72, t * 0.34);
    vec2 p2 = rot2D(0.78) * xz * 1.05 + vec2(-t * 0.64, t * 0.52);
    vec2 p3 = rot2D(-0.55) * xz * 1.95 + vec2(t * 0.95, -t * 0.80);
    vec2 p4 = xz * 3.40 + vec2(-t * 1.35, -t * 1.10);

    float h = 0.0;
    h += (valueNoise2D(p1) * 2.0 - 1.0) * 0.095;
    h += (valueNoise2D(p2) * 2.0 - 1.0) * 0.055;
    h += (valueNoise2D(p3) * 2.0 - 1.0) * 0.026;
    h += (valueNoise2D(p4) * 2.0 - 1.0) * 0.012;

    // Animated raindrop concentric ripple rings on water when raining
    if (rainAmount > 0.02) {
        vec2 grid = xz * 1.45;
        vec2 cell = floor(grid);
        vec2 f = fract(grid);
        float seed = hash12(cell);
        float phase = fract(timeSec * 0.85 + seed);
        vec2 center = hash22(cell + 17.3) * 0.6 + 0.2;
        float dist = length(f - center);
        float ring = sin((dist - phase * 0.65) * 34.0) * exp(-abs(dist - phase * 0.65) * 14.0) * (1.0 - phase);
        h += ring * 0.032 * rainAmount;
    }

    return h;
}

// Compute perturbed world-space water normal using central finite differences
vec3 computeWaterWorldNormal(vec3 worldPos, vec3 baseWorldNormal, float timeSec, float rainAmount) {
    // Only apply horizontal ripples strongly on top/flat water surfaces, softer on waterfalls
    float upWeight = smoothstep(0.15, 0.85, abs(baseWorldNormal.y));
    float eps = 0.065;

    float hL = waterWaveHeight(worldPos.xz - vec2(eps, 0.0), timeSec, rainAmount);
    float hR = waterWaveHeight(worldPos.xz + vec2(eps, 0.0), timeSec, rainAmount);
    float hD = waterWaveHeight(worldPos.xz - vec2(0.0, eps), timeSec, rainAmount);
    float hU = waterWaveHeight(worldPos.xz + vec2(0.0, eps), timeSec, rainAmount);

    float slopeScale = mix(0.35, 1.0, upWeight);
    vec3 rippleNormal = normalize(vec3((hL - hR) * slopeScale, 2.0 * eps, (hD - hU) * slopeScale));

    // Blend smoothly with geometric normal for waterfalls/sloped water
    if (baseWorldNormal.y < 0.0) {
        rippleNormal.y = -rippleNormal.y;
    }
    return safeNormalize(mix(baseWorldNormal, rippleNormal, 0.35 + 0.65 * upWeight));
}

#endif
