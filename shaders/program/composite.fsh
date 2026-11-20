// ==============================================================================
// Composite Pass 0 — Fragment Shader
// 1. Water & Ice Real-Time Screen-Space Reflections (SSR)
// 2. Pastel Anime Aerial Perspective, Horizon Mist & Crystal Underwater Fog
// 3. Volumetric Crepuscular Godrays (Sunbeams & Moonbeams) + Anime Halo Flare
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/constants.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"
#include "/lib/atmosphere/fog.glsl"
#include "/lib/water/waterWaves.glsl"
#include "/lib/water/waterSSR.glsl"
#include "/lib/post/godrays.glsl"

uniform sampler2D colortex0; // Lit HDR Scene (with translucent water/glass/particles)
uniform sampler2D colortex1; // Water/Ice ViewNormal (on translucent) or Opaque ViewNormal + MatID
uniform sampler2D colortex3; // Water/Ice SSR mask (x=strength, y=fresnel, z=depthFade)
uniform sampler2D colortex4; // Clean opaque HDR scene from deferred (for SSR reflection lookup!)
uniform sampler2D depthtex0; // Full depth (including translucent water/hand)
uniform sampler2D depthtex1; // Opaque depth (for godrays & underwater thickness)

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform vec3 endFlashPosition;
uniform float endFlashIntensity;
uniform float frameTimeCounter;
uniform float far;
uniform float aspectRatio;
uniform float rainStrength;
uniform float thunderStrength;
uniform float blindness;
uniform float darknessFactor;
uniform int isEyeInWater;

in vec2 vTexCoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorOut;

void main() {
    vec3 color = texture(colortex0, vTexCoord).rgb;
    float depth0 = texture(depthtex0, vTexCoord).r;
    vec4 normMat = texture(colortex1, vTexCoord);
    vec4 ssrMask = texture(colortex3, vTexCoord);
    float dither = interleavedGradientNoise(gl_FragCoord.xy);

    vec3 sunWorldDir  = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 moonWorldDir = safeNormalize((gbufferModelViewInverse * vec4(moonPosition, 0.0)).xyz);

    AnimeLightingState st = computeAnimeLightingState(
        sunWorldDir,
        moonWorldDir,
        rainStrength,
        thunderStrength,
        endFlashIntensity
    );

    bool isSky  = (depth0 >= 0.9999);
    bool isHand = (!isSky) && isMat(normMat.w, MAT_HAND) && (ssrMask.x < 0.05);

    if (!isSky && !isHand) {
        vec3 viewPos = screenToView(vTexCoord, depth0, gbufferProjectionInverse);
        float viewDist = length(viewPos);
        vec3 viewDir = safeNormalize(viewPos);
        vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 worldDir = safeNormalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);

        // --- 1. Water & Ice Real-Time Screen-Space Reflections (SSR) ---
        if (ssrMask.x > 0.05 && isEyeInWater == 0) {
            bool isWaterSSR = (ssrMask.x > 0.65);
            vec3 reflViewNormal;
            if (ssrMask.x > 0.85) {
                // Recompute flat water wave normal analytically from worldPos for 100% immunity
                // against any G-buffer normal blending or underwater block leakage!
                vec3 worldPos  = playerPos + cameraPosition;
                vec3 waveWNorm = computeWaterWorldNormal(worldPos, vec3(0.0, 1.0, 0.0), viewDist, frameTimeCounter, rainStrength);
                vec3 upVNorm   = safeNormalize(mat3(gbufferModelView) * vec3(0.0, 1.0, 0.0));
                vec3 waveVNorm = safeNormalize(mat3(gbufferModelView) * waveWNorm);
                reflViewNormal = safeNormalize(mix(upVNorm, waveVNorm, 0.55));
            } else {
                reflViewNormal = safeNormalize(normMat.xyz);
            }

            vec4 ssr = traceAnimeSSR(
                viewPos,
                reflViewNormal,
                dither,
                colortex4,
                depthtex0,
                depthtex1,
                gbufferProjection,
                gbufferProjectionInverse,
                gbufferModelViewInverse,
                isWaterSSR
            );
            float maskStrength = isWaterSSR ? 1.0 : ssrMask.x;
            float reflBlend = clamp(ssr.a * maskStrength * ssrMask.y * ssrMask.z * 0.82, 0.0, 0.78);
            color = mix(color, ssr.rgb, reflBlend);
        }

        // --- 2. Pastel Anime Aerial Perspective & Status Fog ---
        // Note: When submerged (isEyeInWater > 0), medium fog is applied accurately per depth layer
        // in deferred.fsh + gbuffers_water.fsh + particles so underwater ice never X-rays!
        if (isEyeInWater == 0) {
            color = applyAnimeFog(
                color,
                playerPos,
                worldDir,
                viewDist,
                far,
                st,
                isEyeInWater,
                blindness,
                darknessFactor
            );
        } else {
            color = applyStatusFog(color, viewDist, blindness, darknessFactor);
        }
    } else if (isSky && isEyeInWater > 0) {
        // Medium fog on sky was already applied in deferred.fsh; only apply status fog here
        color = applyStatusFog(color, far * 0.65, blindness, darknessFactor);
    }

    // --- 3. Volumetric Crepuscular Godrays (Sunbeams & Moonbeams) + Halo Flare ---
#if defined(DIMENSION_END)
    vec3 rayLightViewPos = endFlashPosition;
    float rayScale = clamp(endFlashIntensity, 0.0, 1.0);
#else
    vec3 rayLightViewPos = (sunWorldDir.y >= -0.04) ? sunPosition : moonPosition;
    float rayScale = 1.0;
#endif

    if (rayScale > 0.01 && !isHand) {
        vec3 godrays = computeAnimeGodrays(
            vTexCoord,
            rayLightViewPos,
            st,
            dither,
            depthtex1,
            gbufferProjection,
            aspectRatio,
            isEyeInWater
        );
        color += godrays * rayScale;
    }

    colorOut = vec4(max(color, vec3(0.0)), 1.0);
}
