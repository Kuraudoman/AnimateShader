// ==============================================================================
// gbuffers_hand_water — Fragment Shader (Forward-lit HDR translucent held items)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"
#include "/lib/lighting/shading.glsl"

uniform sampler2D gtexture;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float rainStrength;
uniform float thunderStrength;
uniform float endFlashIntensity;

in vec2 vTexCoord;
in vec2 vLmCoord;
in vec4 vColor;
in vec3 vViewNormal;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorOut;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < 0.02) discard;

    vec2 lm = clamp((vLmCoord - 0.03125) / 0.9375, 0.0, 1.0);
    vec3 sunWorldDir  = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 moonWorldDir = safeNormalize((gbufferModelViewInverse * vec4(moonPosition, 0.0)).xyz);
    AnimeLightingState st = computeAnimeLightingState(sunWorldDir, moonWorldDir, rainStrength, thunderStrength, endFlashIntensity);

    vec3 wNorm = safeNormalize((gbufferModelViewInverse * vec4(safeNormalize(vViewNormal), 0.0)).xyz);
    float diff = animeDiffuseRamp(dot(wNorm, st.activeLightDir), false);
    float skyF = smoothstep(0.05, 0.95, lm.y);

    vec3 light = st.directColor * diff * (0.35 + 0.65 * skyF)
               + mix(vec3(0.24, 0.28, 0.42) * CAVE_BRIGHTNESS, st.ambientSky, skyF)
               + vec3(1.25, 0.84, 0.46) * pow(lm.x, 1.8) * BLOCKLIGHT_STRENGTH;

    colorOut = vec4(srgbToLinear(tex.rgb) * light, tex.a);
}
