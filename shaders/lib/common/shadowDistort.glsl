#ifndef ANIMATE_SHADOW_DISTORT_GLSL
#define ANIMATE_SHADOW_DISTORT_GLSL

// ==============================================================================
// Non-Linear Shadow Map Distortion
// Concentrates high shadow-map texel density near the player while keeping
// wide coverage out to shadowDistance without wasting VRAM.
// ==============================================================================

const float SHADOW_DISTORT_BIAS = 0.85;

float getShadowDistortFactor(vec2 shadowClipXY) {
    float radial = length(shadowClipXY);
    return mix(1.0, radial, SHADOW_DISTORT_BIAS) + (1.0 - SHADOW_DISTORT_BIAS);
}

vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float factor = getShadowDistortFactor(shadowClipPos.xy);
    vec3 distorted;
    distorted.xy = shadowClipPos.xy / factor;
    // Compress Z to extend vertical shadow frustum when sun/moon is low on the horizon
    distorted.z = shadowClipPos.z * 0.45;
    return distorted;
}

#endif
