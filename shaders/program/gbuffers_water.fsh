// ==============================================================================
// gbuffers_water — Fragment Shader
// Renders:
//   1. Crystal Anime Water: refraction from read-only colortex4, depth-based
//      aquamarine-to-sapphire Beer-Lambert absorption, shadow- & normal-gated
//      underwater caustics, Fresnel sky/cloud/aurora reflection, and
//      twinkling sun/moon anime water sparkles! Writes SSR normal & mask.
//   2. Glowing Swirling Nether Portals (magical violet-magenta vortex).
//   3. Glossy Reflective Ice, Stained Glass, Slime & Honey in Linear HDR.
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/constants.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"
#include "/lib/atmosphere/sky.glsl"
#include "/lib/atmosphere/clouds.glsl"
#include "/lib/atmosphere/fog.glsl"
#include "/lib/lighting/shadows.glsl"
#include "/lib/lighting/caustics.glsl"
#include "/lib/lighting/shading.glsl"
#include "/lib/water/waterWaves.glsl"

uniform sampler2D gtexture;
uniform sampler2D colortex4;  // Read-only clean opaque HDR scene from deferred!
uniform sampler2D depthtex1;  // Opaque depth behind translucent geometry

#if !defined(DIMENSION_NETHER)
uniform sampler2D shadowtex1;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 shadowLightPosition;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float thunderStrength;
uniform float endFlashIntensity;
uniform vec3 endFlashPosition;
uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

in vec2 vTexCoord;
in vec2 vLmCoord;
in vec4 vColor;
in vec3 vViewPos;
in vec3 vWorldPos;
in vec3 vViewNormal;
in vec3 vWorldNormal;
flat in int vBlockId;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 colorOut;
layout(location = 1) out vec4 reflNormalOut;
layout(location = 2) out vec4 envReflOut;
layout(location = 3) out vec4 ssrMaskOut;

// Reconstruct underwater opaque block world normal from depthtex1 using minimum-depth-gradient
// neighbors so block edges & vertical cliff walls never produce false upward-facing normals.
vec3 reconstructOpaqueWorldNormal(
    vec2 uv,
    float centerDepth,
    vec3 centerViewPos,
    vec2 texelSize,
    sampler2D depthOpaqueTex,
    mat4 projInv,
    mat4 modelViewInv
) {
    vec2 uvL = clamp(uv - vec2(texelSize.x, 0.0), vec2(0.001), vec2(0.999));
    vec2 uvR = clamp(uv + vec2(texelSize.x, 0.0), vec2(0.001), vec2(0.999));
    vec2 uvD = clamp(uv - vec2(0.0, texelSize.y), vec2(0.001), vec2(0.999));
    vec2 uvU = clamp(uv + vec2(0.0, texelSize.y), vec2(0.001), vec2(0.999));

    float dL = texture(depthOpaqueTex, uvL).r;
    float dR = texture(depthOpaqueTex, uvR).r;
    float dD = texture(depthOpaqueTex, uvD).r;
    float dU = texture(depthOpaqueTex, uvU).r;

    vec3 dPdx;
    if (abs(dR - centerDepth) < abs(centerDepth - dL)) {
        dPdx = screenToView(uvR, dR, projInv) - centerViewPos;
    } else {
        dPdx = centerViewPos - screenToView(uvL, dL, projInv);
    }

    vec3 dPdy;
    if (abs(dU - centerDepth) < abs(centerDepth - dD)) {
        dPdy = screenToView(uvU, dU, projInv) - centerViewPos;
    } else {
        dPdy = centerViewPos - screenToView(uvD, dD, projInv);
    }

    float lenX2 = dot(dPdx, dPdx);
    float lenY2 = dot(dPdy, dPdy);
    float maxEdgeStep = max(abs(centerViewPos.z) * 0.12, 0.35);
    float maxEdgeStep2 = maxEdgeStep * maxEdgeStep;
    if (lenX2 < 1e-12 || lenY2 < 1e-12 || lenX2 > maxEdgeStep2 || lenY2 > maxEdgeStep2) {
        return vec3(0.0);
    }

    // Normalize tangent vectors BEFORE cross product so near-camera small pixel steps never underflow
    vec3 n = cross(dPdx * inversesqrt(lenX2), dPdy * inversesqrt(lenY2));
    float lenN2 = dot(n, n);
    if (lenN2 < 1e-6) {
        return vec3(0.0);
    }
    vec3 viewNorm = n * inversesqrt(lenN2);
    if (dot(viewNorm, -centerViewPos) < 0.0) {
        viewNorm = -viewNorm;
    }
    return safeNormalize((modelViewInv * vec4(viewNorm, 0.0)).xyz);
}

