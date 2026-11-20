// ==============================================================================
// Final Pass — Fragment Shader
// Combines HDR Scene + Multi-Scale Anime Bloom, balances brightness across day,
// sunset, night, and caves, applies Anime Luminance-Preserving Filmic Tone Map,
// painterly color grading, soft vignette, ordered IGN dithering, and sRGB!
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"
#include "/lib/post/tonemap.glsl"

uniform sampler2D colortex0; // Final Lit HDR Scene
uniform sampler2D colortex6; // Multi-Scale Silky Anime Bloom

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform ivec2 eyeBrightnessSmooth;
uniform float rainStrength;
uniform float thunderStrength;
uniform float endFlashIntensity;

in vec2 vTexCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    vec3 hdrScene = texture(colortex0, vTexCoord).rgb;
    vec3 bloomCol = vec3(0.0);
#ifdef BLOOM_ENABLED
    bloomCol = texture(colortex6, vTexCoord).rgb;
#endif

    vec3 sunWorldDir  = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 moonWorldDir = safeNormalize((gbufferModelViewInverse * vec4(moonPosition, 0.0)).xyz);
    AnimeLightingState st = computeAnimeLightingState(
        sunWorldDir,
        moonWorldDir,
        rainStrength,
        thunderStrength,
        endFlashIntensity
    );

    float dither = interleavedGradientNoise(gl_FragCoord.xy);

    vec3 finalSrgb = applyAnimeColorGrading(
        hdrScene,
        bloomCol,
        vTexCoord,
        dither,
        eyeBrightnessSmooth,
        st.dayFactor,
        st.sunsetFactor,
        st.rainMix
    );

    fragColor = vec4(finalSrgb, 1.0);
}
