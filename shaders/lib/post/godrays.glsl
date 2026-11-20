#ifndef ANIMATE_GODRAYS_GLSL
#define ANIMATE_GODRAYS_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"

// ==============================================================================
// Volumetric Crepuscular Godrays (Sunbeams & Moonbeams) + Anime Halo Lens Flare
// Uses IGN-jittered radial occlusion marching against opaque depth (depthtex1).
// ==============================================================================

vec3 computeAnimeGodrays(
    vec2 uv,
    vec3 lightViewPos,
    AnimeLightingState st,
    float dither,
    sampler2D depthOpaqueTex,
    sampler2D auxMaskTex,
    mat4 proj,
    float aspectRatioVal,
    int eyeInWater
) {
#if defined(DIMENSION_NETHER)
    return vec3(0.0);
#endif

#ifndef GODRAYS_ENABLED
    return vec3(0.0);
#else
    // Only project godrays when light source is in front of the camera (view space -Z is forward)
    if (lightViewPos.z >= -0.05) return vec3(0.0);

    vec3 lightScr = viewToScreen(lightViewPos, proj);
    vec2 lightUV = lightScr.xy;

    // Fade gracefully if sun/moon is far off-screen
    float offscreenDist = length(max(abs(lightUV - 0.5) - vec2(0.55), vec2(0.0)));
    float screenMask = 1.0 - smoothstep(0.0, 0.75, offscreenDist);
    if (screenMask <= 0.001) return vec3(0.0);

    // Fade when light body is below horizon or hidden by heavy rain
    float elevVis = smoothstep(-0.06, 0.08, st.activeLightDir.y);
    float weatherVis = 1.0 - st.rainMix * 0.78;
    float baseVis = screenMask * elevVis * weatherVis;
    if (baseVis <= 0.001) return vec3(0.0);

    const int NUM_SAMPLES = 28;
    const float DENSITY = 0.92;
    const float DECAY = 0.945;

    vec2 deltaUV = (uv - lightUV) * (DENSITY / float(NUM_SAMPLES));
    vec2 sampleUV = uv - deltaUV * dither;

    float accum = 0.0;
    float illumDecay = 1.0;

    for (int i = 0; i < NUM_SAMPLES; i++) {
        sampleUV -= deltaUV;
        if (sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0) {
            break;
        }
        float d = texture(depthOpaqueTex, sampleUV).r;
        // Sky pixels (d >= 0.9995) transmit shafts of light past terrain/leaves!
        float skyMask = step(0.9995, d);
        if (eyeInWater == 1 && skyMask > 0.5) {
            // Solid underwater ice blocks direct sun shafts so sunlight does not X-ray through ice
            float iceOcc = texture(auxMaskTex, sampleUV).z;
            skyMask *= (1.0 - smoothstep(0.25, 0.75, iceOcc));
        }
        accum += skyMask * illumDecay;
        illumDecay *= DECAY;
    }

    accum /= float(NUM_SAMPLES);

    // Radial falloff around light source so shafts feel focused and painterly
    vec2 aspectCorr = vec2(aspectRatioVal, 1.0);
    float radialDist = length((uv - lightUV) * aspectCorr);
    float radialAtten = exp(-radialDist * 1.45) * 0.85 + exp(-radialDist * 0.55) * 0.35;

    // Filter underwater light shafts into soft cool cerulean-blue sunbeams (never blinding yellow glare)
    vec3 rayColor = st.godrayColor;
    float mediumScale = 1.0;
    if (eyeInWater == 1) {
        float rayLuma = luma(st.godrayColor);
        vec3 uwRayCol = mix(vec3(0.24, 0.44, 0.95), vec3(0.36, 0.58, 1.06), st.dayFactor);
        rayColor = mix(st.godrayColor * vec3(0.28, 0.50, 0.96), uwRayCol * max(rayLuma, 0.35), 0.58);
        mediumScale = 0.62;
    } else if (eyeInWater >= 2) {
        return vec3(0.0);
    }
    float timeStrength = mix(0.42, 0.72 + 0.55 * st.sunsetFactor, st.dayFactor);

    vec3 rays = rayColor * accum * radialAtten * baseVis * timeStrength * GODRAYS_STRENGTH * mediumScale * 0.72;

    // --- Delicate Anime Sun / Moon Halo Lens Flare & Pastel Bokeh Rings ---
#ifdef SUN_LENS_FLARE
    if (eyeInWater == 0 && lightUV.x >= -0.15 && lightUV.x <= 1.15 && lightUV.y >= -0.15 && lightUV.y <= 1.15) {
        // Check direct occlusion of celestial center with a small 5-tap cross
        vec2 cUV = clamp(lightUV, vec2(0.005), vec2(0.995));
        float centerOpen = 0.0;
        centerOpen += step(0.9995, texture(depthOpaqueTex, cUV).r);
        centerOpen += step(0.9995, texture(depthOpaqueTex, clamp(cUV + vec2(0.012, 0.0), vec2(0.0), vec2(1.0))).r);
        centerOpen += step(0.9995, texture(depthOpaqueTex, clamp(cUV - vec2(0.012, 0.0), vec2(0.0), vec2(1.0))).r);
        centerOpen += step(0.9995, texture(depthOpaqueTex, clamp(cUV + vec2(0.0, 0.015), vec2(0.0), vec2(1.0))).r);
        centerOpen += step(0.9995, texture(depthOpaqueTex, clamp(cUV - vec2(0.0, 0.015), vec2(0.0), vec2(1.0))).r);
        centerOpen *= 0.2;

        if (centerOpen > 0.02) {
            vec2 ghostAxis = (vec2(0.5) - lightUV);
            vec3 flare = vec3(0.0);

            // Soft pastel rainbow halo ring around light source
            float haloR = abs(radialDist - 0.19);
            vec3 rainbowRing = vec3(
                exp(-pow((radialDist - 0.184) / 0.020, 2.0)),
                exp(-pow((radialDist - 0.192) / 0.022, 2.0)),
                exp(-pow((radialDist - 0.200) / 0.024, 2.0))
            );
            flare += rainbowRing * 0.075 * st.godrayColor;

            // 3 delicate anime lens bokeh discs opposite the sun/moon
            vec2 g1Pos = lightUV + ghostAxis * 0.72;
            float g1 = smoothstep(0.065, 0.042, length((uv - g1Pos) * aspectCorr));
            flare += vec3(0.75, 1.05, 1.35) * g1 * 0.055;

            vec2 g2Pos = lightUV + ghostAxis * 1.28;
            float g2 = smoothstep(0.042, 0.020, length((uv - g2Pos) * aspectCorr));
            flare += vec3(1.30, 0.85, 1.15) * g2 * 0.065;

            vec2 g3Pos = lightUV + ghostAxis * 1.78;
            float g3 = exp(-pow((length((uv - g3Pos) * aspectCorr) - 0.085) / 0.016, 2.0));
            flare += vec3(1.25, 1.05, 0.75) * g3 * 0.048;

            float flareFade = centerOpen * baseVis * mix(0.45, 0.85, st.dayFactor) * (1.0 - smoothstep(0.42, 0.88, length((lightUV - 0.5) * aspectCorr)));
            rays += flare * flareFade * clamp(GODRAYS_STRENGTH, 0.4, 1.4);
        }
    }
#endif

    return max(rays, vec3(0.0));
#endif
}

#endif
