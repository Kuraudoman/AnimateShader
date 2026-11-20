#ifndef ANIMATE_SHADING_GLSL
#define ANIMATE_SHADING_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/constants.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"

// ==============================================================================
// Anime Fantasy Shading, Hue-Shifted Colored Shadows, Rim Lighting, SSS,
// Colorful Blocklights, Handheld Dynamic Light, & Balanced Night Visibility
// ==============================================================================

// Anime diffuse shading curve: converts NdotL in [-1, 1] to painterly illumination
float animeDiffuseRamp(float NdotL, bool isFoliage) {
    if (isFoliage) {
        // Leaves and flowers wrap sunlight softly from all directions
        return 0.48 + 0.52 * clamp(NdotL * 0.65 + 0.35, 0.0, 1.0);
    }

    float halfLamb = clamp(NdotL * 0.5 + 0.5, 0.0, 1.0);

    #if ANIME_SHADING_STYLE == 0
        // Smooth Fantasy: lush wrapped illustration lighting
        return smoothstep(0.18, 0.96, halfLamb);
    #elif ANIME_SHADING_STYLE == 1
        // Soft Anime Cel (Signature Makoto Shinkai / Genshin Impact soft-step ramp)
        float softStep = smoothstep(0.38, 0.64, halfLamb);
        return mix(halfLamb * 0.55, 0.30 + 0.70 * softStep, 0.68);
    #else
        // Crisp Anime Cel: bold two-step cel shading with anti-aliased edge
        float band1 = smoothstep(0.44, 0.53, halfLamb);
        float band2 = smoothstep(0.74, 0.84, halfLamb);
        return 0.14 + 0.62 * band1 + 0.24 * band2;
    #endif
}

// Fast 8-tap rotated screen-space ambient occlusion with gentle anime softness
float computeAnimeSSAO(
    vec2 uv,
    vec3 viewPos,
    vec3 viewNormal,
    float dither,
    sampler2D depthTex,
    mat4 proj,
    mat4 projInv
) {
#ifdef SSAO_ENABLED
    float viewDist = -viewPos.z;
    if (viewDist > 75.0 || viewDist < 0.25) return 1.0;

    float radius = clamp(0.42 + viewDist * 0.015, 0.38, 1.45);
    float occ = 0.0;
    float phi = dither * TAU;

    for (int i = 0; i < 8; i++) {
        vec2 disk = vogelDiskSample(i, 8, phi);
        // Build hemisphere sample offset in view space
        vec3 offsetVec = vec3(disk, 0.35 + 0.65 * hash12(disk * 31.7 + float(i)));
        if (dot(offsetVec, viewNormal) < 0.0) offsetVec = -offsetVec;

        vec3 sampleViewPos = viewPos + normalize(offsetVec) * radius * (0.35 + 0.65 * float(i + 1) / 8.0);
        vec3 sampleScreen = viewToScreen(sampleViewPos, proj);
        if (sampleScreen.x < 0.0 || sampleScreen.x > 1.0 || sampleScreen.y < 0.0 || sampleScreen.y > 1.0) continue;

        float sampleDepth = texture(depthTex, sampleScreen.xy).r;
        if (sampleDepth >= 0.9999) continue;

        vec3 sceneViewPos = screenToView(sampleScreen.xy, sampleDepth, projInv);
        vec3 delta = sceneViewPos - viewPos;
        float dist = length(delta);
        float rangeFade = smoothstep(radius * 1.65, radius * 0.15, dist);
        float horizon = max(dot(viewNormal, delta / max(dist, 1e-4)) - 0.12, 0.0);
        occ += horizon * rangeFade;
    }

    float distFade = 1.0 - smoothstep(45.0, 75.0, viewDist);
    float ao = 1.0 - clamp((occ / 8.0) * 1.35, 0.0, 0.62) * distFade;
    return clamp(ao, 0.38, 1.0);
#else
    return 1.0;
#endif
}

