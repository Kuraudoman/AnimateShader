// ==============================================================================
// gbuffers_textured_lit & gbuffers_particles — Vertex Shader
// ==============================================================================

#include "/lib/settings.glsl"

out vec2 vTexCoord;
out vec2 vLmCoord;
out vec4 vColor;
out vec3 vViewPos;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLmCoord    = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor      = gl_Color;
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vViewPos    = viewPos.xyz;
    gl_Position = gl_ProjectionMatrix * viewPos;
}

