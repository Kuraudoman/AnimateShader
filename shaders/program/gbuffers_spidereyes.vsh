// ==============================================================================
// gbuffers_spidereyes — Vertex Shader (Glowing Spider / Enderman / Dragon Eyes)
// ==============================================================================

#include "/lib/settings.glsl"

out vec2 vTexCoord;
out vec4 vColor;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor      = gl_Color;
    gl_Position = ftransform();
}
