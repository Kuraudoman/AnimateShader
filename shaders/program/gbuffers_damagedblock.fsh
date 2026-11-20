// ==============================================================================
// gbuffers_damagedblock — Fragment Shader
// Writes only to colortex0 so normals and lightmaps underneath stay intact.
// ==============================================================================

#include "/lib/settings.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec4 vColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 albedoOut;

void main() {
    vec4 color = texture(gtexture, vTexCoord) * vColor;
    if (color.a < alphaTestRef) {
        discard;
    }
    albedoOut = color;
}