// Compute warm-gold / magical blocklight & dual-hand dynamic held light
vec3 computeBlockAndHandLight(
    float blockLightMap,
    float viewDist,
    vec3 viewNormal,
    vec3 viewDir,
    int heldLightMain,
    int heldLightOff
) {
    // Smooth, rich curve for vanilla torch/lantern lightmap
    float bl = clamp(blockLightMap, 0.0, 1.0);
    float blCurve = pow(bl, 1.85) * 1.35 + pow(bl, 4.2) * 0.95;

    // Warm honey-amber near source fading to dreamy peach-gold at edges
    vec3 warmCore = vec3(1.45, 0.96, 0.50);
    vec3 warmEdge = vec3(1.12, 0.64, 0.36);
    vec3 blockCol = mix(warmEdge, warmCore, smoothstep(0.25, 0.95, bl)) * blCurve * BLOCKLIGHT_STRENGTH;

#ifdef DYNAMIC_HANDLIGHT
    float maxHeld = float(max(heldLightMain, heldLightOff));
    if (maxHeld > 0.5) {
        float range = maxHeld * 1.15 + 2.5;
        float atten = clamp(1.0 - viewDist / range, 0.0, 1.0);
        atten = atten * atten * (0.45 + 0.55 * max(dot(viewNormal, -viewDir), 0.15));
        float power = (maxHeld / 15.0) * 1.35 * BLOCKLIGHT_STRENGTH;
        blockCol += vec3(1.38, 0.94, 0.52) * atten * power;
    }
#endif

    return blockCol;
}

