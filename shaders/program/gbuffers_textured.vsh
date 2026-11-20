// ==============================================================================
// gbuffers_textured — Vertex Shader (World border & unlit glowing particles)
// ==============================================================================

#include "/lib/settings.glsl"

out vec2 vTexCoord;
out vec4 vColor;
out vec3 vViewPos;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor      = gl_Color;
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vViewPos    = viewPos.xyz;
    gl_Position = gl_ProjectionMatrix * viewPos;
}