void main() {
    vec2 lm = clamp((vLmCoord - 0.03125) / 0.9375, 0.0, 1.0);
    vec2 invRes = 1.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec2 screenUV = gl_FragCoord.xy * invRes;
    float dither = interleavedGradientNoise(gl_FragCoord.xy);

    vec3 sunWorldDir  = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 moonWorldDir = safeNormalize((gbufferModelViewInverse * vec4(moonPosition, 0.0)).xyz);
    vec3 endFlashDir  = safeNormalize((gbufferModelViewInverse * vec4(endFlashPosition, 0.0)).xyz);

    AnimeLightingState st = computeAnimeLightingState(
        sunWorldDir,
        moonWorldDir,
        rainStrength,
        thunderStrength,
        endFlashIntensity
    );

    vec3 viewDir      = safeNormalize(vViewPos);
    vec3 worldViewDir = safeNormalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
    float viewDist    = length(vViewPos);
    vec3 playerPos    = vWorldPos - cameraPosition;

    // =========================================================================
    // 1. CRYSTAL ANIME FANTASY WATER (blockId == 10001)
    // =========================================================================
    if (vBlockId == 10001) {
        vec3 baseWNorm = safeNormalize(vWorldNormal);
        vec3 baseVNorm = safeNormalize(vViewNormal);
        bool isFlatTopWater = (baseWNorm.y > 0.98);
        float flatWeight    = smoothstep(0.50, 0.98, baseWNorm.y);

        vec3 waveWNorm = computeWaterWorldNormal(vWorldPos, baseWNorm, viewDist, frameTimeCounter, rainStrength);
        vec3 waveVNorm = safeNormalize(mat3(gbufferModelView) * waveWNorm);
        // Gentle ripple normal for SSR keeps reflected mountains & treetops crisp and recognizable
        vec3 ssrVNorm  = safeNormalize(mix(baseVNorm, waveVNorm, 0.30));

        // Compute true geometric water column thickness along the view ray
        float bgDepth = texture(depthtex1, screenUV).r;
        float waterThickness = 20.0;
        vec3 bgViewPos  = vViewPos + viewDir * 20.0;
        vec3 bgWorldPos = vWorldPos + worldViewDir * 20.0;
        if (bgDepth < 0.999999) {
            bgViewPos = screenToView(screenUV, bgDepth, gbufferProjectionInverse);
            waterThickness = max(length(bgViewPos - vViewPos), 0.0);
            vec3 bgPlayer = (gbufferModelViewInverse * vec4(bgViewPos, 1.0)).xyz;
            bgWorldPos = bgPlayer + cameraPosition;
        }

        // Gentle, clean refraction for underwater blocks (never bleeds foreground or above-water cliffs!)
        float refractStrength = 0.010 * smoothstep(0.0, 1.8, waterThickness) / (1.0 + viewDist * 0.075);
        vec2 refractOffset = (waveVNorm.xy - baseVNorm.xy) * refractStrength;
        vec2 refractUV = clamp(screenUV + refractOffset, vec2(0.002), vec2(0.998));

        float refrDepth = texture(depthtex1, refractUV).r;
        vec3 refrViewPos  = bgViewPos;
        vec3 refrWorldPos = bgWorldPos;
        if (refrDepth <= gl_FragCoord.z + 0.00005 || refrDepth >= 0.999999) {
            refractUV = screenUV;
            refrDepth = bgDepth;
        } else {
            vec3 candViewPos  = screenToView(refractUV, refrDepth, gbufferProjectionInverse);
            vec3 candWorldPos = (gbufferModelViewInverse * vec4(candViewPos, 1.0)).xyz + cameraPosition;
            // Reject refracted samples that belong to above-water shore/cliffs when viewing from above water
            if (isEyeInWater == 0 && candWorldPos.y > vWorldPos.y + 0.05) {
                refractUV = screenUV;
                refrDepth = bgDepth;
            } else {
                refrViewPos  = candViewPos;
                refrWorldPos = candWorldPos;
            }
        }

        vec3 refractedScene = texture(colortex4, refractUV).rgb;

        if (isEyeInWater > 0) {
            // --- SUBMERGED VIEW OF WATER SURFACE (Snell's Window + Aqua Total Internal Reflection) ---
            // Background in colortex4 already has accurate distance-based underwater fog from deferred.fsh!
            vec3 effWNorm = (dot(waveWNorm, -worldViewDir) < 0.0) ? -waveWNorm : waveWNorm;
            float NdotV_uw = max(dot(effWNorm, -worldViewDir), 0.0);
            vec3 uwCol = computeUnderwaterFogColor(worldViewDir, st);

            // Snell's window looking steeply upward vs. shimmering aqua TIR at grazing angles
            float snellWindow = smoothstep(0.46, 0.76, NdotV_uw) * smoothstep(0.02, 0.25, worldViewDir.y);
            float rippleShimmer = clamp(0.5 + 4.5 * (waveWNorm.x + waveWNorm.z), 0.0, 1.0);
            vec3 tirCol = uwCol * (0.90 + 0.16 * rippleShimmer);

            vec3 waterFinal;
            if (isEyeInWater == 1 && bgDepth >= 0.999999 && snellWindow > 0.01) {
                vec3 skyLookDir = safeNormalize(vec3(worldViewDir.x, max(worldViewDir.y, 0.08), worldViewDir.z));
                vec3 skyHint = renderAnimeSky(skyLookDir, st, frameTimeCounter, endFlashIntensity, endFlashDir);
                vec3 snellCol = mix(refractedScene, mix(uwCol, skyHint * 0.52, 0.58), 0.65);
                waterFinal = mix(tirCol, snellCol, snellWindow);
            } else {
                waterFinal = mix(tirCol, refractedScene, 0.28 + 0.72 * snellWindow);
            }

            // Fade distant underwater water surfaces smoothly into medium fog (never X-rays!)
            waterFinal = applyAnimeFog(waterFinal, playerPos, worldViewDir, viewDist, far, st, isEyeInWater, 0.0, 0.0);

            colorOut      = vec4(max(waterFinal, vec3(0.0)), 1.0);
            reflNormalOut = vec4(ssrVNorm, 1.0);
            envReflOut    = vec4(0.0, 0.0, 0.0, 1.0);
            ssrMaskOut    = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        // Real-time opaque shadow at the water surface (prevents fake sun caustics,
        // sparkles, and bright shallow cyan glow inside shadowed canyons & caves)
        float waterSurfaceShadow = 1.0;
#if !defined(DIMENSION_NETHER)
        vec3 shadowLightWorldDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);
    #if defined(DIMENSION_END)
        if (endFlashIntensity > 0.05) {
            float endShad = sampleOpaqueShadowPCF4(playerPos, baseWNorm, shadowLightWorldDir, lm.y, dither, shadowtex1, shadowModelView, shadowProjection);
            waterSurfaceShadow = mix(1.0, endShad, clamp(endFlashIntensity * 1.2, 0.0, 1.0));
        }
    #else
        waterSurfaceShadow = sampleOpaqueShadowPCF4(playerPos, baseWNorm, shadowLightWorldDir, lm.y, dither, shadowtex1, shadowModelView, shadowProjection);
        #ifndef NIGHT_SHADOWS
            waterSurfaceShadow = mix(1.0, waterSurfaceShadow, st.dayFactor);
        #endif
    #endif
#endif

        // Project crystalline underwater caustics ONLY onto sunlit, upward-facing submerged seabeds
        // under calm water (never stretched across vertical cliff walls, waterfalls, shadows, or shallow block edges!)
#ifdef WATER_CAUSTICS
        if (isFlatTopWater && refrDepth < 0.999999 && waterThickness < 18.0 && lm.y > 0.15) {
            float submergedDepth = max(vWorldPos.y - refrWorldPos.y, 0.0);
            // Physical refraction convergence: zero right where water touches a block, peaking over shallow beds
            float depthFocus = smoothstep(0.16, 0.85, submergedDepth) * exp(-submergedDepth * 0.18);
            float sunElevVis = smoothstep(0.04, 0.25, st.activeLightDir.y) * (1.0 - st.rainMix * 0.85);
            if (depthFocus > 0.005 && sunElevVis > 0.005) {
                vec3 bgWorldNorm = reconstructOpaqueWorldNormal(
                    refractUV,
                    refrDepth,
                    refrViewPos,
                    invRes,
                    depthtex1,
                    gbufferProjectionInverse,
                    gbufferModelViewInverse
                );
                // Reject vertical cliff faces & overhangs so caustics never shear into diagonal white stripes
                float bedUpMask = smoothstep(0.55, 0.88, bgWorldNorm.y);
                if (bedUpMask > 0.005) {
                    float bedShadow = 1.0;
                #if !defined(DIMENSION_NETHER)
                    vec3 refrPlayerPos = refrWorldPos - cameraPosition;
                    #if defined(DIMENSION_END)
                        if (endFlashIntensity > 0.05) {
                            float endBedShad = sampleOpaqueShadowPCF4(refrPlayerPos, bgWorldNorm, shadowLightWorldDir, lm.y, dither, shadowtex1, shadowModelView, shadowProjection);
                            bedShadow = mix(1.0, endBedShad, clamp(endFlashIntensity * 1.2, 0.0, 1.0));
                        }
                    #else
                        bedShadow = sampleOpaqueShadowPCF4(refrPlayerPos, bgWorldNorm, shadowLightWorldDir, lm.y, dither, shadowtex1, shadowModelView, shadowProjection);
                        #ifndef NIGHT_SHADOWS
                            bedShadow = mix(1.0, bedShadow, st.dayFactor);
                        #endif
                    #endif
                #endif
                    if (bedShadow > 0.01) {
                        float caust = computeUnderwaterCaustics(refrWorldPos, st.activeLightDir, frameTimeCounter);
                        float caustAtten = depthFocus * bedUpMask * bedShadow * sunElevVis * smoothstep(0.15, 0.85, lm.y);
                        vec3 caustTint = mix(vec3(0.32, 0.78, 1.10) * NIGHT_BRIGHTNESS, vec3(0.62, 1.06, 1.16), st.dayFactor);
                        // Modulate by lit underwater surface so dark shadowed rock never turns glowing white
                        refractedScene += refractedScene * caustTint * caust * caustAtten * 0.85;
                    }
                }
            }
        }
#endif

        // Biome tint blended gently with crystal anime aquamarine -> sapphire palette
        vec3 biomeLinear = srgbToLinear(clamp(vColor.rgb, vec3(0.08), vec3(1.0)));
        float skyLightFactor = smoothstep(0.04, 0.92, lm.y);
        float shallowLitScale = mix(0.28 * NIGHT_BRIGHTNESS, 1.0, st.dayFactor) * mix(0.38, 1.0, waterSurfaceShadow);
        vec3 shallowAlbedo = mix(vec3(0.08, 0.50, 0.62), biomeLinear * vec3(0.45, 0.96, 1.02), 0.36);
        vec3 shallowTint   = shallowAlbedo * shallowLitScale;
        vec3 deepTint      = mix(vec3(0.016, 0.095, 0.26), vec3(0.026, 0.17, 0.44), st.dayFactor);
        deepTint          *= mix(vec3(0.85 * NIGHT_BRIGHTNESS), vec3(mix(0.62, 1.0, waterSurfaceShadow)), st.dayFactor);

        // Beer-Lambert optical absorption (scaled by WATER_CLARITY)
        // Smoothly reaches full transparency at waterThickness -> 0 for seamless contact with shore blocks
        float absorbRate = 0.20 / max(WATER_CLARITY, 0.4);
        float transmittance = exp(-waterThickness * absorbRate);
        float bodyLight = mix(0.18 * CAVE_BRIGHTNESS, 1.0, skyLightFactor);
        vec3 waterBodyColor = mix(deepTint, shallowTint, exp(-waterThickness * 0.35)) * bodyLight;
        vec3 refractedTint = mix(mix(shallowAlbedo * 1.15, vec3(1.0), 0.45), vec3(1.0), smoothstep(0.30, 1.0, transmittance));
        vec3 refractedWater = mix(waterBodyColor, refractedScene * refractedTint, clamp(transmittance, 0.14, 1.0));

        // Fresnel Sky + Cloud + Aurora Reflection:
        // Crisp mirror-like reflections on calm flat water across grazing & mid angles (full mountain + treetop!)
        // while keeping steep waterfalls natural and free of harsh grazing sky glare
        vec3 fresnelNorm = safeNormalize(mix(baseWNorm, waveWNorm, 0.45));
        float NdotV = max(dot(fresnelNorm, -worldViewDir), 0.0);
        float fresnelPow = mix(4.2, 2.5, flatWeight);
        float fresnel = 0.06 + 0.89 * pow(1.0 - NdotV, fresnelPow);
        fresnel = clamp(fresnel, 0.06, 0.90);

        vec3 reflDir = reflect(worldViewDir, waveWNorm);
        reflDir.y = max(reflDir.y, 0.015);
        vec3 skyRefl = renderAnimeSky(reflDir, st, frameTimeCounter, endFlashIntensity, endFlashDir);
        vec4 cloudRefl = renderAnimeClouds(reflDir, cameraPosition, st, frameTimeCounter, dither);
        skyRefl = skyRefl * (1.0 - cloudRefl.a) + cloudRefl.rgb;

        vec3 indoorRefl = mix(vec3(0.12, 0.18, 0.28), st.ambientSky * 0.85, lm.y) * max(CAVE_BRIGHTNESS, 0.9);
        vec3 envRefl = mix(indoorRefl, skyRefl, smoothstep(0.10, 0.85, lm.y));

        // On vertical/sloped waterfalls (which do not run SSR), softly attenuate bright sky glare in shadows
        if (!isFlatTopWater) {
            float wfSkyVis = mix(0.32, 1.0, waterSurfaceShadow);
            envRefl = mix(indoorRefl, envRefl, mix(wfSkyVis, 1.0, flatWeight));
        }

        float reflWeight = mix(0.18, 0.92, flatWeight);
        float waterReflAmt = fresnel * reflWeight;
        vec3 waterFinal = mix(refractedWater, envRefl, waterReflAmt);

        // --- Twinkling Anime Water Sun & Moon Sparkles! ---
#ifdef WATER_SPARKLES
        if (lm.y > 0.35 && isFlatTopWater && waterSurfaceShadow > 0.05) {
            vec3 H = safeNormalize(st.activeLightDir - worldViewDir);
            float NdotH = max(dot(waveWNorm, H), 0.0);
            float broadGlint = pow(NdotH, 120.0) * 1.40;
            float facetNoise = valueNoise2D(vWorldPos.xz * 7.5 + vec2(frameTimeCounter * 1.5, -frameTimeCounter * 1.0));
            float sparkle = pow(NdotH, 260.0) * smoothstep(0.42, 0.82, facetNoise) * 6.0;

            vec3 glintCol = mix(vec3(0.75, 1.15, 1.65) * NIGHT_BRIGHTNESS, st.directColor * 1.45, st.dayFactor);
            float glintVis = smoothstep(0.35, 0.85, lm.y) * (1.0 - st.rainMix * 0.82) * smoothstep(-0.04, 0.08, st.activeLightDir.y) * waterSurfaceShadow;
            waterFinal += glintCol * (broadGlint + sparkle) * glintVis;
        }
#endif

        // Subtle warm blocklight shimmer from nearby lanterns & torches
        vec3 waterBlockLight = computeBlockAndHandLight(lm.x, viewDist, waveVNorm, viewDir, heldBlockLightValue, heldBlockLightValue2);
        waterFinal += waterBlockLight * (0.12 + 0.20 * fresnel);

        // Enable SSR on flat top water; keep shoreline SSR continuous right up to block contact edges
        float enableSSR = isFlatTopWater ? 1.0 : 0.0;

        colorOut      = vec4(max(waterFinal, vec3(0.0)), 1.0);
        reflNormalOut = vec4(ssrVNorm, 1.0);
        envReflOut    = vec4(max(envRefl, vec3(0.0)), 1.0);
        ssrMaskOut    = vec4(enableSSR, waterReflAmt, smoothstep(0.0, 0.02, waterThickness), 1.0);
        return;
    }

    // =========================================================================
    // 2. SWIRLING ANIME NETHER PORTAL (blockId == 10004)
    // =========================================================================
    if (vBlockId == 10004) {
        vec4 tex = texture(gtexture, vTexCoord) * vColor;
        vec2 pUV = vWorldPos.xy + vWorldPos.zy;
        float swirl = fbm2D(pUV * 1.6 + vec2(sin(frameTimeCounter * 0.8), cos(frameTimeCounter * 0.6)));
        float sparks = pow(valueNoise2D(pUV * 8.5 + vec2(0.0, frameTimeCounter * 1.8)), 5.0) * 3.2;

        vec3 portalCol = mix(vec3(0.65, 0.16, 1.35), vec3(1.38, 0.42, 1.25), swirl);
        portalCol += vec3(0.72, 1.10, 1.65) * sparks;
        portalCol = mix(srgbToLinear(tex.rgb) * 1.8, portalCol, 0.65) * (1.15 * EMISSIVE_GLOW);

        if (isEyeInWater > 0) {
            portalCol = applyAnimeFog(portalCol, playerPos, worldViewDir, viewDist, far, st, isEyeInWater, 0.0, 0.0);
        }

        colorOut      = vec4(portalCol, clamp(tex.a, 0.55, 0.92));
        reflNormalOut = vec4(safeNormalize(vViewNormal), 1.0);
        envReflOut    = vec4(0.0, 0.0, 0.0, 1.0);
        ssrMaskOut    = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // =========================================================================
    // 3. STAINED GLASS, ICE, SLIME, HONEY & OTHER TRANSLUCENT BLOCKS
    // =========================================================================
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < 0.02) discard;

    vec3 albedoLinear = srgbToLinear(tex.rgb);
    vec3 wNorm = safeNormalize(vWorldNormal);
    vec3 vNorm = safeNormalize(vViewNormal);

    float NdotL = dot(wNorm, st.activeLightDir);
    float diff  = animeDiffuseRamp(NdotL, false);
    float skyF  = smoothstep(0.05, 0.95, lm.y);

    vec3 direct = st.directColor * diff * skyF;
    vec3 amb    = mix(vec3(0.20, 0.24, 0.36) * CAVE_BRIGHTNESS, mix(st.ambientGround, st.ambientSky, wNorm.y * 0.5 + 0.5), skyF);
    vec3 blockL = computeBlockAndHandLight(lm.x, viewDist, vNorm, viewDir, heldBlockLightValue, heldBlockLightValue2);

    vec3 lit = albedoLinear * (direct + amb + blockL);

    // Crisp glossy anime Fresnel sky reflection & specular glint on glass and ice!
    float NdotV = max(dot(wNorm, -worldViewDir), 0.0);
    float fresnel = 0.06 + 0.72 * pow(1.0 - NdotV, 3.8);

    vec3 H = safeNormalize(st.activeLightDir - worldViewDir);
    float spec = pow(max(dot(wNorm, H), 0.0), 72.0) * 1.35 * skyF;

    if (isEyeInWater == 0) {
        vec3 skyTintRefl = mix(st.ambientSky, st.skyHorizon, 0.5) * fresnel * (0.45 + 0.55 * skyF);
        lit += skyTintRefl + st.directColor * spec;
    } else {
        // Underwater ice & glass: subtle aqua-tinted crystal sheen + accurate underwater fog!
        // Background in colortex0 is already fogged by deferred.fsh -> ZERO underwater X-ray!
        vec3 uwSheen = computeUnderwaterFogColor(worldViewDir, st) * fresnel * 0.38;
        lit += uwSheen + st.directColor * spec * 0.25;
        lit = applyAnimeFog(lit, playerPos, worldViewDir, viewDist, far, st, isEyeInWater, 0.0, 0.0);
    }

    bool isIce = (vBlockId == 10002);
    float outAlpha = clamp(tex.a + fresnel * (isIce ? 0.28 : 0.18), 0.05, 0.96);
    bool enableIceSSR = isIce && (isEyeInWater == 0);

    colorOut      = vec4(max(lit, vec3(0.0)), outAlpha);
    reflNormalOut = vec4(vNorm, 1.0);
    envReflOut    = vec4(0.0, 0.0, 0.0, 1.0);
    // Give above-water translucent ice subtle SSR reflection; cleanly zero colortex3 otherwise
    ssrMaskOut    = enableIceSSR ? vec4(0.45, fresnel * 0.55, 1.0, 1.0) : vec4(0.0, 0.0, 0.0, 1.0);
}

