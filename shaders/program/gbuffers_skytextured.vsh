// ==============================================================================
// gbuffers_skytextured — Vertex Shader (Custom anime sun/moon rendered in deferred)
// ==============================================================================

#include "/lib/settings.glsl"

out vec2 vTexCoord;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gl_Position = ftransform();
}
