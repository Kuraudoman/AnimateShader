#ifndef ANIMATE_WATER_WAVES_GLSL
#define ANIMATE_WATER_WAVES_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

// ==============================================================================
// Multi-Octave Analytical Fantasy Water Ripples + Rain Splash Rings
// Calibrated gentle anime wave slopes with distance attenuation so close-up
// water shimmers crisply while distant river/ocean reflections stay silky smooth.
// ==============================================================================

float waterWaveHeight(vec2 xz, float timeSec, float rainAmount) {
    float t = timeSec * 0.95;

    // 4 layered directional smooth swells (gentle, natural anime water amplitude)
    vec2 p1 = xz * 0.42 + vec2(t * 0.55, t * 0.26);
    vec2 p2 = rot2D(0.82) * xz * 0.78 + vec2(-t * 0.48, t * 0.38);
    vec2 p3 = rot2D(-0.58) * xz * 1.45 + vec2(t * 0.72, -t * 0.62);
    vec2 p4 = xz * 2.65 + vec2(-t * 0.95, -t * 0.82);

    float h = 0.0;
    h += (valueNoise2D(p1) * 2.0 - 1.0) * 0.042;
    h += (valueNoise2D(p2) * 2.0 - 1.0) * 0.024;
    h += (valueNoise2D(p3) * 2.0 - 1.0) * 0.011;
    h += (valueNoise2D(p4) * 2.0 - 1.0) * 0.005;

    // Animated concentric raindrop rings on water during rain
    if (rainAmount > 0.02) {
        vec2 grid = xz * 1.35;
        vec2 cell = floor(grid);
        vec2 f = fract(grid);
        float seed = hash12(cell);
        float phase = fract(timeSec * 0.80 + seed);
        vec2 center = hash22(cell + 17.3) * 0.6 + 0.2;
        float dist = length(f - center);
        float ring = sin((dist - phase * 0.65) * 30.0) * exp(-abs(dist - phase * 0.65) * 14.0) * (1.0 - phase);
        h += ring * 0.014 * rainAmount;
    }

    return h;
}

// Compute perturbed world-space water normal with distance anti-aliasing.
// Horizontal/top water uses multi-octave XZ swells; vertical waterfall faces use
// tangent-plane flowing ripples without artificially tilting toward the sky!
vec3 computeWaterWorldNormal(vec3 worldPos, vec3 baseWorldNormal, float viewDist, float timeSec, float rainAmount) {
    float upWeight = smoothstep(0.25, 0.85, abs(baseWorldNormal.y));
    float eps = 0.11;
    // Distance attenuation prevents sub-pixel aliasing and shattered reflections far away
    float distAtten = 1.0 / (1.0 + viewDist * 0.028);

    float hL = waterWaveHeight(worldPos.xz - vec2(eps, 0.0), timeSec, rainAmount);
    float hR = waterWaveHeight(worldPos.xz + vec2(eps, 0.0), timeSec, rainAmount);
    float hD = waterWaveHeight(worldPos.xz - vec2(0.0, eps), timeSec, rainAmount);
    float hU = waterWaveHeight(worldPos.xz + vec2(0.0, eps), timeSec, rainAmount);

    float slopeScale = 0.72 * distAtten;
    vec3 horizNormal = normalize(vec3((hL - hR) * slopeScale, 2.0 * eps, (hD - hU) * slopeScale));
    if (baseWorldNormal.y < 0.0) {
        horizNormal.y = -horizNormal.y;
    }

    if (upWeight >= 0.999) {
        return horizNormal;
    }

    // Vertical / falling water faces: subtle flowing ripples strictly in the vertical tangent plane
    vec3 tangentH = safeNormalize(vec3(-baseWorldNormal.z, 0.0, baseWorldNormal.x));
    vec3 tangentV = vec3(0.0, 1.0, 0.0);
    vec2 flowUV = vec2(dot(worldPos, tangentH) * 1.15, worldPos.y * 0.85 + timeSec * 2.4);
    float fL = valueNoise2D(flowUV - vec2(eps, 0.0)) + 0.45 * valueNoise2D(flowUV * 2.1 - vec2(eps, 0.0));
    float fR = valueNoise2D(flowUV + vec2(eps, 0.0)) + 0.45 * valueNoise2D(flowUV * 2.1 + vec2(eps, 0.0));
    float fD = valueNoise2D(flowUV - vec2(0.0, eps)) + 0.45 * valueNoise2D(flowUV * 2.1 - vec2(0.0, eps));
    float fU = valueNoise2D(flowUV + vec2(0.0, eps)) + 0.45 * valueNoise2D(flowUV * 2.1 + vec2(0.0, eps));
    float vScale = 0.08 * distAtten;
    vec3 vertNormal = safeNormalize(baseWorldNormal + tangentH * ((fL - fR) * vScale) + tangentV * ((fD - fU) * vScale));

    return safeNormalize(mix(vertNormal, horizNormal, upWeight));
}

#endif
