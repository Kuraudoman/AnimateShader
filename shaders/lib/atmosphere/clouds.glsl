#ifndef ANIMATE_CLOUDS_GLSL
#define ANIMATE_CLOUDS_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"

// ==============================================================================
// Makoto Shinkai Painterly Layered Volumetric Anime Clouds
// Sculpted puffy cumulus islands floating cleanly across open electric skies,
// with bright creamy sunlit crowns, pastel cerulean/violet undersides, silver
// rim backlighting, and delicate high-altitude cirrus wisps!
// ==============================================================================

float sampleCumulusDensity(vec2 xz, float heightNorm, float timeSec, float rainAmount) {
    vec2 wind = vec2(timeSec * 2.2, timeSec * 0.85);
    vec2 p = (xz + wind) * 0.0022;

    float base = fbm2D(p);
    float detail = fbm2D(p * 2.7 - vec2(timeSec * 0.015, -timeSec * 0.01));

    // Crisp sculpted Makoto Shinkai cumulus towers floating over open sky
    float coverage = mix(0.56, 0.34, rainAmount);
    float shape = smoothstep(coverage, coverage + 0.19, base * 0.76 + detail * 0.28);

    float bottomFlat = smoothstep(0.0, 0.16, heightNorm);
    float topBillow  = smoothstep(1.0, 0.25 + 0.38 * detail, heightNorm);
    return shape * bottomFlat * topBillow;
}

vec4 renderAnimeClouds(
    vec3 worldDir,
    vec3 camPos,
    AnimeLightingState st,
    float timeSec,
    float dither
) {
#if defined(DIMENSION_NETHER) || defined(DIMENSION_END)
    return vec4(0.0);
#endif

#ifndef ANIME_CLOUDS
    return vec4(0.0);
#else
    if (worldDir.y <= 0.02) return vec4(0.0);

    const float CLOUD_BOTTOM = 195.0;
    const float CLOUD_TOP    = 275.0;
    const float CIRRUS_ALT   = 390.0;

    float invY = 1.0 / max(worldDir.y, 0.04);
    float tStart = max((CLOUD_BOTTOM - camPos.y) * invY, 0.0);
    float tEnd   = max((CLOUD_TOP    - camPos.y) * invY, 0.0);

    if (tEnd <= tStart && camPos.y < CLOUD_TOP) return vec4(0.0);
    if (camPos.y >= CLOUD_TOP) {
        tStart = 0.0;
        tEnd = 0.0;
    }

    tStart = min(tStart, 3400.0);
    tEnd   = min(tEnd,   4200.0);

    #if CLOUD_QUALITY == 0
        const int STEPS = 6;
    #elif CLOUD_QUALITY == 1
        const int STEPS = 10;
    #else
        const int STEPS = 16;
    #endif

    float lightCos = dot(worldDir, st.activeLightDir);
    float hgPhase  = 0.24 + 0.76 * pow(max(lightCos, 0.0), 5.0);
    float silverLining = pow(max(lightCos, 0.0), 16.0) * 1.15;

    // Make clouds slightly lighter & airier at night so stars & aurora shine through cleanly!
    float nightThin = mix(0.62, 1.0, st.dayFactor);

    vec3 cloudColorAcc = vec3(0.0);
    float transmittance = 1.0;

    if (tEnd > tStart) {
        float dt = (tEnd - tStart) / float(STEPS);
        float t = tStart + dt * dither;

        for (int i = 0; i < STEPS; i++) {
            if (transmittance < 0.02) break;

            vec3 pos = camPos + worldDir * t;
            float hNorm = clamp((pos.y - CLOUD_BOTTOM) / (CLOUD_TOP - CLOUD_BOTTOM), 0.0, 1.0);
            float dens = sampleCumulusDensity(pos.xz, hNorm, timeSec, st.rainMix) * nightThin;

            if (dens > 0.005) {
                vec3 sunSamplePos = pos + st.activeLightDir * 28.0;
                float sunHNorm = clamp((sunSamplePos.y - CLOUD_BOTTOM) / (CLOUD_TOP - CLOUD_BOTTOM), 0.0, 1.0);
                float densSun = sampleCumulusDensity(sunSamplePos.xz, sunHNorm, timeSec, st.rainMix);

                float directLight = exp(-densSun * 2.35) * (0.38 + 0.62 * hNorm);
                float celCloud = smoothstep(0.14, 0.72, directLight);

                vec3 cLit  = st.cloudLitColor * (0.82 + 0.42 * hgPhase);
                vec3 cShad = st.cloudShadowColor;
                vec3 sampleCol = mix(cShad, cLit, celCloud);

                float edgeThinness = (1.0 - smoothstep(0.12, 0.60, dens)) * (0.45 + 0.55 * hNorm);
                sampleCol += st.skyGlowColor * silverLining * edgeThinness * (1.0 - st.rainMix * 0.72) * 0.65;

                float stepAlpha = 1.0 - exp(-dens * 1.85 * (dt / 55.0));
                cloudColorAcc += sampleCol * stepAlpha * transmittance;
                transmittance *= (1.0 - stepAlpha);
            }

            t += dt;
        }
    }

    // Delicate high-altitude anime cirrus wisps
    float tCirrus = (CIRRUS_ALT - camPos.y) * invY;
    if (tCirrus > 0.0 && tCirrus < 6800.0) {
        vec2 cPos = (camPos.xz + worldDir.xz * tCirrus + vec2(timeSec * 3.8, -timeSec * 1.1)) * 0.00095;
        vec2 warp = vec2(fbm2D(cPos * 1.8), fbm2D(cPos * 1.8 + vec2(5.2, 1.3)));
        float cirrus = fbm2D(cPos * vec2(1.4, 3.2) + warp * 0.85);
        float cirrusAlpha = smoothstep(0.62, 0.88, cirrus) * 0.28 * nightThin * (1.0 - st.rainMix * 0.6);

        vec3 cirrusCol = mix(st.cloudShadowColor * 1.15, st.cloudLitColor * 1.12, 0.62 + 0.38 * hgPhase);
        cloudColorAcc += cirrusCol * cirrusAlpha * transmittance;
        transmittance *= (1.0 - cirrusAlpha);
    }

    float totalAlpha = clamp(1.0 - transmittance, 0.0, 1.0);
    float horizonFade = smoothstep(0.02, 0.16, worldDir.y);
    cloudColorAcc *= horizonFade;
    totalAlpha *= horizonFade;

    return vec4(cloudColorAcc, totalAlpha);
#endif
}

#endif
