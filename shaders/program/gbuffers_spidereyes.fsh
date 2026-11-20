// ==============================================================================
// gbuffers_spidereyes — Fragment Shader
// Adds vivid anime glowing mob eyes into colortex3 for clean HDR bloom!
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

uniform sampler2D gtexture;

in vec2 vTexCoord;
in vec4 vColor;

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 glowOut;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < 0.05) discard;

    vec3 eyeGlow = adjustSaturation(srgbToLinear(tex.rgb), 1.30) * (2.10 * EMISSIVE_GLOW);
    glowOut = vec4(eyeGlow, tex.a);
}
