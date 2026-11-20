// ==============================================================================
// gbuffers_weather — Fragment Shader
// Renders airy, silky pastel anime rain streaks and softly glowing snowflakes!
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"

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

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorOut;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < 0.04) discard;

    vec2 lm = clamp((vLmCoord - 0.03125) / 0.9375, 0.0, 1.0);
    vec3 sunWorldDir  = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 moonWorldDir = safeNormalize((gbufferModelViewInverse * vec4(moonPosition, 0.0)).xyz);
    AnimeLightingState st = computeAnimeLightingState(sunWorldDir, moonWorldDir, rainStrength, thunderStrength, endFlashIntensity);

    // Light pastel sky-matched hue with warm lantern shimmer when near torches
    vec3 baseCol = srgbToLinear(tex.rgb);
    vec3 envCol = mix(st.ambientSky * 0.95, st.skyHorizon * 1.10, 0.55) * (0.35 + 0.65 * lm.y);
    envCol += vec3(1.25, 0.88, 0.52) * pow(lm.x, 1.8) * 0.85;

    // Make raindrops delicate & translucent rather than harsh opaque lines
    colorOut = vec4(baseCol * envCol * 1.15, tex.a * 0.58);
}
