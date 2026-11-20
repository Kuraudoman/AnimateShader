// ==============================================================================
// gbuffers_skybasic — Fragment Shader
// ==============================================================================

#include "/lib/settings.glsl"

in vec4 vColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorOut;

void main() {
    colorOut = vec4(vColor.rgb, 1.0);
}
