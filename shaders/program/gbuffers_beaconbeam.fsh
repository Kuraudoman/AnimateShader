// ==============================================================================
// gbuffers_beaconbeam — Fragment Shader
// Projects a dazzling luminous anime pillar with rich HDR bloom aura!
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/constants.glsl"
#include "/lib/common/math.glsl"

uniform sampler2D gtexture;

in vec2 vTexCoord;
in vec4 vColor;

/* RENDERTARGETS: 0,2,3 */
layout(location = 0) out vec4 albedoOut;
layout(location = 1) out vec4 lightExtraOut;
layout(location = 2) out vec4 glowOut;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < 0.05) discard;

    vec3 linearCol = srgbToLinear(tex.rgb);
    vec3 radiantGlow = adjustSaturation(linearCol, 1.25) * (1.85 * EMISSIVE_GLOW);

    albedoOut     = tex;
    lightExtraOut = vec4(1.0, 1.0, EMIS_STAR_PEARL, 1.0);
    glowOut       = vec4(radiantGlow, tex.a);
}
