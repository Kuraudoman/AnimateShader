#ifndef ANIMATE_SHADOWS_GLSL
#define ANIMATE_SHADOWS_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/shadowDistort.glsl"

// ==============================================================================
// Soft Vogel-Disk PCF Shadows + Stained-Glass Colored Shadow Transmission
// Supports Overworld sunlight, soft moonlight shadows, and MC 26.3 End Flashes.
// ==============================================================================

#if !defined(DIMENSION_NETHER)

// Returns vec3 shadow transmission:
//   vec3(1.0) = fully lit
//   vec3(0.0) = opaque shadow
//   colored   = sunlight filtered through stained glass / translucent crystals
vec3 computeAnimeShadow(
    vec3 feetPlayerPos,
    vec3 worldNormal,
    vec3 worldLightDir,
    float skyLight,
    float dither,
    sampler2D shadowTexAll,
    sampler2D shadowTexOpaque,
    sampler2D shadowColTex,
    mat4 shadowMV,
    mat4 shadowProj
) {
    // Smooth distance fade approaching shadowDistance so there is never a hard cutoff line
    float horizDist = length(feetPlayerPos.xz);
    float distFade = 1.0 - smoothstep(shadowDistance * 0.78, shadowDistance * 0.98, horizDist);
    if (distFade <= 0.001) {
        return vec3(smoothstep(0.35, 0.85, skyLight));
    }

    // Normal-offset bias eliminates shadow acne cleanly even at grazing angles
    float NdotL = dot(worldNormal, worldLightDir);
    float normalBiasScale = mix(0.14, 0.04, clamp(NdotL, 0.0, 1.0));
    vec3 biasedPlayerPos = feetPlayerPos + worldNormal * normalBiasScale + worldLightDir * 0.03;

    vec3 shadowViewPos = (shadowMV * vec4(biasedPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProj * vec4(shadowViewPos, 1.0);
    vec3 shadowNDC = shadowClipPos.xyz / max(shadowClipPos.w, 1e-6);

    float distortFactor = getShadowDistortFactor(shadowNDC.xy);
    vec3 distortedNDC = distortShadowClipPos(shadowNDC);
    vec3 shadowScreenPos = distortedNDC * 0.5 + 0.5;

    // Out of shadow frustum -> graceful fallback to skylight
    if (shadowScreenPos.x <= 0.002 || shadowScreenPos.x >= 0.998 ||
        shadowScreenPos.y <= 0.002 || shadowScreenPos.y >= 0.998 ||
        shadowScreenPos.z <= 0.0   || shadowScreenPos.z >= 0.999) {
        return vec3(smoothstep(0.35, 0.85, skyLight));
    }

    // Distortion-aware depth bias
    float depthBias = (0.00055 + 0.00075 * (1.0 - max(NdotL, 0.0))) * distortFactor * (2048.0 / float(shadowMapResolution));
    float compareZ = shadowScreenPos.z - depthBias;

    #if SHADOW_QUALITY == 0
        const int SAMPLES = 4;
        float radiusTexels = 1.25;
    #elif SHADOW_QUALITY == 1
        const int SAMPLES = 9;
        float radiusTexels = 1.85;
    #else
        const int SAMPLES = 16;
        float radiusTexels = 2.35;
    #endif

    float texelSize = 1.0 / float(shadowMapResolution);
    float radius = radiusTexels * texelSize / max(distortFactor * 0.75, 0.35);
    float phi = dither * TAU;

    vec3 shadowAccum = vec3(0.0);

    for (int i = 0; i < SAMPLES; i++) {
        vec2 offset = vogelDiskSample(i, SAMPLES, phi) * radius;
        vec2 sampleUV = clamp(shadowScreenPos.xy + offset, vec2(0.001), vec2(0.999));

        float opaqueDepth = texture(shadowTexOpaque, sampleUV).r;
        float opaqueLit = step(compareZ, opaqueDepth);

#ifdef COLORED_SHADOWS
        if (opaqueLit > 0.5) {
            float allDepth = texture(shadowTexAll, sampleUV).r;
            if (compareZ > allDepth) {
                // Light passed through a translucent block (stained glass, ice, water)
                vec4 sc = texture(shadowColTex, sampleUV);
                // Convert sRGB stained glass color to rich linear transmitted light
                vec3 glassTint = pow(max(sc.rgb, vec3(0.02)), vec3(1.8));
                float opacity = clamp(sc.a, 0.0, 1.0);
                // Vibrant anime stained-glass transmission (never overly darkened!)
                vec3 transmitted = mix(vec3(1.0), glassTint * 1.35, clamp(opacity * 0.85, 0.15, 0.85));
                shadowAccum += transmitted;
            } else {
                shadowAccum += vec3(1.0);
            }
        }
#else
        shadowAccum += vec3(opaqueLit);
#endif
    }

    vec3 shadowColor = shadowAccum / float(SAMPLES);
    vec3 fallback = vec3(smoothstep(0.35, 0.85, skyLight));
    return mix(fallback, shadowColor, distFade);
}

// Fast 4-tap Vogel-disk opaque shadow check for translucent water caustics, sparkles & shallow tint
// Samples shadowtex1 (opaque-only) so water surfaces never self-shadow the seabed below.
float sampleOpaqueShadowPCF4(
    vec3 feetPlayerPos,
    vec3 worldNormal,
    vec3 worldLightDir,
    float skyLight,
    float dither,
    sampler2D shadowTexOpaque,
    mat4 shadowMV,
    mat4 shadowProj
) {
    float horizDist = length(feetPlayerPos.xz);
    float distFade = 1.0 - smoothstep(shadowDistance * 0.78, shadowDistance * 0.98, horizDist);
    float fallback = smoothstep(0.35, 0.85, skyLight);
    if (distFade <= 0.001) {
        return fallback;
    }

    float NdotL = dot(worldNormal, worldLightDir);
    float normalBiasScale = mix(0.14, 0.04, clamp(NdotL, 0.0, 1.0));
    vec3 biasedPlayerPos = feetPlayerPos + worldNormal * normalBiasScale + worldLightDir * 0.03;

    vec3 shadowViewPos = (shadowMV * vec4(biasedPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProj * vec4(shadowViewPos, 1.0);
    vec3 shadowNDC = shadowClipPos.xyz / max(shadowClipPos.w, 1e-6);

    float distortFactor = getShadowDistortFactor(shadowNDC.xy);
    vec3 distortedNDC = distortShadowClipPos(shadowNDC);
    vec3 shadowScreenPos = distortedNDC * 0.5 + 0.5;

    if (shadowScreenPos.x <= 0.002 || shadowScreenPos.x >= 0.998 ||
        shadowScreenPos.y <= 0.002 || shadowScreenPos.y >= 0.998 ||
        shadowScreenPos.z <= 0.0   || shadowScreenPos.z >= 0.999) {
        return fallback;
    }

    float depthBias = (0.00060 + 0.00080 * (1.0 - max(NdotL, 0.0))) * distortFactor * (2048.0 / float(shadowMapResolution));
    float compareZ = shadowScreenPos.z - depthBias;

    float texelSize = 1.0 / float(shadowMapResolution);
    float radius = 1.50 * texelSize / max(distortFactor * 0.75, 0.35);
    float phi = dither * TAU;

    float shadowAccum = 0.0;
    for (int i = 0; i < 4; i++) {
        vec2 offset = vogelDiskSample(i, 4, phi) * radius;
        vec2 sampleUV = clamp(shadowScreenPos.xy + offset, vec2(0.001), vec2(0.999));
        float opaqueDepth = texture(shadowTexOpaque, sampleUV).r;
        shadowAccum += step(compareZ, opaqueDepth);
    }

    return mix(fallback, shadowAccum * 0.25, distFade);
}

#endif

#endif
