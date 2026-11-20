#ifndef ANIMATE_WAVING_GLSL
#define ANIMATE_WAVING_GLSL

#include "/lib/settings.glsl"

// ==============================================================================
// Wind-Driven Waving Foliage & Subtle Water Wave Displacement
// Shared between gbuffers_terrain.vsh, gbuffers_water.vsh, and shadow.vsh
// so foliage shadows sway smoothly in sync with the leaves!
// ==============================================================================

vec3 computeFoliageWaveOffset(vec3 worldPos, int blockId, vec2 texCoord, vec2 midTexCoord, float timeSec, float rainAmount) {
#ifdef WAVING_FOLIAGE
    float windSpeed = mix(1.55, 3.15, rainAmount);
    float windAmp   = mix(1.0, 1.85, rainAmount);
    float t = timeSec * windSpeed;

    // Ground plants (short grass, tall grass, flowers, crops, saplings)
    if (blockId == 10010) {
        // Only sway upper vertices so roots stay anchored to the ground
        float topMask = (texCoord.y < midTexCoord.y) ? 1.0 : 0.0;
        float gust = sin(t * 0.7 + worldPos.x * 0.35 + worldPos.z * 0.28) * 0.5 + 0.5;
        float wX = sin(t * 1.4 + worldPos.x * 0.9 + worldPos.z * 0.6) * (0.055 + 0.035 * gust);
        float wZ = cos(t * 1.15 + worldPos.z * 0.85 - worldPos.x * 0.5) * (0.045 + 0.025 * gust);
        return vec3(wX, 0.0, wZ) * topMask * windAmp;
    }

    // Tree leaves & cherry blossom canopies
    if (blockId == 10011) {
        float phase = worldPos.x * 0.55 + worldPos.y * 0.45 + worldPos.z * 0.52;
        float wX = sin(t * 1.10 + phase) * 0.042 + sin(t * 2.25 + phase * 1.7) * 0.014;
        float wY = sin(t * 0.95 + phase * 1.3) * 0.022;
        float wZ = cos(t * 1.05 + phase * 0.9) * 0.038;
        return vec3(wX, wY, wZ) * windAmp;
    }

    // Hanging vines, glowing cave vines, kelp, seagrass
    if (blockId == 10012) {
        float phase = worldPos.x * 0.7 + worldPos.y * 0.9 + worldPos.z * 0.65;
        float wX = sin(t * 1.30 + phase) * 0.052;
        float wZ = cos(t * 1.10 + phase * 1.2) * 0.048;
        return vec3(wX, 0.0, wZ) * windAmp;
    }

    // Lily pads gently bobbing on water
    if (blockId == 10013) {
        float bob = sin(timeSec * 2.1 + worldPos.x * 1.2 + worldPos.z * 1.1) * 0.018;
        return vec3(0.0, bob, 0.0);
    }
#endif
    return vec3(0.0);
}

// Gentle vertical ripple on water surfaces (kept subtle so shallow 1-block beds never clip)
float computeWaterVertexWave(vec3 worldPos, float timeSec) {
    float w1 = sin(worldPos.x * 1.05 + worldPos.z * 0.70 + timeSec * 1.55) * 0.014;
    float w2 = cos(worldPos.x * 0.80 - worldPos.z * 1.25 + timeSec * 1.25) * 0.010;
    return w1 + w2;
}

#endif
