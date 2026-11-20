// ==============================================================================
// gbuffers_basic — Vertex Shader (Block outlines via Iris line expansion,
// leashes, debug overlays, untextured geometry)
// ==============================================================================

#include "/lib/settings.glsl"

out vec4 vColor;

void main() {
    vColor = gl_Color;
    gl_Position = ftransform();
}
