// ==============================================================================
// gbuffers_skybasic — Vertex Shader (Procedural Anime Sky renders in deferred)
// ==============================================================================

#include "/lib/settings.glsl"

out vec4 vColor;

void main() {
    vColor = gl_Color;
    gl_Position = ftransform();
}
