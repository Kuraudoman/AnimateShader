// ==============================================================================
// gbuffers_water — Fragment Shader
// Renders:
//   1. Crystal Anime Water: refraction from read-only colortex4, depth-based
//      aquamarine-to-sapphire Beer-Lambert absorption, underwater caustics,
//      delicate shoreline foam, Fresnel sky/cloud/aurora reflection, and
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
#include "/lib/lighting/caustics.glsl"
#include "/lib/lighting/shading.glsl"
#include "/lib/water/waterWaves.glsl"

uniform sampler2D gtexture;
uniform sampler2D colortex4;  // Read-only clean opaque HDR scene from deferred!
uniform sampler2D depthtex1;  // Opaque depth behind translucent geometry

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
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

/* RENDERTARGETS: 0,1,3 */
layout(location = 0) out vec4 colorOut;
layout(location = 1) out vec4 reflNormalOut;
layout(location = 2) out vec4 ssrMaskOut;

void main() {
    vec2 lm = clamp((vLmCoord - 0.03125) / 0.9375, 0.0, 1.0);
    vec2 screenUV = gl_FragCoord.xy / max(vec2(viewWidth, viewHeight), vec2(1.0));
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

    // =========================================================================
    // 1. CRYSTAL ANIME FANTASY WATER (blockId == 10001)
    // =========================================================================
    if (vBlockId == 10001) {
        vec3 baseWNorm = safeNormalize(vWorldNormal);
        vec3 waveWNorm = computeWaterWorldNormal(vWorldPos, baseWNorm, frameTimeCounter, rainStrength);
        vec3 waveVNorm = safeNormalize(mat3(gbufferModelView) * waveWNorm);

        // Compute true geometric water column thickness along the view ray
        float bgDepth = texture(depthtex1, screenUV).r;
        float waterThickness = 24.0;
        vec3 bgWorldPos = vWorldPos + worldViewDir * 24.0;
        if (bgDepth < 0.9998) {
            vec3 bgViewPos = screenToView(screenUV, bgDepth, gbufferProjectionInverse);
            waterThickness = max(length(bgViewPos - vViewPos), 0.0);
            vec3 bgPlayer = (gbufferModelViewInverse * vec4(bgViewPos, 1.0)).xyz;
            bgWorldPos = bgPlayer + cameraPosition;
        }

        // Gentle depth-scaled screen refraction with foreground occluder safety check
        float refractStrength = 0.018 * smoothstep(0.0, 1.5, waterThickness) / (1.0 + viewDist * 0.045);
        vec2 refractOffset = (waveVNorm.xy - vViewNormal.xy) * refractStrength;
        vec2 refractUV = clamp(screenUV + refractOffset, vec2(0.002), vec2(0.998));

        // Prevent foreground solid blocks from bleeding into water refraction
        float refrDepth = texture(depthtex1, refractUV).r;
        if (refrDepth <= gl_FragCoord.z + 0.00002) {
            refractUV = screenUV;
            refrDepth = bgDepth;
        }

        vec3 refractedScene = texture(colortex4, refractUV).rgb;

        // Project crystalline underwater caustics onto submerged terrain seen through water!
        if (isEyeInWater == 0 && refrDepth < 0.9998 && waterThickness < 18.0) {
            float caust = computeUnderwaterCaustics(bgWorldPos, st.activeLightDir, frameTimeCounter);
            float caustAtten = exp(-waterThickness * 0.22) * smoothstep(0.15, 0.85, lm.y);
            vec3 caustTint = mix(vec3(0.32, 0.86, 1.18), vec3(0.58, 1.12, 1.24), st.dayFactor);
            refractedScene += caustTint * caust * caustAtten * 0.36;
        }

        // Biome tint blended gently with our crystal anime aquamarine -> sapphire palette
        vec3 biomeLinear = srgbToLinear(clamp(vColor.rgb, vec3(0.08), vec3(1.0)));
        vec3 shallowTint = mix(vec3(0.08, 0.56, 0.66), biomeLinear * vec3(0.45, 1.05, 1.08), 0.36);
        vec3 deepTint    = mix(vec3(0.014, 0.085, 0.24), vec3(0.024, 0.16, 0.42), st.dayFactor);
        deepTint        *= mix(vec3(0.85 * NIGHT_BRIGHTNESS), vec3(1.0), st.dayFactor);

        // Beer-Lambert optical absorption (scaled by WATER_CLARITY)
        float absorbRate = 0.24 / max(WATER_CLARITY, 0.4);
        float transmittance = exp(-waterThickness * absorbRate);
        vec3 waterBodyColor = mix(deepTint * (0.45 + 0.55 * lm.y), shallowTint * (0.42 + 0.58 * lm.y), exp(-waterThickness * 0.35));
        vec3 refractedWater = mix(waterBodyColor, refractedScene * mix(shallowTint * 1.25, vec3(1.0), transmittance * 0.65), clamp(transmittance, 0.12, 1.0));

        // Delicate Anime Shoreline Foam where water kisses shallow blocks
        if (isEyeInWater == 0 && bgDepth < 0.9998) {
            float foamEdge = 1.0 - smoothstep(0.04, 0.42, waterThickness);
            float foamPattern = smoothstep(0.35, 0.72, valueNoise2D(vWorldPos.xz * 2.8 + vec2(frameTimeCounter * 0.45, -frameTimeCounter * 0.32)));
            float foamMask = foamEdge * (0.45 + 0.55 * foamPattern) * smoothstep(0.0, 0.04, waterThickness);
            vec3 foamCol = mix(vec3(0.28, 0.44, 0.68) * NIGHT_BRIGHTNESS, vec3(0.92, 0.98, 1.05), st.dayFactor);
            refractedWater = mix(refractedWater, foamCol, clamp(foamMask * 0.60, 0.0, 0.76));
        }

        // Fresnel Sky + Cloud + Aurora Reflection
        float NdotV = max(dot(waveWNorm, -worldViewDir), 0.0);
        float fresnel = 0.035 + 0.965 * pow(1.0 - NdotV, 4.4);
        fresnel = clamp(fresnel, 0.04, 0.92);

        vec3 reflDir = reflect(worldViewDir, waveWNorm);
        reflDir.y = max(reflDir.y, 0.015);
        vec3 skyRefl = renderAnimeSky(reflDir, st, frameTimeCounter, endFlashIntensity, endFlashDir);
        vec4 cloudRefl = renderAnimeClouds(reflDir, cameraPosition, st, frameTimeCounter, dither);
        skyRefl = skyRefl * (1.0 - cloudRefl.a) + cloudRefl.rgb;

        // Indoor water reflects cozy ambient rather than full outdoor sky
        vec3 indoorRefl = mix(vec3(0.12, 0.18, 0.28), st.ambientSky * 0.85, lm.y) * max(CAVE_BRIGHTNESS, 0.9);
        vec3 envRefl = mix(indoorRefl, skyRefl, smoothstep(0.10, 0.85, lm.y));

        vec3 waterFinal = mix(refractedWater, envRefl, fresnel * (isEyeInWater == 1 ? 0.35 : 0.86));

        // --- Twinkling Anime Water Sun & Moon Sparkles! ---
#ifdef WATER_SPARKLES
        if (lm.y > 0.35 && isEyeInWater == 0) {
            vec3 H = safeNormalize(st.activeLightDir - worldViewDir);
            float NdotH = max(dot(waveWNorm, H), 0.0);
            float broadGlint = pow(NdotH, 110.0) * 1.45;
            // Crisp twinkling anime star glints on fine wave facets
            float facetNoise = valueNoise2D(vWorldPos.xz * 7.5 + vec2(frameTimeCounter * 1.6, -frameTimeCounter * 1.1));
            float sparkle = pow(NdotH, 280.0) * smoothstep(0.42, 0.82, facetNoise) * 6.5;

            vec3 glintCol = mix(vec3(0.75, 1.15, 1.65) * NIGHT_BRIGHTNESS, st.directColor * 1.45, st.dayFactor);
            float glintVis = smoothstep(0.35, 0.85, lm.y) * (1.0 - st.rainMix * 0.82) * smoothstep(-0.04, 0.08, st.activeLightDir.y);
            waterFinal += glintCol * (broadGlint + sparkle) * glintVis;
        }
#endif

        // Subtle warm blocklight reflection from nearby lanterns & torches
        vec3 waterBlockLight = computeBlockAndHandLight(lm.x, viewDist, waveVNorm, viewDir, heldBlockLightValue, heldBlockLightValue2);
        waterFinal += waterBlockLight * (0.14 + 0.24 * fresnel);

        colorOut      = vec4(max(waterFinal, vec3(0.0)), 1.0);
        reflNormalOut = vec4(waveVNorm, 0.0);
        ssrMaskOut    = vec4(isEyeInWater == 1 ? 0.0 : 1.0, fresnel, smoothstep(0.0, 0.25, waterThickness), 1.0);
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

        colorOut      = vec4(portalCol, clamp(tex.a, 0.55, 0.92));
        reflNormalOut = vec4(safeNormalize(vViewNormal), 0.0);
        ssrMaskOut    = vec4(0.0);
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

    vec3 skyTintRefl = mix(st.ambientSky, st.skyHorizon, 0.5) * fresnel * (0.45 + 0.55 * skyF);
    lit += skyTintRefl + st.directColor * spec;

    bool isIce = (vBlockId == 10002);
    float outAlpha = clamp(tex.a + fresnel * (isIce ? 0.28 : 0.18), 0.05, 0.96);

    colorOut      = vec4(max(lit, vec3(0.0)), outAlpha);
    reflNormalOut = vec4(vNorm, 0.0);
    // Give translucent ice subtle SSR reflection!
    ssrMaskOut    = isIce ? vec4(0.45, fresnel * 0.55, 1.0, 1.0) : vec4(0.0);
}
