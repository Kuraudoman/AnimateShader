#ifndef ANIMATE_CAUSTICS_GLSL
#define ANIMATE_CAUSTICS_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

// ==============================================================================
// Animated Crystalline Underwater Caustics
// Dual-layer organic water-web refraction bands projected along light direction
// ==============================================================================

float causticLayer(vec2 p, float t) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float minDist = 1.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 pt = hash22(i + neighbor);
            pt = 0.5 + 0.42 * sin(t + TAU * pt);
            float d = length(neighbor + pt - f);
            minDist = min(minDist, d);
        }
    }
    // Crisp luminous cell ridges
    return pow(clamp(minDist, 0.0, 1.0), 3.2);
}

float computeUnderwaterCaustics(vec3 worldPos, vec3 lightDir, float timeSec) {
#ifdef WATER_CAUSTICS
    // Project world coordinate along the incoming light ray onto horizontal wave plane
    vec2 proj = worldPos.xz - lightDir.xz * (worldPos.y / max(abs(lightDir.y), 0.35));
    float c1 = causticLayer(proj * 0.58 + vec2(timeSec * 0.14, timeSec * 0.09), timeSec * 1.45);
    float c2 = causticLayer(proj * 0.86 - vec2(timeSec * 0.11, -timeSec * 0.15), timeSec * 1.15 + 2.1);
    return clamp((c1 + c2) * 1.55, 0.0, 1.6);
#else
    return 0.0;
#endif
}

#endif
