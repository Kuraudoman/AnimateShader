// ==============================================================================
// Deferred Pass — Fragment Shader
// 1. Renders procedural Makoto Shinkai Anime Sky + Volumetric Clouds on sky pixels.
// 2. Computes full Anime Fantasy deferred lighting (soft colored Vogel-disk PCF
//    shadows, hue-shifted shadows, SSS foliage, rim light, SSAO, colorful block
//    lights, dynamic dual-hand light, underwater caustics, and additive glint).
// 3. Outputs Lit Linear HDR scene to colortex0 AND clean copy to colortex4 for
//    water refraction & SSR, and resets colortex3 to 0 for translucent pass!
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

uniform sampler2D colortex0; // Albedo sRGB
uniform sampler2D colortex1; // ViewNormal.xyz + MatID.w
uniform sampler2D colortex2; // Lightmap.xy + Extra.z + Emissive.w
uniform sampler2D colortex3; // Additive HDR glow (glint, spider eyes, beacon)
uniform sampler2D depthtex0;

#if !defined(DIMENSION_NETHER)
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
#endif

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float far;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;
uniform float thunderStrength;
uniform float nightVision;
uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform float endFlashIntensity;
uniform vec3 endFlashPosition;

in vec2 vTexCoord;

/* RENDERTARGETS: 0,3,4 */
layout(location = 0) out vec4 sceneColorOut;
layout(location = 1) out vec4 resetAuxOut;
layout(location = 2) out vec4 opaqueCopyOut;

void main() {
    float depth = texture(depthtex0, vTexCoord).r;
    float dither = interleavedGradientNoise(gl_FragCoord.xy);

    // Compute world-space celestial directions & smooth anime fantasy lighting state
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

    // In The End, align directional light with MC 26.3 End Flash when active!
#if defined(DIMENSION_END)
    if (endFlashIntensity > 0.02 && length(endFlashPosition) > 0.1) {
        st.activeLightDir = safeNormalize(mix(st.activeLightDir, endFlashDir, clamp(endFlashIntensity, 0.0, 1.0)));
    }
#endif

    // --- SKY PIXELS: Procedural Anime Fantasy Sky Dome + Volumetric Clouds ---
    if (depth >= 0.9999) {
        vec3 viewPosFar = screenToView(vTexCoord, 1.0, gbufferProjectionInverse);
        vec3 worldDir = safeNormalize((gbufferModelViewInverse * vec4(viewPosFar, 0.0)).xyz);

        vec3 skyCol = renderAnimeSky(worldDir, st, frameTimeCounter, endFlashIntensity, endFlashDir);

        // Layer Makoto Shinkai painterly volumetric clouds over Overworld sky
        vec4 clouds = renderAnimeClouds(worldDir, cameraPosition, st, frameTimeCounter, dither);
        skyCol = skyCol * (1.0 - clouds.a) + clouds.rgb;

        // When submerged, apply medium fog before translucents (ice/glass/water) draw
        // so distant sky behind underwater ice never X-rays through!
        if (isEyeInWater > 0) {
            skyCol = applyAnimeFog(
                skyCol,
                worldDir * far,
                worldDir,
                far * 0.65,
                far,
                st,
                isEyeInWater,
                0.0,
                0.0
            );
        }

        sceneColorOut = vec4(skyCol, 1.0);
        resetAuxOut   = vec4(0.0, 0.0, 0.0, 1.0);
        opaqueCopyOut = vec4(skyCol, 1.0);
        return;
    }

    // --- OPAQUE SURFACE PIXELS: Full Deferred Anime Fantasy Lighting ---
    vec4 albedoSample = texture(colortex0, vTexCoord);
    vec4 normMat      = texture(colortex1, vTexCoord);
    vec4 lightExtra   = texture(colortex2, vTexCoord);
    vec3 additiveGlow = texture(colortex3, vTexCoord).rgb;

    vec3 albedoLinear = srgbToLinear(albedoSample.rgb);
    vec3 viewNormal   = safeNormalize(normMat.xyz);
    float matId       = normMat.w;
    vec2 lightmap     = lightExtra.xy;
    float matExtra    = lightExtra.z;
    float emissiveVal = lightExtra.w;

    bool isHand  = isMat(matId, MAT_HAND);
    bool isUnlit = isMat(matId, MAT_UNLIT);

    vec3 viewPos = screenToView(vTexCoord, depth, gbufferProjectionInverse);
    float viewDist = length(viewPos);
    vec3 viewDir = safeNormalize(viewPos);

    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 worldPos      = feetPlayerPos + cameraPosition;
    vec3 worldNormal   = safeNormalize((gbufferModelViewInverse * vec4(viewNormal, 0.0)).xyz);
    vec3 worldViewDir  = safeNormalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);

    // Shadow sampling (skipped for hand, unlit overlays, and Nether)
    vec3 shadowTrans = vec3(1.0);
