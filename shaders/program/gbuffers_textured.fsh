// ==============================================================================
// gbuffers_textured — Fragment Shader (World border & unlit bright particles)
// Renders in Linear HDR directly onto colortex0 after deferred.
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
in vec4 vColor;
in vec3 vViewPos;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorOut;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < alphaTestRef) discard;

    vec3 linearCol = srgbToLinear(tex.rgb) * (1.15 + 0.25 * EMISSIVE_GLOW);

    if (isEyeInWater > 0) {
        vec3 sunWorldDir  = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
        vec3 moonWorldDir = safeNormalize((gbufferModelViewInverse * vec4(moonPosition, 0.0)).xyz);
        AnimeLightingState st = computeAnimeLightingState(sunWorldDir, moonWorldDir, rainStrength, thunderStrength, endFlashIntensity);
        float viewDist = length(vViewPos);
        vec3 playerPos = (gbufferModelViewInverse * vec4(vViewPos, 1.0)).xyz;
        vec3 worldViewDir = safeNormalize((gbufferModelViewInverse * vec4(safeNormalize(vViewPos), 0.0)).xyz);
        linearCol = applyAnimeFog(linearCol, playerPos, worldViewDir, viewDist, far, st, isEyeInWater, 0.0, 0.0);
    }

    // Give vibrant magical glow to unlit particles & world border
    colorOut = vec4(max(linearCol, vec3(0.0)), tex.a);
}

