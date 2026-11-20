// ==============================================================================
// gbuffers_basic — Fragment Shader
// Marks untextured lines/overlays as unlit so block selection outlines stay
// crisp, sharp, and always legible.
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/constants.glsl"

in vec4 vColor;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 albedoOut;
layout(location = 1) out vec4 normalMatOut;
layout(location = 2) out vec4 lightExtraOut;

void main() {
    albedoOut     = vColor;
    normalMatOut  = vec4(0.0, 0.0, 1.0, MAT_UNLIT);
    lightExtraOut = vec4(1.0, 1.0, 0.0, 1.0);
}
