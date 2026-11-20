// ==============================================================================
// Composite / Bloom / Final — Shared Fullscreen Quad Vertex Shader
// ==============================================================================

#include "/lib/settings.glsl"

out vec2 vTexCoord;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gl_Position = ftransform();
}
