// ==============================================================================
// gbuffers_textured — Fragment Shader (World border & unlit bright particles)
// Renders in Linear HDR directly onto colortex0 after deferred.
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec4 vColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorOut;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < alphaTestRef) discard;

    vec3 linearCol = srgbToLinear(tex.rgb);
    // Give vibrant magical glow to unlit particles & world border
    colorOut = vec4(linearCol * (1.15 + 0.25 * EMISSIVE_GLOW), tex.a);
}