#if !defined(DIMENSION_NETHER)
    if (!isHand && !isUnlit) {
        vec3 shadowLightWorldDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);
    #if defined(DIMENSION_END)
        // Cast dynamic End Flash shadows when an End Flash occurs
        if (endFlashIntensity > 0.05) {
            shadowTrans = computeAnimeShadow(
                feetPlayerPos,
                worldNormal,
                shadowLightWorldDir,
                1.0,
                dither,
                shadowtex0,
                shadowtex1,
                shadowcolor0,
                shadowModelView,
                shadowProjection
            );
            shadowTrans = mix(vec3(1.0), shadowTrans, clamp(endFlashIntensity * 1.2, 0.0, 1.0));
        }
    #else
        shadowTrans = computeAnimeShadow(
            feetPlayerPos,
            worldNormal,
            shadowLightWorldDir,
            lightmap.y,
            dither,
            shadowtex0,
            shadowtex1,
            shadowcolor0,
            shadowModelView,
            shadowProjection
        );
    #endif
    }
#endif

    // Gentle anime screen-space ambient occlusion (skipped on hand & unlit overlays)
    float aoFactor = 1.0;
    if (!isHand && !isUnlit) {
        aoFactor = computeAnimeSSAO(
            vTexCoord,
            viewPos,
            viewNormal,
            dither,
            depthtex0,
            gbufferProjection,
            gbufferProjectionInverse
        );
    }

    vec3 litColor = shadeAnimeSurface(
        albedoLinear,
        worldNormal,
        viewNormal,
        viewDir,
        worldViewDir,
        viewDist,
        lightmap,
        matId,
        matExtra,
        emissiveVal,
        shadowTrans,
        aoFactor,
        st,
        wetness,
        nightVision,
        heldBlockLightValue,
        heldBlockLightValue2,
        worldPos,
        frameTimeCounter
    );

    // Sparkling underwater caustics when the player is submerged
    if (isEyeInWater == 1 && !isHand && !isUnlit) {
        float caust = computeUnderwaterCaustics(worldPos, st.activeLightDir, frameTimeCounter);
        float upFace = clamp(worldNormal.y * 0.7 + 0.3, 0.0, 1.0);
        float caustFade = exp(-viewDist * 0.032) * smoothstep(0.15, 0.85, lightmap.y);
        vec3 caustCol = mix(vec3(0.32, 0.86, 1.15), vec3(0.55, 1.08, 1.22), st.dayFactor);
        litColor += albedoLinear * caustCol * caust * upFace * caustFade * luma(shadowTrans) * 0.75;
    }

    // Add glowing enchantment glint, mob eyes, and beacon energy from colortex3
    litColor += additiveGlow;

    // Apply accurate distance-based underwater/lava/snow fog to opaque terrain BEFORE
    // translucents (ice/glass/water) draw so distant mountains never X-ray through ice!
    if (isEyeInWater > 0 && !isHand) {
        litColor = applyAnimeFog(
            litColor,
            feetPlayerPos,
            worldViewDir,
            viewDist,
            far,
            st,
            isEyeInWater,
            0.0,
            0.0
        );
    }

    sceneColorOut = vec4(litColor, 1.0);
    resetAuxOut   = vec4(0.0, 0.0, 0.0, 1.0);
    opaqueCopyOut = vec4(litColor, 1.0);
}

