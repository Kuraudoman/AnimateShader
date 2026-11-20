// ==============================================================================
// gbuffers_skytextured — Fragment Shader (Discarded; procedural sun/moon in deferred)
// ==============================================================================

#include "/lib/settings.glsl"

in vec2 vTexCoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorOut;

void main() {
    discard;
    colorOut = vec4(0.0);
}
