// ==============================================================================
// gbuffers_entities — Vertex Shader (Players, mobs, dropped items, nametags)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

out vec2 vTexCoord;
out vec2 vLmCoord;
out vec4 vColor;
out vec3 vViewNormal;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLmCoord    = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor      = gl_Color;
    vViewNormal = safeNormalize(gl_NormalMatrix * gl_Normal);
    gl_Position = ftransform();
}
