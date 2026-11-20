// ==============================================================================
// gbuffers_textured_lit & gbuffers_particles — Fragment Shader
// Forward-lit Linear HDR particles with luminous magic/flame/blossom bloom!
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"
#include "/lib/atmosphere/fog.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float far;
uniform float rainStrength;
uniform float thunderStrength;
uniform float endFlashIntensity;
uniform int isEyeInWater;

in vec2 vTexCoord;
in vec2 vLmCoord;
in vec4 vColor;
in vec3 vViewPos;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorOut;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < alphaTestRef) discard;

    vec2 lm = clamp((vLmCoord - 0.03125) / 0.9375, 0.0, 1.0);
    vec3 sunWorldDir  = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 moonWorldDir = safeNormalize((gbufferModelViewInverse * vec4(moonPosition, 0.0)).xyz);
    AnimeLightingState st = computeAnimeLightingState(sunWorldDir, moonWorldDir, rainStrength, thunderStrength, endFlashIntensity);

    vec3 albedoLinear = srgbToLinear(tex.rgb);

    // Smooth ambient + sky + warm blocklight for regular particles (smoke, splashes, petals)
    float skyF = smoothstep(0.04, 0.95, lm.y);
    vec3 envLight = mix(vec3(0.24, 0.28, 0.42) * CAVE_BRIGHTNESS, st.ambientSky + st.directColor * 0.42, skyF);
    envLight += vec3(1.30, 0.88, 0.48) * pow(lm.x, 1.65) * BLOCKLIGHT_STRENGTH;

    // Detect glowing particles (flame, soul fire, end rod, spore, magic crit, fireflies)
    // Minecraft assigns full blocklight (lm.x > 0.92) to self-luminous particles!
    float magicGlow = smoothstep(0.88, 0.99, lm.x);
    vec3 lit = albedoLinear * envLight;
    lit += adjustSaturation(albedoLinear, 1.25) * magicGlow * (1.35 * EMISSIVE_GLOW);

    float outAlpha = tex.a;

    if (isEyeInWater > 0) {
        float viewDist = length(vViewPos);
        vec3 playerPos = (gbufferModelViewInverse * vec4(vViewPos, 1.0)).xyz;
        vec3 worldViewDir = safeNormalize((gbufferModelViewInverse * vec4(safeNormalize(vViewPos), 0.0)).xyz);

        // Vanilla underwater ambient specks are dark sRGB squares that turn pitch-black in linear HDR:
        // lift them into delicate, semi-translucent shimmering aqua motes!
        if (isEyeInWater == 1 && magicGlow < 0.2) {
            float darkMask = 1.0 - smoothstep(0.02, 0.14, luma(albedoLinear));
            vec3 aquaMote = mix(vec3(0.08, 0.34, 0.54) * max(NIGHT_BRIGHTNESS, 1.0), vec3(0.24, 0.70, 0.88), st.dayFactor);
            lit = mix(lit, aquaMote, darkMask * 0.88);
            outAlpha *= mix(1.0, 0.38, darkMask);
        }

        lit = applyAnimeFog(lit, playerPos, worldViewDir, viewDist, far, st, isEyeInWater, 0.0, 0.0);
    }

    colorOut = vec4(max(lit, vec3(0.0)), outAlpha);
}