// Complete Anime Fantasy Opaque Surface Shading
vec3 shadeAnimeSurface(
    vec3 albedoLinear,
    vec3 worldNormal,
    vec3 viewNormal,
    vec3 viewDir,
    vec3 worldViewDir,
    float viewDist,
    vec2 lightmap,       // x = blocklight, y = skylight
    float matId,
    float matExtra,      // emissive tint code or foliage flag
    float emissiveVal,
    vec3 shadowTrans,
    float aoFactor,
    AnimeLightingState st,
    float wetnessVal,
    float nightVisionVal,
    int heldLightMain,
    int heldLightOff,
    vec3 worldPos,
    float timeSec
) {
    // Fully unlit / beacon / glowing text / UI elements pass cleanly with vivid boost
    if (isMat(matId, MAT_UNLIT) || emissiveVal >= 0.99) {
        return albedoLinear * (1.05 + 0.35 * EMISSIVE_GLOW);
    }

    // Special cosmic shader for End Portal / End Gateway blocks
    if (isMat(matId, MAT_PORTAL_END)) {
        vec2 pUV = worldPos.xz * 0.45 + worldViewDir.xz * 1.4;
        float swirl = fbm2D(pUV * 2.2 + vec2(timeSec * 0.12, -timeSec * 0.09));
        float stars = pow(valueNoise2D(pUV * 12.0 + vec2(timeSec * 0.06)), 7.0) * 4.5;
        vec3 cosmic = mix(vec3(0.12, 0.06, 0.32), vec3(0.45, 0.22, 0.95), swirl);
        cosmic += vec3(0.45, 1.15, 1.45) * stars;
        return cosmic * (1.2 + 0.4 * EMISSIVE_GLOW);
    }

    bool isFoliage  = isMat(matId, MAT_FOLIAGE) || isMat(matId, MAT_LEAVES);
    bool isLeaves   = isMat(matId, MAT_LEAVES);
    bool isPolished = isMat(matId, MAT_POLISHED);
    bool isEntity   = isMat(matId, MAT_ENTITY);
    bool isHand     = isMat(matId, MAT_HAND);
    bool isEmissive = isMat(matId, MAT_EMISSIVE) || emissiveVal > 0.02;

    float blockLight = clamp(lightmap.x, 0.0, 1.0);
    float skyLight   = clamp(lightmap.y, 0.0, 1.0);
    float skyFactor  = smoothstep(0.04, 0.96, skyLight);

    // --- 1. Directional Sun / Moon Lighting with Anime Diffuse Ramp ---
    float NdotL = dot(worldNormal, st.activeLightDir);
    float diffuseAmt = animeDiffuseRamp(NdotL, isFoliage);

    // Mask shadows subtly in deep caves via skylight, keep moonlight shadows soft
    vec3 effectiveShadow = shadowTrans;
#if !defined(DIMENSION_NETHER) && !defined(DIMENSION_END)
    #ifndef NIGHT_SHADOWS
        effectiveShadow = mix(vec3(1.0), effectiveShadow, st.dayFactor);
    #else
        // At night, keep shadowed side luminous & gentle so shadows never become black holes
        effectiveShadow = mix(mix(vec3(0.42), vec3(1.0), effectiveShadow), effectiveShadow, st.dayFactor);
    #endif
#endif

    // Modulate direct light by skylight indoors (except first-person hand which gets soft fill)
    float indoorMask = isHand ? (0.35 + 0.65 * skyFactor) : smoothstep(0.06, 0.45, skyLight);
    vec3 directLight = st.directColor * diffuseAmt * effectiveShadow * indoorMask;

    // --- 2. Foliage Subsurface Scattering (Backlit Translucent Leaves & Blossoms!) ---
    vec3 sssLight = vec3(0.0);
#ifdef FOLIAGE_SSS
    if (isFoliage) {
        float backAlign = pow(clamp(dot(worldViewDir, st.activeLightDir), 0.0, 1.0), 3.0);
        float scatterAmt = (0.28 + 0.85 * backAlign) * (isLeaves ? 0.65 : 0.50);
        // Warm luminous translucency tinted by sunlight & leaf hue
        vec3 sssTint = mix(vec3(0.95, 1.15, 0.65), vec3(1.25, 0.95, 1.05), smoothstep(0.35, 0.75, albedoLinear.r - albedoLinear.g));
        sssLight = st.directColor * sssTint * scatterAmt * (0.30 + 0.70 * effectiveShadow) * indoorMask;
    }
#endif

    // --- 3. Anime Hue-Shifted Ambient + Guaranteed Luminous Night & Cave Floor ---
    float upMask = worldNormal.y * 0.5 + 0.5;
    vec3 hemiAmbient = mix(st.ambientGround, st.ambientSky, upMask);

    // Classic anime background-art shadow tint: shift shadowed planes toward pure cerulean/lavender
    float shadowPresence = 1.0 - clamp(diffuseAmt * luma(effectiveShadow) * indoorMask, 0.0, 1.0);
    vec3 animeShadowHue = mix(vec3(1.0), st.shadowTint * 1.48, clamp(SHADOW_COLOR_TINT * 0.50 * shadowPresence, 0.0, 0.78));

    // Cave / indoor soft magical blue-violet floor so unlit interiors remain readable & atmospheric
    vec3 caveFloor = mix(vec3(0.055, 0.072, 0.135), vec3(0.090, 0.115, 0.195), upMask) * (0.78 * CAVE_BRIGHTNESS);
    // Night Vision potion smoothly illuminates everything brightly
    caveFloor = mix(caveFloor, vec3(0.45, 0.52, 0.65), clamp(nightVisionVal, 0.0, 1.0));

    // Blend outdoor sky ambient with indoor cave floor smoothly
    vec3 ambientLight = mix(caveFloor, hemiAmbient * animeShadowHue, skyFactor);
    // Luminous night safety floor ensures open landscapes at night stay clear & vivid (never dark!)
    vec3 nightSafetyFloor = vec3(0.068, 0.095, 0.165) * (0.88 * NIGHT_BRIGHTNESS) * st.nightFactor * skyFactor;
    ambientLight = max(ambientLight, nightSafetyFloor);

    // Apply colored SSAO (never dull black — tints crevices with soft shadow hue!)
    vec3 aoColored = mix(st.shadowTint * 0.52, vec3(1.0), aoFactor);
    ambientLight *= aoColored;

    // --- 4. Block Light (Torches, Lanterns, Soul Lights) + Dynamic Held Light ---
    vec3 blockAndHand = computeBlockAndHandLight(blockLight, viewDist, viewNormal, viewDir, heldLightMain, heldLightOff);

    // --- 5. Anime Rim Highlight (Backlit Golden/Moonlit Silhouette Edge on Entities & Foliage Only!) ---
    // Flat terrain/block faces must never receive grazing Fresnel rim light, otherwise
    // matte blocks (dirt, grass, stone) show an artificial white specular-like sheen at oblique angles.
    vec3 rimLight = vec3(0.0);
    if (RIM_LIGHT_STRENGTH > 0.001 && (isEntity || isFoliage)) {
        float fresnel = pow(1.0 - max(dot(viewNormal, -viewDir), 0.0), 4.8);
        // True backlit alignment: only illuminates silhouettes when looking toward the sun/moon
        float backLit = smoothstep(0.15, 0.85, dot(worldViewDir, st.activeLightDir));
        float directVis = luma(effectiveShadow) * indoorMask * smoothstep(0.0, 0.14, st.activeLightDir.y);
        float rimScale = (isEntity ? 0.36 : 0.18) * RIM_LIGHT_STRENGTH;
        vec3 rimTint = mix(albedoLinear, vec3(0.5) + albedoLinear * 0.5, isEntity ? 0.45 : 0.15);
        rimLight = st.rimColor * rimTint * fresnel * backLit * rimScale * directVis;
    }

    // --- 6. Glossy Anime Specular (Gems, Metals, Polished Blocks & Rain-Wet Puddles) ---
    vec3 specLight = vec3(0.0);
    float rainPuddle = 0.0;
#ifdef WET_REFLECTIONS
    if (wetnessVal > 0.01 && skyLight > 0.75 && !isFoliage && !isHand) {
        float upSurface = smoothstep(0.65, 0.95, worldNormal.y);
        float puddleNoise = smoothstep(0.38, 0.72, fbm2D(worldPos.xz * 0.22));
        rainPuddle = wetnessVal * upSurface * puddleNoise;
    }
#endif

    float gloss = isPolished ? 0.72 : (isEntity ? 0.18 : 0.0);
    gloss = max(gloss, rainPuddle * 0.80);
    if (gloss > 0.05) {
        vec3 H = safeNormalize(st.activeLightDir - worldViewDir);
        float NdotH = max(dot(worldNormal, H), 0.0);
        float specPow = mix(28.0, 96.0, gloss);
        float spec = pow(NdotH, specPow) * gloss * 0.72;
        specLight += st.directColor * spec * effectiveShadow * indoorMask;

        if (rainPuddle > 0.02) {
            float wetFresnel = pow(1.0 - max(dot(viewNormal, -viewDir), 0.0), 5.0);
            specLight += st.skyHorizon * wetFresnel * rainPuddle * 0.24 * skyFactor;
        }
    }

    // --- 7. Combine Lighting ---
    vec3 totalLight = directLight + sssLight + ambientLight + blockAndHand;
    vec3 litColor = albedoLinear * totalLight + rimLight + specLight;

    // --- 8. Colorful Anime Self-Emissive Glow (Triggers Dreamy HDR Bloom!) ---
    if (isEmissive && emissiveVal > 0.01) {
        vec3 eTint = getEmissiveTint(matExtra);
        float texLuma = max(luma(albedoLinear), 0.20);
        vec3 emissiveColor = mix(albedoLinear, albedoLinear * eTint * 1.50, 0.72) * (1.45 + 1.55 * texLuma);
        litColor += emissiveColor * emissiveVal * EMISSIVE_GLOW;
    }

    return max(litColor, vec3(0.0));
}

#endif
