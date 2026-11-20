#ifndef ANIMATE_FOG_GLSL
#define ANIMATE_FOG_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"

// ==============================================================================
// Aerial Perspective Pastel Mist, Underwater Aqua Fog, & Status Fog
// Crisp foreground clarity with dreamy pastel depth separation at long range.
// ==============================================================================

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
        float clarityScale = 0.022 / max(WATER_CLARITY, 0.4);
        float uwFog = 1.0 - exp(-viewDist * clarityScale);
        vec3 uwDay   = vec3(0.04, 0.34, 0.54);
        vec3 uwNight = vec3(0.025, 0.11, 0.24) * max(NIGHT_BRIGHTNESS, 1.0);
        vec3 uwCol   = mix(uwNight, uwDay, st.dayFactor);
        uwCol += vec3(0.06, 0.24, 0.32) * smoothstep(-0.1, 0.8, worldDir.y) * (0.4 + 0.6 * st.dayFactor);
        return mix(color, uwCol, clamp(uwFog, 0.0, 0.88));
    } else if (eyeInWater == 2) {
        float lavaFog = 1.0 - exp(-viewDist * 0.45);
        return mix(color, vec3(0.95, 0.24, 0.06), clamp(lavaFog, 0.0, 0.96));
    } else if (eyeInWater == 3) {
        float snowFog = 1.0 - exp(-viewDist * 0.35);
        return mix(color, vec3(0.58, 0.72, 0.88), clamp(snowFog, 0.0, 0.95));
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

#endif
