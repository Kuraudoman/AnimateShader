// ==============================================================================
// gbuffers_clouds — Fragment Shader (Discarded; volumetric anime clouds in deferred)
// ==============================================================================

#include "/lib/settings.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorOut;

void main() {
    discard;
    colorOut = vec4(0.0);
}
