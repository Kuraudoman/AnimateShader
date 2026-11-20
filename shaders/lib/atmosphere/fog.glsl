#ifndef ANIMATE_FOG_GLSL
#define ANIMATE_FOG_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"

// ==============================================================================
// Aerial Perspective Pastel Mist, Underwater Aqua Fog, & Status Fog
// Crisp foreground clarity with dreamy pastel depth separation at long range.
// ==============================================================================

vec3 computeUnderwaterFogColor(vec3 worldDir, AnimeLightingState st) {
    vec3 uwDay   = vec3(0.032, 0.066, 0.165);
    vec3 uwNight = vec3(0.015, 0.036, 0.095) * max(NIGHT_BRIGHTNESS, 1.0);
    vec3 uwCol   = mix(uwNight, uwDay, st.dayFactor);

    // Gentle upward skylight gradient through water (serene deep cobalt-cerulean, never blinding cyan)
    float upGrad = smoothstep(-0.15, 0.85, worldDir.y);
    uwCol += vec3(0.028, 0.052, 0.115) * upGrad * (0.25 + 0.75 * st.dayFactor) * (1.0 - st.rainMix * 0.40);

    // Subtle twilight indigo-violet warmth at sunset & calm muted slate in rain
    uwCol = mix(uwCol, uwCol * vec3(1.18, 0.90, 1.02), st.sunsetFactor * 0.30);
    uwCol = mix(uwCol, uwCol * vec3(0.82, 0.88, 0.86), st.rainMix * 0.35);
    return uwCol;
}

// Spectral attenuation of sunlight/moonlight filtered through water (red absorbed fastest, blue preserved)
vec3 computeUnderwaterLightFilter(AnimeLightingState st) {
    return mix(vec3(0.56, 0.68, 0.96), vec3(0.36, 0.48, 0.76), st.dayFactor);
}

vec3 applyStatusFog(vec3 color, float viewDist, float blindnessVal, float darknessVal) {
    if (blindnessVal > 0.001) {
        float blindAmt = clamp(smoothstep(2.0, 12.0, viewDist) * blindnessVal, 0.0, 0.96);
        color = mix(color, vec3(0.01, 0.01, 0.02), blindAmt);
    }
    if (darknessVal > 0.001) {
        float darkAmt = clamp(smoothstep(4.0, 22.0, viewDist) * darknessVal * 0.85, 0.0, 0.90);
        color = mix(color, vec3(0.015, 0.02, 0.035), darkAmt);
    }
    return color;
}

vec3 applyAnimeFog(
    vec3 color,
    vec3 worldPosRel,
    vec3 worldDir,
    float viewDist,
    float renderFar,
    AnimeLightingState st,
    int eyeInWater,
    float blindnessVal,
    float darknessVal
) {
    if (eyeInWater == 1) {
        float clarityInv = 1.0 / max(WATER_CLARITY, 0.4);
        // Physical Beer-Lambert spectral absorption along the water travel path + smooth scatter veil
        vec3 uwAbsorb = exp(-viewDist * clarityInv * vec3(0.036, 0.020, 0.010));
        float uwFog   = clamp(1.0 - exp(-viewDist * 0.024 * clarityInv), 0.0, 0.94);
        vec3 uwCol    = computeUnderwaterFogColor(worldDir, st);
        color = color * uwAbsorb * (1.0 - uwFog) + uwCol * uwFog;
        return applyStatusFog(color, viewDist, blindnessVal, darknessVal);
    } else if (eyeInWater == 2) {
        float lavaFog = 1.0 - exp(-viewDist * 0.45);
        color = mix(color, vec3(0.95, 0.24, 0.06), clamp(lavaFog, 0.0, 0.96));
        return applyStatusFog(color, viewDist, blindnessVal, darknessVal);
    } else if (eyeInWater == 3) {
        float snowFog = 1.0 - exp(-viewDist * 0.35);
        color = mix(color, vec3(0.58, 0.72, 0.88), clamp(snowFog, 0.0, 0.95));
        return applyStatusFog(color, viewDist, blindnessVal, darknessVal);
    }

    float fogMult = ATMOSPHERIC_FOG;
    if (fogMult > 0.001) {
#if defined(DIMENSION_NETHER)
        float distNorm = clamp(viewDist / max(renderFar * 0.95, 48.0), 0.0, 1.0);
        float fogAmt = smoothstep(0.12, 1.0, distNorm) * 0.65 * fogMult;
        vec3 netherFog = mix(st.fogColorAnime, st.skyHorizon, 0.35);
        color = mix(color, netherFog, clamp(fogAmt, 0.0, 0.82));

#elif defined(DIMENSION_END)
        float distNorm = clamp(viewDist / max(renderFar * 1.08, 64.0), 0.0, 1.0);
        float fogAmt = pow(distNorm, 1.85) * 0.55 * fogMult;
        color = mix(color, st.fogColorAnime, clamp(fogAmt, 0.0, 0.75));

#else
        float farDist = max(renderFar, 64.0);
        float distNorm = clamp(viewDist / farDist, 0.0, 1.0);

        float heightFade = exp(-max(worldPosRel.y, 0.0) * 0.022);
        float aerial = (1.0 - exp(-max(viewDist - 12.0, 0.0) * (0.0022 + 0.0038 * st.rainMix))) * (0.50 + 0.50 * heightFade);
        float borderFog = smoothstep(0.68, 1.0, distNorm);
        float fogFactor = clamp(max(aerial * 0.48 * fogMult, borderFog * 0.92), 0.0, 0.94);

        float sunAlign = pow(max(dot(worldDir, st.activeLightDir), 0.0), 4.5);
        vec3 fogCol = st.fogColorAnime;
        fogCol += st.skyGlowColor * sunAlign * (0.16 + 0.32 * st.sunsetFactor) * (1.0 - st.rainMix * 0.75);

        color = mix(color, fogCol, fogFactor);
#endif
    }

    return applyStatusFog(color, viewDist, blindnessVal, darknessVal);
}

#endif

